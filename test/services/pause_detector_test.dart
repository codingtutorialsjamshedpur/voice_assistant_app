import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/services/pause_detector.dart';

void main() {
  group('PauseDetector', () {
    late PauseDetector detector;

    setUp(() {
      detector = PauseDetector(
        minPauseDurationMs: 300,
        silenceThreshold: 0.01,
      );
    });

    test('should detect pause in audio data', () {
      final audioData = _createAudioWithPause();

      final pauses = detector.detectPause(audioData);

      expect(pauses, isNotEmpty);
    });

    test('should detect pause at end of audio', () {
      final audioData = _createAudioWithEndPause();

      final hasEndPause = detector.isPauseAtEnd(audioData);

      expect(hasEndPause, true);
    });

    test('should calculate silence duration', () {
      final audioData = _createAudioWithPause();

      final silenceDuration = detector.calculateSilenceDuration(audioData);

      expect(silenceDuration, greaterThan(0));
    });

    test('should detect last pause index', () {
      final audioData = _createAudioWithPause();

      final lastPauseIndex = detector.detectLastPauseIndex(audioData);

      expect(lastPauseIndex, greaterThanOrEqualTo(0));
    });

    test('hasSignificantPause should detect pauses', () {
      final audioData = _createAudioWithPause();

      final hasPause = detector.hasSignificantPause(audioData);

      expect(hasPause, true);
    });

    test('getLongestPauseDuration should return duration', () {
      final audioData = _createAudioWithPause();

      final longestDuration = detector.getLongestPauseDuration(audioData);

      expect(longestDuration.inMilliseconds, greaterThan(0));
    });

    test('analyzeAudio should return audio analysis', () {
      final audioData = _createAudioWithPause();

      final analysis = detector.analyzeAudio(audioData);

      expect(analysis.containsKey('pauseCount'), true);
      expect(analysis.containsKey('totalSilenceMs'), true);
      expect(analysis.containsKey('totalDurationMs'), true);
      expect(analysis.containsKey('silencePercentage'), true);
      expect(analysis.containsKey('hasPauseAtEnd'), true);
      expect(analysis.containsKey('longestPauseMs'), true);
    });

    test('should handle empty audio data', () {
      final audioData = Uint8List(0);

      final pauses = detector.detectPause(audioData);

      expect(pauses, isEmpty);
    });

    test('should handle audio with no pauses', () {
      final audioData = _createContinuousAudio();

      final pauses = detector.detectPause(audioData);

      expect(pauses.length, lessThanOrEqualTo(1));
    });

    test('should detect pause with custom minimum duration', () {
      final audioData = _createAudioWithPause();

      final pauses = detector.detectPause(audioData, minDurationMs: 500);
      final pausesDefault = detector.detectPause(audioData);

      expect(pauses.length, lessThanOrEqualTo(pausesDefault.length));
    });
  });

  group('PauseEvent', () {
    test('should create pause event correctly', () {
      const event = PauseEvent(
        startIndex: 100,
        endIndex: 200,
        duration: Duration(milliseconds: 300),
        isAtEnd: false,
      );

      expect(event.startIndex, 100);
      expect(event.endIndex, 200);
      expect(event.duration.inMilliseconds, 300);
      expect(event.isAtEnd, false);
    });

    test('toString should format correctly', () {
      const event = PauseEvent(
        startIndex: 100,
        endIndex: 200,
        duration: Duration(milliseconds: 300),
      );

      final str = event.toString();

      expect(str.contains('100'), true);
      expect(str.contains('200'), true);
      expect(str.contains('300ms'), true);
    });
  });
}

Uint8List _createAudioWithPause() {
  final data = Uint8List(32000);
  for (int i = 0; i < 10000; i++) {
    data[i] = 127;
  }
  for (int i = 10000; i < 20000; i++) {
    data[i] = 0;
  }
  for (int i = 20000; i < 32000; i++) {
    data[i] = 127;
  }
  return data;
}

Uint8List _createAudioWithEndPause() {
  final data = Uint8List(16000);
  for (int i = 0; i < 10000; i++) {
    data[i] = 127;
  }
  for (int i = 10000; i < 16000; i++) {
    data[i] = 0;
  }
  return data;
}

Uint8List _createContinuousAudio() {
  final data = Uint8List(16000);
  for (int i = 0; i < 16000; i++) {
    data[i] = (127 + (i % 20) - 10).clamp(0, 255).toInt();
  }
  return data;
}
