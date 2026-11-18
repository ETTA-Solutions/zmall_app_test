import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zmall/utils/constants.dart';

/// Shows the CyberSource Unified Checkout page (card form + OTP).
///
/// Pops with `true` as soon as the page navigates to
/// `.../pay/<checkoutId>/result`, or `null` if the user closes it.
/// The caller must then confirm the real status with `/cybersource/status`
/// (the `?status=` in the result URL is never trusted).
class CyberSourceWebView extends StatefulWidget {
  const CyberSourceWebView({
    super.key,
    required this.checkoutUrl,
    required this.checkoutId,
    this.title = 'Card Payment',
  });

  final String checkoutUrl;
  final String checkoutId;
  final String title;

  @override
  State<CyberSourceWebView> createState() => _CyberSourceWebViewState();
}

class _CyberSourceWebViewState extends State<CyberSourceWebView> {
  final InAppWebViewSettings _settings = InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
    javaScriptEnabled: true,
    domStorageEnabled: true,
    mediaPlaybackRequiresUserGesture: false,
    clearCache: true,
    useHybridComposition: true,
    allowsInlineMediaPlayback: true,
  );

  bool _done = false;
  double _progress = 0;

  bool _isResultUrl(WebUri? uri) {
    if (uri == null) return false;
    final s = uri.pathSegments;
    for (var i = 0; i + 2 < s.length; i++) {
      if (s[i] == 'pay' &&
          s[i + 1] == widget.checkoutId &&
          s[i + 2] == 'result') {
        return true;
      }
    }
    return false;
  }

  void _check(WebUri? uri) {
    if (_done || !_isResultUrl(uri)) return;
    _done = true;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: kBlackColor)),
        bottom: _progress < 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 2,
                  color: kSecondaryColor,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: InAppWebView(
          initialSettings: _settings,
          initialUrlRequest: URLRequest(url: WebUri(widget.checkoutUrl)),
          shouldOverrideUrlLoading: (controller, action) async {
            if (_isResultUrl(action.request.url)) {
              _check(action.request.url);
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onLoadStart: (controller, url) => _check(url),
          onUpdateVisitedHistory: (controller, url, _) => _check(url),
          onProgressChanged: (controller, p) {
            if (mounted) setState(() => _progress = p / 100);
          },
        ),
      ),
    );
  }
}
