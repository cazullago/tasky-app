import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// OpenAI-compatible chat provider (works with OpenAI, or any compatible
/// endpoint). Never fakes responses: throws [AiException] on any failure so
/// the UI can show an honest error.
class AiService {
  /// Quick connectivity check: GET {baseUrl}/models with the key.
  static Future<void> testConnection(AiConfig cfg) async {
    final base = cfg.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (cfg.apiKey.trim().isEmpty) {
      throw AiException('Enter your API key first.');
    }
    try {
      final res = await http
          .get(
            Uri.parse('$base/models'),
            headers: {'Authorization': 'Bearer ${cfg.apiKey.trim()}'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return;
      if (res.statusCode == 401) {
        throw AiException('The API key was rejected (401). Check the key.');
      }
      throw AiException(
          'Server replied ${res.statusCode}. Check the base URL.');
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException(
          'Could not reach the server. Check the URL and your connection.');
    }
  }

  /// One chat completion. Throws [AiException] on failure.
  static Future<String> complete({
    required AiConfig cfg,
    required String system,
    required String user,
  }) async {
    final base = cfg.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (cfg.apiKey.trim().isEmpty) {
      throw AiException('No API key configured.');
    }
    try {
      final res = await http
          .post(
            Uri.parse('$base/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${cfg.apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': cfg.model.trim().isEmpty ? 'gpt-4o-mini' : cfg.model.trim(),
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw AiException(
            'AI request failed (${res.statusCode}). Check key/model/URL.');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      final msg = choices?.isNotEmpty == true
          ? (choices!.first as Map)['message'] as Map?
          : null;
      final content = (msg?['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) throw AiException('The AI returned an empty reply.');
      return content;
    } catch (e) {
      if (e is AiException) rethrow;
      debugPrint('Tasky AI complete failed: $e');
      throw AiException('AI request failed. Check connection and settings.');
    }
  }
}
