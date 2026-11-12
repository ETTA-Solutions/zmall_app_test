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
    // chat_test is mounted at the server root, not under /api/chatbot
    // (/api/chatbot/chat_test returns 404).
    final url = "$baseUrl/chat_test";

    debugPrint(
      "═════════════════════════════════════════════════════════i══════",
    );
    debugPrint("💬 [CHAT SERVICE] >>> START sendMessage");
    debugPrint("💬 [CHAT SERVICE] Base URL: $baseUrl");
    debugPrint("💬 [CHAT SERVICE] Full URL: $url");
    debugPrint("💬 [CHAT SERVICE] User ID: $userId");
    debugPrint(
      "💬 [CHAT SERVICE] Session ID: ${sessionId ?? 'none (new session)'}",
    );
    debugPrint("💬 [CHAT SERVICE] Order ID: ${orderId ?? 'none'}");
    debugPrint(
      "💬 [CHAT SERVICE] Server Token: ${serverToken.isNotEmpty ? 'Present (${serverToken.length} chars)' : 'MISSING!'}",
    );
    debugPrint("💬 [CHAT SERVICE] User Location: $userLocation");
    debugPrint("💬 [CHAT SERVICE] User Message: \"$message\"");

    // Build the system prompt that tells the backend model to return
    // structured JSON (browse_results / stores) matching the UI pipeline.
    final systemPrompt = getMockChatbotSystemPrompt(userOrderId: orderId);
    debugPrint(
      "💬 [CHAT SERVICE] System Prompt length: ${systemPrompt.length} chars",
    );

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

    final body = json.encode(data);
    debugPrint("💬 [CHAT SERVICE] Request Payload size: ${body.length} bytes");

    // ── Retry loop ────────────────────────────────────────────────────────────
    int attempt = 0;
    while (attempt <= _maxRetries) {
      attempt++;
      if (attempt > 1) {
        final backoffSec = (attempt - 1) * 2;
        debugPrint(
          "🔄 [CHAT SERVICE] Retry attempt $attempt / ${_maxRetries + 1} (backing off ${backoffSec}s)...",
        );
        await Future.delayed(Duration(seconds: backoffSec));
      }

      final stopwatch = Stopwatch()..start();
      try {
        debugPrint(
          "🌐 [CHAT SERVICE HTTP] Attempt $attempt: Sending POST to $url...",
        );
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

        stopwatch.stop();
        debugPrint(
          "🌐 [CHAT SERVICE HTTP] Attempt $attempt finished in ${stopwatch.elapsedMilliseconds}ms",
        );
        debugPrint(
          "🌐 [CHAT SERVICE HTTP] Response Status Code: ${response.statusCode}",
        );
        debugPrint(
          "🌐 [CHAT SERVICE HTTP] Response Body (${response.body.length} chars): ${response.body}",
        );

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          debugPrint(
            "✅ [CHAT SERVICE] Decoded JSON type: ${decoded.runtimeType}",
          );
          if (decoded is Map) {
            debugPrint(
              "✅ [CHAT SERVICE] Decoded Map keys: ${decoded.keys.toList()}",
            );
            // Convert markdown replies into browse_results / stores JSON
            final normalized = normalizeChatResponse(
              Map<String, dynamic>.from(decoded),
            );
            debugPrint(
              "✅ [CHAT SERVICE] Normalized Result keys: ${normalized.keys.toList()}",
            );
            debugPrint(
              "═══════════════════════════════════════════════════════════════",
            );
            return normalized;
          }
          debugPrint("✅ [CHAT SERVICE] Primitive response returned: $decoded");
          debugPrint(
            "═══════════════════════════════════════════════════════════════",
          );
          return {'message': decoded.toString()};
        }

        // Non-200 but the server responded — no point retrying
        debugPrint(
          "❌ [CHAT SERVICE HTTP] Server returned non-200 status: ${response.statusCode}",
        );
        debugPrint("❌ [CHAT SERVICE HTTP] Server error body: ${response.body}");
        debugPrint(
          "═══════════════════════════════════════════════════════════════",
        );
        return {
          'error': true,
          'message':
              'The server returned an error (${response.statusCode}). Please try again.',
        };
      } on TimeoutException catch (e) {
        stopwatch.stop();
        debugPrint(
          "⏰ [CHAT SERVICE TIMEOUT] Attempt $attempt timed out after ${stopwatch.elapsedMilliseconds}ms: $e",
        );
        if (attempt > _maxRetries) {
          debugPrint(
            "❌ [CHAT SERVICE TIMEOUT] All $_maxRetries retries exhausted!",
          );
          debugPrint(
            "═══════════════════════════════════════════════════════════════",
          );
          return {
            'error': true,
            'message':
                'The server is taking too long to respond. Please try again in a moment. ⏳',
          };
        }
      } on SocketException catch (e) {
        stopwatch.stop();
        debugPrint(
          "📡 [CHAT SERVICE NETWORK] Attempt $attempt SocketException after ${stopwatch.elapsedMilliseconds}ms: $e",
        );
        if (attempt > _maxRetries) {
          debugPrint(
            "❌ [CHAT SERVICE NETWORK] All $_maxRetries retries exhausted on network error!",
          );
          debugPrint(
            "═══════════════════════════════════════════════════════════════",
          );
          return {
            'error': true,
            'message':
                'No internet connection. Please check your network and try again. 📡',
          };
        }
      } catch (e, stack) {
        stopwatch.stop();
        debugPrint(
          "❌ [CHAT SERVICE EXCEPTION] Attempt $attempt unexpected error after ${stopwatch.elapsedMilliseconds}ms: $e",
        );
        debugPrint("❌ [CHAT SERVICE EXCEPTION] Stack trace: $stack");
        debugPrint(
          "═══════════════════════════════════════════════════════════════",
        );
        return {
          'error': true,
          'message': 'Something went wrong. Please try again. 🙏',
        };
      }
    }

    // Fallback (should not normally be reached)
    debugPrint(
      "⚠️ [CHAT SERVICE] Exited retry loop without definitive response",
    );
    debugPrint(
      "═══════════════════════════════════════════════════════════════",
    );
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
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final url = "$baseUrl/api/user/get_orders";
    debugPrint("📦 [CHAT ORDERS] Fetching orders from: $url");
    debugPrint(
      "📦 [CHAT ORDERS] userId: $userId, serverToken: ${serverToken.isNotEmpty ? 'Present' : 'Missing'}",
    );
    Map data = {"user_id": userId, "server_token": serverToken};
    var body = json.encode(data);
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
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      debugPrint("📦 [CHAT ORDERS] Response Status: ${response.statusCode}");
      debugPrint("📦 [CHAT ORDERS] Response Body: ${response.body}");
      final decoded = json.decode(response.body);
      debugPrint(
        "📦 [CHAT ORDERS] Decoded success: ${decoded?['success']}, total orders: ${decoded?['order_list']?.length ?? 0}",
      );
      return decoded;
    } catch (e, stack) {
      debugPrint("❌ [CHAT ORDERS] Error fetching orders: $e");
      debugPrint("❌ [CHAT ORDERS] Stack trace: $stack");
      return null;
    }
  }
}
