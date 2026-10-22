import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/help/support_chat/service/chat_response_parser.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';

class ChatService {
  static const Duration chatResponseTimeout = Duration(minutes: 4);
  static const int _maxRetries = 4;

  /// Send a message to the chat API and get bot response.
  /// Includes the structured system prompt so the backend model returns
  /// browse_results / stores JSON that renders as product and store cards
  /// in the chat UI — matching the mock data UI exactly.
  ///
  /// Retries up to [_maxRetries] times on timeout or socket errors before
  /// surfacing an error to the caller.
  static Future<Map<String, dynamic>?> sendMessage({
    required String message,
    required BuildContext context,
    required String userId,
    String? sessionId,
    String? orderId,
    required String serverToken,
    required List userLocation,
  }) async {
    // Get base URL from metadata provider
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = "$baseUrl/api/chatbot/chat_web";

    debugPrint("🚀 [CHAT DEBUG] Base URL: $baseUrl");
    debugPrint("🚀 [CHAT DEBUG] Full URL: $url");
    debugPrint("🚀 [CHAT DEBUG] User ID: $userId");
    debugPrint(
      "🚀 [CHAT DEBUG] Server Token: ${serverToken.isNotEmpty ? 'Present' : 'Missing'}",
    );
    debugPrint("🚀 [CHAT DEBUG] User Location: $userLocation");

    // Build the system prompt that tells the backend model to return
    // structured JSON (browse_results / stores) matching the UI pipeline.
    final systemPrompt = getMockChatbotSystemPrompt(userOrderId: orderId);

    final Map<String, dynamic> data = {
      "message": message,
      "user_id": userId,
      "user_location": userLocation,
      "server_token": serverToken,
      "system_prompt": systemPrompt,
    };

    if (sessionId != null && sessionId.isNotEmpty) {
      data["session_id"] = sessionId;
    }
    if (orderId != null && orderId.isNotEmpty) {
      data["order_id"] = orderId;
    }

    debugPrint("🚀 [CHAT DEBUG] Request Data (message): $message");
    final body = json.encode(data);

    // ── Retry loop ────────────────────────────────────────────────────────────
    int attempt = 0;
    while (attempt <= _maxRetries) {
      attempt++;
      if (attempt > 1) {
        debugPrint(
          "🔄 [CHAT] Retry attempt $attempt / ${_maxRetries + 1} for /chat_test",
        );
        // Brief back-off before retrying (2 s, then 4 s)
        await Future.delayed(Duration(seconds: (attempt - 1) * 2));
      }

      try {
        final http.Response response = await http
            .post(
              Uri.parse(url),
              headers: <String, String>{
                "Content-Type": "application/json",
                "Accept": "application/json",
              },
              body: body,
            )
            .timeout(chatResponseTimeout);

        debugPrint(
          "=====Chat API Response Status (attempt $attempt): ${response.statusCode}",
        );
        debugPrint("====Chat API Response Body: ${response.body}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map) {
            // Convert markdown replies into browse_results / stores JSON
            return normalizeChatResponse(Map<String, dynamic>.from(decoded));
          }
          return {'message': decoded.toString()};
        }

        // Non-200 but the server responded — no point retrying
        debugPrint("====Chat API Error: Status ${response.statusCode}");
        return {
          'error': true,
          'message': 'The server returned an error. Please try again.',
        };
      } on TimeoutException {
        debugPrint("====Chat API Timeout (attempt $attempt)");
        if (attempt > _maxRetries) {
          return {
            'error': true,
            'message':
                'The server is taking too long to respond. Please try again in a moment. ⏳',
          };
        }
      } on SocketException catch (e) {
        debugPrint("====Chat API SocketException (attempt $attempt): $e");
        if (attempt > _maxRetries) {
          return {
            'error': true,
            'message':
                'No internet connection. Please check your network and try again. 📡',
          };
        }
      } catch (e) {
        debugPrint("=====Chat API Error (attempt $attempt): $e");
        // Unknown error — don't retry
        return {
          'error': true,
          'message': 'Something went wrong. Please try again. 🙏',
        };
      }
    }

    // Fallback (should not normally be reached)
    return {
      'error': true,
      'message':
          'The server is taking too long to respond. Please try again in a moment. ⏳',
    };
  }

  ////////////////////get user orders///////////////////

  static Future<dynamic> getOrders({
    required String userId,
    required String serverToken,
    required BuildContext context,
  }) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_orders";
    Map data = {"user_id": userId, "server_token": serverToken};
    var body = json.encode(data);
    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }
}
