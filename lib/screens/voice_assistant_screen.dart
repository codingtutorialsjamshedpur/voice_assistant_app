import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/voice_controller.dart';
import '../widgets/dual_mode_input_panel.dart';
import '../widgets/banner_ad_widget.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../shared/widgets/glassmorphic_dialog.dart';

/// Main Voice Assistant Screen
///
/// Features:
/// - Chat interface with AI
/// - Dual-mode input panel (Chat + Voice Memo)
/// - Voice input/output in English/Hindi/Hinglish
/// - Persona selection
/// - Message management
class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with WidgetsBindingObserver {
  late final VoiceController _controller;

  @override
  void initState() {
    super.initState();

    // Register for app lifecycle callbacks
    WidgetsBinding.instance.addObserver(this);

    // Get or create the controller
    try {
      _controller = Get.find<VoiceController>();
    } catch (e) {
      _controller = Get.put(VoiceController());
    }

    // Reset services when entering voice assistant screen
    _resetServicesOnEntry();

    debugPrint(
        '✅ [VoiceAssistantScreen] Initialized with proper lifecycle management');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ensure services are clean when returning from background
      _resetServicesOnEntry();
    }
  }

  /// Reset all STT/TTS services when entering this screen
  void _resetServicesOnEntry() {
    debugPrint(
        '🔄 [VoiceAssistantScreen] Resetting all STT/TTS services on entry');

    // Stop any stale STT from previous screen
    try {
      final sttService = Get.find<STTService>();
      if (sttService.isListening.value) {
        sttService.stopListening();
        debugPrint(
            '🔄 [VoiceAssistantScreen] Stopped stale STT on entry (was listening)');
      }
    } catch (e) {
      debugPrint('⚠️ [VoiceAssistantScreen] Error accessing STT service: $e');
    }

    // Ensure TTS is stopped
    try {
      final ttsService = Get.find<TTSService>();
      if (ttsService.isSpeaking.value) {
        ttsService.stop();
        debugPrint(
            '🔄 [VoiceAssistantScreen] Stopped stale TTS on entry (was speaking)');
      }
    } catch (e) {
      debugPrint('⚠️ [VoiceAssistantScreen] Error accessing TTS service: $e');
    }

    // Reset controller state
    if (_controller.isTalking.value) {
      _controller.isTalking.value = false;
    }

    // Clear any ongoing language-specific STT errors by resetting the service
    try {
      final sttService = Get.find<STTService>();
      // Reset language and error state
      sttService.currentLanguage.value = STTLanguage.englishUS;
      debugPrint(
          '🔄 [VoiceAssistantScreen] Reset STT language to default (English US)');
    } catch (e) {
      debugPrint('⚠️ [VoiceAssistantScreen] Error resetting STT language: $e');
    }
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Clean up STT/TTS when leaving voice assistant screen
    debugPrint('🔄 [VoiceAssistantScreen] Cleaning up services on dispose');

    try {
      final sttService = Get.find<STTService>();
      if (sttService.isListening.value) {
        sttService.stopListening();
        debugPrint(
            '🔄 [VoiceAssistantScreen] Stopped STT listening on dispose');
      }
    } catch (e) {
      debugPrint('⚠️ [VoiceAssistantScreen] Error stopping STT: $e');
    }

    try {
      final ttsService = Get.find<TTSService>();
      if (ttsService.isSpeaking.value) {
        ttsService.stop();
        debugPrint('🔄 [VoiceAssistantScreen] Stopped TTS on dispose');
      }
    } catch (e) {
      debugPrint('⚠️ [VoiceAssistantScreen] Error stopping TTS: $e');
    }

    // Reset controller talking state
    if (_controller.isTalking.value) {
      _controller.isTalking.value = false;
    }

    // Force deletion of VoiceController to ensure a fresh instance is created next time
    // This prevents state leakage and STT/TTS interference between distinct screens
    Get.delete<VoiceController>();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Handle device back button
        await _controller.stopSpeaking();
        Get.back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() {
          if (!_controller.isInitialized.value) {
            return _buildLoadingScreen();
          }

          return _buildMainScreen(_controller);
        }),
      ),
    );
  }

  /// Loading screen
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
              'Initializing CTJ AI...',
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

  /// Main screen
  Widget _buildMainScreen(VoiceController controller) {
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
            // Top App Bar
            _buildAppBar(controller),

            // Chat Messages Area
            Expanded(
              child: _buildChatArea(controller),
            ),

            // Status Bar
            _buildStatusBar(controller),

            // Input Panel
            DualModeInputPanel(
              textController: controller.textController,
              onSendMessage: (_) => controller.sendMessage(),
              onVoiceInput: (text) => controller.processVoiceInput(text),
              height: 80,
            ),

            // Banner Ad
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  /// App Bar
  Widget _buildAppBar(VoiceController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Obx(() {
        if (controller.isSelectionMode.value) {
          return _buildSelectionAppBar(controller);
        }
        return _buildNormalAppBar(controller);
      }),
    );
  }

  /// Normal App Bar
  Widget _buildNormalAppBar(VoiceController controller) {
    return Row(
      children: [
        // Back Button
        GestureDetector(
          onTap: () async {
            await controller.stopSpeaking();
            Get.back();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white70,
              size: 20,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Logo/Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.cyanAccent, Colors.purpleAccent],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.mic,
            color: Colors.white,
          ),
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
              Text(
                'Voice Assistant',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Persona Selector
        _buildPersonaSelector(controller),

        const SizedBox(width: 8),

        // Settings Menu
        _buildSettingsMenu(controller),
      ],
    );
  }

  /// Selection Mode App Bar with professional styling
  Widget _buildSelectionAppBar(VoiceController controller) {
    final selectedCount = controller.selectedMessageIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Close button
          _buildSelectionButton(
            icon: Icons.close,
            color: Colors.white70,
            onPressed: () {
              controller.selectedMessageIds.clear();
              controller.isSelectionMode.value = false;
            },
          ),

          const SizedBox(width: 12),

          // Selected count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.cyanAccent.withValues(alpha: 0.3),
                  Colors.cyanAccent.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '$selectedCount',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Selected text
          Text(
            selectedCount == 1 ? 'selected' : 'selected',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),

          const Spacer(),

          // Action buttons with scrollable row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Select All button
                _buildSelectionButton(
                  icon: Icons.select_all,
                  color: Colors.white70,
                  onPressed: () => controller.selectAllMessages(),
                ),
                const SizedBox(width: 4),
                // Copy button
                _buildSelectionButton(
                  icon: Icons.copy,
                  color: Colors.blueAccent,
                  onPressed: () => controller.copySelectedMessages(),
                ),
                const SizedBox(width: 4),
                // Delete button with confirmation
                _buildSelectionButton(
                  icon: Icons.delete_outline,
                  color: Colors.redAccent,
                  onPressed: () => _showDeleteConfirmation(controller),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a consistent selection action button
  Widget _buildSelectionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(VoiceController controller) {
    final selectedCount = controller.selectedMessageIds.length;

    GlassmorphicDialogHelper.showDeleteConfirmation(
      title: 'Delete ${selectedCount == 1 ? 'Message' : 'Messages'}?',
      message:
          'Are you sure you want to delete $selectedCount ${selectedCount == 1 ? 'message' : 'messages'}?',
      subtitle: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      onConfirm: () {
        controller.deleteSelectedMessages();
        Get.snackbar(
          'Deleted',
          '$selectedCount ${selectedCount == 1 ? 'message' : 'messages'} deleted',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      },
    );
  }

  /// Persona Selector
  Widget _buildPersonaSelector(VoiceController controller) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: controller.personas[controller.currentPersona.value]!.color
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          controller.personas[controller.currentPersona.value]!.icon,
          color: controller.personas[controller.currentPersona.value]!.color,
          size: 20,
        ),
      ),
      color: Colors.grey[900],
      onSelected: (persona) => controller.setPersona(persona),
      itemBuilder: (context) {
        return controller.personas.entries.map((entry) {
          return PopupMenuItem(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  entry.value.icon,
                  color: entry.value.color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        entry.value.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.currentPersona.value == entry.key)
                  const Icon(
                    Icons.check,
                    color: Colors.cyanAccent,
                    size: 20,
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  /// Settings Menu
  Widget _buildSettingsMenu(VoiceController controller) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      color: Colors.grey[900],
      onSelected: (value) {
        switch (value) {
          case 'clear':
            _showClearChatDialog(controller);
            break;
          case 'settings':
            // Navigate to settings
            break;
          case 'profile':
            _showProfileDialog(controller);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Profile', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text('Clear Chat', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Settings', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  /// Chat Area
  Widget _buildChatArea(VoiceController controller) {
    return Obx(() {
      if (controller.messages.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message = controller.messages[index];
          final isSelected = controller.selectedMessageIds.contains(message.id);

          return _buildMessageBubble(
            controller: controller,
            message: message,
            isSelected: isSelected,
          );
        },
      );
    });
  }

  /// Empty state
  Widget _buildEmptyState() {
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
              Icons.chat_bubble_outline,
              size: 60,
              color: Colors.cyanAccent.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start a conversation',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type or speak to chat with CTJ AI',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Message bubble
  Widget _buildMessageBubble({
    required VoiceController controller,
    required ChatMessage message,
    required bool isSelected,
  }) {
    final isUser = message.role == 'user';

    return GestureDetector(
      onLongPress: () => controller.toggleMessageSelection(message.id),
      onTap: () {
        if (controller.isSelectionMode.value) {
          controller.toggleMessageSelection(message.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              // AI Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.cyanAccent, Colors.purpleAccent],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.cyanAccent.withValues(alpha: 0.3)
                      : isUser
                          ? Colors.cyanAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  border: Border.all(
                    color: isSelected
                        ? Colors.cyanAccent
                        : isUser
                            ? Colors.cyanAccent.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        if (!isUser) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => controller.speakMessage(message),
                            child: Icon(
                              Icons.volume_up,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              // User Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Status Bar
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

  /// Show clear chat dialog
  void _showClearChatDialog(VoiceController controller) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear Chat',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to clear all messages? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              controller.clearChat();
              Get.back();
            },
            child:
                const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  /// Show profile dialog
  void _showProfileDialog(VoiceController controller) {
    final nameController =
        TextEditingController(text: controller.userName.value);
    final title = controller.userTitle.value.obs;

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Your Profile',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title selector
            Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTitleOption(
                        'Mr.', title.value, (val) => title.value = val),
                    const SizedBox(width: 16),
                    _buildTitleOption(
                        'Mrs.', title.value, (val) => title.value = val),
                  ],
                )),

            const SizedBox(height: 16),

            // Name input
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Your Name',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                controller.setUserName(nameController.text, title.value);
              }
              Get.back();
            },
            child:
                const Text('Save', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  /// Build title option
  Widget _buildTitleOption(
      String value, String selected, Function(String) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white24,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: isSelected ? Colors.cyanAccent : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Format time
  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
