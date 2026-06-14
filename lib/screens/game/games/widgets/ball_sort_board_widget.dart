import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controllers/ball_sort_controller.dart';
import '../../../../shared/theme/responsive.dart';
import '../../../../controllers/game_controller.dart';
import 'ball_sort_ball_widget.dart';
import 'ball_sort_tube_widget.dart';
import 'ball_sort_liquid_pour_overlay.dart';

class BallSortBoardWidget extends StatefulWidget {
  const BallSortBoardWidget({super.key});

  @override
  State<BallSortBoardWidget> createState() => _BallSortBoardWidgetState();
}

class _BallSortBoardWidgetState extends State<BallSortBoardWidget>
    with TickerProviderStateMixin {
  final BallSortController _bsc = Get.find<BallSortController>();
  late AnimationController _pourCtrl;
  late Animation<double> _pourProgress;
  final List<GlobalKey> _tubeKeys = [];
  final Map<int, Offset> _tubePositions = {};

  @override
  void initState() {
    super.initState();
    _pourCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pourProgress = CurvedAnimation(
      parent: _pourCtrl,
      curve: Curves.easeInOut,
    );

    _pourCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bsc.completePendingMove();
      }
    });
  }

  @override
  void dispose() {
    _pourCtrl.dispose();
    super.dispose();
  }

  /// Pick a ball diameter (and therefore a tube size) that:
  ///   * fits every tube on screen with no horizontal scrolling,
  ///   * keeps a comfortable touch target (>= 30 px),
  ///   * never lets the tube column grow taller than the available
  ///     height (so 8+ tube levels stay readable on short screens).
  ///
  /// `maxWidth` and `maxHeight` come from the LayoutBuilder.
  /// `tubeCount` is the total number of tubes for this level.
  /// `columns` is the number of tubes per row that fits horizontally
  /// at the candidate diameter — the layout engine uses it to decide
  /// how many rows are needed.
  double _computeBallDiameter({
    required double maxWidth,
    required double maxHeight,
    required int tubeCount,
  }) {
    if (tubeCount <= 0) return 40;
    const double tubeWidthRatio = 1.6;
    const double horizontalPadding = 12.0; // matches the wrapping spacing
    // Use the smaller of: width-derived diameter vs height-derived
    // diameter (so 4 capacity * 1.08 slot + 0.6 vertical padding fits).
    final double heightBudget = (maxHeight - 16).clamp(120.0, 400.0);

    double best = 30;
    for (final candidate in const [56.0, 52.0, 48.0, 44.0, 40.0, 36.0, 32.0]) {
      if (candidate > heightBudget / 5.5) continue;
      // Figure out how many tubes fit per row at this diameter.
      final perRow =
          ((maxWidth - horizontalPadding) / (candidate * tubeWidthRatio + 8))
              .floor();
      final cols = perRow.clamp(1, tubeCount);
      final neededWidth =
          cols * (candidate * tubeWidthRatio + 8) + horizontalPadding;
      if (neededWidth <= maxWidth && candidate >= 30) {
        best = candidate;
        break;
      }
    }

    // Clamp by tube count so 2-3 tube levels feel generous.
    if (tubeCount <= 3) best = best.clamp(44, 56);
    if (tubeCount <= 5) best = best.clamp(38, 50);
    if (tubeCount <= 7) best = best.clamp(34, 44);
    if (tubeCount > 7) best = best.clamp(28, 38);
    return best;
  }

  void _recordTubePositions() {
    _tubePositions.clear();
    for (int i = 0; i < _tubeKeys.length && i < _bsc.tubes.length; i++) {
      final renderBox =
          _tubeKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        _tubePositions[i] = position;
      }
    }
  }

  Offset? _getTubeCenterTop(int index) {
    final renderBox =
        _tubeKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    return Offset(position.dx + size.width / 2, position.dy);
  }

  /// Returns the tube's bounding rect in the board's local coordinate
  /// system (the same coord system the outer Stack uses), or null if
  /// the tube has not been laid out yet. Used by the liquid pour
  /// overlay to position the transformed source tube precisely.
  Rect? _getTubeRect(int index) {
    if (index < 0 || index >= _tubeKeys.length) return null;
    final ctx = _tubeKeys[index].currentContext;
    if (ctx == null) return null;
    final tubeBox = ctx.findRenderObject() as RenderBox?;
    if (tubeBox == null) return null;
    final boardBox = context.findRenderObject() as RenderBox?;
    if (boardBox == null) return null;
    final tubeOrigin = tubeBox.localToGlobal(Offset.zero);
    final boardOrigin = boardBox.localToGlobal(Offset.zero);
    final localTL = tubeOrigin - boardOrigin;
    return localTL & tubeBox.size;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_bsc.tubes.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Subscribing to tubes and isAnimating here ensures full rebuild
      // whenever GetX state changes.
      final tubeCount = _bsc.tubes.length;
      final animating = _bsc.isAnimating.value;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: context.r.scale(4), vertical: context.r.scale(4)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            // Reserve some height for the stats bar and action buttons.
            const chromeHeight = 76.0;
            final availableHeight =
                (constraints.maxHeight - chromeHeight).clamp(120.0, 400.0);
            final ballDiameter = _computeBallDiameter(
              maxWidth: maxWidth,
              maxHeight: availableHeight,
              tubeCount: tubeCount,
            );

            while (_tubeKeys.length < tubeCount) {
              _tubeKeys.add(GlobalKey());
            }

            return Stack(
              children: [
                Container(
                  padding: EdgeInsets.all(context.r.scale(10)),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(context.r.scale(24)),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatsBar(),
                      SizedBox(height: context.r.scale(6)),
                      _buildActionButtons(),
                      SizedBox(height: context.r.scale(8)),
                      Flexible(child: _buildTubeGrid(ballDiameter)),
                    ],
                  ),
                ),
                if (animating) _buildPourOverlay(ballDiameter),
              ],
            );
          },
        ),
      );
    });
  }

  Widget _buildPourOverlay(double ballDiameter) {
    if (_bsc.isLiquidMode) {
      return _buildLiquidPourOverlay(ballDiameter);
    }
    return _buildBallPourOverlay(ballDiameter);
  }

  Widget _buildLiquidPourOverlay(double ballDiameter) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pourCtrl.isAnimating) return;
      _recordTubePositions();
      _pourCtrl.forward(from: 0.0);
    });

    final srcRect = _getTubeRect(_bsc.animSrcIndex);
    final dstRect = _getTubeRect(_bsc.animDstIndex);
    if (srcRect == null || dstRect == null) {
      return const SizedBox.shrink();
    }

    final srcTube = _bsc.tubes[_bsc.animSrcIndex];
    final dstTube = _bsc.tubes[_bsc.animDstIndex];

    return Positioned.fill(
      child: IgnorePointer(
        child: BallSortLiquidPour(
          key: ValueKey(
              'liquid_pour_${_bsc.animSrcIndex}_${_bsc.animDstIndex}_${_pourCtrl.value}'),
          sourceRect: srcRect,
          destRect: dstRect,
          sourceBalls: List<String>.from(srcTube.balls),
          sourceCapacity: srcTube.capacity,
          destBalls: List<String>.from(dstTube.balls),
          destCapacity: dstTube.capacity,
          segmentsToPour: _bsc.animSegmentsToPour,
          liquidColorKey: _bsc.animBallColor,
          ballDiameter: ballDiameter,
          onComplete: () => _bsc.completePendingMove(),
        ),
      ),
    );
  }

  Widget _buildBallPourOverlay(double ballDiameter) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPourAnimation(ballDiameter);
    });

    return AnimatedBuilder(
      animation: _pourProgress,
      builder: (context, child) {
        final srcPos = _getTubeCenterTop(_bsc.animSrcIndex);
        final dstPos = _getTubeCenterTop(_bsc.animDstIndex);

        if (srcPos == null || dstPos == null) return const SizedBox.shrink();

        final progress = _pourProgress.value;
        final ballColorName = _bsc.animBallColor;
        final ballColor =
            BallColor.palette[ballColorName] ?? Colors.transparent;

        Offset ballPos;
        final liftHeight = ballDiameter * 2.8;

        // Compute the exact stack position the new ball should occupy
        // inside the destination tube, matching the layout used by
        // BallSortTubeWidget. The new ball always sits at the top of
        // the existing stack so the drop never has to overshoot.
        final tubeHeight = ballDiameter * 4.8;
        final tubeVerticalPadding = ballDiameter * 0.3;
        final ballSlotHeight = ballDiameter * 1.08;
        final columnBottom = dstPos.dy + tubeHeight - tubeVerticalPadding;
        final dstBallsBeforeMove = _bsc.tubes[_bsc.animDstIndex].balls.length;
        final landingY =
            columnBottom - (dstBallsBeforeMove + 0.5) * ballSlotHeight;
        // Clamp landingY so the ball never goes past the tube opening
        // (it must not touch the tube base or outside surface).
        final safeLandingY = landingY < dstPos.dy ? dstPos.dy : landingY;

        // Three-stage path:
        //   1) Vertical lift straight up from the source tube.
        //   2) Smooth curved horizontal arc above the tubes.
        //   3) Vertical drop straight down into the destination tube,
        //      landing precisely at the correct stack position with
        //      no bounce, ground touch, or outside-surface contact.
        if (progress < 0.3) {
          // Phase 1: Vertical lift from source
          final phaseProgress = (progress / 0.3);
          final eased = Curves.easeOutCubic.transform(phaseProgress);
          ballPos = Offset(
            srcPos.dx,
            srcPos.dy - liftHeight * eased,
          );
        } else if (progress < 0.7) {
          // Phase 2: Smooth curved horizontal trajectory above tubes
          final phaseProgress = ((progress - 0.3) / 0.4);
          final easedX = Curves.easeInOutSine.transform(phaseProgress);

          // Add a gentle arc upwards during horizontal travel so the
          // ball never dips toward the ground or the tube base.
          final parabola =
              1 - (2 * phaseProgress - 1) * (2 * phaseProgress - 1);
          final extraLift = ballDiameter * 1.5 * parabola;

          ballPos = Offset(
            srcPos.dx + (dstPos.dx - srcPos.dx) * easedX,
            srcPos.dy - liftHeight - extraLift,
          );
        } else {
          // Phase 3: Vertical drop into destination tube.
          // Use a smooth easeIn (gravity-like) curve and clamp the
          // end-point to the computed landing Y so the ball always
          // stops at the correct stack position without bouncing
          // against the tube base or overshooting the surface.
          final phaseProgress = ((progress - 0.7) / 0.3).clamp(0.0, 1.0);
          final eased = Curves.easeInCubic.transform(phaseProgress);
          final startY = dstPos.dy - liftHeight;
          ballPos = Offset(
            dstPos.dx,
            startY + (safeLandingY - startY) * eased,
          );
        }

        return Positioned(
          left: ballPos.dx - ballDiameter / 2,
          top: ballPos.dy - ballDiameter / 2,
          child: BallSortBallWidget(
            ballColor: ballColor,
            ballDiameter: ballDiameter,
            isTopBall: false,
          ),
        );
      },
    );
  }

  void _startPourAnimation(double ballDiameter) {
    if (_pourCtrl.isAnimating) return;
    _recordTubePositions();
    _pourCtrl.forward(from: 0.0);
  }

  Widget _buildStatsBar() {
    return Obx(() {
      final minutes = _bsc.elapsedSeconds.value ~/ 60;
      final seconds = _bsc.elapsedSeconds.value % 60;
      final timeStr =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: context.r.scale(4)),
        child: Row(
          children: [
            Expanded(
              child: _statChipWithHint(
                label: 'Level',
                value: _bsc.currentLevel.value.toString(),
                tooltip: 'Current level you are playing',
              ),
            ),
            SizedBox(width: context.r.scale(4)),
            Expanded(
              child: _statChipWithHint(
                label: 'Best',
                value: _bsc.optimalMoves.value.toString(),
                tooltip:
                    'Minimum number of moves needed to solve this level (best solution)',
              ),
            ),
            SizedBox(width: context.r.scale(4)),
            Expanded(
              child: _statChipWithHint(
                label: 'Moves',
                value:
                    '${_bsc.moveCount.value} / ${_bsc.maxAllowedMoves.value}',
                tooltip:
                    'Moves you have used out of the maximum allowed for this level',
              ),
            ),
            SizedBox(width: context.r.scale(4)),
            Expanded(
              child: _statChipWithHint(
                label: 'Time',
                value: timeStr,
                tooltip: 'Time spent on this level',
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _statChipWithHint({
    required String label,
    required String value,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      textStyle: TextStyle(color: Colors.white, fontSize: context.r.sp(12)),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(context.r.scale(8)),
      ),
      padding: EdgeInsets.symmetric(horizontal: context.r.scale(10), vertical: context.r.scale(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.r.scale(8), vertical: context.r.scale(5)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(context.r.scale(8)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label: ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: context.r.sp(11),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: context.r.sp(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Obx(() {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: context.r.scale(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton('↩', 'Undo', _bsc.canUndo, () => _bsc.undo()),
            _actionButton('↪', 'Redo', _bsc.canRedo, () => _bsc.redo()),
            _actionButton('↺', 'Reset', true, () => _bsc.restartLevel()),
            _actionButton('💡', 'Hint', true, () => _requestAiHint()),
          ],
        ),
      );
    });
  }

  Future<void> _requestAiHint() async {
    try {
      final gc = Get.find<GameController>();
      if (gc.activeGame.value != null) {
        await gc.processGameInput('hint');
      }
    } catch (_) {
      final hint = _bsc.computeHint();
      if (hint != null) {
        _bsc.hintHighlight.assignAll(hint);
        Future.delayed(const Duration(milliseconds: 2500), () {
          _bsc.hintHighlight.clear();
        });
      }
    }
  }

  Widget _actionButton(
      String icon, String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.r.scale(12), vertical: context.r.scale(8)),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(context.r.scale(16)),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: context.r.sp(14))),
            SizedBox(width: context.r.scale(4)),
            Text(
              label,
              style: TextStyle(
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                fontSize: context.r.sp(12),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTubeGrid(double ballDiameter) {
    final tubeCount = _bsc.tubes.length;
    final isAnimating = _bsc.isAnimating.value;
    final isLiquid = _bsc.isLiquidMode;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: context.r.scale(8),
        runSpacing: context.r.scale(12),
        children: List.generate(tubeCount, (i) {
          final tube = _bsc.tubes[i];
          final isSelected = _bsc.selectedTubeIndex.value == i;
          final isHintSrc =
              _bsc.hintHighlight.length > 1 && _bsc.hintHighlight[0] == i;
          final isHintDst =
              _bsc.hintHighlight.length > 1 && _bsc.hintHighlight[1] == i;
          final isCompleted = !tube.isEmpty && tube.isComplete;
          final isAnimatingSource = isAnimating && _bsc.animSrcIndex == i;
          // In liquid mode we hide the in-place source tube entirely
          // (the pour overlay draws a transformed copy), so the
          // bottom-slot reservation isn't needed.
          final hideSourceTubeInPlace = isAnimatingSource && isLiquid;
          final tubeWidget = BallSortTubeWidget(
            tubeIndex: i,
            tube: tube,
            ballDiameter: ballDiameter,
            isSelected: isSelected,
            isHintSource: isHintSrc,
            isHintDest: isHintDst,
            isCompleted: isCompleted,
            hideTopBalls: isAnimatingSource ? _bsc.animSegmentsToPour : 0,
            onTap: () => _bsc.onTubeTap(i),
          );

          return RepaintBoundary(
            child: Opacity(
              opacity: hideSourceTubeInPlace ? 0.0 : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                key: _tubeKeys[i],
                children: [
                  tubeWidget,
                  SizedBox(height: context.r.scale(4)),
                  Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: context.r.sp(11),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
