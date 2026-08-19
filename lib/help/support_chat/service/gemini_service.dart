import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zmall/utils/constants.dart';

/// Direct Gemini chatbot integration used when the ZMall chat backend is
/// unavailable, so the support chat keeps replying with real AI answers.
class GeminiService {
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models";

  /// Sends a single user message to Gemini and returns the reply text,
  /// or null if the request fails.
  static Future<String?> sendMessage(String message) async {
    final url = Uri.parse(
      "$_baseUrl/$kGeminiModel:generateContent?key=$kGeminiApiKey",
    );

    try {
      final response = await http
          .post(
            url,
            headers: <String, String>{
              "Content-Type": "application/json",
            },
            body: json.encode({
              "contents": [
                {
                  "parts": [
                    {
                      "text": "You are ZMall support assistant. Help users "
                          "with orders, delivery, payments, refunds, products "
                          "and cart questions. Keep replies concise and "
                          "friendly, and use bullet points when helpful.\n\n"
                          "User: $message",
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text is String && text.trim().isNotEmpty ? text.trim() : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}