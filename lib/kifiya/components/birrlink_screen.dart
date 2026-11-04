import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class BirrLinkScreen extends StatefulWidget {
  const BirrLinkScreen({
    Key? key,
    required this.generateUrl,
    required this.statusUrl,
    required this.uniqueId,
    required this.amount,
    this.phone,
    this.title = "BirrLink Payment",
  }) : super(key: key);

  final String generateUrl;
  final String statusUrl;
  final int uniqueId;
  final double amount;
  final String? phone;
  final String title;

  @override
  _BirrLinkScreenState createState() => _BirrLinkScreenState();
}

class _BirrLinkScreenState extends State<BirrLinkScreen> {
  bool _loading = true;
  String _checkoutUrl = "";
  String? _invoiceId;
  DateTime? _expiresAt;
  Timer? _pollingTimer;
  Timer? _autoCloseTimer;
  bool _paymentFinished = false;

  final InAppWebViewSettings settings = InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: false,
    javaScriptEnabled: true,
    clearCache: true,
    useHybridComposition: true,
    allowsInlineMediaPlayback: true,
  );

  @override
  void initState() {
    super.initState();
    debugPrint("[BirrLinkScreen] initState: Starting payment initialization");
    _initiatePayment();
  }

  @override
  void dispose() {
    debugPrint("[BirrLinkScreen] dispose: Cancelling timers");
    _pollingTimer?.cancel();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  /// Converts user phone into BirrLink international format: 2519XXXXXXXX
  String _formatPhoneNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) return "";
    String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('251')) {
      return digits;
    }
    if (digits.startsWith('0')) {
      return '251${digits.substring(1)}';
    }
    if (digits.length == 9) {
      return '251$digits';
    }
    return digits;
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _loading = true;
    });

    Map<String, dynamic> requestBody = {
      "unique_id": widget.uniqueId,
      "amount": widget.amount,
    };

    String formattedPhone = _formatPhoneNumber(widget.phone);
    if (formattedPhone.isNotEmpty) {
      requestBody["phone_number"] = formattedPhone;
    }

    debugPrint("[BirrLinkScreen] POST to: ${widget.generateUrl}");
    debugPrint("[BirrLinkScreen] Payload: ${json.encode(requestBody)}");

    try {
      final http.Response response = await http
          .post(
            Uri.parse(widget.generateUrl),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint("[BirrLinkScreen] Response status: ${response.statusCode}");
      debugPrint("[BirrLinkScreen] Response body: ${response.body}");

      final data = json.decode(response.body);

      if (!mounted) return;

      if (data != null && data['success'] == true && data['data'] != null) {
        final resData = data['data'];
        setState(() {
          _invoiceId = resData['invoice_id'];
          _checkoutUrl = resData['checkout_url'] ?? "";
          if (resData['expires_at'] != null) {
            _expiresAt = DateTime.tryParse(resData['expires_at']);
          }
          _loading = false;
        });

        debugPrint("[BirrLinkScreen] Invoice ID: $_invoiceId");
        debugPrint("[BirrLinkScreen] Checkout URL: $_checkoutUrl");
        debugPrint("[BirrLinkScreen] Expires at: $_expiresAt");

        // Start polling payment status every ~3 seconds
        _startPolling();
      } else {
        setState(() {
          _loading = false;
        });
        String errorMsg = data != null && data['message'] != null
            ? data['message']
            : "Failed to initiate BirrLink payment. Please try again.";
        debugPrint("[BirrLinkScreen] Initiation failed: $errorMsg");
        Service.showMessage(
          context: context,
          title: errorMsg,
          error: true,
          duration: 4,
        );
        Navigator.pop(context, false);
      }
    } catch (e) {
      debugPrint("[BirrLinkScreen] Error in _initiatePayment: $e");
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      Service.showMessage(
        context: context,
        title: "Connection error. Please check your internet connection!",
        error: true,
        duration: 4,
      );
      Navigator.pop(context, false);
    }
  }

  void _startPolling() {
    debugPrint("[BirrLinkScreen] Starting background polling every 3 seconds...");
    final startTime = DateTime.now();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_paymentFinished || _invoiceId == null) {
        debugPrint("[BirrLinkScreen] Polling stopped: finished=$_paymentFinished, invoiceId=$_invoiceId");
        timer.cancel();
        return;
      }

      // Stop polling after 2 minutes or when expires_at has passed
      if (DateTime.now().difference(startTime).inSeconds > 120 ||
          (_expiresAt != null && DateTime.now().isAfter(_expiresAt!))) {
        debugPrint("[BirrLinkScreen] Polling timed out (2 min or expired). Stopping timer.");
        timer.cancel();
        return;
      }

      final status = await _checkTransactionStatus();
      if (!mounted) {
        timer.cancel();
        return;
      }

      debugPrint("[BirrLinkScreen] Polled transaction status: $status");

      if (status == "succeeded") {
        debugPrint(
            "[BirrLinkScreen] Payment SUCCEEDED! User is on the BirrLink success receipt screen.");
        timer.cancel();
        if (mounted) {
          setState(() {
            _paymentFinished = true;
          });
          Service.showMessage(
            context: context,
            title: "Payment confirmed successfully!",
            error: false,
            duration: 3,
          );
        }

        // Give the user time to view and review the BirrLink success receipt screen.
        // It auto-redirects after 6 seconds, or user can tap 'Done' / Back anytime.
        _autoCloseTimer?.cancel();
        _autoCloseTimer = Timer(const Duration(seconds: 6), () {
          if (mounted && _paymentFinished) {
            debugPrint(
                "[BirrLinkScreen] Auto-redirecting to ZMall after showing receipt...");
            Navigator.pop(context, true);
          }
        });
      }
    });
  }

  Future<String?> _checkTransactionStatus() async {
    if (_invoiceId == null) return null;

    try {
      final http.Response response = await http
          .post(
            Uri.parse(widget.statusUrl),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: json.encode({"invoice_id": _invoiceId}),
          )
          .timeout(const Duration(seconds: 8));

      final data = json.decode(response.body);
      debugPrint("[BirrLinkScreen] checktransactionstatus raw response: ${response.body}");

      if (data != null && data['success'] == true && data['data'] != null) {
        return data['data']['status'];
      }
    } catch (e) {
      debugPrint("[BirrLinkScreen] checktransactionstatus error: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        debugPrint("[BirrLinkScreen] User triggered back/exit");
        _autoCloseTimer?.cancel();
        if (_paymentFinished) {
          Navigator.pop(context, true);
          return false;
        }
        // When user initiates back button before finished, do one synchronous status check
        if (_invoiceId != null) {
          debugPrint("[BirrLinkScreen] Checking status one last time before exiting...");
          final status = await _checkTransactionStatus();
          debugPrint("[BirrLinkScreen] Final exit status check: $status");
          if (status == "succeeded") {
            _paymentFinished = true;
            Navigator.pop(context, true);
            return false;
          }
        }
        Navigator.pop(context, false);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(color: kBlackColor)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kBlackColor),
            onPressed: () async {
              _autoCloseTimer?.cancel();
              if (_paymentFinished) {
                Navigator.pop(context, true);
                return;
              }
              if (_invoiceId != null) {
                final status = await _checkTransactionStatus();
                if (status == "succeeded") {
                  _paymentFinished = true;
                  Navigator.pop(context, true);
                  return;
                }
              }
              Navigator.pop(context, false);
            },
          ),
          actions: [
            if (_paymentFinished)
              TextButton(
                onPressed: () {
                  _autoCloseTimer?.cancel();
                  Navigator.pop(context, true);
                },
                child: const Text(
                  "Done",
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _paymentFinished
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Payment confirmed!",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          _autoCloseTimer?.cancel();
                          Navigator.pop(context, true);
                        },
                        child: const Text("Done"),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: _loading || _checkoutUrl.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitWave(
                        color: kSecondaryColor,
                        size: getProportionateScreenWidth(kDefaultPadding * 2),
                      ),
                      SizedBox(
                        height: getProportionateScreenHeight(kDefaultPadding),
                      ),
                      Text(
                        "Connecting to BirrLink...",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: kBlackColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                )
              : InAppWebView(
                  initialSettings: settings,
                  initialUrlRequest: URLRequest(url: WebUri(_checkoutUrl)),
                  onLoadStart: (controller, url) {
                    debugPrint("[BirrLinkScreen WebView] onLoadStart: $url");
                  },
                  onLoadStop: (controller, url) {
                    debugPrint("[BirrLinkScreen WebView] onLoadStop: $url");
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    debugPrint("[BirrLinkScreen WebView] Navigating to: ${navigationAction.request.url}");
                    return NavigationActionPolicy.ALLOW;
                  },
                ),
        ),
      ),
    );
  }
}
