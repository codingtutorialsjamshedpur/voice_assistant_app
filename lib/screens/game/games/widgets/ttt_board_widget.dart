import 'package:flutter/material.dart';
import '../../../../shared/theme/responsive.dart';

class TttBoardWidget extends StatelessWidget {
  final List<String> board;
  final int roundNumber;
  final String? statusLine;
  final Function(int index) onTap;
  final List<int> winningLine;

  const TttBoardWidget({
    super.key,
    required this.board,
    required this.roundNumber,
    this.statusLine,
    required this.onTap,
    this.winningLine = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRoundHeader(context),
        const SizedBox(height: 16),
        _buildGrid(context),
      ],
    );
  }

  Widget _buildRoundHeader(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.r.scale(20), vertical: context.r.scale(10)),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A),
          borderRadius: BorderRadius.circular(context.r.scale(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: Colors.white, size: context.r.scale(18)),
                SizedBox(width: context.r.scale(6)),
                Text(
                  'Round $roundNumber',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: context.r.sp(16),
                  ),
                ),
              ],
            ),
            if (statusLine != null) ...[
              const SizedBox(height: 4),
              Text(
                statusLine!,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: context.r.sp(14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        margin: EdgeInsets.all(context.r.scale(16)),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF4FC3F7), width: context.r.scale(1.5)),
          borderRadius: BorderRadius.circular(context.r.scale(4)),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          itemCount: 9,
          itemBuilder: (_, index) => _buildCell(context, index),
        ),
      ),
    );
  }

  Widget _buildCell(BuildContext context, int index) {
    final value = board[index];
    final isWinner = winningLine.contains(index);

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isWinner
              ? const Color(0xFF1E4DB7).withValues(alpha: 0.4)
              : const Color(0xFF0D2252),
          border: Border.all(color: const Color(0xFF4FC3F7), width: context.r.scale(0.75)),
        ),
        child: Center(
          child: value.isEmpty
              ? const SizedBox.shrink()
              : _buildPiece(context, value, isWinner, index),
        ),
      ),
    );
  }

  Widget _buildPiece(BuildContext context, String value, bool isWinner, int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${board.join()}_$index'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.elasticOut,
      builder: (_, scale, __) {
        return Transform.scale(
          scale: scale,
          child: value == 'X'
              ? _XPainter(isWinner: isWinner)
              : _OPainter(isWinner: isWinner),
        );
      },
    );
  }
}

class _XPainter extends StatelessWidget {
  final bool isWinner;
  const _XPainter({this.isWinner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(context.r.scale(12)),
      child: CustomPaint(
        painter: _XCustomPainter(isWinner: isWinner),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _XCustomPainter extends CustomPainter {
  final bool isWinner;
  _XCustomPainter({this.isWinner = false});

  @override
  void paint(Canvas canvas, Size size) {
    final color = isWinner ? const Color(0xFFBAE6FD) : const Color(0xFF7DD3FC);
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.28
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = size.width * 0.36
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final p1 = Offset(size.width * 0.15, size.height * 0.15);
    final p2 = Offset(size.width * 0.85, size.height * 0.85);
    final p3 = Offset(size.width * 0.85, size.height * 0.15);
    final p4 = Offset(size.width * 0.15, size.height * 0.85);

    canvas.drawLine(p1, p2, glowPaint);
    canvas.drawLine(p3, p4, glowPaint);
    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(p3, p4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OPainter extends StatelessWidget {
  final bool isWinner;
  const _OPainter({this.isWinner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(context.r.scale(12)),
      child: CustomPaint(
        painter: _OCustomPainter(isWinner: isWinner),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _OCustomPainter extends CustomPainter {
  final bool isWinner;
  _OCustomPainter({this.isWinner = false});

  @override
  void paint(Canvas canvas, Size size) {
    final color = isWinner ? const Color(0xFFFF8C5A) : const Color(0xFFFF6B35);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.36;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = size.width * 0.28
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.22
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, glowPaint);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WinningLinePainter extends StatelessWidget {
  final List<int> winningLine;
  final List<String> board;

  const WinningLinePainter({
    super.key,
    required this.winningLine,
    required this.board,
  });

  @override
  Widget build(BuildContext context) {
    if (winningLine.length != 3) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, progress, __) {
        return CustomPaint(
          painter: _WinningLinePainter(
            winningLine: winningLine,
            progress: progress,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _WinningLinePainter extends CustomPainter {
  final List<int> winningLine;
  final double progress;

  _WinningLinePainter({
    required this.winningLine,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (winningLine.length != 3) return;

    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;

    final startCell = winningLine.first;
    final endCell = winningLine.last;

    final startX = (startCell % 3) * cellWidth + cellWidth / 2;
    final startY = (startCell ~/ 3) * cellHeight + cellHeight / 2;
    final endX = (endCell % 3) * cellWidth + cellWidth / 2;
    final endY = (endCell ~/ 3) * cellHeight + cellHeight / 2;

    final currentEndX = startX + (endX - startX) * progress;
    final currentEndY = startY + (endY - startY) * progress;

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(startX, startY), Offset(currentEndX, currentEndY), glowPaint);
    canvas.drawLine(
        Offset(startX, startY), Offset(currentEndX, currentEndY), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
