import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../routes/app_routes.dart';
import '../../services/sound_service.dart';
import '../../controllers/wallpaper_controller.dart';
import '../../models/wallpaper_model.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';

class WallpaperSetScreen extends StatefulWidget {
  const WallpaperSetScreen({super.key});

  @override
  State<WallpaperSetScreen> createState() => _WallpaperSetScreenState();
}

class _WallpaperSetScreenState extends State<WallpaperSetScreen> {
  final WallpaperController _controller = Get.find<WallpaperController>();
  late Wallpaper _wallpaper;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  double _previewBlur = 2.0;
  double _previewVolume = 0.0;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _wallpaper = Get.arguments as Wallpaper;
    _previewBlur = _controller.blurIntensity.value;
    _previewVolume = _wallpaper.volume;
    _isMuted = _wallpaper.isMuted;

    if (_wallpaper.isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (_wallpaper.isAsset) {
        _videoController = VideoPlayerController.asset(_wallpaper.path);
      } else {
        _videoController = VideoPlayerController.file(File(_wallpaper.path));
      }

      await _videoController!.initialize();
      _videoController!.setLooping(true);
      // Apply preview volume settings
      _videoController!.setVolume(_isMuted ? 0.0 : _previewVolume);
      _videoController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video preview: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _applyWallpaper() async {
    if (!_controller.isDownloaded(_wallpaper)) {
      _downloadAndSet();
      return;
    }

    // Update wallpaper with volume settings before applying
    final wallpaperWithVolume = _wallpaper.copyWith(
      volume: _previewVolume,
      isMuted: _isMuted,
    );
    // fromUser: true → shows blur overlay + success snackbar during transition
    await _controller.setWallpaper(wallpaperWithVolume, fromUser: true);
    await _controller.setBlurIntensity(_previewBlur);

    // Navigate only after the controller has fully finished (overlay hidden)
    Get.offAllNamed(AppRoutes.voiceChat);
  }

  void _downloadAndSet() async {
    try {
      final downloaded = await _controller.downloadWallpaper(_wallpaper);
      if (mounted) {
        setState(() {
          _wallpaper = downloaded;
          if (_wallpaper.isVideo) {
            _initializeVideo();
          }
        });
      }
    } catch (e) {
      Get.snackbar(
        'Download Failed',
        'Check your internet connection and try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withAlpha(204),
        colorText: Colors.white,
      );
    }
  }

  void _resetToDefault() async {
    await SoundService.to.playClick();
    // fromUser: true → shows the blur overlay during the reset transition
    final defaultWallpaper = Wallpaper.fromAsset(
      'assets/images/Wallpaper_default.png',
      isDefault: true,
    );
    await _controller.setWallpaper(defaultWallpaper, fromUser: true);

    Get.snackbar(
      'Reset',
      'Wallpaper reset to default',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue.withValues(alpha: 0.8),
      colorText: Colors.white,
    );

    Get.offAllNamed(AppRoutes.voiceChat);
  }

  void _deleteWallpaper() async {
    final confirmed = await GlassmorphicDialogHelper.showDeleteConfirmation(
      title: 'Delete Wallpaper',
      message: 'Are you sure you want to delete "${_wallpaper.name}"?',
      subtitle: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      onConfirm: () async {
        await _controller.deleteWallpaper(_wallpaper);
      },
    );

    if (confirmed == true) {
      Get.back(); // Navigate back to main wallpaper screen
    }
  }

  void _navigateBack() async {
    await SoundService.to.playClick();
    Get.back(); // Navigate back to main wallpaper screen
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      useWallpaper: false, // Use plain background for this screen
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: _navigateBack,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Color(0xFF230F1F)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _wallpaper.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF230F1F),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_wallpaper.isDefault)
                      GestureDetector(
                        onTap: _deleteWallpaper,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // Preview
                Expanded(
                  child: GlassContainer(
                    child: Semantics(
                      image: true,
                      label: '${_wallpaper.name} preview',
                      child: Hero(
                      tag: 'wallpaper_${_wallpaper.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                          // Wallpaper content
                          if (_wallpaper.isVideo)
                            _isVideoInitialized && _videoController != null
                                ? SizedBox.expand(
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width:
                                            _videoController!.value.size.width,
                                        height:
                                            _videoController!.value.size.height,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                          else if (_wallpaper.isNetwork &&
                              !_controller.isDownloaded(_wallpaper))
                            CachedNetworkImage(
                              imageUrl: _controller.getPublicUrl(_wallpaper),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            )
                          else
                            Image(
                              image: _wallpaper.isAsset
                                  ? AssetImage(_wallpaper.path)
                                  : FileImage(File(_wallpaper.path))
                                      as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                          // Blur overlay preview
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withAlpha(102),
                                  Colors.transparent,
                                  Colors.white.withAlpha(153),
                                ],
                              ),
                            ),
                          ),
                          // Center icon
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _wallpaper.isVideo
                                      ? Icons.videocam
                                      : Icons.wallpaper,
                                  size: 64,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _wallpaper.isVideo
                                        ? 'Video Wallpaper'
                                        : 'Image Wallpaper',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Blur Intensity Slider
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blur Intensity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF230F1F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.blur_off,
                              size: 20, color: Colors.grey),
                          Expanded(
                            child: Slider(
                              value: _previewBlur,
                              min: 0,
                              max: 20,
                              divisions: 20,
                              activeColor: const Color(0xFFFFB2EE),
                              onChanged: (value) {
                                setState(() {
                                  _previewBlur = value;
                                });
                              },
                            ),
                          ),
                          const Icon(Icons.blur_on,
                              size: 20, color: Colors.grey),
                        ],
                      ),
                      Center(
                        child: Text(
                          _previewBlur.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF230F1F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Volume Controls - Only show for video wallpapers
                if (_wallpaper.isVideo) ...[
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Volume',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF230F1F),
                              ),
                            ),
                            // Mute/Unmute Button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isMuted = !_isMuted;
                                  // Update video controller volume immediately
                                  if (_videoController != null &&
                                      _videoController!.value.isInitialized) {
                                    _videoController!.setVolume(
                                        _isMuted ? 0.0 : _previewVolume);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isMuted
                                      ? Colors.grey.withAlpha(77)
                                      : const Color(0xFFFFB2EE).withAlpha(77),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isMuted
                                        ? Colors.grey
                                        : const Color(0xFFFFB2EE),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isMuted
                                          ? Icons.volume_off
                                          : Icons.volume_up,
                                      size: 18,
                                      color: _isMuted
                                          ? Colors.grey[600]
                                          : const Color(0xFFFF69B4),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isMuted ? 'Muted' : 'Unmuted',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _isMuted
                                            ? Colors.grey[600]
                                            : const Color(0xFFFF69B4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Volume Slider
                        Row(
                          children: [
                            Icon(
                              Icons.volume_mute,
                              size: 20,
                              color: _isMuted ? Colors.grey : Colors.grey[700],
                            ),
                            Expanded(
                              child: Slider(
                                value: _previewVolume,
                                min: 0.0,
                                max: 1.0,
                                divisions: 100,
                                activeColor: _isMuted
                                    ? Colors.grey
                                    : const Color(0xFFFFB2EE),
                                inactiveColor: _isMuted
                                    ? Colors.grey[300]
                                    : Colors.grey[300],
                                onChanged: _isMuted
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _previewVolume = value;
                                          // Update video controller volume immediately
                                          if (_videoController != null &&
                                              _videoController!
                                                  .value.isInitialized) {
                                            _videoController!.setVolume(value);
                                          }
                                        });
                                      },
                              ),
                            ),
                            Icon(
                              Icons.volume_up,
                              size: 20,
                              color: _isMuted ? Colors.grey : Colors.grey[700],
                            ),
                          ],
                        ),
                        Center(
                          child: Text(
                            _isMuted
                                ? 'Muted (0%)'
                                : '${(_previewVolume * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _isMuted
                                  ? Colors.grey
                                  : const Color(0xFF230F1F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Download / Apply Button
                Obx(() {
                  final isDownloaded = _controller.isDownloaded(_wallpaper);
                  final isDownloading = _controller.isDownloading.value;
                  final progress = _controller.downloadProgress.value;

                  return Column(
                    children: [
                      if (!isDownloaded && isDownloading)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white.withAlpha(51),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFFB2EE)),
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Downloading: ${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Color(0xFF230F1F),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Semantics(
                        button: true,
                        label: isDownloaded ? 'Apply Wallpaper' : 'Download Wallpaper',
                        child: PressScale(
                        onTap: isDownloading
                            ? null
                            : (isDownloaded
                                ? _applyWallpaper
                                : _downloadAndSet),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDownloading
                                  ? [Colors.grey, Colors.grey.shade400]
                                  : [
                                      const Color(0xFFFFB2EE),
                                      const Color(0xFFFF69B4)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              if (!isDownloading)
                                BoxShadow(
                                  color: const Color(0xFFFFB2EE)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isDownloading
                                  ? 'Downloading...'
                                  : (isDownloaded
                                      ? 'Apply Wallpaper'
                                      : 'Download Wallpaper'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                      ),
                    ),
                    ),
                  ),
                ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                // Reset to Default Button
                GestureDetector(
                  onTap: _resetToDefault,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restore, color: Color(0xFF230F1F)),
                          SizedBox(width: 8),
                          Text(
                            'Reset to Default',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF230F1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Cancel Button
                GestureDetector(
                  onTap: _navigateBack,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF230F1F),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
