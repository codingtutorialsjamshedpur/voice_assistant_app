import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'cloud_painter.dart';
import 'orb_thinking_controller.dart';

/// Enhanced Thought Bubble Widget
/// Smart cloud with unpredictable transitions, eye movement, and thinking progression
class ThoughtBubbleWidget extends StatefulWidget {
  final String avatarAssetPath;
  final bool visible;
  final double size;

  const ThoughtBubbleWidget({
    required this.avatarAssetPath,
    required this.visible,
    this.size = 100, // Increased default size for better visibility
    super.key,
  });

  @override
  State<ThoughtBubbleWidget> createState() => _ThoughtBubbleWidgetState();
}

class _ThoughtBubbleWidgetState extends State<ThoughtBubbleWidget>
    with TickerProviderStateMixin {
  // Enhanced animation controllers for smart transitions
  late AnimationController _entryController;
  late AnimationController _floatController;
  late AnimationController _crossfadeController;
  late AnimationController _transitionController;

  // Smart transition animations
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _crossfadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _rotationAnim;

  // Enhanced cloud painter with thinking dots
  static final _cloudPainter = CloudPainter();

  // Track avatar states for smart transitions
  String? _previousAvatarPath;
  String? _currentAvatarPath;
  String _currentTransitionType = 'fadeIn';

  @override
  void initState() {
    super.initState();

    // Initialize avatar paths
    _currentAvatarPath = widget.avatarAssetPath;

    // Entry/exit animation - optimized for 60fps with smart transitions
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Floating animation - dreamy cloud movement
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Fast crossfade for avatar changes (1-2 seconds as requested)
    _crossfadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _crossfadeAnim = CurvedAnimation(
      parent: _crossfadeController,
      curve: Curves.easeInOutCubic,
    );

    // Smart transition controller for unpredictable animations
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _initializeSmartTransitions();

    if (widget.visible) {
      _startCloudSequence();
    }
  }

  /// Initialize smart transition animations based on random type
  void _initializeSmartTransitions() {
    // Get transition type from controller
    try {
      final controller = Get.find<OrbThinkingController>();
      _currentTransitionType = controller.transitionType;
    } catch (e) {
      _currentTransitionType = 'fadeIn';
    }

    // Configure animations based on transition type
    switch (_currentTransitionType) {
      case 'slideLeft':
        _slideAnim = Tween<Offset>(
          begin: const Offset(1.0, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.easeOutBack,
        ));
        break;
      case 'slideRight':
        _slideAnim = Tween<Offset>(
          begin: const Offset(-1.0, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.easeOutBack,
        ));
        break;
      case 'slideUp':
        _slideAnim = Tween<Offset>(
          begin: const Offset(0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.bounceOut,
        ));
        break;
      case 'slideDown':
        _slideAnim = Tween<Offset>(
          begin: const Offset(0, -1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.bounceOut,
        ));
        break;
      case 'rotateIn':
        _rotationAnim = Tween<double>(
          begin: 2 * pi,
          end: 0,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.elasticOut,
        ));
        break;
      case 'scaleUp':
        _scaleAnim = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.elasticOut,
        ));
        break;
      case 'scaleDown':
        _scaleAnim = Tween<double>(
          begin: 2.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.easeOutBack,
        ));
        break;
      default: // fadeIn, bounceIn, flipIn
        _opacityAnim = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.easeOutCubic,
        ));
        _scaleAnim = Tween<double>(
          begin: 0.3,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _transitionController,
          curve: Curves.elasticOut,
        ));
    }
  }

  /// Start the complete cloud thinking sequence
  void _startCloudSequence() {
    _floatController.repeat(reverse: true);
    _transitionController.forward();
  }

  @override
  void didUpdateWidget(ThoughtBubbleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle visibility changes with smart transitions
    if (widget.visible && !oldWidget.visible) {
      if (widget.avatarAssetPath.isNotEmpty) {
        _currentAvatarPath = widget.avatarAssetPath;
      }
      _initializeSmartTransitions(); // Reinitialize for new transition type
      _startCloudSequence();
    } else if (!widget.visible && oldWidget.visible) {
      _stopCloudSequence();
    }

    // Handle avatar changes with fast crossfade (1-2 seconds as requested)
    if (widget.visible &&
        oldWidget.visible &&
        widget.avatarAssetPath != oldWidget.avatarAssetPath) {
      _previousAvatarPath = _currentAvatarPath;
      _currentAvatarPath = widget.avatarAssetPath;

      // Reinitialize smart transitions for new avatar
      _initializeSmartTransitions();

      // Fast crossfade with new transition
      _crossfadeController.forward(from: 0).then((_) {
        _previousAvatarPath = null;
        _crossfadeController.reset();
        _transitionController.forward(from: 0); // Apply new transition
      });
    }
  }

  /// Stop the cloud sequence
  void _stopCloudSequence() {
    _entryController.reverse();
    _floatController.stop();
    _transitionController.reverse();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _floatController.dispose();
    _crossfadeController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in RepaintBoundary for performance isolation
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _entryController,
          _floatController,
          _crossfadeController,
          _transitionController,
        ]),
        builder: (context, child) {
          return _buildSmartTransitionWrapper(
            child: Transform.translate(
              offset: Offset(0, _floatAnim.value),
              child: _buildEnhancedCloudWithThinkingDots(),
            ),
          );
        },
      ),
    );
  }

  /// Build smart transition wrapper based on current transition type
  Widget _buildSmartTransitionWrapper({required Widget child}) {
    switch (_currentTransitionType) {
      case 'slideLeft':
      case 'slideRight':
      case 'slideUp':
      case 'slideDown':
        return SlideTransition(
          position: _slideAnim,
          child: child,
        );
      case 'rotateIn':
        return Transform.rotate(
          angle: _rotationAnim.value,
          child: child,
        );
      case 'scaleUp':
      case 'scaleDown':
        return Transform.scale(
          scale: _scaleAnim.value,
          alignment: Alignment.bottomLeft,
          child: child,
        );
      default: // fadeIn, bounceIn, flipIn
        return Opacity(
          opacity: _opacityAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        );
    }
  }

  /// Build enhanced cloud with thinking progression dots
  Widget _buildEnhancedCloudWithThinkingDots() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Main cloud bubble
        _buildMainCloudBubble(),
      ],
    );
  }

  /// Build the main cloud bubble
  Widget _buildMainCloudBubble() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Cloud shape with Glassmorphism (BackdropFilter + CustomPaint)
          ClipPath(
            clipper: CloudClipper(),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _cloudPainter,
              ),
            ),
          ),
          // Avatar image clipped to cloud interior
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(
                  widget.size * 0.12), // Balanced padding for better fit
              child: ClipOval(
                child: _buildCrossfadeImage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build crossfade image with smart transitions
  Widget _buildCrossfadeImage() {
    // If no crossfade is happening, show current image
    if (_previousAvatarPath == null || !_crossfadeController.isAnimating) {
      return _buildOptimizedImageForPath(
          _currentAvatarPath ?? widget.avatarAssetPath);
    }

    // During crossfade, stack previous and current images with opacity transition
    return Stack(
      fit: StackFit.expand,
      children: [
        // Previous image fading out
        Opacity(
          opacity: 1.0 - _crossfadeAnim.value,
          child: _buildOptimizedImageForPath(_previousAvatarPath!),
        ),
        // Current image fading in
        Opacity(
          opacity: _crossfadeAnim.value,
          child: _buildOptimizedImageForPath(
              _currentAvatarPath ?? widget.avatarAssetPath),
        ),
      ],
    );
  }

  /// Build optimized image for specific path
  Widget _buildOptimizedImageForPath(String assetPath) {
    if (assetPath.isEmpty) return const SizedBox.shrink();

    // Check if image is preloaded for better performance
    try {
      final controller = Get.find<OrbThinkingController>();
      final isPreloaded = controller.isImagePreloaded(assetPath);

      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        // Use memory cache for preloaded images
        cacheWidth: isPreloaded ? (widget.size * 2).round() : null,
        cacheHeight: isPreloaded ? (widget.size * 2).round() : null,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if image fails to load
          return Icon(
            Icons.psychology,
            size: widget.size * 0.5,
            color: const Color(0xFFFFB2EE),
          );
        },
      );
    } catch (e) {
      // Fallback if controller not available
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.psychology,
            size: widget.size * 0.5,
            color: const Color(0xFFFFB2EE),
          );
        },
      );
    }
  }
}
