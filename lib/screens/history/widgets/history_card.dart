import 'package:flutter/material.dart';

import '../../../models/history_model.dart';
import '../../../services/sound_service.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/responsive.dart';
import '../../../shared/theme/responsive_widgets.dart';

class HistoryCard extends StatefulWidget {
  final HistoryActivity activity;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const HistoryCard({
    super.key,
    required this.activity,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  double _dragOffset = 0;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0),
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  IconData _iconFor(ActivityType type) {
    switch (type) {
      case ActivityType.chat:
        return Icons.chat_bubble_outline;
      case ActivityType.naamJaap:
        return Icons.self_improvement;
      case ActivityType.game:
        return Icons.sports_esports;
      case ActivityType.alarm:
        return Icons.alarm;
      case ActivityType.voiceStudio:
        return Icons.mic;
      case ActivityType.reminder:
        return Icons.notifications_none;
      case ActivityType.wallpaper:
        return Icons.wallpaper;
      case ActivityType.languageCoach:
        return Icons.language;
      case ActivityType.settings:
        return Icons.settings;
      default:
        return Icons.history;
    }
  }

  Color _colorFor(ActivityType type) {
    switch (type) {
      case ActivityType.chat:
        return const Color(0xFF9C27B0);
      case ActivityType.naamJaap:
        return const Color(0xFFFF9800);
      case ActivityType.game:
        return const Color(0xFF4CAF50);
      case ActivityType.alarm:
        return const Color(0xFF2196F3);
      case ActivityType.voiceStudio:
        return const Color(0xFFE91E63);
      case ActivityType.reminder:
        return const Color(0xFFFFEB3B);
      case ActivityType.wallpaper:
        return const Color(0xFF00BCD4);
      case ActivityType.languageCoach:
        return const Color(0xFF3F51B5);
      case ActivityType.settings:
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF607D8B);
    }
  }

  String _formatTime(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(ts.year, ts.month, ts.day);

    final hhmm =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    if (day == today) return hhmm;
    if (day == yesterday) return 'Yesterday $hhmm';
    return '${ts.month}/${ts.day}/${ts.year}';
  }

  Future<void> _triggerDelete() async {
    if (_isDeleting) return;
    _isDeleting = true;
    await SoundService.to.playClick();
    await _slideCtrl.forward();
    widget.onDelete();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_isDeleting) return;
    setState(() => _dragOffset += d.delta.dx);
    if (_dragOffset.abs() >= 100) _triggerDelete();
  }

  void _onDragEnd(DragEndDetails _) {
    if (!_isDeleting) setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(widget.activity.type);
    final color = _colorFor(widget.activity.type);

    return SlideTransition(
      position: _slideAnim,
      child: Semantics(
        label: '${widget.activity.title}, history item',
        button: true,
        child: GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.only(bottom: context.r.scale(12)),
          child: GlassContainer(
            padding: context.r.all(16),
            child: Row(
              children: [
                Container(
                  width: context.r.scale(48),
                  height: context.r.scale(48),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(context.r.scale(12)),
                  ),
                  child: Icon(icon, color: color, size: context.r.scale(24)),
                ),
                const RSizedBox(w: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (ctx) => Text(
                          widget.activity.title,
                          style: TextStyle(
                            fontSize: context.r.sp(16),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(ctx),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.activity.description != null) ...[
                        const RSizedBox(h: 2),
                        Text(
                          widget.activity.description!,
                          style: TextStyle(
                            fontSize: context.r.sp(12),
                            color: Colors.grey[600],
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const RSizedBox(h: 4),
                      Text(
                        _formatTime(widget.activity.timestamp),
                        style: TextStyle(fontSize: context.r.sp(12), color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const RSizedBox(w: 12),
                Icon(Icons.arrow_forward_ios,
                    size: context.r.scale(16), color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
