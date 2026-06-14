import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';

class ExtendedVoiceChatScreen extends StatelessWidget {
  const ExtendedVoiceChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.extendedVoiceChat,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RSizedBox(h: 16),
            // Topic Categories
            SizedBox(
              height: context.r.scale(100),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildTopicCard(
                      'Meditation', Icons.self_improvement, Colors.purple),
                  _buildTopicCard(
                      'Wisdom', Icons.lightbulb_outline, Colors.amber),
                  _buildTopicCard('Healing', Icons.favorite, Colors.red),
                  _buildTopicCard(
                      'Guidance', Icons.compass_calibration, Colors.blue),
                  _buildTopicCard('Prayer', Icons.back_hand, Colors.green),
                ],
              ),
            ),
            const RSizedBox(h: 24),
            // Extended Chat Interface
            GlassContainer(
              padding: context.r.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFFFFB2EE),
                      ),
                      const RSizedBox(w: 8),
                      Text(
                        'Extended Chat Mode',
                        style: TextStyle(
                          fontSize: context.r.sp(16),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: context.r.symmetric(h: 8, v: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: context.r.scale(6),
                              height: context.r.scale(6),
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const RSizedBox(w: 4),
                            Text(
                              'Active',
                              style: TextStyle(
                                fontSize: context.r.sp(10),
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const RSizedBox(h: 16),
                  Text(
                    'In Extended Mode, you can have longer, more in-depth conversations with the Spirit Guide. Share your thoughts, ask questions, and receive detailed guidance.',
                    style: TextStyle(
                      fontSize: context.r.sp(14),
                      height: 1.6,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const RSizedBox(h: 16),
            // Suggested Prompts
            Text(
              'Suggested Prompts',
              style: TextStyle(
                fontSize: context.r.sp(16),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const RSizedBox(h: 12),
            _buildPromptChip('Help me understand my dreams'),
            const RSizedBox(h: 8),
            _buildPromptChip('Guide me through a difficult decision'),
            const RSizedBox(h: 8),
            _buildPromptChip('What does my spiritual path look like?'),
            const RSizedBox(h: 8),
            _buildPromptChip('Help me find inner peace'),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(String title, IconData icon, MaterialColor color) {
    return Builder(
      builder: (context) => Container(
        width: context.r.scale(80),
        margin: EdgeInsets.only(right: context.r.scale(12)),
        child: GlassContainer(
          padding: context.r.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color[700], size: context.r.scale(28)),
              const RSizedBox(h: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: context.r.sp(11),
                  fontWeight: FontWeight.w600,
                  color: color[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildPromptChip(String text) {
    return Builder(
      builder: (context) => Container(
        padding: context.r.symmetric(h: 16, v: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(context.r.scale(12)),
          border: Border.all(color: Colors.white.withAlpha(77)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: context.r.scale(16),
              color: Colors.grey[600],
            ),
            const RSizedBox(w: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: context.r.sp(14),
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: context.r.scale(14),
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
