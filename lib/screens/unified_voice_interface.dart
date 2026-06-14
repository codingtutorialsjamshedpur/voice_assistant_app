import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/voice_controller.dart';
import '../services/naam_jaap_service.dart';
import '../widgets/dual_mode_input_panel.dart';

/// Unified Voice Interface
///
/// Demonstrates the integration of all voice features:
/// - Chat with AI
/// - Voice Memo recording
/// - Naam Jaap chanting
///
/// All modes work seamlessly together through the VoiceController
class UnifiedVoiceInterface extends StatelessWidget {
  const UnifiedVoiceInterface({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VoiceController>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (!controller.isInitialized.value) {
          return _buildLoadingScreen();
        }

        return _buildMainInterface(controller);
      }),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
            ),
            SizedBox(height: 20),
            Text(
              'Initializing Voice Assistant...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInterface(VoiceController controller) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
            Color(0xFF1a1a2e),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header with Mode Switcher
            _buildHeader(controller),

            // Mode Indicator
            _buildModeIndicator(controller),

            // Main Content Area
            Expanded(
              child: Obx(() {
                switch (controller.currentInputMode.value) {
                  case UnifiedInputMode.chat:
                    return _buildChatArea(controller);
                  case UnifiedInputMode.voiceMemo:
                    return _buildVoiceMemoArea(controller);
                  case UnifiedInputMode.naamJaap:
                    return _buildNaamJaapArea(controller);
                }
              }),
            ),

            // Status Bar
            _buildStatusBar(controller),

            // Unified Input Panel
            DualModeInputPanel(
              textController: controller.textController,
              onSendMessage: (_) => controller.sendMessage(),
              onVoiceInput: (text) => controller.processVoiceInput(text),
              height: 80,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(VoiceController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.cyanAccent, Colors.purpleAccent],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mic, color: Colors.white),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CTJ AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Obx(() => Text(
                      _getModeDisplayName(controller.currentInputMode.value),
                      style: TextStyle(
                        color: Colors.cyanAccent.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    )),
              ],
            ),
          ),

          // Mode Switcher
          _buildModeSwitcher(controller),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher(VoiceController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Obx(() => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton(
                icon: Icons.chat,
                mode: UnifiedInputMode.chat,
                currentMode: controller.currentInputMode.value,
                onTap: () => controller.setInputMode(UnifiedInputMode.chat),
              ),
              _buildModeButton(
                icon: Icons.mic,
                mode: UnifiedInputMode.voiceMemo,
                currentMode: controller.currentInputMode.value,
                onTap: () =>
                    controller.setInputMode(UnifiedInputMode.voiceMemo),
              ),
              _buildModeButton(
                icon: Icons.self_improvement,
                mode: UnifiedInputMode.naamJaap,
                currentMode: controller.currentInputMode.value,
                onTap: () => controller.setInputMode(UnifiedInputMode.naamJaap),
              ),
            ],
          )),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required UnifiedInputMode mode,
    required UnifiedInputMode currentMode,
    required VoidCallback onTap,
  }) {
    final isActive = mode == currentMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.cyanAccent.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.cyanAccent : Colors.white54,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildModeIndicator(VoiceController controller) {
    return Obx(() => Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getModeIcon(controller.currentInputMode.value),
                color: Colors.cyanAccent.withValues(alpha: 0.6),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _getModeDescription(controller.currentInputMode.value),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildChatArea(VoiceController controller) {
    return Obx(() {
      if (controller.messages.isEmpty) {
        return _buildEmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'Start a Conversation',
          subtitle: 'Type or speak to chat with CTJ AI',
        );
      }

      return ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message = controller.messages[index];
          return _buildMessageBubble(message);
        },
      );
    });
  }

  Widget _buildVoiceMemoArea(VoiceController controller) {
    final memoService = controller.memoService;

    return Obx(() {
      if (memoService.memos.isEmpty) {
        return _buildEmptyState(
          icon: Icons.mic_none,
          title: 'No Voice Memos',
          subtitle: 'Tap the record button to start recording',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: memoService.memos.length,
        itemBuilder: (context, index) {
          final memo = memoService.memos[index];
          final isPlaying = memoService.currentMemo.value?.id == memo.id &&
              memoService.isPlaying.value;

          return Card(
            color: Colors.white.withValues(alpha: 0.1),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: isPlaying ? Colors.cyanAccent : Colors.white70,
                size: 40,
              ),
              title: Text(
                memo.title ?? 'Voice Memo ${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${memoService.formatDuration(memo.duration)} • ${memoService.formatFileSize(memo.fileSize)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: Colors.grey[900],
                onSelected: (value) {
                  if (value == 'play') {
                    memoService.playMemo(memo);
                  } else if (value == 'delete') {
                    memoService.deleteMemo(memo);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'play',
                    child: Text('Play', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              onTap: () {
                if (isPlaying) {
                  memoService.pausePlayback();
                } else {
                  memoService.playMemo(memo);
                }
              },
            ),
          );
        },
      );
    });
  }

  Widget _buildNaamJaapArea(VoiceController controller) {
    final jaapService = controller.naamJaapService;

    return Obx(() {
      if (jaapService.currentState.value == JaapSessionState.active ||
          jaapService.currentState.value == JaapSessionState.paused) {
        return _buildActiveJaapSession(jaapService, controller);
      }

      return _buildMantraSelector(jaapService, controller);
    });
  }

  Widget _buildActiveJaapSession(
      NaamJaapService service, VoiceController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Current Mantra
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  service.currentMantra.value?.text ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  service.currentMantra.value?.meaning ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Counter
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withValues(alpha: 0.3),
                  Colors.orange.withValues(alpha: 0.1),
                ],
              ),
              border:
                  Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${service.currentCount.value}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '/ ${service.targetCount.value}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: service.currentCount.value / service.targetCount.value,
                minHeight: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pause/Resume
              GestureDetector(
                onTap: () {
                  if (service.currentState.value == JaapSessionState.active) {
                    service.pauseSession();
                  } else {
                    service.resumeSession();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    service.currentState.value == JaapSessionState.active
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Increment
              GestureDetector(
                onTap: () => service.incrementCount(),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withValues(alpha: 0.5),
                        Colors.orange.withValues(alpha: 0.3),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Stop
              GestureDetector(
                onTap: () => service.stopSession(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stop,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Session Duration
          Text(
            'Duration: ${service.getFormattedDuration(service.sessionDuration.value)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMantraSelector(
      NaamJaapService service, VoiceController controller) {
    final mantras = service.getMantrasByLanguage(service.currentLanguage.value);

    return Column(
      children: [
        // Language Selector
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: NaamJaapLanguage.values.map((lang) {
              final isSelected = service.currentLanguage.value == lang;
              return GestureDetector(
                onTap: () => service.setLanguage(lang),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.orange : Colors.white24,
                    ),
                  ),
                  child: Text(
                    service.getLanguageName(lang),
                    style: TextStyle(
                      color: isSelected ? Colors.orange : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Statistics Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Chants',
                '${service.totalLifetimeChants.value}',
                Icons.format_list_numbered,
              ),
              _buildStatItem(
                'Current Streak',
                '${service.currentStreak.value} days',
                Icons.local_fire_department,
              ),
              _buildStatItem(
                'Best Streak',
                '${service.longestStreak.value} days',
                Icons.emoji_events,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mantras List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mantras.length,
            itemBuilder: (context, index) {
              final mantra = mantras[index];
              return Card(
                color: Colors.white.withValues(alpha: 0.1),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      mantra.isFavorite
                          ? Icons.favorite
                          : Icons.self_improvement,
                      color: mantra.isFavorite ? Colors.red : Colors.orange,
                    ),
                  ),
                  title: Text(
                    mantra.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    mantra.meaning,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      service.startSession(mantra);
                      controller.speakText(
                        'Starting ${mantra.text} for ${mantra.targetCount} times',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withValues(alpha: 0.3),
                      foregroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Start'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange.withValues(alpha: 0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.cyanAccent.withValues(alpha: 0.2),
                  Colors.purpleAccent.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              icon,
              size: 60,
              color: Colors.cyanAccent.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic message) {
    final isUser = message.role == 'user';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.cyanAccent, Colors.purpleAccent],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.cyanAccent.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.person,
                  color: Colors.white.withValues(alpha: 0.8), size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBar(VoiceController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.cyanAccent.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                controller.status.value,
                style: TextStyle(
                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }

      if (controller.ttsService.isSpeaking.value) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: GestureDetector(
            onTap: () => controller.stopSpeaking(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.volume_up,
                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Speaking... (Tap to stop)',
                  style: TextStyle(
                    color: Colors.cyanAccent.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return const SizedBox.shrink();
    });
  }

  String _getModeDisplayName(UnifiedInputMode mode) {
    switch (mode) {
      case UnifiedInputMode.chat:
        return 'Chat Mode';
      case UnifiedInputMode.voiceMemo:
        return 'Voice Memo';
      case UnifiedInputMode.naamJaap:
        return 'Naam Jaap';
    }
  }

  String _getModeDescription(UnifiedInputMode mode) {
    switch (mode) {
      case UnifiedInputMode.chat:
        return 'Chat with AI using voice or text';
      case UnifiedInputMode.voiceMemo:
        return 'Record and manage voice memos';
      case UnifiedInputMode.naamJaap:
        return 'Spiritual chanting with tracking';
    }
  }

  IconData _getModeIcon(UnifiedInputMode mode) {
    switch (mode) {
      case UnifiedInputMode.chat:
        return Icons.chat;
      case UnifiedInputMode.voiceMemo:
        return Icons.mic;
      case UnifiedInputMode.naamJaap:
        return Icons.self_improvement;
    }
  }
}
