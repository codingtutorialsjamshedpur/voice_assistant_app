import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/language_model.dart';
import '../shared/theme/responsive.dart';

class LanguageBadge extends StatelessWidget {
  final LanguageModel? currentLanguage;
  final VoidCallback? onTap;
  final bool showArrow;

  const LanguageBadge({
    super.key,
    this.currentLanguage,
    this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    if (currentLanguage == null) {
      return _buildDefaultBadge(context);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLanguage!.flag,
              style: TextStyle(fontSize: context.r.sp(18)),
            ),
            const SizedBox(width: 6),
            Text(
              currentLanguage!.nativeName,
              style: TextStyle(
                color: Colors.white,
                fontSize: context.r.sp(14),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showArrow) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.7),
                size: context.r.scale(18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBadge(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🌐',
              style: TextStyle(fontSize: context.r.sp(18)),
            ),
            const SizedBox(width: 6),
            Text(
              'Language',
              style: TextStyle(
                color: Colors.white70,
                fontSize: context.r.sp(14),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showArrow) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.7),
                size: context.r.scale(18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LanguageBadgeCompact extends StatelessWidget {
  final LanguageModel? currentLanguage;
  final VoidCallback? onTap;

  const LanguageBadgeCompact({
    super.key,
    this.currentLanguage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (currentLanguage == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLanguage!.flag,
              style: TextStyle(fontSize: context.r.sp(14)),
            ),
            const SizedBox(width: 4),
            Text(
              currentLanguage!.code.toUpperCase(),
              style: TextStyle(
                color: Colors.white70,
                fontSize: context.r.sp(10),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
