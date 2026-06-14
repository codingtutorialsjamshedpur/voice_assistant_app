import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';

class VoiceChatV2Screen extends StatefulWidget {
  const VoiceChatV2Screen({super.key});

  @override
  State<VoiceChatV2Screen> createState() => _VoiceChatV2ScreenState();
}

class _VoiceChatV2ScreenState extends State<VoiceChatV2Screen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildScrollNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withAlpha(77),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white.withAlpha(204),
          size: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.voiceChatV2,
      content: Stack(
        children: [
          // ── Scrollable content ──────────────────────────
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Dashboard Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildDashboardCard(
                        icon: Icons.chat_bubble_outline,
                        title: 'Conversations',
                        value: '24',
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDashboardCard(
                        icon: Icons.timer_outlined,
                        title: 'Minutes',
                        value: '128',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDashboardCard(
                        icon: Icons.favorite_outline,
                        title: 'Favorites',
                        value: '12',
                        color: Colors.pink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDashboardCard(
                        icon: Icons.trending_up,
                        title: 'Streak',
                        value: '7 Days',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Recent Conversations
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) => Text(
                          'Recent Conversations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildConversationItem(
                        'Morning Reflection',
                        'Today we discussed mindfulness...',
                        '2h ago',
                      ),
                      const Divider(height: 24),
                      _buildConversationItem(
                        'Evening Wisdom',
                        'Exploring the path of inner peace...',
                        'Yesterday',
                      ),
                      const Divider(height: 24),
                      _buildConversationItem(
                        'Guided Meditation',
                        'A journey through consciousness...',
                        '2 days ago',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Scroll Navigation Buttons (right-center) ──
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScrollNavButton(
                    Icons.keyboard_arrow_up_rounded,
                    _scrollToTop,
                  ),
                  const SizedBox(height: 6),
                  _buildScrollNavButton(
                    Icons.keyboard_arrow_down_rounded,
                    _scrollToBottom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String value,
    required MaterialColor color,
  }) {
    return Builder(
      builder: (context) => GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color[100]!.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color[700]),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildConversationItem(String title, String preview, String time) {
    return Builder(
      builder: (context) => Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat,
              color: Color(0xFFFFB2EE),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }
}
