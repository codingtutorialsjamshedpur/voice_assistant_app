/// ═══════════════════════════════════════════════════════════════
/// Natural Speech Service  (Task 5.1)
/// ═══════════════════════════════════════════════════════════════
///
/// Pre-processes AI response text before it is passed to TTSService:
///   1. Inserts SSML-style pause markers between sentences.
///   2. Injects 1–2 natural filler words per response (language-aware).
///   3. Determines the appropriate TTS speech rate for the content type.
///
/// Usage (in VoiceController or QueryHandler):
///   final processed = naturalSpeech.addNaturalPauses(response);
///   final withFillers = naturalSpeech.addFillerWords(processed, 'Hinglish');
///   final rate = naturalSpeech.getAppropriateRate(processed);
///   ttsService.speak(withFillers);
///   ttsService.setSpeechRate(rate);
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NaturalSpeechService extends GetxService {
  final _rng = Random();

  @override
  void onInit() {
    super.onInit();
    debugPrint('✅ [NaturalSpeechService] Initialized');
  }

  // ── Pause Injection ───────────────────────────────────────────────────

  /// Insert SSML-style break markers between sentence boundaries.
  String addNaturalPauses(String text) {
    return text
        .replaceAll('. ', '. <break time="300ms"/> ')
        .replaceAll('! ', '! <break time="500ms"/> ')
        .replaceAll('? ', '? <break time="400ms"/> ')
        .replaceAll('; ', '; <break time="200ms"/> ')
        .replaceAll('... ', '<break time="600ms"/> ')
        .replaceAll('\n\n', ' <break time="800ms"/> ');
  }

  // ── Filler Words ──────────────────────────────────────────────────────

  static const _fillers = <String, List<String>>{
    'English': [
      'So',
      'Well',
      'Actually',
      'You see',
      'Here\'s the thing',
      'Now',
      'Think about it',
      'Interestingly',
    ],
    'Hindi': [
      'Achha',
      'Toh dekhiye',
      'Bilkul',
      'Seedha baat yeh hai',
      'Suno',
      'Yeh dekho',
    ],
    'Hinglish': [
      'Toh basically',
      'Actually kya hai',
      'Dekho yaar',
      'So basically',
      'Samjhe na',
    ],
  };

  /// Inject 1–2 natural filler words at the start of sentences.
  /// Maximum 2 per response to avoid sounding unnatural.
  String addFillerWords(String text, String language) {
    final candidates = _fillers[language] ?? _fillers['Hinglish']!;
    final sentences = text.split('. ');
    if (sentences.length < 3) return text; // too short for fillers

    int fillerCount = 0;
    final result = <String>[];

    for (int i = 0; i < sentences.length; i++) {
      // Only inject at non-first sentences, max 2 total, ~25% chance each
      if (i > 0 && fillerCount < 2 && _rng.nextDouble() < 0.25) {
        final filler = candidates[_rng.nextInt(candidates.length)];
        result.add('$filler, ${sentences[i]}');
        fillerCount++;
      } else {
        result.add(sentences[i]);
      }
    }

    return result.join('. ');
  }

  // ── Speech Rate ───────────────────────────────────────────────────────

  /// Returns the TTS speech rate most appropriate for [text]'s content type.
  double getAppropriateRate(String text) {
    final lower = text.toLowerCase();

    // Story detection
    if (_containsAny(lower, [
      'once upon a time',
      'long ago',
      'story',
      'legend',
      'tale',
      'and then',
      'suddenly',
      'finally',
      'the end',
    ])) {
      return 0.85; // storytelling pace
    }

    // Technical / step-by-step
    if (_containsAny(lower, [
      'step 1',
      'first',
      'second',
      'third',
      'algorithm',
      'equation',
      'formula',
      'method',
      'process',
      'procedure',
      'implementation',
    ])) {
      return 0.65; // slow for clarity
    }

    // Excited/positive
    if (_containsAny(lower, [
      '!',
      'amazing',
      'awesome',
      'incredible',
      'wow',
      'great',
      'wonderful',
      'fantastic',
      'exciting',
    ])) {
      return 0.92; // upbeat
    }

    // Greeting / first turn
    if (_containsAny(lower, [
      'namaste',
      'hello',
      'hi ',
      'good morning',
      'good afternoon',
      'welcome',
      'namaskar',
    ])) {
      return 0.90;
    }

    return 0.75; // default
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
