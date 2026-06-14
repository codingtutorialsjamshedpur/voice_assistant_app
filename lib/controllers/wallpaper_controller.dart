import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import '../services/supabase_service.dart';
import '../models/wallpaper_model.dart';
import '../services/history_logger_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/foundation.dart';

class WallpaperController extends GetxController {
  static WallpaperController get to => Get.find();

  final _box = GetStorage();

  // Keys for storage
  static const String _currentWallpaperKey = 'current_wallpaper';
  static const String _customWallpapersKey = 'custom_wallpapers';
  static const String _blurIntensityKey = 'wallpaper_blur_intensity';
  static const String _defaultWallpaperPath =
      'assets/images/Wallpaper_default.png';
  static const String _storageBucket = 'wallpapers';

  static const int _maxCustomStaticWallpapers = 5;
  static const int _maxCustomDynamicWallpapers = 5;

  // Observable states
  final Rx<Wallpaper?> currentWallpaper = Rx<Wallpaper?>(null);
  final RxList<Wallpaper> assetWallpapers = <Wallpaper>[].obs;
  final RxList<Wallpaper> networkWallpapers = <Wallpaper>[].obs;
  final RxList<Wallpaper> customWallpapers = <Wallpaper>[].obs;
  final RxList<String> selectedWallpaperIds = <String>[].obs;
  final RxBool isMultiSelectMode = false.obs;
  final RxDouble blurIntensity = 2.0.obs;
  final RxDouble downloadProgress = 0.0.obs;
  final RxBool isDownloading = false.obs;
  final RxBool isLoading = false.obs;

  /// True only while a user-triggered setWallpaper() is in flight.
  /// Used by AppBackground to show the blur/loading overlay without
  /// flickering on silent background initialisation.
  final RxBool isApplying = false.obs;

