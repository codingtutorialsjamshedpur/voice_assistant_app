import 'package:flutter/material.dart';

class BallSortLoadingScreen extends StatefulWidget {
  final VoidCallback onLoadingComplete;
  const BallSortLoadingScreen({super.key, required this.onLoadingComplete});

  @override
  State<BallSortLoadingScreen> createState() => _BallSortLoadingScreenState();
}

class _BallSortLoadingScreenState extends State<BallSortLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;
  late Animation<double> _fade;

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
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.0, 0.3, curve: Curves.easeIn)),
    );

    _ctrl.forward().then((_) {
      Future.delayed(
          const Duration(milliseconds: 300), widget.onLoadingComplete);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Transparent scaffold so app wallpaper shows through
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: Colors.black.withValues(alpha: 0.5), // dim overlay
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    return Opacity(
                      opacity: _fade.value,
                      child: Column(
                        children: [
                          _buildAnimatedTeaser(),
                          const SizedBox(height: 32),
                          const Text(
                            'Ball Sort',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 10)
                              ],
                            ),
                          ),
                          const Text(
                            'Puzzle',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 10)
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),
                _buildProgressBar(),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    String text;
                    if (_ctrl.value < 0.3) {
                      text = 'Mixing the colours…';
                    } else if (_ctrl.value < 0.7) {
                      text = 'Preparing Level…';
                    } else {
                      text = 'Ready!';
                    }
                    return Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.2,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTeaser() {
    return SizedBox(
      height: 120,
      width: 200,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final p = _ctrl.value;

          // Ball 1: Center to Left
          final b1p = ((p - 0.1) * 2.5).clamp(0.0, 1.0);
          final act1 = Curves.easeInOut.transform(b1p);
          final arc1 = 4 * act1 * (1 - act1);

          // Ball 2: Center to Right
          final b2p = ((p - 0.3) * 2.5).clamp(0.0, 1.0);
          final act2 = Curves.easeInOut.transform(b2p);
          final arc2 = 4 * act2 * (1 - act2);

          // Ball 3: Liquid bubble rising in center
          final b3p = ((p - 0.5) * 2.5).clamp(0.0, 1.0);
          final act3 = Curves.easeOutBack.transform(b3p);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Tubes
              Positioned(left: 20, bottom: 0, child: _buildMiniTube()),
              Positioned(
                  left: 85, bottom: 0, child: _buildMiniTube(isLiquid: true)),
              Positioned(left: 150, bottom: 0, child: _buildMiniTube()),

              // Ball 1 (Red)
              if (b1p > 0 && b1p < 1)
                Positioned(
                  left: 85 + 10 - act1 * 65, // moving to left tube
                  bottom: 10 + arc1 * 80,
                  child: _buildMiniBall(Colors.redAccent),
                )
              else if (b1p >= 1)
                Positioned(
                  left: 20 + 10,
                  bottom: 10,
                  child: _buildMiniBall(Colors.redAccent),
                ),

              // Ball 2 (Blue)
              if (b2p > 0 && b2p < 1)
                Positioned(
                  left: 85 + 10 + act2 * 65, // moving to right tube
                  bottom: 10 + arc2 * 80,
                  child: _buildMiniBall(Colors.blueAccent),
                )
              else if (b2p >= 1)
                Positioned(
                  left: 150 + 10,
                  bottom: 10,
                  child: _buildMiniBall(Colors.blueAccent),
                ),

              // Liquid rise
              if (b3p > 0)
                Positioned(
                  left: 85 + 4,
                  bottom: 4,
                  child: Container(
                    width: 22,
                    height: 50 * act3,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.5),
                            blurRadius: 10)
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniTube({bool isLiquid = false}) {
    return Container(
      width: 30,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        boxShadow: isLiquid
            ? [
                BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 2)
              ]
            : null,
      ),
    );
  }

  Widget _buildMiniBall(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration:
          BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.6),
          blurRadius: 6,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        )
      ]),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progress.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00FFFF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFFF).withOpacity(0.5),
                        blurRadius: 10,
                      )
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
}
