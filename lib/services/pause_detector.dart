import 'dart:typed_data';

class PauseEvent {
  final int startIndex;
  final int endIndex;
  final Duration duration;
  final bool isAtEnd;

  const PauseEvent({
    required this.startIndex,
    required this.endIndex,
    required this.duration,
    this.isAtEnd = false,
  });

  @override
  String toString() {
    return 'PauseEvent(start: $startIndex, end: $endIndex, duration: ${duration.inMilliseconds}ms, isAtEnd: $isAtEnd)';
  }
}

class PauseDetector {
  final int _minPauseDurationMs;
  final double _silenceThreshold;
  final int _sampleRate;

  PauseDetector({
    int minPauseDurationMs = 300,
    double silenceThreshold = 0.01,
    int sampleRate = 16000,
  })  : _minPauseDurationMs = minPauseDurationMs,
        _silenceThreshold = silenceThreshold,
        _sampleRate = sampleRate;

  List<PauseEvent> detectPause(Uint8List audioData, {int? minDurationMs}) {
    final minDuration = minDurationMs ?? _minPauseDurationMs;
    final pauseEvents = <PauseEvent>[];

    final samplesPerMs = _sampleRate ~/ 1000;
    final minPauseSamples = minDuration * samplesPerMs;

    int i = 0;
    int? pauseStart;

    while (i < audioData.length) {
      final amplitude = _getAmplitude(audioData, i);
      final isSilent = amplitude < _silenceThreshold;

      if (isSilent) {
        pauseStart ??= i;
      } else {
        if (pauseStart != null) {
          final pauseLength = i - pauseStart;
          if (pauseLength >= minPauseSamples) {
            final duration = Duration(
              milliseconds: (pauseLength / samplesPerMs).round(),
            );
            pauseEvents.add(PauseEvent(
              startIndex: pauseStart,
              endIndex: i,
              duration: duration,
            ));
          }
          pauseStart = null;
        }
      }
      i += 1024;
    }

    if (pauseStart != null &&
        (audioData.length - pauseStart) >= minPauseSamples) {
      final duration = Duration(
        milliseconds: ((audioData.length - pauseStart) / samplesPerMs).round(),
      );
      pauseEvents.add(PauseEvent(
        startIndex: pauseStart,
        endIndex: audioData.length,
        duration: duration,
        isAtEnd: true,
      ));
    }

    return pauseEvents;
  }

  double _getAmplitude(Uint8List audioData, int startIndex) {
    if (startIndex >= audioData.length) return 0.0;

    final endIndex = (startIndex + 1024).clamp(0, audioData.length);
    double sum = 0.0;
    int count = 0;

    for (int i = startIndex; i < endIndex; i++) {
      if (i < audioData.length) {
        final sample = audioData[i] / 127.5 - 1.0;
        sum += sample.abs();
        count++;
      }
    }

    return count > 0 ? sum / count : 0.0;
  }

  bool isPauseAtEnd(Uint8List audioData, {int? minDurationMs}) {
    final pauses = detectPause(audioData, minDurationMs: minDurationMs);
    return pauses.any((p) => p.isAtEnd);
  }

  int calculateSilenceDuration(Uint8List audioData) {
    final pauses = detectPause(audioData);
    if (pauses.isEmpty) return 0;

    int totalSilence = 0;
    for (final pause in pauses) {
      totalSilence += pause.duration.inMilliseconds;
    }
    return totalSilence;
  }

  int detectLastPauseIndex(Uint8List audioData, {int? minDurationMs}) {
    final pauses = detectPause(audioData, minDurationMs: minDurationMs);
    if (pauses.isEmpty) return -1;

    return pauses.last.startIndex;
  }

  bool hasSignificantPause(Uint8List audioData, {int? minDurationMs}) {
    final pauses = detectPause(audioData, minDurationMs: minDurationMs);
    return pauses.isNotEmpty;
  }

  Duration getLongestPauseDuration(Uint8List audioData, {int? minDurationMs}) {
    final pauses = detectPause(audioData, minDurationMs: minDurationMs);
    if (pauses.isEmpty) return Duration.zero;

    Duration longest = Duration.zero;
    for (final pause in pauses) {
      if (pause.duration > longest) {
        longest = pause.duration;
      }
    }
    return longest;
  }

  Map<String, dynamic> analyzeAudio(Uint8List audioData) {
    final pauses = detectPause(audioData);
    final silenceDuration = calculateSilenceDuration(audioData);
    final totalDuration = (audioData.length / _sampleRate * 1000).round();

    return {
      'pauseCount': pauses.length,
      'totalSilenceMs': silenceDuration,
      'totalDurationMs': totalDuration,
      'silencePercentage': totalDuration > 0
          ? (silenceDuration / totalDuration * 100).round()
          : 0,
      'hasPauseAtEnd': isPauseAtEnd(audioData),
      'longestPauseMs': getLongestPauseDuration(audioData).inMilliseconds,
    };
  }
}
