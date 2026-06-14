import 'dart:convert';
import 'package:http/http.dart' as http;

class RuFloService {
  // PRODUCTION SUPABASE EDGE FUNCTION (LIVE SWARM MULTI-AGENT IN THE CLOUD)
  static const String _baseUrl =
      'https://befcerlzbcauvxkssiwp.supabase.co/functions/v1/ruflo_swarm';
  static final RuFloService _instance = RuFloService._internal();
  factory RuFloService() => _instance;
  RuFloService._internal();

  Future<void> memoryStore({
    required String namespace,
    required String key,
    required Map<String, dynamic> value,
    List<double>? embedding,
    Map<String, dynamic>? metadata,
  }) async {
    await _post('/tools/memory_store', {
      'namespace': namespace,
      'key': key,
      'value': jsonEncode(value),
      if (embedding != null) 'embedding': embedding,
      if (metadata != null) 'metadata': metadata,
    });
  }

  Future<List<Map<String, dynamic>>> memorySearch({
    required String namespace,
    required String query,
    int topK = 5,
    double threshold = 0.75,
  }) async {
    final res = await _post('/tools/memory_search', {
      'namespace': namespace,
      'query': query,
      'top_k': topK,
      'threshold': threshold,
    });
    return List<Map<String, dynamic>>.from(res['results'] ?? []);
  }

  Future<Map<String, dynamic>> swarmQuery({
    required String input,
    required List<String> agents,
    Map<String, dynamic>? context,
  }) async {
    return await _post('/tools/swarm_init', {
      'input': input,
      'agents': agents,
      if (context != null) 'context': context,
    });
  }

  Future<Map<String, dynamic>> callTool(
    String toolName,
    Map<String, dynamic> params,
  ) async {
    return await _post('/tools/$toolName', params);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('RuFlo error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('[RuFlo] Tool call failed: $e');
      return {};
    }
  }
}

final ruflo = RuFloService();
