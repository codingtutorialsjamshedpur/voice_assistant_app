import 'dart:async';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'avatar_resolver.dart';
import 'enhanced_sound_effect_player.dart';

/// Enhanced Orb Thinking Controller
/// Manages smart avatar transitions, cloud effects, and synchronized sound
class OrbThinkingController extends GetxController {
  final _currentAvatarPath = Rxn<String>();
  final _isThinking = false.obs;
  final _isBlinking = false.obs;
  final _showCloud = false.obs;
  final _preloadedImages = <String, bool>{};

  bool _sequenceRunning = false;
  // Avatar queue for smart transitions
  final _avatarQueue = <String>[];
  Timer? _avatarTransitionTimer;

  // Transition state
  final _transitionType =
      'fadeIn'.obs; // fadeIn, slideLeft, slideRight, scaleUp, etc.

  // Performance monitoring
  DateTime? _lastFrameTime;
  int _slowFrameCount = 0;
  static const int _frameThresholdMs = 17; // 60fps = 16.67ms per frame

  // Random transition types for unpredictable animations
  final _transitionTypes = [
    'fadeIn',
  ];
  final _random = Random();

  String? get currentAvatarPath => _currentAvatarPath.value;
  bool get isThinking => _isThinking.value;
  bool get isBlinking => _isBlinking.value;
  bool get showCloud => _showCloud.value;
  String get transitionType => _transitionType.value;

  // Reactive getters for Obx widgets
  Rxn<String> get currentAvatarPathRx => _currentAvatarPath;
  RxBool get isThinkingRx => _isThinking;
  RxBool get isBlinkingRx => _isBlinking;
  RxBool get showCloudRx => _showCloud;
  RxString get transitionTypeRx => _transitionType;

  @override
  void onInit() {
    super.onInit();
    _preloadAvatarImages();
    _setupPerformanceMonitoring();
  }

  /// Setup performance monitoring for 60fps validation
  void _setupPerformanceMonitoring() {
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  /// Monitor frame rate performance
  void _onFrame(Duration timestamp) {
    final now = DateTime.now();

    if (_lastFrameTime != null) {
      final frameDuration = now.difference(_lastFrameTime!);
      // Track slow frames for performance analysis
      if (frameDuration.inMilliseconds > _frameThresholdMs) {
        _slowFrameCount++;
        print(
            '⚠️ Frame drop detected: ${frameDuration.inMilliseconds}ms (total slow frames: $_slowFrameCount)');
      }
    }

    _lastFrameTime = now;

    // Continue monitoring if controller is still active
    if (!isClosed) {
      SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    }
  }

  /// Preload all avatar images to improve performance
  Future<void> _preloadAvatarImages() async {
    try {
      // Get all unique avatar paths from AvatarResolver
      final allAvatarPaths = AvatarResolver.getAllAvatarPaths();

      // Preload images in batches to avoid overwhelming the system
      const batchSize = 5;
      for (int i = 0; i < allAvatarPaths.length; i += batchSize) {
        final batch = allAvatarPaths.skip(i).take(batchSize);

        await Future.wait(
          batch.map((path) => _preloadSingleImage(path)),
          eagerError: false, // Continue even if some images fail
        );

        // Small delay between batches to prevent blocking
        await Future.delayed(const Duration(milliseconds: 50));
      }

      print('✅ Preloaded ${_preloadedImages.length} avatar images');
    } catch (e) {
      print('⚠️ Error preloading avatar images: $e');
    }
  }

  /// Preload a single image
  Future<void> _preloadSingleImage(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      _preloadedImages[assetPath] = true;
    } catch (e) {
      print('⚠️ Failed to preload image: $assetPath - $e');
      _preloadedImages[assetPath] = false;
    }
  }

  /// Enhanced sentence processing with smart avatar detection
  void onSentenceSpoken(String sentence) {
    _processSmartAvatarDetection(sentence);
  }

  /// Smart avatar detection - finds multiple avatars and queues them
  void _processSmartAvatarDetection(String sentence) {
    final words = sentence.toLowerCase().split(RegExp(r'[\s\.,!?;]+'));
    final foundAvatars = <String>[];

    // Find all trigger words in the sentence
    for (final word in words) {
      final avatar = AvatarResolver.resolve(word);
      if (avatar != null && !foundAvatars.contains(avatar)) {
        foundAvatars.add(avatar);
      }
    }

    if (foundAvatars.isNotEmpty) {
      _queueAvatarTransitions(foundAvatars);
    }
  }

  /// Queue multiple avatars for smart transitions
  void _queueAvatarTransitions(List<String> avatars) {
    _avatarQueue.clear();
    _avatarQueue.addAll(avatars);

    if (_avatarQueue.isNotEmpty) {
      _startThinkingSequence();
    }
  }

