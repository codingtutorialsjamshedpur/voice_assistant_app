import 'package:flutter/material.dart';
import '../../../../services/sound_service.dart';

class TttLoadingScreen extends StatefulWidget {
  final VoidCallback onLoadingComplete;
  const TttLoadingScreen({super.key, required this.onLoadingComplete});

  @override
  State<TttLoadingScreen> createState() => _TttLoadingScreenState();
}

class _TttLoadingScreenState extends State<TttLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    SoundService.to.playEffect('assets/sounds/game_sounds/slowdown1.mp3');

    _ctrl.forward().then((_) {
      Future.delayed(
          const Duration(milliseconds: 200), widget.onLoadingComplete);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1A3D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: _buildLogo(),
                  ),
                );
              },
            ),
            const SizedBox(height: 60),
            _buildProgressBar(),
            const SizedBox(height: 14),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Stack(
      children: [
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StrokeText(
              text: 'TIC',
              fillColor: Color(0xFF4DD9D5),
            ),
            _StrokeText(
              text: 'TAC',
              fillColor: Color(0xFF4DD9D5),
            ),
            _StrokeText(
              text: 'TOE',
              fillColor: Color(0xFF7C3AED),
            ),
          ],
        ),
        Positioned(
          top: 8,
          left: 0,
          child: Stack(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 118,
          left: 95,
          child: Transform.rotate(
            angle: 0.5,
            child: const Text(
              '✕',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          top: 125,
          left: 120,
          child: Transform.rotate(
            angle: -0.3,
            child: const Text(
              '✳',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF1C2E5E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progress.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4DD9D5),
                    borderRadius: BorderRadius.circular(8),
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

class _StrokeText extends StatelessWidget {
  final String text;
  final Color fillColor;

  const _StrokeText({
    required this.text,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..color = Colors.white,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            color: fillColor,
          ),
        ),
      ],
    );
  }
}
