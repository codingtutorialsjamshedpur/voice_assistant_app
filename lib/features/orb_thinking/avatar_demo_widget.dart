import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'orb_thinking_controller.dart';
import 'thought_bubble_widget.dart';
import '../../shared/widgets/animated_orb.dart';
import 'avatar_demo.dart';

/// Avatar Demo Widget - Visual demonstration of the enhanced avatar system
class AvatarDemoWidget extends StatefulWidget {
  const AvatarDemoWidget({super.key});

  @override
  State<AvatarDemoWidget> createState() => _AvatarDemoWidgetState();
}

class _AvatarDemoWidgetState extends State<AvatarDemoWidget> {
  late OrbThinkingController _orbController;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orbController = Get.put(OrbThinkingController());
    _textController.text = AvatarDemo.exampleStory;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Avatar System Demo'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade900,
              Colors.purple.shade700,
              Colors.pink.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Demo Controls
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(51)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enhanced Avatar System Demo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter text with trigger words to see smart avatar transitions:',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter your story here...',
                        hintStyle:
                            TextStyle(color: Colors.white.withAlpha(128)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.white.withAlpha(77)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.white.withAlpha(77)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _startDemo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Start Demo'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _stopDemo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Stop'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _loadExampleStory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Example Story'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Avatar Display Area
              Expanded(
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Main Orb
                      Obx(() => AnimatedOrb(
                            size: 120,
                            showTalkingAnimation: false,
                            autoBlink: _orbController.isBlinking,
                          )),

                      // Enhanced Thought Bubble with Smart Transitions
                      Obx(() => ThoughtBubbleWidget(
                            avatarAssetPath:
                                _orbController.currentAvatarPath ?? '',
                            visible: _orbController.showCloud &&
                                _orbController.currentAvatarPath != null,
                            size: 120,
                          )),
                    ],
                  ),
                ),
              ),

              // Status Display
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(77),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Obx(() => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'System Status',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow(
                            'Thinking:',
                            _orbController.isThinking
                                ? '✅ Active'
                                : '❌ Inactive'),
                        _buildStatusRow(
                            'Blinking:',
                            _orbController.isBlinking
                                ? '👁️ Blinking'
                                : '👁️ Normal'),
                        _buildStatusRow(
                            'Cloud:',
                            _orbController.showCloud
                                ? '☁️ Visible'
                                : '☁️ Hidden'),
                        _buildStatusRow(
                            'Transition:', _orbController.transitionType),
                        _buildStatusRow('Position:', 'Dynamic'),
                        if (_orbController.currentAvatarPath != null)
                          _buildStatusRow(
                              'Avatar:',
                              _getAvatarName(
                                  _orbController.currentAvatarPath!)),
                      ],
                    )),
              ),

              // Quick Test Buttons
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickTestButton('Happy & Excited',
                        'I am very happy and excited about this!'),
                    _buildQuickTestButton('Angry & Sad',
                        'I am so angry and feeling very sad today'),
                    _buildQuickTestButton('Music & Dance',
                        'I love music and dancing makes me smile'),
                    _buildQuickTestButton('Yoga & Meditation',
                        'I practice yoga and meditation for peace'),
                    _buildQuickTestButton('Mixed Emotions',
                        'First angry, then happy, finally excited and laughing'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTestButton(String label, String text) {
    return ElevatedButton(
      onPressed: () {
        _textController.text = text;
        _startDemo();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  void _startDemo() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      _orbController.onSentenceSpoken(text);

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎭 Avatar demo started! Watch the magic happen...'),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _stopDemo() {
    _orbController.onSpeechEnd();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🛑 Avatar demo stopped'),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _loadExampleStory() {
    _textController.text = AvatarDemo.exampleStory;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            '📖 Example story loaded! Press "Start Demo" to see it in action'),
        backgroundColor: Colors.blue.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getAvatarName(String path) {
    if (path.contains('angry')) return '😠 Angry';
    if (path.contains('dreaming')) return '💭 Dreaming';
    if (path.contains('cowboy')) return '🤠 Cowboy';
    if (path.contains('exhausted')) return '😴 Exhausted';
    if (path.contains('flirting')) return '😉 Flirting';
    if (path.contains('excited')) return '🤩 Excited';
    if (path.contains('music')) return '🎵 Music';
    if (path.contains('smiling')) return '😊 Smiling';
    if (path.contains('diamond')) return '💎 Diamond';
    if (path.contains('scared')) return '😨 Scared';
    if (path.contains('exercising')) return '💪 Exercising';
    if (path.contains('laughing')) return '😂 Laughing';
    if (path.contains('yoga')) return '🧘 Yoga';
    if (path.contains('thinking')) return '🤔 Thinking';
    return '🎭 Avatar';
  }
}
