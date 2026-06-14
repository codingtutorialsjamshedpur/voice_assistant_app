import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../services/audio_export_service.dart';
import '../shared/controllers/top_panel_controller.dart';
import '../shared/theme/responsive.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AudioExportPanel
///
/// A compact, premium row of audio-action buttons for a single chat message.
///
/// States:
///   ① Idle     – small download icon inside a faint accent ring; single tap starts.
///   ② Saving   – animated WhatsApp-style sweeping gradient arc showing 0→100 %.
///                Tap again to cancel.
///   ③ Ready    – blinking file icon.  Tap → Play ▶ / Share ↗ / Delete 🗑 chips.
/// ─────────────────────────────────────────────────────────────────────────────
class AudioExportPanel extends StatelessWidget {
  final String messageId;
  final String messageText;

  /// 'voiceChat' or 'game'
  final String brandingScreen;

  /// BCP-47 language code for the TTS engine accent (e.g. 'pa-IN', 'or', 'sa')
  final String? languageCode;

  const AudioExportPanel({
    super.key,
    required this.messageId,
    required this.messageText,
    this.brandingScreen = 'voiceChat',
    this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AudioExportService>();

    return Obx(() {
      Color accent = const Color(0xFFB39DDB);
      try {
        accent = Get.find<TopPanelController>().currentColor;
      } catch (_) {}

      final fileReady = service.isFileReady(messageId);
      final isGen = service.isCurrentlyGenerating(messageId);
      final progress = service.getProgress(messageId);
      final playing = service.isPlaying(messageId);

      if (fileReady) {
        // ── State ③: File ready — blinking file + action chips ────────────
        return _ReadyRow(
          messageId: messageId,
          messageText: messageText,
          service: service,
          playing: playing,
          accent: accent,
        );
      }

      // ── State ① / ②: Idle / Saving ────────────────────────────────────
      return _DownloadRing(
        messageId: messageId,
        messageText: messageText,
        brandingScreen: brandingScreen,
        languageCode: languageCode,
        service: service,
        isGenerating: isGen,
        progress: progress,
        accent: accent,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp-style animated progress ring button
// ─────────────────────────────────────────────────────────────────────────────
class _DownloadRing extends StatelessWidget {
  final String messageId;
  final String messageText;
  final String brandingScreen;
  final String? languageCode;
  final AudioExportService service;
  final bool isGenerating;
  final double progress;
  final Color accent;

  const _DownloadRing({
    required this.messageId,
    required this.messageText,
    required this.brandingScreen,
    required this.languageCode,
    required this.service,
    required this.isGenerating,
    required this.progress,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    final label = isGenerating
        ? (pct < 99 ? 'Saving… $pct%' : 'Finishing…')
        : 'Save audio';

    return GestureDetector(
      onTap: isGenerating
          ? () async {
              HapticFeedback.mediumImpact();
              await service.cancelGeneration(messageId);
              Get.snackbar(
                '⏸️ Cancelled',
                'Audio export was cancelled.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange.shade700,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
            }
          : () async {
              HapticFeedback.lightImpact();
              final path = await service.generateAudioFile(
                messageId,
                messageText,
                brandingScreen: brandingScreen,
                languageCode: languageCode,
              );
              if (path == null) {
                Get.snackbar(
                  '⚠️ Audio Export',
                  'Could not generate audio. Check TTS language support.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.orange.shade800,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 3),
                );
              } else {
                HapticFeedback.heavyImpact();
                Get.snackbar(
                  '✅ Audio Ready',
                  'Tap ▶ to preview · Share · Delete when done.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.purple.shade700,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 3),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                );
              }
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular progress-ring button
          isGenerating
              ? _GradientProgressRing(
                  progress: progress,
                  accent: accent,
                  size: context.r.scale(36),
                  pct: pct,
                )
              : _IdleDownloadRing(accent: accent, size: context.r.scale(36)),
          const SizedBox(width: 6),
          // Text label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontSize: context.r.sp(10),
                color: accent.withValues(alpha: 0.85),
                fontWeight: isGenerating ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Cancel hint
          if (isGenerating) ...[
            const SizedBox(width: 4),
            Text(
              '(tap to cancel)',
              style: TextStyle(
                fontSize: context.r.sp(9),
                color: accent.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Idle state: simple download icon in a faint ring (single-tap to start)
// ─────────────────────────────────────────────────────────────────────────────
class _IdleDownloadRing extends StatelessWidget {
  final Color accent;
  final double size;
  const _IdleDownloadRing({required this.accent, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 2.5,
              color: accent.withValues(alpha: 0.18),
            ),
          ),
          // Inner circle
          Container(
            width: size - 10,
            height: size - 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border:
                  Border.all(color: accent.withValues(alpha: 0.35), width: 1),
            ),
            child: Center(
              child: Icon(
                Icons.download_rounded,
                size: context.r.scale(14),
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp-style gradient sweep arc showing real progress
// ─────────────────────────────────────────────────────────────────────────────
class _GradientProgressRing extends StatefulWidget {
  final double progress;
  final Color accent;
  final double size;
  final int pct;

  const _GradientProgressRing({
    required this.progress,
    required this.accent,
    required this.size,
    required this.pct,
  });

  @override
  State<_GradientProgressRing> createState() => _GradientProgressRingState();
}

class _GradientProgressRingState extends State<_GradientProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accent;
    final brighterColor = Color.lerp(color, Colors.white, 0.4)!;
    final s = widget.size;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final glow = 0.08 + _pulseCtrl.value * 0.12;
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              SizedBox(
                width: s,
                height: s,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 2.8,
                  color: color.withValues(alpha: 0.15),
                ),
              ),
              // Gradient arc (painted custom)
              CustomPaint(
                size: Size(s, s),
                painter: _GradientArcPainter(
                  progress: widget.progress,
                  startColor: color,
                  endColor: brighterColor,
                  strokeWidth: 2.8,
                ),
              ),
              // Glowing inner circle
              Container(
                width: s - 10,
                height: s - 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: glow),
                  border:
                      Border.all(color: color.withValues(alpha: 0.5), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: glow * 1.5),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: widget.pct < 99
                      ? Text(
                          '${widget.pct}',
                          style: TextStyle(
                            fontSize: context.r.sp(9),
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        )
                      : Icon(Icons.hourglass_top_rounded,
                          size: context.r.scale(11), color: color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Custom painter that draws a gradient sweep arc
class _GradientArcPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  final double strokeWidth;

  _GradientArcPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - strokeWidth / 2,
    );

    final sweepAngle = 2 * math.pi * progress;
    const startAngle = -math.pi / 2; // Starts from top

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [startColor, endColor],
      stops: const [0.0, 1.0],
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_GradientArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.startColor != startColor ||
      oldDelegate.endColor != endColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Blinking file icon (shown when audio is ready — taps open action menu)
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingFileIcon extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const _BlinkingFileIcon({
    required this.color,
    required this.onTap,
  });

  @override
  State<_BlinkingFileIcon> createState() => _BlinkingFileIconState();
}

class _BlinkingFileIconState extends State<_BlinkingFileIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _blinkCtrl,
        builder: (_, __) => Opacity(
          opacity: 0.55 + _blinkCtrl.value * 0.45,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.17),
              border: Border.all(
                  color: widget.color.withValues(alpha: 0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: widget.color
                      .withValues(alpha: 0.25 + _blinkCtrl.value * 0.2),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.audio_file_rounded,
              size: context.r.scale(16),
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ready state: blinking file icon + Play / Share / Delete chips
// ─────────────────────────────────────────────────────────────────────────────
class _ReadyRow extends StatelessWidget {
  final String messageId;
  final String messageText;
  final AudioExportService service;
  final bool playing;
  final Color accent;

  const _ReadyRow({
    required this.messageId,
    required this.messageText,
    required this.service,
    required this.playing,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blinking file icon
          _BlinkingFileIcon(
            color: Colors.greenAccent.shade400,
            onTap: () => HapticFeedback.lightImpact(),
          ),
          const SizedBox(width: 5),
          // Checkmark + label
          Icon(Icons.check_circle_rounded,
              size: context.r.scale(13), color: Colors.greenAccent.shade400),
          const SizedBox(width: 4),
          Text(
            'Saved',
            style: TextStyle(
              fontSize: context.r.sp(9),
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 7),
          // Divider
          Container(width: 1, height: 14, color: Colors.white12),
          const SizedBox(width: 7),

          // ▶ Play / Stop
          _Chip(
            icon:
                playing ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
            label: playing ? 'Stop' : 'Play',
            color: playing ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7),
            onTap: () {
              HapticFeedback.lightImpact();
              if (playing) {
                service.stopPlayback();
              } else {
                service.playAudio(messageId);
              }
            },
          ),
          const SizedBox(width: 4),

          // ↗ Share
          _Chip(
            icon: Icons.share_rounded,
            label: 'Share',
            color: const Color(0xFF80DEEA),
            onTap: () {
              HapticFeedback.lightImpact();
              service.shareAudio(messageId);
            },
          ),
          const SizedBox(width: 4),

          // 📄 Copy
          _Chip(
            icon: Icons.copy_rounded,
            label: 'Copy',
            color: const Color(0xFFFFD54F),
            onTap: () {
              HapticFeedback.lightImpact();
              Clipboard.setData(ClipboardData(text: messageText));
              Get.snackbar(
                'Copied',
                'Message copied',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green.shade700,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
              Get.back(); // Automatically close the bottom sheet
            },
          ),
          const SizedBox(width: 4),

          // 🗑 Delete
          _Chip(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFEF9A9A),
            onTap: () {
              HapticFeedback.mediumImpact();
              service.deleteAudio(messageId);
            },
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: context.r.scale(13), color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: context.r.sp(10),
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact inline variant used inside expanded message bubbles
// ─────────────────────────────────────────────────────────────────────────────
class CompactAudioExportButton extends StatelessWidget {
  final String messageId;
  final String messageText;
  final String brandingScreen;
  final String? languageCode;

  const CompactAudioExportButton({
    super.key,
    required this.messageId,
    required this.messageText,
    this.brandingScreen = 'voiceChat',
    this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final service = Get.find<AudioExportService>();

    return Obx(() {
      Color accent = const Color(0xFFB39DDB);
      try {
        accent = Get.find<TopPanelController>().currentColor;
      } catch (_) {}

      final fileReady = service.isFileReady(messageId);
      final isGen = service.isCurrentlyGenerating(messageId);
      final progress = service.getProgress(messageId);
      final pct = (progress * 100).toInt();

      if (fileReady) {
        return Tooltip(
          message: 'Audio saved — tap to open options',
          child: _BlinkingFileIcon(
            color: Colors.greenAccent.shade400,
            onTap: () => _showReadyMenu(context, service, messageId, accent),
          ),
        );
      }

      return GestureDetector(
        onTap: isGen
            ? () async {
                HapticFeedback.mediumImpact();
                await service.cancelGeneration(messageId);
              }
            : () async {
                HapticFeedback.lightImpact();
                await service.generateAudioFile(
                  messageId,
                  messageText,
                  brandingScreen: brandingScreen,
                  languageCode: languageCode,
                );
              },
        child: isGen
            ? _GradientProgressRing(
                progress: progress,
                accent: accent,
                size: context.r.scale(28),
                pct: pct,
              )
            : SizedBox(
                width: context.r.scale(28),
                height: context.r.scale(28),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: context.r.scale(28),
                      height: context.r.scale(28),
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 1.8,
                        color: accent.withValues(alpha: 0.18),
                      ),
                    ),
                    Icon(
                      Icons.download_rounded,
                      size: context.r.scale(13),
                      color: accent,
                    ),
                  ],
                ),
              ),
      );
    });
  }

  void _showReadyMenu(BuildContext context, AudioExportService service,
      String msgId, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MiniAction(
                  icon: service.isPlaying(msgId)
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_rounded,
                  label: service.isPlaying(msgId) ? 'Stop' : 'Play',
                  color: const Color(0xFFA5D6A7),
                  onTap: () {
                    if (service.isPlaying(msgId)) {
                      service.stopPlayback();
                    } else {
                      service.playAudio(msgId);
                    }
                  },
                ),
                _MiniAction(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: const Color(0xFF80DEEA),
                  onTap: () {
                    Navigator.pop(context);
                    service.shareAudio(msgId);
                  },
                ),
                _MiniAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: const Color(0xFFEF9A9A),
                  onTap: () {
                    service.deleteAudio(msgId);
                    Navigator.pop(context);
                  },
                ),
              ],
            )),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: context.r.scale(52),
            height: context.r.scale(52),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: context.r.scale(24)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: context.r.sp(11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
