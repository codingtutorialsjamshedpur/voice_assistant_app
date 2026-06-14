import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceGameTutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const VoiceGameTutorialOverlay({
    super.key,
    required this.onComplete,
  });

  @override
  State<VoiceGameTutorialOverlay> createState() =>
      _VoiceGameTutorialOverlayState();
}

class _VoiceGameTutorialOverlayState extends State<VoiceGameTutorialOverlay> {
  int _currentScreen = 0;
  final int _totalScreens = 6;

  final List<Map<String, dynamic>> _screens = [
    {
      'title': 'Welcome to AI Voice Game!',
      'description': 'Your AI companion is ready to chat with you.',
      'icon': '🤖',
    },
    {
      'title': 'Single Tap',
      'description': 'Tap the orb to START recording your voice.',
      'icon': '👆',
    },
    {
      'title': 'Recording',
      'description': 'Speak your question or command clearly.',
      'icon': '🎤',
    },
    {
      'title': 'End Recording',
      'description': 'Say "done", "finished", or tap once to pause.',
      'icon': '✋',
    },
    {
      'title': 'Double Tap',
      'description': 'Double tap to reset and exit the game.',
      'icon': '👆👆',
    },
    {
      'title': 'You\'re Ready!',
      'description':
          '✓ Single tap: Start/Pause\n✓ Say "done": End recording\n✓ Double tap: Exit game',
      'icon': '✅',
    },
  ];

  void _nextScreen() {
    if (_currentScreen < _totalScreens - 1) {
      setState(() {
        _currentScreen++;
      });
    } else {
      _completeTutorial();
    }
  }

  void _previousScreen() {
    if (_currentScreen > 0) {
      setState(() {
        _currentScreen--;
      });
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenVoiceGameTutorial', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screens[_currentScreen];

    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _skipTutorial,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        screen['icon'] as String,
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        screen['title'] as String,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        screen['description'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalScreens, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentScreen ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentScreen
                              ? Colors.pink
                              : Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentScreen > 0)
                        TextButton(
                          onPressed: _previousScreen,
                          child: const Text(
                            'Previous',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      else
                        const SizedBox(width: 80),
                      ElevatedButton(
                        onPressed: _nextScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          _currentScreen == _totalScreens - 1
                              ? 'Start Game'
                              : 'Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