  /// Start the thinking sequence with orb blinking and cloud appearance
  void _startThinkingSequence() async {
    if (_sequenceRunning) {
      _avatarTransitionTimer?.cancel();
      _startAvatarTransitions();
      return;
    }
    _sequenceRunning = true;
    _sequenceStartTime = DateTime.now();

    // Step 1: Orb blinks (brief duration)
    _isBlinking.value = true;
    await EnhancedSoundEffectPlayer.playOrbBlinking();
    await Future.delayed(const Duration(milliseconds: 400));
    _isBlinking.value = false;

    if (_avatarQueue.isEmpty || isClosed) {
      _sequenceRunning = false;
      return;
    }

    // Step 2: Cloud appears in sync with avatar
    _showCloud.value = true;
    await EnhancedSoundEffectPlayer.playCloudAppearance();
    await Future.delayed(const Duration(milliseconds: 100));

    if (_avatarQueue.isEmpty || isClosed) {
      _sequenceRunning = false;
      return;
    }

    // Step 3: Start avatar transitions
    _startAvatarTransitions();
  }

  /// Start rapid avatar transitions (1-2 seconds each)
  void _startAvatarTransitions() {
    if (_avatarQueue.isEmpty) {
      _endThinkingSequence();
      return;
    }

    final avatar = _avatarQueue.removeAt(0);
    _currentAvatarPath.value = avatar;
    _isThinking.value = true;

    // Random transition type for unpredictability
    _transitionType.value =
        _transitionTypes[_random.nextInt(_transitionTypes.length)];

    // Play transition sounds
    EnhancedSoundEffectPlayer.playForAvatar(avatar);

    // Schedule next transition (make sure it stays for at least 4 seconds as requested)
    const transitionDelay = Duration(milliseconds: 4000);
    _avatarTransitionTimer = Timer(transitionDelay, () {
      _avatarQueue.clear();
      _startAvatarTransitions(); // This will now empty and call _endThinkingSequence
    });
  }

  DateTime? _sequenceStartTime;

  /// End the thinking sequence, ensuring minimum 4 seconds visibility
  void _endThinkingSequence() {
    if (_sequenceStartTime != null) {
      final elapsed = DateTime.now().difference(_sequenceStartTime!);
      if (elapsed.inMilliseconds < 4000) {
        // Enforce minimum 4 seconds visibility (not less than that)
        _avatarTransitionTimer?.cancel();
        _avatarTransitionTimer = Timer(
          Duration(milliseconds: 4000 - elapsed.inMilliseconds),
          _executeEndSequence,
        );
        return;
      }
    }
    _executeEndSequence();
  }

  void _executeEndSequence() {
    _sequenceRunning = false;
    _isThinking.value = false;
    _showCloud.value = false;
    _currentAvatarPath.value = null;
    _sequenceStartTime = null;

    EnhancedSoundEffectPlayer.resetLastAvatar();

    // Clear any pending timers
    _avatarTransitionTimer?.cancel();
  }

  /// Called when TTS begins speaking a word/chunk (legacy support)
  void onWordSpoken(String word) {
    final avatar = AvatarResolver.resolve(word);
    if (avatar != null) {
      _queueAvatarTransitions([avatar]);
    }
  }

  /// Manually show a specific avatar (for testing or direct control)
  void showAvatar(String avatarPath) {
    _queueAvatarTransitions([avatarPath]);
  }

  /// Called when TTS finishes speaking
  void onSpeechEnd() {
    _endThinkingSequence();
  }

  /// Clear the current avatar without sound (immediate bypass of 4s rule for cleanups)
  void clearAvatar() {
    _sequenceStartTime = null;
    _executeEndSequence();
  }

  /// Check if an image has been preloaded successfully
  bool isImagePreloaded(String assetPath) {
    return _preloadedImages[assetPath] == true;
  }

  /// Get preloading statistics for debugging
  Map<String, dynamic> getPreloadingStats() {
    final total = _preloadedImages.length;
    final successful = _preloadedImages.values.where((loaded) => loaded).length;
    final failed = total - successful;

    return {
      'total': total,
      'successful': successful,
      'failed': failed,
      'successRate':
          total > 0 ? (successful / total * 100).toStringAsFixed(1) : '0.0',
    };
  }

  @override
  void onClose() {
    // Cancel any pending timers
    _avatarTransitionTimer?.cancel();

    EnhancedSoundEffectPlayer.dispose();

    // Log preloading statistics on disposal
    final stats = getPreloadingStats();
    print('📊 Image preloading stats: ${stats['successful']}/${stats['total']} '
        'loaded (${stats['successRate']}% success rate)');

    super.onClose();
  }
}
