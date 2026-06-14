import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_trimmer/video_trimmer.dart';
import '../../shared/widgets/shared_widgets.dart';

class WallpaperTrimScreen extends StatefulWidget {
  const WallpaperTrimScreen({super.key});

  @override
  State<WallpaperTrimScreen> createState() => _WallpaperTrimScreenState();
}

class _WallpaperTrimScreenState extends State<WallpaperTrimScreen> {
  final Trimmer _trimmer = Trimmer();

  late String _videoPath;

  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool _isTrimming = false;

  @override
  void initState() {
    super.initState();
    _videoPath = Get.arguments as String;
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      await _trimmer.loadVideo(videoFile: File(_videoPath));
    } catch (e) {
      debugPrint('Error loading video: $e');
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to load video: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withAlpha(200),
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _saveVideo() async {
    // Validate: at least a start/end must have been set
    if (_endValue == 0.0) {
      final videoDuration = _trimmer
              .videoPlayerController?.value.duration.inMilliseconds
              .toDouble() ??
          0;
      _endValue = videoDuration.clamp(0, 30000).toDouble();
    }

    final duration = _endValue - _startValue;
    if (duration > 30000) {
      Get.snackbar(
        'Too Long',
        'Max duration is 30 seconds. Please trim more.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withAlpha(200),
        colorText: Colors.white,
      );
      return;
    }

    if (duration < 500) {
      Get.snackbar(
        'Too Short',
        'Please select at least 0.5 seconds.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withAlpha(200),
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isTrimming = true);

    try {
      // Prepare the permanent output directory
      final appDir = await getApplicationDocumentsDirectory();
      final wallpapersDir = Directory('${appDir.path}/custom_wallpapers');
      if (!wallpapersDir.existsSync()) {
        wallpapersDir.createSync(recursive: true);
      }

      final fileName = 'dynamic_${DateTime.now().millisecondsSinceEpoch}';

      // Use Trimmer.saveTrimmedVideo() — it wraps the native trimmer
      // internally and handles file output more safely than calling
      // flutter_native_video_trimmer directly.
      final completer = Completer<String?>();

      await _trimmer.saveTrimmedVideo(
        startValue: _startValue,
        endValue: _endValue,
        videoFolderName: 'custom_wallpapers',
        videoFileName: fileName,
        onSave: (outputPath) {
          if (!completer.isCompleted) {
            completer.complete(outputPath);
          }
        },
      );

      final outputPath = await completer.future;

      if (!mounted) return;

      if (outputPath != null && File(outputPath).existsSync()) {
        // The trimmer saves to app documents dir already.
        // Move/copy it to our custom_wallpapers folder if needed.
        final outFile = File(outputPath);
        final permanentPath = '${wallpapersDir.path}/$fileName.mp4';

        String finalPath;
        if (outputPath == permanentPath) {
          finalPath = outputPath;
        } else {
          await outFile.copy(permanentPath);
          // Clean up the intermediate file
          try {
            await outFile.delete();
          } catch (_) {}
          finalPath = permanentPath;
        }

        debugPrint('Trimmed video saved to: $finalPath');
        Get.back(result: finalPath);
      } else {
        if (mounted) setState(() => _isTrimming = false);
        Get.snackbar(
          'Error',
          'Failed to save trimmed video',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withAlpha(200),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('Error trimming video: $e');
      if (mounted) {
        setState(() => _isTrimming = false);
        Get.snackbar(
          'Error',
          'Failed to trim video: ${e.toString().split('\n').first}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withAlpha(200),
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Trim Video',
            style: TextStyle(color: Color(0xFF230F1F)),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF230F1F)),
            onPressed: () => Get.back(),
          ),
          actions: [
            if (_isTrimming)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF69B4),
                    ),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _saveVideo,
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF69B4),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (_isTrimming)
              const LinearProgressIndicator(
                backgroundColor: Colors.pink,
                color: Color(0xFFFF69B4),
              ),
            Expanded(
              child: VideoViewer(trimmer: _trimmer),
            ),
            Center(
              child: TrimViewer(
                trimmer: _trimmer,
                viewerHeight: 50.0,
                viewerWidth: MediaQuery.of(context).size.width,
                maxVideoLength: const Duration(seconds: 30),
                onChangeStart: (value) => setState(() => _startValue = value),
                onChangeEnd: (value) => setState(() => _endValue = value),
                onChangePlaybackState: (value) =>
                    setState(() => _isPlaying = value),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                try {
                  final playbackState = await _trimmer.videoPlaybackControl(
                    startValue: _startValue,
                    endValue: _endValue,
                  );
                  if (mounted) setState(() => _isPlaying = playbackState);
                } catch (e) {
                  debugPrint('Playback error: $e');
                }
              },
              child: _isPlaying
                  ? const Icon(Icons.pause, size: 80.0, color: Colors.white)
                  : const Icon(Icons.play_arrow,
                      size: 80.0, color: Colors.white),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
