import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/banner_ad_widget.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../routes/app_routes.dart';
import '../../services/theme_service.dart';
import '../theme/app_colors.dart';
import '../../controllers/wallpaper_controller.dart';
import '../../models/wallpaper_model.dart';
import '../controllers/top_panel_controller.dart';
import '../../widgets/dual_mode_input_panel.dart';
import '../../controllers/voice_controller.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/festival_theme_controller.dart';
import '../theme/responsive_layout.dart';
import '../theme/responsive.dart';
import '../theme/responsive_widgets.dart';
import 'press_scale.dart';
import '../../widgets/god_mode_bottom_sheet.dart';
import '../../services/god_mode_intelligence_service.dart';

class GlobalWallpaper extends StatelessWidget {
  final Widget child;

  const GlobalWallpaper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final WallpaperController controller;
    try {
      controller = Get.find<WallpaperController>();
    } catch (_) {
      // Very early frame
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [
          _buildDefaultBackground(const SizedBox.shrink(), 2.0, null),
          child,
        ]),
      );
    }

    return Obx(() {
      final wallpaper = controller.currentWallpaper.value;
      final blurSigma = controller.blurIntensity.value;
      final isVideoLoading = controller.isVideoLoading.value;
      final isApplying = controller.isApplying.value || isVideoLoading;

      Color? festivalPrimaryColor;
      try {
        if (Get.isRegistered<FestivalThemeController>()) {
          final festCtrl = Get.find<FestivalThemeController>();
          if (festCtrl.isFestivalDay &&
              festCtrl.activeFestivalTheme.value != null) {
            festivalPrimaryColor =
                festCtrl.activeFestivalTheme.value!.primaryColor;
          }
        }
      } catch (_) {}

      Widget background;
      if (wallpaper == null) {
        background = _buildDefaultBackground(
            const SizedBox.shrink(), blurSigma, festivalPrimaryColor);
      } else if (wallpaper.isVideo) {
        background = _VideoBackground(
          wallpaper: wallpaper,
          blurSigma: blurSigma,
          festivalPrimaryColor: festivalPrimaryColor,
          child: const SizedBox.shrink(),
        );
      } else {
        background = _ImageBackground(
          wallpaper: wallpaper,
          blurSigma: blurSigma,
          festivalPrimaryColor: festivalPrimaryColor,
          child: const SizedBox.shrink(),
        );
      }

      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Wallpaper Layer (Never rebuilt during navigation!)
            RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(wallpaper?.path ?? 'default'),
                  child: background,
                ),
              ),
            ),

            // 2. The App UI (Navigator, etc)
            // It MUST have transparent scaffolds
            RepaintBoundary(
              child: child,
            ),

            // 3. Loading Overlay Layer - blurs everything beautifully!
            if (isApplying)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: isApplying ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildWallpaperLoadingOverlay(context),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildWallpaperLoadingOverlay(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
      child: Container(
        color: Colors.black.withAlpha(150),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: context.r.scale(80),
                height: context.r.scale(80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFB2EE).withAlpha(230),
                      const Color(0xFFFF69B4).withAlpha(180),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB2EE).withAlpha(128),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: context.r.scale(36),
                    height: context.r.scale(36),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
              RSizedBox(h: 24),
              RText(
                'Applying Wallpaper...',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              RSizedBox(h: 8),
              Text(
                'Please wait while we set up your background',
                style: TextStyle(
                  fontSize: context.r.sp(14),
                  color: Colors.white.withAlpha(180),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBackground(
      Widget child, double blurSigma, Color? festivalColor) {
    final overlayColor =
        festivalColor?.withAlpha(51) ?? Colors.white.withAlpha(102);
    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Wallpaper_default.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  overlayColor,
                  Colors.transparent,
                  overlayColor,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Transparent passthrough for all existing screens
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool useWallpaper;

  const AppBackground({
    super.key,
    required this.child,
    this.useWallpaper = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: child,
    );
  }
}

class _ImageBackground extends StatelessWidget {
  final Wallpaper wallpaper;
  final double blurSigma;
  final Widget child;
  final Color? festivalPrimaryColor;

  const _ImageBackground({
    required this.wallpaper,
    required this.blurSigma,
    required this.child,
    this.festivalPrimaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = wallpaper.isAsset
        ? AssetImage(wallpaper.path)
        : FileImage(File(wallpaper.path));

    final overlayColor =
        festivalPrimaryColor?.withAlpha(51) ?? Colors.white.withAlpha(102);

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: imageProvider as ImageProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  overlayColor,
                  Colors.transparent,
                  overlayColor,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _VideoBackground extends StatefulWidget {
  final Wallpaper wallpaper;
  final double blurSigma;
  final Widget child;
  final Color? festivalPrimaryColor;

  const _VideoBackground({
    required this.wallpaper,
    required this.blurSigma,
    required this.child,
    this.festivalPrimaryColor,
  });

  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  final WallpaperController _wallpaperController = WallpaperController.to;

  late final Worker _videoWorker;

  @override
  void initState() {
    super.initState();
    _ensureVideoPlaying();
    _applyVolumeSettings();

    // WP-03: Reactive playback listener
    // Ensures video starts playing whenever the controller is replaced/initialized,
    // even if the widget was already mounted (e.g. during navigation or re-selection).
    _videoWorker = ever(_wallpaperController.cachedVideoController,
        (_) => _onControllerChanged());
  }

  void _onControllerChanged() {
    if (mounted) {
      _ensureVideoPlaying();
      _applyVolumeSettings();
    }
  }

  void _ensureVideoPlaying() {
    // Use the cached controller if available
    final cachedController = _wallpaperController.cachedVideoController.value;
    if (cachedController != null && cachedController.value.isInitialized) {
      // Resume playback
      if (!cachedController.value.isPlaying) {
        cachedController.play();
      }
    }
  }

  /// Apply volume settings from current wallpaper to the video controller
  void _applyVolumeSettings() {
    final cachedController = _wallpaperController.cachedVideoController.value;
    final currentWallpaper = _wallpaperController.currentWallpaper.value;

    if (cachedController != null &&
        cachedController.value.isInitialized &&
        currentWallpaper != null &&
        currentWallpaper.isVideo) {
      final effectiveVolume = currentWallpaper.effectiveVolume;
      cachedController.setVolume(effectiveVolume);
      debugPrint(
          'VideoBackground: Applied volume $effectiveVolume (muted: ${currentWallpaper.isMuted})');
    }
  }

  @override
  void dispose() {
    _videoWorker.dispose();
    // Don't dispose the cached controller - it's managed by WallpaperController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cachedController = _wallpaperController.cachedVideoController.value;
      final isLoading = _wallpaperController.isVideoLoading.value;
      final currentWallpaper = _wallpaperController.currentWallpaper.value;

      // Apply volume settings reactively when wallpaper or its volume changes
      if (cachedController != null &&
          cachedController.value.isInitialized &&
          currentWallpaper != null &&
          currentWallpaper.isVideo) {
        final effectiveVolume = currentWallpaper.effectiveVolume;
        // Only update if volume is different to avoid unnecessary calls
        if (cachedController.value.volume != effectiveVolume) {
          cachedController.setVolume(effectiveVolume);
        }
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          // Video player layer - isolated with RepaintBoundary to prevent conflicts
          // Wrapped in IgnorePointer to prevent gesture conflicts
          // Uses SizedBox.expand to ensure full coverage
          if (cachedController != null && cachedController.value.isInitialized)
            IgnorePointer(
              child: RepaintBoundary(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: cachedController.value.size.width,
                      height: cachedController.value.size.height,
                      child: VideoPlayer(cachedController),
                    ),
                  ),
                ),
              ),
            )
          else
            // Show wallpaper thumbnail or gradient while loading
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Color(0xFF0f3460),
                  ],
                ),
              ),
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading wallpaper...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          // Blur overlay layer - separate from video
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (widget.festivalPrimaryColor?.withAlpha(51) ??
                        Colors.white.withAlpha(102)),
                    Colors.transparent,
                    (widget.festivalPrimaryColor?.withAlpha(51) ??
                        Colors.white.withAlpha(153)),
                  ],
                ),
              ),
              // Content layer - isolated to prevent overlap with video
              child: RepaintBoundary(
                child: widget.child,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? backgroundColor;
  final double opacity;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 12,
    this.backgroundColor,
    this.opacity = 0.25,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 30,
                spreadRadius: 0,
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius:
            borderRadius ?? BorderRadius.circular(context.r.cardRadius),
        child: RepaintBoundary(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white.withAlpha(64),
                borderRadius:
                    borderRadius ?? BorderRadius.circular(context.r.cardRadius),
                border: border ??
                    Border.all(
                      color: Colors.white.withAlpha(77),
                      width: 1,
                    ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class TopControlPanel extends StatefulWidget {
  final String currentRoute;
  final VoidCallback? onThemeToggle;

  const TopControlPanel({
    super.key,
    required this.currentRoute,
    this.onThemeToggle,
  });

  @override
  State<TopControlPanel> createState() => _TopControlPanelState();
}

class _TopControlPanelState extends State<TopControlPanel> {
  final TopPanelController controller = Get.put(TopPanelController());

  void _navigateTo(String route, int index) {
    if (widget.currentRoute != route) {
      Get.offAllNamed(route);
    }
  }

  void _cycleThemeMode() {
    ThemeService.to.cycleMode();
  }

  /// Shorten city name to 3-4 characters or abbreviation
  String _shortenCityName(String fullName) {
    if (fullName.isEmpty) return 'Loc...';

    // 1. Remove common descriptors
    final String name = fullName
        .replaceAll(
            RegExp(r'(City|District|Township|Borough|Area)',
                caseSensitive: false),
            '')
        .trim();

    // 2. Clear known abbreviations
    final abbreviations = {
      'Jamshedpur': 'JSR',
      'Mumbai': 'MUM',
      'Delhi': 'DEL',
      'Bangalore': 'BNG',
      'Bengaluru': 'BNG',
      'Hyderabad': 'HYD',
      'Kolkata': 'KOL',
      'Chennai': 'CHN',
      'Ahmedabad': 'AMD',
      'Pune': 'PUN',
      'London': 'LDN',
      'New York': 'NYC',
      'San Francisco': 'SFO',
    };

    if (abbreviations.containsKey(name)) {
      return abbreviations[name]!;
    }

    // 3. Dynamic logic: If it's multi-word (e.g., "San Francisco"), take initials
    if (name.contains(' ')) {
      final initials = name
          .split(' ')
          .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
          .join();
      if (initials.length >= 2) return initials;
    }

    // 4. Default: Take first 3-4 letters in uppercase
    if (name.length <= 4) return name.toUpperCase();
    return name.substring(0, 3).toUpperCase();
  }

  Widget _buildHeader() {
    return Obx(() {
      if (controller.isLoadingWeather.value) {
        return const Center(
            child: Text('Loading Intelligence...',
                style: TextStyle(color: Colors.white70, fontSize: 13)));
      }

      String modelName = 'AI Ready';
      try {
        final vc = Get.find<VoiceController>();
        modelName = vc.activeModelName.value;
      } catch (_) {}

      final city = _shortenCityName(controller.placeName.value);
      final temp = controller.temperature.value;
      final aqi = controller.aqi.value;

      return Row(
        children: [
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '📍 $city  🌡️ $temp  💨 AQI: $aqi',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _openGodModeSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(50),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.amberAccent.withAlpha(200), width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.amberAccent.withAlpha(40), blurRadius: 6),
                ],
              ),
              child: const Text(
                '[GOD MODE]',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                modelName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _openGodModeSheet() {
    try {
      final godService = Get.find<GodModeIntelligenceService>();
      godService.data.value =
          null; // flush old data to prevent hallucination/overlap
      final topPanelController = Get.find<TopPanelController>();
      topPanelController.checkServicesAndFetch(forceRefresh: true);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(128),
      builder: (context) => const GodModeBottomSheet(),
    );
  }

  Widget _buildDefaultGrid(Color darkVariant) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavIcon(
                Icons.chat, 'Voice Chat', AppRoutes.voiceChat, 0, darkVariant),
            _buildNavIcon(
                Icons.person, 'Profile', AppRoutes.profile, 1, darkVariant),
            _buildNavIcon(
                Icons.sports_esports, 'Games', AppRoutes.game, 2, darkVariant),
            _buildNavIcon(Icons.graphic_eq, 'Voice Studio',
                AppRoutes.voiceStudio, 3, darkVariant),
            _buildNavIcon(
                Icons.alarm, 'Alarm', AppRoutes.alarm, 4, darkVariant),
            _buildNavIcon(Icons.self_improvement, 'Naam Jaap',
                AppRoutes.naamJaap, 5, darkVariant),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavIcon(
                Icons.history, 'History', AppRoutes.history, 6, darkVariant),
            _buildNavIcon(
                Icons.settings, 'Settings', AppRoutes.settings, 7, darkVariant),
            _buildNavIcon(Icons.checklist, 'Reminders', AppRoutes.reminder, 8,
                darkVariant),
            _buildNavIcon(Icons.wallpaper, 'Wallpaper', AppRoutes.wallpaper, 9,
                darkVariant),
            _buildNavIcon(
                Icons.info, 'About', AppRoutes.about, 10, darkVariant),
            // Theme toggle always visible — highlighted to distinguish from nav icons
            _buildThemeToggleButton(darkVariant),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedGrid(Color darkVariant) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavIcon(
                Icons.chat, 'Voice Chat', AppRoutes.voiceChat, 0, darkVariant),
            _buildNavIcon(
                Icons.person, 'Profile', AppRoutes.profile, 1, darkVariant),
            _buildNavIcon(
                Icons.sports_esports, 'Games', AppRoutes.game, 2, darkVariant),
            _buildNavIcon(Icons.graphic_eq, 'Voice Studio',
                AppRoutes.voiceStudio, 3, darkVariant),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavIcon(
                Icons.alarm, 'Alarm', AppRoutes.alarm, 4, darkVariant),
            _buildNavIcon(Icons.self_improvement, 'Naam Jaap',
                AppRoutes.naamJaap, 5, darkVariant),
            _buildNavIcon(
                Icons.history, 'History', AppRoutes.history, 6, darkVariant),
            _buildNavIcon(
                Icons.settings, 'Settings', AppRoutes.settings, 7, darkVariant),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavIcon(Icons.checklist, 'Reminders', AppRoutes.reminder, 8,
                darkVariant),
            _buildNavIcon(Icons.wallpaper, 'Wallpaper', AppRoutes.wallpaper, 9,
                darkVariant),
            _buildNavIcon(
                Icons.info, 'About', AppRoutes.about, 10, darkVariant),
            _buildThemeToggleButton(darkVariant),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (GetPlatform.isDesktop || GetPlatform.isWeb);

    return MouseRegion(
      onEnter: isDesktop ? (_) => controller.expand() : null,
      onExit: isDesktop ? (_) => controller.collapse() : null,
      child: Semantics(
        label: 'Toggle navigation menu',
        button: true,
        child: GestureDetector(
          onTap: isDesktop ? null : () => controller.toggle(),
          child: Obx(() {
            final currentColor = controller.currentColor;
            final darkVariant = controller.getDarkVariant();

            return TweenAnimationBuilder<Color?>(
              tween: ColorTween(begin: currentColor, end: currentColor),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, color, child) {
                final c = color ?? currentColor;
                return GlassContainer(
                  backgroundColor: c.withAlpha(64),
                  border: Border.all(
                    color: c.withAlpha(128),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.withAlpha(77),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                  padding: const EdgeInsets.all(12),
                  child: child!,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axis: Axis.vertical,
                          child: child,
                        ),
                      );
                    },
                    child: controller.isExpanded.value
                        ? _buildExpandedGrid(darkVariant)
                        : _buildDefaultGrid(darkVariant),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, String? route, int index,
      Color darkVariant) {
    final isActive = route != null && widget.currentRoute == route;
    return Semantics(
      label: label,
      button: true,
      child: PressScale(
        onTap: route != null ? () => _navigateTo(route, index) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: context.r.all(12),
          decoration: BoxDecoration(
            color: isActive ? darkVariant.withAlpha(230) : Colors.transparent,
            borderRadius: BorderRadius.circular(context.r.scale(14)),
            border: isActive
                ? Border.all(
                    color: darkVariant.withAlpha(204),
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: context.r.scale(20),
                color: isActive ? Colors.white : Colors.grey[700],
              ),
              RSizedBox(h: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: context.r.sp(9),
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.wallpaper;
      case AppThemeMode.light:
        return Icons.wb_sunny;
      case AppThemeMode.dark:
        return Icons.nights_stay;
    }
  }

  Widget _buildThemeToggleButton(Color darkVariant) {
    return Obx(() {
      final mode = ThemeService.to.appThemeMode.value;
      final resolvedBrightness = ThemeService.to.resolvedBrightness;
      final isDark = resolvedBrightness == Brightness.dark;

      return GestureDetector(
        onTap: _cycleThemeMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: context.r.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkVariant.withAlpha(128),
                darkVariant.withAlpha(77),
              ],
            ),
            borderRadius: BorderRadius.circular(context.r.scale(14)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(179)
                  : darkVariant.withAlpha(179),
              width: 1.5,
            ),
          ),
          child: Icon(
            _getThemeIcon(mode),
            size: context.r.scale(22),
            color: isDark ? Colors.white : darkVariant,
          ),
        ),
      );
    });
  }
}

/// Expandable Text Input Bottom Sheet
/// Shows a large 20x text input area when user taps on the text field
class ExpandableTextInput extends StatefulWidget {
  final TextEditingController? controller;
  final VoidCallback? onSend;
  final String hintText;
  final int maxLines;

  const ExpandableTextInput({
    super.key,
    this.controller,
    this.onSend,
    this.hintText = 'Type or speak...',
    this.maxLines = 8,
  });

  @override
  State<ExpandableTextInput> createState() => _ExpandableTextInputState();
}

class _ExpandableTextInputState extends State<ExpandableTextInput>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late AnimationController _animationController;
  bool _isExpanded = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_isExpanded) {
      _showExpandedInput();
    }
  }

  void _showExpandedInput() {
    setState(() => _isExpanded = true);
    _animationController.forward();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(128),
      builder: (context) => _buildExpandedSheet(),
    ).then((_) {
      setState(() => _isExpanded = false);
      _animationController.reverse();
    });
  }

  Widget _buildExpandedSheet() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withAlpha(26),
                Colors.white.withAlpha(13),
              ],
            ),
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(context.r.scale(24))),
            border: Border.all(
              color: Colors.white.withAlpha(77),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(context.r.scale(24))),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: EdgeInsets.only(
                            top: context.r.scale(12),
                            bottom: context.r.scale(8)),
                        width: context.r.scale(40),
                        height: context.r.scale(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[400]?.withAlpha(128),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.r.scale(20),
                            vertical: context.r.scale(8)),
                        child: Row(
                          children: [
                            Text(
                              'Enter your message',
                              style: TextStyle(
                                fontSize: context.r.sp(16),
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: context.r.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200]?.withAlpha(128),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: context.r.scale(20),
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Large text input area
                      Expanded(
                        child: Padding(
                          padding: context.r.all(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(38),
                              borderRadius:
                                  BorderRadius.circular(context.r.scale(16)),
                              border: Border.all(
                                color: Colors.white.withAlpha(77),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: TextStyle(
                                fontSize: context.r.sp(18),
                                height: 1.6,
                                color: AppColors.textPrimary(context),
                              ),
                              decoration: InputDecoration(
                                hintText: widget.hintText,
                                hintStyle: TextStyle(
                                  fontSize: context.r.sp(16),
                                  color: AppColors.textTertiary(context),
                                ),
                                contentPadding: context.r.all(20),
                                border: InputBorder.none,
                              ),
                              scrollPhysics: const BouncingScrollPhysics(),
                            ),
                          ),
                        ),
                      ),
                      // Bottom actions
                      Padding(
                        padding: context.r.all(20),
                        child: Row(
                          children: [
                            // Clear button
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                HapticFeedback.lightImpact();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: context.r.scale(20),
                                    vertical: context.r.scale(12)),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200]?.withAlpha(128),
                                  borderRadius: BorderRadius.circular(
                                      context.r.scale(12)),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: context.r.sp(14),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Send button
                            GestureDetector(
                              onTap: () {
                                if (_controller.text.trim().isNotEmpty) {
                                  HapticFeedback.mediumImpact();
                                  if (widget.onSend != null) {
                                    widget.onSend!();
                                  }
                                  Navigator.pop(context);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: context.r.scale(28),
                                    vertical: context.r.scale(12)),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFB2EE),
                                      Color(0xFFFF69B4)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                      context.r.scale(12)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFB2EE)
                                          .withAlpha(102),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: context.r.scale(18),
                                    ),
                                    RSizedBox(w: 8),
                                    Text(
                                      'Send',
                                      style: TextStyle(
                                        fontSize: context.r.sp(14),
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showExpandedInput,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withAlpha(38),
              Colors.white.withAlpha(13),
            ],
          ),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: Colors.white.withAlpha(77),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.keyboard,
                    color: AppColors.iconNeutral(context),
                    size: context.r.scale(24),
                  ),
                  RSizedBox(w: 12),
                  Expanded(
                    child: Text(
                      _controller.text.isEmpty
                          ? widget.hintText
                          : _controller.text,
                      style: TextStyle(
                        fontSize: context.r.sp(15),
                        color: _controller.text.isEmpty
                            ? AppColors.textTertiary(context)
                            : AppColors.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.expand_less,
                    color: Colors.grey[400],
                    size: context.r.scale(20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }
}

class GlassInputPanel extends StatefulWidget {
  final VoidCallback? onKeyboardToggle;
  final VoidCallback? onPauseToggle;
  final VoidCallback? onMicToggle;
  final VoidCallback? onStop;
  final bool isRecording;
  final bool useExpandableInput;

  const GlassInputPanel({
    super.key,
    this.onKeyboardToggle,
    this.onPauseToggle,
    this.onMicToggle,
    this.onStop,
    this.isRecording = false,
    this.useExpandableInput = true,
  });

  @override
  State<GlassInputPanel> createState() => _GlassInputPanelState();
}

class _GlassInputPanelState extends State<GlassInputPanel>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  late AnimationController _micAnimController;
  final TopPanelController _controller = Get.find<TopPanelController>();

  @override
  void initState() {
    super.initState();
    _micAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _micAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentColor = _controller.currentColor;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassContainer(
            height: context.r.scale(72),
            borderRadius: BorderRadius.circular(context.r.scale(30)),
            padding: EdgeInsets.symmetric(horizontal: context.r.scale(16)),
            backgroundColor: currentColor.withAlpha(64),
            border: Border.all(
              color: currentColor.withAlpha(128),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: currentColor.withAlpha(77),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            child: Row(
              children: [
                Row(
                  children: [
                    if (widget.useExpandableInput)
                      Expanded(
                        child: ExpandableTextInput(
                          hintText: 'Type a message...',
                          onSend: () {
                            // Handle send
                            widget.onKeyboardToggle?.call();
                          },
                        ),
                      )
                    else ...[
                      _buildSmallButton(
                        icon: Icons.keyboard,
                        onTap: () {
                          widget.onKeyboardToggle?.call();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildSmallButton(
                        icon: Icons.pause,
                        onTap: () {
                          widget.onPauseToggle?.call();
                        },
                      ),
                    ],
                  ],
                ),
                if (!widget.useExpandableInput) ...[
                  const Spacer(),
                  _buildAnimatedMicButton(),
                  const Spacer(),
                ] else ...[
                  RSizedBox(w: 12),
                  _buildAnimatedMicButton(),
                ],
                RSizedBox(w: 12),
                GestureDetector(
                  onTap: () {
                    widget.onStop?.call();
                  },
                  child: Container(
                    height: context.r.buttonHeight,
                    padding:
                        EdgeInsets.symmetric(horizontal: context.r.scale(20)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(context.r.scale(12)),
                      border: Border.all(
                        color: Colors.white.withAlpha(153),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.stop_circle,
                          color: AppColors.textPrimary(context),
                          size: context.r.scale(20),
                        ),
                        RSizedBox(w: 4),
                        Text(
                          'Stop',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w700,
                            fontSize: context.r.sp(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          RSizedBox(h: 8),
          Center(
            child: Container(
              width: context.r.scale(128),
              height: context.r.scale(4),
              decoration: BoxDecoration(
                color: Colors.grey[400]?.withAlpha(128),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildAnimatedMicButton() {
    final darkVariant = _controller.getDarkVariant();

    return AnimatedBuilder(
      animation: _micAnimController,
      builder: (context, child) {
        final animValue = _micAnimController.value;
        final scale = 1.0 + (0.2 * animValue);
        final yOffset =
            -3.0 * (animValue < 0.5 ? animValue * 2 : (1 - animValue) * 2);
        final shakeX = _isRecording ? (animValue * 2 - 1) * 1.5 : 0.0;

        return GestureDetector(
          onTap: () async {
            setState(() {
              _isRecording = !_isRecording;
            });
            if (_isRecording) {
              _micAnimController.repeat();
            } else {
              _micAnimController.stop();
              _micAnimController.reset();
            }
            widget.onMicToggle?.call();
          },
          child: Transform.translate(
            offset: Offset(shakeX, yOffset),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? const Color(0xFFFF4444)
                      : darkVariant.withAlpha(128),
                  boxShadow: [
                    BoxShadow(
                      color: _isRecording
                          ? const Color(0x66FF4444)
                          : darkVariant.withAlpha(128),
                      blurRadius: _isRecording ? 30 : 20,
                      spreadRadius: _isRecording ? 8 : 0,
                    ),
                    if (_isRecording)
                      const BoxShadow(
                        color: Color(0x40FF4444),
                        blurRadius: 40,
                        spreadRadius: 15,
                      ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isRecording
                        ? const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 28,
                            key: ValueKey('stop'),
                          )
                        : const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 28,
                            key: ValueKey('mic'),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(102),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withAlpha(128),
          ),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF230F1F),
          size: 24,
        ),
      ),
    );
  }
}

class DefaultLayout extends StatefulWidget {
  final Widget content;
  final String currentRoute;
  final VoidCallback? onKeyboardToggle;
  final VoidCallback? onPauseToggle;
  final VoidCallback? onMicToggle;
  final VoidCallback? onStop;
  final bool useDualModeInput;
  final Widget? customTopPanel;

  const DefaultLayout({
    super.key,
    required this.content,
    required this.currentRoute,
    this.onKeyboardToggle,
    this.onPauseToggle,
    this.onMicToggle,
    this.onStop,
    this.useDualModeInput = true,
    this.customTopPanel,
  });

  @override
  State<DefaultLayout> createState() => _DefaultLayoutState();
}

class _DefaultLayoutState extends State<DefaultLayout>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            widget.customTopPanel ??
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 16),
                      child: TopControlPanel(currentRoute: widget.currentRoute),
                    ),
                  ),
                ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.isTablet(context)
                          ? 720
                          : (ResponsiveLayout.isDesktop(context)
                              ? 960
                              : double.infinity),
                    ),
                    child: widget.content,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: widget.useDualModeInput
                  ? DualModeInputPanel(
                      onSendMessage: (text) async {
                        // Route to game controller when a game is active
                        try {
                          final gc = Get.find<GameController>();
                          if (gc.activeGame.value != null) {
                            // Game is active — text input goes to game
                            await gc.processGameInput(text);
                            return;
                          }
                        } catch (_) {}
                        // Default: route to VoiceController AI pipeline
                        try {
                          final vc = Get.find<VoiceController>();
                          await vc.sendMessage();
                        } catch (_) {}
                        widget.onStop?.call();
                      },
                      onVoiceInput: (text) async {
                        // Route to game controller when a game is active
                        try {
                          final gc = Get.find<GameController>();
                          if (gc.activeGame.value != null) {
                            await gc.processGameInput(text);
                            return;
                          }
                        } catch (_) {}
                        // Default: route to VoiceController AI pipeline
                        try {
                          final vc = Get.find<VoiceController>();
                          await vc.processVoiceInput(text);
                        } catch (_) {}
                        widget.onMicToggle?.call();
                      },
                    )
                  : GlassInputPanel(
                      onKeyboardToggle: widget.onKeyboardToggle,
                      onPauseToggle: widget.onPauseToggle,
                      onMicToggle: widget.onMicToggle,
                      onStop: widget.onStop,
                    ),
            ),
            // Banner Ad placed consistently below the input panel
            const Center(child: BannerAdWidget()),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
