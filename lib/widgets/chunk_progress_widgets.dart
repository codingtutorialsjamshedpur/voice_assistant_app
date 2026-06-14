import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/chunked_highlight_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Chunk Progress Display Widget
/// ═══════════════════════════════════════════════════════════════
///
/// Shows real-time progress of chunked message delivery.
/// Displays:
/// - Current chunk number and total chunks
/// - Progress bar showing chunk completion
/// - Number of chunks remaining
/// - Visual indication of background preparation
/// ═══════════════════════════════════════════════════════════════

class ChunkProgressWidget extends StatelessWidget {
  const ChunkProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<ChunkedHighlightService>();

    return Obx(() {
      // Only show if multi-chunk playback is active
      if (!service.isPlayingChunked.value || service.totalChunks.value <= 1) {
        return const SizedBox.shrink();
      }

      final currentChunk = service.currentChunkIndex.value + 1;
      final totalChunks = service.totalChunks.value;
      final remaining = service.chunksRemaining.value;
      final progress = currentChunk / totalChunks;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: Colors.blue.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withAlpha(100),
              blurRadius: 8.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Chunk Info ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reading Chunk ${currentChunk.toString().padLeft(2, '0')}/$totalChunks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                if (remaining > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$remaining more',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Progress Bar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.blue.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue.shade600,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Status Message ──
            Row(
              children: [
                Icon(
                  Icons.volume_up,
                  size: 16,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusMessage(currentChunk, totalChunks, remaining),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Generate status message based on current progress
  String _getStatusMessage(int current, int total, int remaining) {
    if (remaining == 0) {
      return 'Playing final chunk...';
    } else if (remaining == 1) {
      return 'Next chunk preparing in background...';
    } else {
      return 'Preparing next $remaining chunks...';
    }
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Chunk Highlight Indicator
/// ═══════════════════════════════════════════════════════════════
///
/// Displays which chunk's words are currently being highlighted
/// during playback. Shows animated indicator above the message.
/// ═══════════════════════════════════════════════════════════════

class ChunkHighlightIndicator extends StatefulWidget {
  final int totalChunks;
  final int currentChunk;

  const ChunkHighlightIndicator({
    super.key,
    required this.totalChunks,
    required this.currentChunk,
  });

  @override
  State<ChunkHighlightIndicator> createState() =>
      _ChunkHighlightIndicatorState();
}

class _ChunkHighlightIndicatorState extends State<ChunkHighlightIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalChunks <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < widget.totalChunks; i++)
            _buildChunkDot(i, widget.currentChunk),
        ],
      ),
    );
  }

  /// Build individual chunk indicator dot
  Widget _buildChunkDot(int index, int currentChunk) {
    final isActive = index == currentChunk;
    final isDone = index < currentChunk;

    return ScaleTransition(
      scale: isActive ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone
              ? Colors.green.shade600
              : (isActive ? Colors.blue.shade600 : Colors.grey.shade300),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.blue.shade600.withAlpha(150),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Chunk Statistics Panel
/// ═══════════════════════════════════════════════════════════════
///
/// Displays detailed chunk statistics and metadata.
/// Used for debugging and detailed progress tracking.
/// ═══════════════════════════════════════════════════════════════

class ChunkStatisticsPanel extends StatelessWidget {
  const ChunkStatisticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<ChunkedHighlightService>();

    return Obx(() {
      if (!service.isPlayingChunked.value) {
        return const SizedBox.shrink();
      }

      final stats = service.getChunkStats();

      return Container(
        margin: const EdgeInsets.all(12.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chunk Statistics',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            _buildStatRow('Total Chunks', '${stats['totalChunks']}'),
            _buildStatRow('Current Chunk', '${stats['currentChunk'] + 1}'),
            _buildStatRow('Remaining', '${stats['chunksRemaining']}'),
            _buildStatRow(
              'Chunk Sizes (words)',
              '${stats['chunkWordCounts'].join(", ")}',
            ),
          ],
        ),
      );
    });
  }

  /// Build a stat row
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
