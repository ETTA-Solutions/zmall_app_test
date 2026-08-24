import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/utils/constants.dart';

/// Gemini chatbot integration powered with rich mock data (catalog, stores,
/// active orders, payment methods, delivery policies).
class GeminiService {
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models";

  /// Sends a message to Gemini with full mock context and conversation history.
  static Future<String?> sendMessageWithMockData({
    required String message,
    List<Map<String, String>>? conversationHistory,
    String? userName,
    String? orderId,
    String? orderStatus,
  }) async {
    final systemPrompt = getMockChatbotSystemPrompt(
      userName: userName,
      userOrderId: orderId,
      userOrderStatus: orderStatus,
    );

    final modelsToTry = [
      kGeminiModel,
      "gemini-1.5-flash",
      "gemini-2.0-flash",
    ];

    for (final model in modelsToTry.toSet()) {
      try {
        final reply = await _generateWithModel(
          model: model,
          systemPrompt: systemPrompt,
          userMessage: message,
          conversationHistory: conversationHistory,
        );
        if (reply != null && reply.trim().isNotEmpty) {
          return reply.trim();
        }
      } catch (e) {
        debugPrint("GeminiService error with model $model: $e");
      }
    }

    return null;
  }

  /// Low-level call to Gemini API for a specific model name.
  static Future<String?> _generateWithModel({
    required String model,
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final url = Uri.parse(
      "$_baseUrl/$model:generateContent?key=$kGeminiApiKey",
    );

    final contents = <Map<String, dynamic>>[];

    // Include recent conversation turns (up to last 6 messages)
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      final recentHistory = conversationHistory.length > 6
          ? conversationHistory.sublist(conversationHistory.length - 6)
          : conversationHistory;

      for (final turn in recentHistory) {
        final role = turn['role'] == 'user' ? 'user' : 'model';
        final text = turn['content'] ?? '';
        if (text.isNotEmpty) {
          contents.add({
            "role": role,
            "parts": [
              {"text": text}
            ],
          });
        }
      }
    }

    // Add current user query
    contents.add({
      "role": "user",
      "parts": [
        {"text": userMessage}
      ],
    });

    final requestBody = {
      "system_instruction": {
        "parts": [
          {"text": systemPrompt}
        ]
      },
      "contents": contents,
      "generationConfig": {
        "temperature": 0.7,
        "topP": 0.95,
        "maxOutputTokens": 600,
      },
    };

    final response = await http
        .post(
          url,
          headers: <String, String>{
            "Content-Type": "application/json",
          },
          body: json.encode(requestBody),
        )
        .timeout(
          const Duration(seconds: 25),
          onTimeout: () {
            throw TimeoutException("Gemini connection timed out");
          },
        );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text is String && text.trim().isNotEmpty) {
        return text.trim();
      }
    } else {
      // Fallback for models or endpoints that prefer prompt prefix over system_instruction
      return await _generateWithInlinePrompt(
        model: model,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
      );
    }

    return null;
  }

  /// Alternative call embedding system prompt directly into the user message part
  static Future<String?> _generateWithInlinePrompt({
    required String model,
    required String systemPrompt,
    required String userMessage,
  }) async {
    final url = Uri.parse(
      "$_baseUrl/$model:generateContent?key=$kGeminiApiKey",
    );

    final combinedText = "$systemPrompt\n\nUser Question:\n$userMessage";

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
                  {"text": combinedText}
                ]
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text is String && text.trim().isNotEmpty) {
        return text.trim();
      }
    }

    return null;
  }

  /// Backward-compatible single-message sender
  static Future<String?> sendMessage(String message) async {
    return sendMessageWithMockData(message: message);
  }
}