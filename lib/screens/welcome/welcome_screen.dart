import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../services/storage_service.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/animated_orb.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _slideController;
  late AnimationController _orbBounceController;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.graphic_eq,
      'title': 'Voice-First AI',
      'description':
          'A conversational spiritual guide that allows users to speak naturally to connect with ancient wisdom, rather than typing queries.',
      'glowColor': const Color(0x4D95E1D3),
      'iconColor': const Color(0xFF4A148C),
    },
    {
      'icon': Icons.sports_esports,
      'title': 'Voice Assisted Games',
      'description':
          'Interactive spiritual games designed for mindful play, helping users sharpen focus and cultivate inner peace through voice-controlled engagement.',
      'glowColor': const Color(0x4DFFB1EE),
      'iconColor': const Color(0xFF880E4F),
    },
    {
      'icon': Icons.self_improvement,
      'title': 'Naam Jaap & Alarms',
      'description':
          'Spiritual practice tools including:\n• Customizable spiritual alarms\n• Voice-activated counters for tracking daily Naam Jaap (mantra repetition) practice',
      'glowColor': const Color(0x4D4FC3F7),
      'iconColor': const Color(0xFF006064),
    },
    {
      'icon': Icons.psychology,
      'title': 'Multi-Model Intelligence',
      'description':
          'Advanced AI architecture utilizing multiple models to provide profound, context-aware spiritual guidance that adapts to individual needs.',
      'glowColor': const Color(0x4D69F0AE),
      'iconColor': const Color(0xFF1B5E20),
    },
  ];

  OrbState _orbStateForPage(int page) {
    switch (page) {
      case 0:
        return OrbState.speaking;
      case 1:
        return OrbState.listening;
      case 2:
        return OrbState.thinking;
      case 3:
        return OrbState.idle;
      default:
        return OrbState.idle;
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.85,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _orbBounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _slideController.forward(from: 0);
    _orbBounceController.forward(from: 0);
  }

  void _goToNextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _getStarted();
    }
  }

  Future<void> _getStarted() async {
    await StorageService.to.setFirstTime(false);
    Get.offAllNamed(AppRoutes.privacyPolicy);
  }

  void _skip() async {
    await StorageService.to.setFirstTime(false);
    Get.offAllNamed(AppRoutes.privacyPolicy);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    _orbBounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: context.r.all(16),
                child: Semantics(
                  label: 'Skip onboarding',
                  button: true,
                  child: GestureDetector(
                    onTap: _skip,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(context.r.scale(20)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: context.r.symmetric(h: 16, v: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(context.r.scale(20)),
                            border: Border.all(
                              color: Colors.white.withAlpha(77),
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: context.r.sp(14),
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(200) : Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Animated Face - Using reusable AnimatedOrb widget
            AnimatedBuilder(
              animation: _orbBounceController,
              builder: (context, child) {
                final scale = 1.0 + (Curves.elasticOut.transform(_orbBounceController.value) * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: AnimatedOrb(
                size: context.r.scale(140),
                showTalkingAnimation: true,
                autoBlink: true,
                orbState: _orbStateForPage(_currentPage),
              ),
            ),
            const RSizedBox(h: 40),
            // Horizontal Sliding Cards with Partial Visibility
            SizedBox(
              height: context.r.scale(320),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _buildSlideCard(_slides[index], index);
                },
              ),
            ),
            // Page Indicators
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.r.scale(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => Semantics(
                    label: 'Page ${index + 1} of ${_slides.length}',
                    child: GestureDetector(
                      onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: context.r.all(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: context.r.scale(8),
                          height: context.r.scale(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? (Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(204) : const Color(0xFF1F2937).withAlpha(204))
                                : const Color(0xFF9CA3AF).withAlpha(128),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Get Started / Next Button
            Padding(
              padding: context.r.all(16),
              child: Semantics(
                label: _currentPage < _slides.length - 1 ? 'Next' : 'Get started',
                button: true,
                child: PressScale(
                  onTap: _goToNextPage,
                  child: Container(
                    width: double.infinity,
                    height: context.r.buttonHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB1EE),
                      borderRadius: BorderRadius.circular(context.r.scale(16)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB1EE).withAlpha(128),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage < _slides.length - 1 ? 'Next' : 'Get Started',
                            style: TextStyle(
                              fontSize: context.r.sp(18),
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          if (_currentPage < _slides.length - 1)
                            Padding(
                              padding: EdgeInsets.only(left: context.r.scale(8)),
                              child: Icon(Icons.arrow_forward, color: Colors.black, size: context.r.scale(20)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Home Indicator
            Center(
              child: Container(
                width: context.r.scale(128),
                height: context.r.scale(4),
                margin: EdgeInsets.only(bottom: context.r.scale(8)),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CA3AF).withAlpha(128),
                  borderRadius: BorderRadius.circular(context.r.scale(2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideCard(Map<String, dynamic> slide, int index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 0.0;
        if (_pageController.position.haveDimensions) {
          value = index.toDouble() - (_pageController.page ?? 0);
        }

        value = value.abs();
        value = value.clamp(0.0, 1.0);

        final scale = 1.0 - (value * 0.15);
        final opacity = 1.0 - (value * 0.5);

        return Semantics(
          label: slide['title'] as String,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.r.scale(16)),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(64),
                    borderRadius: BorderRadius.circular(context.r.scale(24)),
                    border: Border.all(
                      color: Colors.white.withAlpha(102),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: slide['glowColor'],
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(context.r.scale(24)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: context.r.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withAlpha(77),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Container(
                              width: context.r.scale(56),
                              height: context.r.scale(56),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(102),
                                borderRadius: BorderRadius.circular(context.r.scale(18)),
                                boxShadow: [
                                  BoxShadow(
                                    color: slide['glowColor'],
                                    blurRadius: 15,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                slide['icon'],
                                size: context.r.scale(32),
                                color: slide['iconColor'],
                              ),
                            ),
                            const RSizedBox(h: 20),
                            // Title
                            Text(
                              slide['title'],
                              style: AppTextStyles.titleLarge(context).copyWith(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(230) : Color(0xFF111827),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const RSizedBox(h: 16),
                            // Description
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  slide['description'],
                                  textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMedium(context).copyWith(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withAlpha(190) : Color(0xFF374151),
                                ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
