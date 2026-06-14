import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../models/language_model.dart';
import '../../constants/language_constants.dart';
import '../../widgets/trigger_word_hints_panel.dart';
import '../../services/tts_service.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final Function(LanguageModel) onLanguageSelected;

  const LanguageSelectionScreen({
    super.key,
    required this.onLanguageSelected,
  });

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  LanguageModel? _selectedLanguage;
  bool _showHints = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.purple.shade900,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildWelcomeMessage(),
                      const SizedBox(height: 30),
                      _buildLanguagePreview(),
                      const SizedBox(height: 20),
                      _buildLanguageSelector(),
                      if (_showHints && _selectedLanguage != null) ...[
                        const SizedBox(height: 24),
                        _buildTriggerPreview(),
                      ],
                      const SizedBox(height: 30),
                      _buildStartButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Get.back(),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Column(
      children: [
        const Icon(
          Icons.language,
          size: 64,
          color: Colors.white70,
        ),
        const SizedBox(height: 16),
        const Text(
          'Welcome!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your preferred language to learn',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'The AI will respond in this language',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLanguagePreview() {
    if (_selectedLanguage == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.touch_app,
              size: 40,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap a language below',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.3),
            Colors.purple.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            _selectedLanguage!.flag,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedLanguage!.nativeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedLanguage!.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Language',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildLanguageTabs(),
      ],
    );
  }

  Widget _buildLanguageTabs() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TabBar(
              indicator: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(text: 'Main'),
                Tab(text: 'Indian'),
                Tab(text: 'Intl'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: TabBarView(
              children: [
                _buildLanguageGrid(LanguageGroup.main),
                _buildLanguageGrid(LanguageGroup.nativeIndian),
                _buildLanguageGrid(LanguageGroup.international),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageGrid(LanguageGroup group) {
    final languages = kAllLanguages.where((l) => l.group == group).toList();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: languages.length,
      itemBuilder: (context, index) {
        final language = languages[index];
        final isSelected = _selectedLanguage?.code == language.code;

        return GestureDetector(
          onTap: () => _selectLanguage(language),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(language.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  language.nativeName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectLanguage(LanguageModel language) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLanguage = language;
      _showHints = true;
    });

    _speakLanguageName(language);
  }

  Future<void> _speakLanguageName(LanguageModel language) async {
    try {
      final tts = Get.find<TTSService>();
      await tts.speak(language.nativeName);
    } catch (e) {
      debugPrint('TTS not available: $e');
    }
  }

  Widget _buildTriggerPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trigger Words Preview',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TriggerWordHintsPanel(
          preferredLanguage: _selectedLanguage,
          onEndOfThoughtPlay: () =>
              _speakTriggerWord(_selectedLanguage!.endOfThoughtTrigger),
          onExitPlay: () => _speakTriggerWord(_selectedLanguage!.exitTrigger),
        ),
      ],
    );
  }

  Future<void> _speakTriggerWord(String word) async {
    try {
      final tts = Get.find<TTSService>();
      await tts.speak(word);
    } catch (e) {
      debugPrint('TTS not available: $e');
    }
  }

  Widget _buildStartButton() {
    return AnimatedOpacity(
      opacity: _selectedLanguage != null ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton(
        onPressed: _selectedLanguage != null
            ? () => widget.onLanguageSelected(_selectedLanguage!)
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Start Session',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

void showLanguageSelectionScreen(
  BuildContext context, {
  required Function(LanguageModel) onLanguageSelected,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => LanguageSelectionScreen(
        onLanguageSelected: onLanguageSelected,
      ),
    ),
  );
}
