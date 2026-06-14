import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/voice_memo_service.dart';

/// Integration example showing how TTS/STT works with DualModeInputPanel
///
/// This demonstrates:
/// 1. Multi-language support (English/Hindi/Hinglish)
/// 2. Hindi TTS normalization rules
/// 3. Voice memo recording with waveform visualization
/// 4. Language switching on the fly
class VoiceAssistantIntegration extends StatelessWidget {
  const VoiceAssistantIntegration({super.key});

  @override
  Widget build(BuildContext context) {
    final ttsService = Get.find<TTSService>();
    final sttService = Get.find<STTService>();
    final memoService = Get.find<VoiceMemoService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Status Display
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TTS Status
                    _buildStatusCard(
                      'TTS Status',
                      Obx(() => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Language: ${ttsService.getLanguageName(ttsService.currentLanguage.value)}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Speaking: ${ttsService.isSpeaking.value ? "Yes" : "No"}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Speed: ${ttsService.voiceSpeed.value.toStringAsFixed(2)}x',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Pitch: ${ttsService.pitch.value.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          )),
                    ),

                    const SizedBox(height: 16),

                    // STT Status
                    _buildStatusCard(
                      'STT Status',
                      Obx(() => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Language: ${sttService.getLanguageName(sttService.currentLanguage.value)}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Listening: ${sttService.isListening.value ? "Yes" : "No"}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Status: ${sttService.status.value}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (sttService.recognizedText.value.isNotEmpty)
                                Text(
                                  'Recognized: ${sttService.recognizedText.value}',
                                  style:
                                      const TextStyle(color: Colors.cyanAccent),
                                ),
                            ],
                          )),
                    ),

                    const SizedBox(height: 16),

                    // Voice Memo Status
                    _buildStatusCard(
                      'Voice Memo Status',
                      Obx(() => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recording: ${memoService.isRecording.value ? "Yes" : "No"}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Paused: ${memoService.isPaused.value ? "Yes" : "No"}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Playing: ${memoService.isPlaying.value ? "Yes" : "No"}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Saved Memos: ${memoService.memos.length}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (memoService
                                      .recordingDuration.value.inSeconds >
                                  0)
                                Text(
                                  'Duration: ${memoService.formatDuration(memoService.recordingDuration.value)}',
                                  style: const TextStyle(
                                      color: Colors.orangeAccent),
                                ),
                            ],
                          )),
                    ),

                    const SizedBox(height: 24),

                    // Test Section
                    const Text(
                      'Test Hindi TTS Normalization',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Test buttons for Hindi normalization
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTestButton(
                          'Test "main" → "mai"',
                          () => ttsService.speak('main thik hoon'),
                        ),
                        _buildTestButton(
                          'Test "hain" → "hai"',
                          () => ttsService.speak('Aap kaise hain'),
                        ),
                        _buildTestButton(
                          'Test "ein" → "e"',
                          () => ttsService.speak('hum jayenge'),
                        ),
                        _buildTestButton(
                          'Test Story Mode',
                          () => ttsService.speak(
                            'Ek baar ki baat hai, ek raja tha.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Panel Placeholder
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const Center(
                child: Text(
                  'DualModeInputPanel is integrated here',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyanAccent.withAlpha(51),
        foregroundColor: Colors.cyanAccent,
        side: BorderSide(color: Colors.cyanAccent.withAlpha(128)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }
}

/// Usage Instructions:
///
/// 1. Add DualModeInputPanel to any screen:
/// ```dart
/// DualModeInputPanel(
///   onSendMessage: () {
///     // Handle text send
///   },
///   onVoiceInput: (text) {
///     // Handle voice input
///   },
/// )
/// ```
///
/// 2. Access services anywhere:
/// ```dart
/// final tts = Get.find<TTSService>();
/// final stt = Get.find<STTService>();
/// final memo = Get.find<VoiceMemoService>();
/// ```
///
/// 3. Switch languages:
/// ```dart
/// tts.setLanguage(TTSLanguage.hinglish);
/// stt.setLanguage(STTLanguage.hinglish);
/// ```
///
/// 4. Speak with Hindi normalization:
/// ```dart
/// tts.speak('Aap kaise hain?'); // Will normalize "hain" → "hai"
/// ```
///
/// 5. Record voice memo:
/// ```dart
/// memo.startRecording();
/// // ... user records ...
/// await memo.stopRecording();
/// ```