  // Video caching
  final Rx<VideoPlayerController?> cachedVideoController =
      Rx<VideoPlayerController?>(null);
  final RxString cachedVideoPath = ''.obs;
  final RxBool isVideoLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeWallpapers();
  }

  Future<void> _initializeWallpapers() async {
    isLoading.value = true;

    try {
      // Scan asset wallpapers
      await _scanAssetWallpapers();

      // Scan network wallpapers from Supabase
      await _scanNetworkWallpapers();

      // Load custom wallpapers
      await _loadCustomWallpapers();

      // Load saved wallpaper settings
      await _loadSavedSettings();
    } catch (e) {
      debugPrint('Error initializing wallpapers: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _scanAssetWallpapers() async {
    final wallpapers = <Wallpaper>[];

    // Only include the default wallpaper from assets.
    // All other wallpapers should come from network/Supabase.
    wallpapers.add(Wallpaper.fromAsset(_defaultWallpaperPath, isDefault: true));

    assetWallpapers.value = wallpapers;
  }

  Future<void> _scanNetworkWallpapers() async {
    try {
      final supabase = Get.find<SupabaseService>().client;
      final response = await supabase.from('wallpapers_metadata').select();

      if (response.isEmpty) {
        debugPrint('No network wallpapers found in database');
        return;
      }

      final List<Wallpaper> fetched = [];
      for (final row in response) {
        try {
          final fileName = row['file_path'] as String;
          final dbName = row['name'] as String?;
          final dbType = row['type'] as String?;

          Wallpaper wallpaper = Wallpaper.fromNetwork(
            fileName,
            fileName, // This is the storage path/name
            isDefault: row['is_default'] ?? false,
          );

          // Overwrite with DB values if available
          if (dbName != null && dbName.isNotEmpty) {
            wallpaper = wallpaper.copyWith(name: dbName);
          }
          if (dbType != null && dbType.isNotEmpty) {
            wallpaper = wallpaper.copyWith(
                type: dbType == 'video'
                    ? WallpaperType.video
                    : WallpaperType.image);
          }

          // Check if already downloaded
          final localPath = await _getLocalStoragePath(wallpaper);
          if (File(localPath).existsSync()) {
            fetched.add(wallpaper.copyWith(
              path: localPath,
              source: WallpaperSource.file,
            ));
          } else {
            fetched.add(wallpaper);
          }
        } catch (e) {
          debugPrint('Error parsing wallpaper row: $e');
        }
      }

      networkWallpapers.assignAll(fetched);
      debugPrint('Sync completed: ${fetched.length} network wallpapers found');
    } catch (e) {
      debugPrint('Error scanning network wallpapers: $e');
    }
  }

  Future<String> _getLocalStoragePath(Wallpaper wallpaper) async {
    final appDir = await getApplicationDocumentsDirectory();
    final wallpapersDir = Directory('${appDir.path}/network_wallpapers');
    if (!wallpapersDir.existsSync()) {
      wallpapersDir.createSync(recursive: true);
    }
    // Extract filename from path or ID
    final fileName = wallpaper.id.replaceFirst('network_', '');
    final nameWithoutSpace = fileName.replaceAll(' ', '_');
    return '${wallpapersDir.path}/$nameWithoutSpace';
  }

  /// Check if a network wallpaper exists locally
  bool isDownloaded(Wallpaper wallpaper) {
    if (wallpaper.isAsset) return true;
    if (wallpaper.isFile) return true;

    // For network wallpapers, check if we have it in the local cache
    return wallpaper.source == WallpaperSource.file;
  }

  String getPublicUrl(Wallpaper wallpaper) {
    if (!wallpaper.isNetwork) return '';
    final supabase = Get.find<SupabaseService>().client;
    return supabase.storage.from(_storageBucket).getPublicUrl(wallpaper.path);
  }

  Future<Wallpaper> downloadWallpaper(Wallpaper wallpaper) async {
    if (!wallpaper.isNetwork) return wallpaper;

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      final localPath = await _getLocalStoragePath(wallpaper);
      final supabase = Get.find<SupabaseService>().client;

      // Get public URL
      final publicUrl =
          supabase.storage.from(_storageBucket).getPublicUrl(wallpaper.path);

      // Download using Dio for progress
      final dio = Dio();
      await dio.download(
        publicUrl,
        localPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
          }
        },
      );

      final downloadedWallpaper = wallpaper.copyWith(
        path: localPath,
        source: WallpaperSource.file,
      );

      // Update in list
      final index = networkWallpapers.indexWhere((w) => w.id == wallpaper.id);
      if (index != -1) {
        networkWallpapers[index] = downloadedWallpaper;
      }

      return downloadedWallpaper;
    } catch (e) {
      debugPrint('Download failed: $e');
      rethrow;
    } finally {
      isDownloading.value = false;
      downloadProgress.value = 0.0;
    }
  }

  Future<void> _loadCustomWallpapers() async {
    try {
      final savedData = _box.read<List<dynamic>>(_customWallpapersKey);
      if (savedData != null) {
        customWallpapers.value = savedData
            .map((item) => Wallpaper.fromJson(Map<String, dynamic>.from(item)))
            .where((wallpaper) => File(wallpaper.path).existsSync())
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading custom wallpapers: $e');
      customWallpapers.clear();
    }
  }

  Future<void> _loadSavedSettings() async {
    // Load blur intensity
    blurIntensity.value = _box.read<double>(_blurIntensityKey) ?? 2.0;

    // Load current wallpaper
    final savedWallpaper =
        _box.read<Map<String, dynamic>?>(_currentWallpaperKey);

    if (savedWallpaper != null) {
      try {
        final wallpaper = Wallpaper.fromJson(savedWallpaper);

        // Verify the wallpaper still exists
        bool exists = false;
        if (wallpaper.isAsset) {
          exists = true; // Assets always exist
        } else if (wallpaper.isFile) {
          exists = File(wallpaper.path).existsSync();
        } else if (wallpaper.isNetwork) {
          // If it's a network wallpaper, check if we have a local cached version
          final localPath = await _getLocalStoragePath(wallpaper);
          if (File(localPath).existsSync()) {
            currentWallpaper.value = wallpaper.copyWith(
              path: localPath,
              source: WallpaperSource.file,
            );
            exists = true;
          } else {
            // It's a network wallpaper but not downloaded.
            // We can still set it as current, and AppBackground should handle the placeholder/loading.
            // But usually we set current wallpaper only after download.
            currentWallpaper.value = wallpaper;
            exists = true;
          }
        }

        if (exists) {
          if (currentWallpaper.value == null) {
            currentWallpaper.value = wallpaper;
          }

          // Preload video if it's a video wallpaper
          if (currentWallpaper.value!.isVideo) {
            await _preloadVideo(currentWallpaper.value!);
          }
        } else {
          // Reset to default if custom wallpaper no longer exists
          await resetToDefault();
        }
      } catch (e) {
        debugPrint('Error loading saved wallpaper: $e');
        await resetToDefault();
      }
    } else {
      // Set default wallpaper if none saved
      await resetToDefault();
    }
  }

  /// Preload and cache video controller for instant playback across screens
  Future<void> _preloadVideo(Wallpaper wallpaper) async {
    if (cachedVideoPath.value == wallpaper.path &&
        cachedVideoController.value != null) {
      // Already cached, just update volume
      _applyVolumeSettings(wallpaper);
      return;
    }

    isVideoLoading.value = true;

    try {
      // Dispose old controller
      await _disposeCachedController();

      // Create new controller
      VideoPlayerController newController;
      final options = VideoPlayerOptions(
          mixWithOthers:
              true); // WP-02: Prevent video from stopping when audio plays
      if (wallpaper.isAsset) {
        newController = VideoPlayerController.asset(wallpaper.path,
            videoPlayerOptions: options);
      } else {
        newController = VideoPlayerController.file(File(wallpaper.path),
            videoPlayerOptions: options);
      }

      // Initialize with optimized settings
      await newController.initialize();
      newController.setLooping(true);

      // Apply volume settings from wallpaper
      _applyVolumeToController(newController, wallpaper);

      // Preload by playing briefly then pausing at first frame
      await newController.play();
      await Future.delayed(const Duration(milliseconds: 100));
      await newController.pause();

      // Update cache
      cachedVideoController.value = newController;
      cachedVideoPath.value = wallpaper.path;

      debugPrint(
          'Video wallpaper cached successfully: ${wallpaper.name} with volume: ${wallpaper.effectiveVolume}');
    } catch (e) {
      debugPrint('Error preloading video: $e');
      await _disposeCachedController();
    } finally {
      isVideoLoading.value = false;
    }
  }

  /// Apply volume settings to current cached controller
  void _applyVolumeSettings(Wallpaper wallpaper) {
    final controller = cachedVideoController.value;
    if (controller != null && controller.value.isInitialized) {
      _applyVolumeToController(controller, wallpaper);
    }
  }

  /// Apply volume to a video controller
  void _applyVolumeToController(
      VideoPlayerController controller, Wallpaper wallpaper) {
    final volume = wallpaper.effectiveVolume;
    controller.setVolume(volume);
    debugPrint('Applied volume: $volume (muted: ${wallpaper.isMuted})');
  }

  /// Update wallpaper volume settings
  Future<void> setWallpaperVolume(double volume, {bool? isMuted}) async {
    final current = currentWallpaper.value;
    if (current == null || !current.isVideo) return;

    // Clamp volume between 0.0 and 1.0
    final clampedVolume = volume.clamp(0.0, 1.0);
    final muted = isMuted ?? (clampedVolume == 0.0);

    // Update the wallpaper with new volume settings
    final updatedWallpaper = current.copyWith(
      volume: clampedVolume,
      isMuted: muted,
    );

    // Save and apply
    currentWallpaper.value = updatedWallpaper;
    await _box.write(_currentWallpaperKey, updatedWallpaper.toJson());

    // Apply to cached controller immediately
    _applyVolumeSettings(updatedWallpaper);

    debugPrint('Volume updated: ${clampedVolume * 100}% (muted: $muted)');
  }

  /// Toggle mute state for current wallpaper
  Future<void> toggleMute() async {
    final current = currentWallpaper.value;
    if (current == null || !current.isVideo) return;

    final updatedWallpaper = current.copyWith(
      isMuted: !current.isMuted,
    );

    currentWallpaper.value = updatedWallpaper;
    await _box.write(_currentWallpaperKey, updatedWallpaper.toJson());

    // Apply to cached controller immediately
    _applyVolumeSettings(updatedWallpaper);

    Get.snackbar(
      updatedWallpaper.isMuted ? 'Muted' : 'Unmuted',
      updatedWallpaper.isMuted
          ? 'Video wallpaper is now muted'
          : 'Volume set to ${(updatedWallpaper.volume * 100).toInt()}%',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: updatedWallpaper.isMuted
          ? Colors.grey.withAlpha(204)
          : Colors.green.withAlpha(204),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _disposeCachedController() async {
    if (cachedVideoController.value != null) {
      await cachedVideoController.value!.dispose();
      cachedVideoController.value = null;
      cachedVideoPath.value = '';
    }
  }

  Future<void> setWallpaper(Wallpaper wallpaper,
      {bool fromUser = false}) async {
    // 1. Show the global blur loading overlay when user picks a wallpaper
    if (fromUser) isApplying.value = true;
    isLoading.value = true;

    try {
      await HistoryLoggerService().logWallpaperActivity(
        wallpaperName: wallpaper.name,
      );

      // 2. DOWNLOAD IF NETWORK
      Wallpaper targetWallpaper = wallpaper;
      if (wallpaper.isNetwork) {
        targetWallpaper = await downloadWallpaper(wallpaper);
      }

      // 3. Pre-cache the assets BEFORE updating UI
      if (targetWallpaper.isVideo) {
        await _preloadVideo(targetWallpaper);
      } else {
        // Wait until image is decoded to prevent blank flashes
        if (Get.context != null) {
          final ImageProvider provider = targetWallpaper.isAsset
              ? AssetImage(targetWallpaper.path) as ImageProvider
              : FileImage(File(targetWallpaper.path)) as ImageProvider;

          await precacheImage(provider, Get.context!);
        } else {
          // Fallback delay if no context
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Dispose video controller if switching to image
        await _disposeCachedController();
      }

      // 4. Now that assets are cached, apply wallpaper to trigger AnimatedSwitcher
      currentWallpaper.value = targetWallpaper;
      await _box.write(_currentWallpaperKey, targetWallpaper.toJson());

      // 4. Important: Give Flutter engine a frame to swap memory under the overlay
      await Future.delayed(const Duration(milliseconds: 100));

      if (fromUser) {
        Get.snackbar(
          'Wallpaper Applied',
          '${wallpaper.name} has been set as your background',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withAlpha(204),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint('Error setting wallpaper: $e');
      if (fromUser) {
        Get.snackbar(
          'Error',
          'Failed to apply wallpaper',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withAlpha(204),
          colorText: Colors.white,
        );
      }
    } finally {
      isLoading.value = false;
      isApplying.value = false;
    }
  }

  Future<void> setBlurIntensity(double intensity) async {
    blurIntensity.value = intensity.clamp(0.0, 20.0);
    await _box.write(_blurIntensityKey, blurIntensity.value);
  }

  Future<void> resetToDefault() async {
    final defaultWallpaper =
        Wallpaper.fromAsset(_defaultWallpaperPath, isDefault: true);
    await setWallpaper(defaultWallpaper);
  }

  Future<void> addCustomWallpaper(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File does not exist');
      }

      // Copy to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final wallpapersDir = Directory('${appDir.path}/custom_wallpapers');
      if (!wallpapersDir.existsSync()) {
        wallpapersDir.createSync(recursive: true);
      }

      final fileName = filePath.split(Platform.pathSeparator).last;
      final newPath = '${wallpapersDir.path}/$fileName';

      // Only copy if the file isn't already in the target directory
      if (filePath != newPath) {
        await file.copy(newPath);
      }

      // Create wallpaper
      final wallpaper = Wallpaper.fromFile(newPath);
      customWallpapers.add(wallpaper);

      // Save custom wallpapers list
      await _saveCustomWallpapers();

      Get.snackbar(
        'Success',
        'Wallpaper added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Error adding custom wallpaper: $e');
      Get.snackbar(
        'Error',
        'Failed to add wallpaper: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  Future<void> deleteWallpaper(Wallpaper wallpaper,
      {bool showSnackbar = true}) async {
    try {
      if (wallpaper.isAsset && wallpaper.isDefault) {
        if (showSnackbar) {
          Get.snackbar(
            'Cannot Delete',
            'Default wallpaper cannot be deleted',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.withValues(alpha: 0.8),
            colorText: Colors.white,
          );
        }
        return;
      }

      // Delete file if it exists
      if (wallpaper.isFile) {
        final file = File(wallpaper.path);
        if (file.existsSync()) {
          await file.delete();
        }
      }

      // Handle custom vs network download
      if (wallpaper.isCustom) {
        // Remove from custom list
        customWallpapers.removeWhere((w) => w.id == wallpaper.id);
        await _saveCustomWallpapers();
      } else if (wallpaper.id.startsWith('network_')) {
        // Revert network wallpaper state in list
        final index = networkWallpapers.indexWhere((w) => w.id == wallpaper.id);
        if (index != -1) {
          final originalPath =
              wallpaper.remotePath ?? wallpaper.id.replaceFirst('network_', '');
          networkWallpapers[index] = wallpaper.copyWith(
            path: originalPath,
            source: WallpaperSource.network,
          );
        }
      }

      // If this was the current wallpaper, reset to default
      if (currentWallpaper.value?.id == wallpaper.id) {
        await resetToDefault();
      }

      if (showSnackbar) {
        Get.snackbar(
          'Success',
          'Wallpaper deleted',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('Error deleting wallpaper: $e');
      if (showSnackbar) {
        Get.snackbar(
          'Error',
          'Failed to delete wallpaper',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _saveCustomWallpapers() async {
    final data = customWallpapers.map((w) => w.toJson()).toList();
    await _box.write(_customWallpapersKey, data);
  }

  // Multi-selection methods
  void toggleSelection(String id) {
    if (selectedWallpaperIds.contains(id)) {
      selectedWallpaperIds.remove(id);
    } else {
      selectedWallpaperIds.add(id);
    }

    if (selectedWallpaperIds.isEmpty) {
      isMultiSelectMode.value = false;
    } else {
      isMultiSelectMode.value = true;
    }
  }

  void clearSelection() {
    selectedWallpaperIds.clear();
    isMultiSelectMode.value = false;
  }

  void selectAllSelectableWallpapers() {
    // Select all wallpapers that are deletable (files, not assets)
    final selectableIds =
        allWallpapers.where((w) => w.isFile).map((w) => w.id).toList();

    if (selectedWallpaperIds.length == selectableIds.length) {
      selectedWallpaperIds.clear();
      isMultiSelectMode.value = false;
    } else {
      selectedWallpaperIds.assignAll(selectableIds);
      isMultiSelectMode.value = true;
    }
  }

  Future<void> deleteSelectedWallpapers() async {
    if (selectedWallpaperIds.isEmpty) return;

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Wallpapers'),
        content: Text(
            'Are you sure you want to delete ${selectedWallpaperIds.length} wallpapers?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      isLoading.value = true;
      try {
        final idsToDelete = List<String>.from(selectedWallpaperIds);
        for (final id in idsToDelete) {
          // Look in all wallpapers to find the one to delete
          final wp = allWallpapers.firstWhereOrNull((w) => w.id == id);
          if (wp != null) {
            await deleteWallpaper(wp, showSnackbar: false);
          }
        }
        clearSelection();
        Get.snackbar('Success', 'Selected wallpapers deleted');
      } catch (e) {
        debugPrint('Error deleting multiple wallpapers: $e');
        Get.snackbar('Error', 'Failed to delete some wallpapers');
      } finally {
        isLoading.value = false;
      }
    }
  }

  bool canAddStaticWallpaper() {
    return customWallpapers.where((w) => w.isImage).length <
        _maxCustomStaticWallpapers;
  }

  bool canAddDynamicWallpaper() {
    return customWallpapers.where((w) => w.isVideo).length <
        _maxCustomDynamicWallpapers;
  }

  // --- CUSTOM WALLPAPER UPLOAD HELPERS ---

  Future<void> pickAndUploadStaticWallpaper() async {
    if (!canAddStaticWallpaper()) {
      Get.snackbar(
          'Limit Reached', 'Maximum 5 custom static wallpapers allowed');
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      // Validate extension
      final extension = image.path.split('.').last.toLowerCase();
      if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
        Get.snackbar('Invalid Format', 'Supported formats: .jpg, .jpeg, .png');
        return;
      }

      // Check aspect ratio and resolution
      final decodedImage = await decodeImageFromList(await image.readAsBytes());
      final width = decodedImage.width;
      final height = decodedImage.height;
      final aspectRatio = width / height;
      const expectedRatio = 9 / 16;
      const tolerance = 0.05;

      if ((aspectRatio - expectedRatio).abs() > tolerance) {
        // Show crop screen
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Wallpaper',
              toolbarColor: const Color(0xFFFFB2EE),
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Wallpaper',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          await addCustomWallpaper(croppedFile.path);
        }
      } else {
        await addCustomWallpaper(image.path);
      }
    } catch (e) {
      debugPrint('Error picking static wallpaper: $e');
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  Future<void> pickAndUploadDynamicWallpaper() async {
    if (!canAddDynamicWallpaper()) {
      Get.snackbar(
          'Limit Reached', 'Maximum 5 custom dynamic wallpapers allowed');
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return;

      // Validate extension
      final extension = video.path.split('.').last.toLowerCase();
      if (extension != 'mp4') {
        Get.snackbar('Invalid Format', 'Supported format: .mp4');
        return;
      }

      // Open trim screen
      final result =
          await Get.toNamed('/wallpaper-trim', arguments: video.path);

      if (result != null && result is String) {
        await addCustomWallpaper(result);
      }
    } catch (e) {
      debugPrint('Error picking dynamic wallpaper: $e');
      Get.snackbar('Error', 'Failed to pick video: $e');
    }
  }

  // --- END CUSTOM WALLPAPER UPLOAD HELPERS ---

  // Use assignAll to ensure reactivity for the combined lists
  List<Wallpaper> get allWallpapers {
    final list = [
      ...assetWallpapers,
      ...networkWallpapers,
      ...customWallpapers
    ];
    return _sortWallpapers(list);
  }

  // Getters for filtered lists - these are reactive because they depend on RxLists
  List<Wallpaper> get imageWallpapers {
    return allWallpapers.where((w) => w.isImage).toList();
  }

  List<Wallpaper> get videoWallpapers {
    return allWallpapers.where((w) => w.isVideo).toList();
  }

  List<Wallpaper> _sortWallpapers(List<Wallpaper> list) {
    final current = currentWallpaper.value;
    const defaultPath = _defaultWallpaperPath;

    // Remove duplicates by ID (if any)
    final Map<String, Wallpaper> uniqueMap = {};
    for (var w in list) {
      uniqueMap[w.id] = w;
    }
    final uniqueList = uniqueMap.values.toList();

    uniqueList.sort((a, b) {
      // 1. Default Wallpaper (Developer Wallpaper)
      final aIsDefault = a.isAsset && a.path == defaultPath;
      final bIsDefault = b.isAsset && b.path == defaultPath;
      if (aIsDefault && !bIsDefault) return -1;
      if (!aIsDefault && bIsDefault) return 1;

      // 2. Downloaded + Currently Set Wallpaper
      final aIsCurrent = current != null && a.id == current.id;
      final bIsCurrent = current != null && b.id == current.id;
      final aIsDownloaded = isDownloaded(a);
      final bIsDownloaded = isDownloaded(b);

      if (aIsCurrent && aIsDownloaded && !(bIsCurrent && bIsDownloaded)) {
        return -1;
      }
      if (!(aIsCurrent && aIsDownloaded) && bIsCurrent && bIsDownloaded) {
        return 1;
      }

      // 3. Downloaded but Not Set Wallpapers
      if (aIsDownloaded && !bIsDownloaded) return -1;
      if (!aIsDownloaded && bIsDownloaded) return 1;

      // 4. Not Downloaded Wallpapers (at the end)
      // If both are same priority, sort by name
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return uniqueList;
  }

  // Count getters for UI display
  int get staticCount => allWallpapers.where((w) => w.isImage).length;
  int get dynamicCount => allWallpapers.where((w) => w.isVideo).length;

  Future<void> refreshWallpapers() async {
    await _initializeWallpapers();
  }

  @override
  void onClose() {
    _disposeCachedController();
    super.onClose();
  }
}
