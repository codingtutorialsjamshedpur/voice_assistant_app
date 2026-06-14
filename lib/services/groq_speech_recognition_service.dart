/// ═══════════════════════════════════════════════════════════════
/// Groq Speech Recognition Service
/// ═══════════════════════════════════════════════════════════════
/// Key 1: ctj_chat_APRIL_2026_key_1
/// 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
///
/// Model: whisper-large-v3
/// Purpose: Audio transcription / Speech-to-text
/// Temperature: 0 (consistent transcription)
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GroqSpeechRecognitionService {
  /// API Configuration
  static const String apiKey =
      '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';
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String model = 'whisper-large-v3';

  /// Transcribe audio file to text
  ///
  /// Supported formats: M4A, WAV, MP3, OGG, FLAC
  /// Max file size: ~25 MB (per Groq API limits)
  ///
  /// Example:
  /// ```dart
  /// final service = GroqSpeechRecognitionService();
  /// final audioFile = File('audio.m4a');
  /// final transcript = await service.transcribeAudio(audioFile);
  /// print(transcript); // Output: transcribed text
  /// ```
  Future<String> transcribeAudio(File audioFile) async {
    try {
      if (!audioFile.existsSync()) {
        throw Exception('Audio file not found: ${audioFile.path}');
      }

      final audioBytes = await audioFile.readAsBytes();
      return await transcribeAudioBytes(audioBytes, audioFile.path);
    } catch (e) {
      print('Error transcribing audio: $e');
      rethrow;
    }
  }

  /// Transcribe audio from bytes
  ///
  /// Useful when you have audio data without a file
  Future<String> transcribeAudioBytes(
      List<int> audioData, String filename) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/audio/transcriptions'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $apiKey';

      // Add form fields
      request.fields['model'] = model;
      request.fields['temperature'] = '0';
      request.fields['response_format'] = 'verbose_json';

      // Add audio file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioData,
          filename: filename,
        ),
      );

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException(
              'Audio transcription timed out after 60 seconds');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['text'] ?? '';
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: ${response.body}');
      } else {
        throw Exception(
          'Transcription failed (HTTP ${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      print('Error transcribing audio bytes: $e');
      rethrow;
    }
  }

  /// Get detailed transcription with metadata
  /// Returns: {'text': '...', 'language': '...', 'duration': ...}
  Future<Map<String, dynamic>> transcribeAudioDetailed(File audioFile) async {
    try {
      if (!audioFile.existsSync()) {
        throw Exception('Audio file not found: ${audioFile.path}');
      }

      final audioBytes = await audioFile.readAsBytes();
      return await transcribeAudioBytesDetailed(audioBytes, audioFile.path);
    } catch (e) {
      print('Error getting detailed transcription: $e');
      rethrow;
    }
  }

  /// Get detailed transcription from bytes
  Future<Map<String, dynamic>> transcribeAudioBytesDetailed(
    List<int> audioData,
    String filename,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';
      request.fields['model'] = model;
      request.fields['temperature'] = '0';
      request.fields['response_format'] = 'verbose_json';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioData,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return {
          'text': json['text'] ?? '',
          'language': json['language'],
          'duration': json['duration'],
          'segments': json['segments'] ?? [],
        };
      } else {
        throw Exception(
          'Failed (HTTP ${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      print('Error getting detailed transcription: $e');
      rethrow;
    }
  }

  /// Verify the API key is valid
  Future<bool> isKeyValid() async {
    try {
      // Create a minimal test request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';
      request.fields['model'] = model;
      request.fields['temperature'] = '0';
      request.fields['response_format'] = 'verbose_json';

      // Add an empty/minimal audio file
      request.files.add(
        http.MultipartFile.fromBytes('file', [], filename: 'test.m4a'),
      );

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 10),
          );

      // 401 = Invalid key, 400 = Invalid request (but key is valid)
      return streamedResponse.statusCode != 401;
    } catch (e) {
      return false;
    }
  }

  /// Get service status and metadata
  Map<String, dynamic> getMetadata() {
    return {
      'service': 'Groq Speech Recognition',
      'key': '${apiKey.substring(0, 20)}...',
      'model': model,
      'baseUrl': baseUrl,
      'temperature': 0,
      'maxTokens': null,
      'supportedFormats': ['m4a', 'wav', 'mp3', 'ogg', 'flac'],
      'maxFileSize': '~25 MB',
      'language': 'auto-detect',
    };
  }
}

/// Exception for timeout errors
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
