import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// ZOORYA-PAY QR code screen.
/// Used for: ethswitch_qr, telebirr_qr, and other QR methods
///
/// Features authentic ZOORYA-PAY theme with #06182A background and #45B5E4 accents.
class ZooryaPayQrScreen extends StatefulWidget {
  const ZooryaPayQrScreen({
    Key? key,
    required this.method,
    required this.displayName,
    this.imageUrl,
    required this.amount,
    required this.userId,
    required this.serverToken,
    required this.uniqueId,
    required this.orderPaymentId,
  }) : super(key: key);

  /// ZOORYA-PAY method key: 'ethswitch_qr', 'telebirr_qr', etc.
  final String method;

  /// Human-readable name for AppBar title
  final String displayName;

  /// Dynamic image URL from backend: e.g. 'web_images/telebirr.png'
  final String? imageUrl;

  final double amount;
  final String userId;
  final String serverToken;

  /// order_payment unique_id (for /api/zooryapay/pay)
  final String uniqueId;

  /// order_payment_id (for /admin/check_paid_order)
  final String orderPaymentId;

  @override
  State<ZooryaPayQrScreen> createState() => _ZooryaPayQrScreenState();
}

class _ZooryaPayQrScreenState extends State<ZooryaPayQrScreen> {
  bool _loading = true;
  bool _payError = false;
  String _errorMessage = '';
  String? _qrValue;
  int _pollAttempt = 0;
  // Checks stop after ZooryaPayService.pollWindow (2 min).
  int _pollGen = 0;
  DateTime? _pollStartedAt;
  bool _pollTimedOut = false;
  bool _manualChecking = false;

  // Zoorya Pay Brand Colors
  static const Color _zooryaDarkBg = Color(0xFF06182A);
  static const Color _zooryaCyan = Color(0xFF45B5E4);
  static const Color _cardSurface = Color(0xFF0B2238);

  // Primary brand colour per method:
  Color get _methodColor {
    switch (widget.method) {
      case 'ethswitch':
      case 'ethswitch_qr':
        return const Color(0xFFF37423); // EthSwitch Orange
      case 'zemen':
      case 'zemen_qr':
        return const Color(0xFFD3214B); // Zemen Red
      case 'nib':
      case 'nib_qr':
        return const Color(0xFF8A4D21); // Nib Brown
      case 'telebirr':
      case 'telebirr_qr':
      default:
        return _zooryaCyan; // #45B5E4
    }
  }

  // Method logo image asset
  String get _methodLogo {
    switch (widget.method) {
      case 'ethswitch':
      case 'ethswitch_qr':
        return 'images/payment/new_payment/ethswitch.png';
      case 'zemen':
      case 'zemen_qr':
        return 'images/payment/new_payment/zemen.png';
      case 'nib':
      case 'nib_qr':
        return 'images/payment/new_payment/nib_bank.png';
      case 'telebirr':
      case 'telebirr_qr':
      default:
        return 'images/payment/new_payment/telebirr.png';
    }
  }

  String get _scanInstruction {
    switch (widget.method) {
      case 'ethswitch':
      case 'ethswitch_qr':
        return 'Scan with your EthSwitch-compatible banking app';
      case 'zemen':
      case 'zemen_qr':
        return 'Scan with your Zemen mobile banking app';
      case 'nib':
      case 'nib_qr':
        return 'Scan with your Nib Bank mobile app';
      default:
        return 'Scan with your telebirr SuperApp';
    }
  }

  @override
  void initState() {
    super.initState();
    _initiatePay();
  }

  Future<void> _initiatePay() async {
    debugPrint('╔══════════════════════════════════════════════════════════════════╗');
    debugPrint('║ 🚀 [ZooryaPayQr] INITIATING QR PAYMENT REQUEST                   ║');
    debugPrint('╠══════════════════════════════════════════════════════════════════╣');
    debugPrint('║ Method:             ${widget.method}');
    debugPrint('║ Unique ID:          ${widget.uniqueId}');
    debugPrint('║ Order Payment ID:   ${widget.orderPaymentId}');
    debugPrint('║ Amount:             ${widget.amount}');
    debugPrint('║ User ID:            ${widget.userId}');
    debugPrint('╚══════════════════════════════════════════════════════════════════╝');

    final result = await ZooryaPayService.pay(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      method: widget.method,
      uniqueId: widget.uniqueId,
      amount: widget.amount,
      // No phoneNumber for QR methods
    );

    if (!mounted) return;

    if (result == null) {
      debugPrint('[ZooryaPayQr] ❌ Network error: result is null');
      setState(() {
        _loading = false;
        _payError = true;
        _errorMessage =
            'Could not connect to ZOORYA-PAY. Please check your internet connection.';
      });
      return;
    }

    debugPrint('╔══════════════════════════════════════════════════════════════════╗');
    debugPrint('║ 📥 [ZooryaPayQr] API RESPONSE RECEIVED FOR ${widget.method.toUpperCase()}');
    debugPrint('╠══════════════════════════════════════════════════════════════════╣');
    debugPrint('║ Success:                 ${result['success']}');
    debugPrint('║ ZooryaPay Payment ID:    ${result['data']?['zooryapay_payment_id']}');
    debugPrint('║ Order Payment Unique ID: ${result['data']?['order_payment_unique_id']}');
    debugPrint('║ Method:                  ${result['data']?['method']}');
    debugPrint('║ Amount:                  ${result['data']?['amount']} ${result['data']?['currency']}');
    debugPrint('║ Status:                  ${result['data']?['status']}');
    debugPrint('║ Is Paid:                 ${result['data']?['is_paid']}');
    debugPrint('║ Error Description:       ${result['data']?['error_description']}');
    debugPrint('║ QR Value:                ${result['data']?['qr_value']}');
    debugPrint('╚══════════════════════════════════════════════════════════════════╝');

    if (result['success'] == true) {
      final qr = result['data']?['qr_value']?.toString() ?? '';

      if (qr.isEmpty) {
        debugPrint('[ZooryaPayQr] ⚠️ QR code value in response is empty!');
        setState(() {
          _loading = false;
          _payError = true;
          _errorMessage =
              'No QR code was returned by the server. Please try again.';
        });
        return;
      }

      setState(() {
        _loading = false;
        _qrValue = qr;
      });

      // Start polling for payment confirmation
      _startPolling();
    } else {
      final msg = result['message']?.toString() ??
          'QR payment initiation failed. Please try again.';
      debugPrint('[ZooryaPayQr] ❌ Pay failed: $msg');
      setState(() {
        _loading = false;
        _payError = true;
        _errorMessage = msg;
      });
      if (mounted) {
        Service.showMessage(
          context: context,
          title: msg,
          error: true,
          duration: 6,
        );
      }
    }
  }

  bool _isPaymentConfirmed(dynamic result) {
    if (result == null) return false;
    if (result['success'] == true || result['success'] == 'true') return true;
    if (result['is_paid'] == true || result['is_paid'] == 'true') return true;
    if (result['paid'] == true || result['paid'] == 'true') return true;
    if (result['data'] is Map) {
      final data = result['data'] as Map;
      if (data['is_paid'] == true || data['is_paid'] == 'true') return true;
      if (data['paid'] == true || data['paid'] == 'true') return true;
      if (data['status'] == 'PAID' || data['status'] == 'COMPLETED') return true;
    }
    return false;
  }

  /// Starts (or restarts) checking with a fresh 2-minute window.
  void _startPolling() {
    _pollGen++;
    _pollAttempt = 0;
    _pollStartedAt = DateTime.now();
    if (mounted) setState(() => _pollTimedOut = false);
    _pollPaymentStatus(_pollGen);
  }

  /// Check → wait for the answer → wait 2s → check again, for up to 2 min.
  void _pollPaymentStatus(int gen) async {
    while (mounted && gen == _pollGen) {
      if (DateTime.now().difference(_pollStartedAt!) >=
          ZooryaPayService.pollWindow) {
        debugPrint(
          '[ZooryaPayQr] ⏱️ Stopped checking after 2 min ($_pollAttempt checks).',
        );
        setState(() => _pollTimedOut = true);
        return;
      }
      _pollAttempt++;
      debugPrint('[ZooryaPayQr] 🔄 Polling Attempt #$_pollAttempt');
      final result = await ZooryaPayService.checkPaidOrder(
        context: context,
        userId: widget.userId,
        serverToken: widget.serverToken,
        orderPaymentId: widget.orderPaymentId,
      );
      if (!mounted || gen != _pollGen) return;
      if (_isPaymentConfirmed(result)) {
        _pollGen++;
        _onPaid(result);
        return;
      }
      await Future.delayed(ZooryaPayService.pollInterval);
    }
  }

  void _onPaid([dynamic result]) {
    debugPrint('[ZooryaPayQr] ✅ PAYMENT CONFIRMED! Closing QR screen');
    Service.showMessage(
      context: context,
      title: 'Payment confirmed successfully!',
      error: false,
      duration: 3,
    );
    // Return the check_paid_order response (backend creates the order).
    Navigator.pop(context, result is Map ? result : true);
  }

  /// "I've paid, check again" — a single check after the 2 minutes.
  Future<void> _manualCheck() async {
    setState(() => _manualChecking = true);
    final result = await ZooryaPayService.checkPaidOrder(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      orderPaymentId: widget.orderPaymentId,
    );
    if (!mounted) return;
    setState(() => _manualChecking = false);
    if (_isPaymentConfirmed(result)) {
      _onPaid(result);
    } else {
      Service.showMessage(
        context: context,
        title: 'Payment not received yet. Get a new QR code to try again.',
        error: true,
        duration: 4,
      );
    }
  }

  /// "Get new QR code" — asks for a new QR and starts a new 2 minutes.
  void _newQr() {
    setState(() {
      _pollTimedOut = false;
      _loading = true;
      _qrValue = null;
    });
    _initiatePay();
  }

  /// Shown after 2 minutes without a confirmed payment.
  Widget _buildTimedOutBody() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
          decoration: BoxDecoration(
            color: _cardSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_off_outlined, size: 40, color: Colors.white70),
              const SizedBox(height: 14),
              const Text(
                "We couldn't confirm your payment",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The QR code may have expired. Get a new one, or check again if you already paid.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _manualChecking ? null : _newQr,
                  icon: const Icon(Icons.refresh_rounded, color: _zooryaDarkBg),
                  label: const Text(
                    'Get new QR code',
                    style: TextStyle(
                      color: _zooryaDarkBg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _zooryaCyan,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _manualChecking ? null : _manualCheck,
                child: _manualChecking
                    ? const SpinKitThreeBounce(color: _zooryaCyan, size: 16)
                    : const Text(
                        "I've paid, check again",
                        style: TextStyle(
                          color: _zooryaCyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTelebirr = widget.method == 'telebirr_qr' || widget.method == 'telebirr';

    return Scaffold(
      backgroundColor: _zooryaDarkBg,
      appBar: AppBar(
        title: isTelebirr
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.asset(
                      'images/payment/new_payment/telebirr.png',
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'telebirr QR Pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              )
            : Text(
                widget.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
        backgroundColor: _zooryaDarkBg,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitWave(color: _zooryaCyan, size: 40),
            const SizedBox(height: 20),
            Text(
              'Generating QR code...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _zooryaCyan,
              ),
            ),
          ],
        ),
      );
    }

    if (_payError) {
      return _buildErrorBody();
    }

    if (_pollTimedOut) {
      return _buildTimedOutBody();
    }

    return _buildQrBody();
  }

  Widget _buildQrBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),

          // ── Brand Logo Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _zooryaCyan.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _zooryaCyan.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _buildQrLogo(context),
            ),
          ),
          const SizedBox(height: 16),

          // Header text
          Text(
            'Scan to Pay',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _zooryaCyan,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _scanInstruction,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // QR Code Container
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _zooryaCyan.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: _zooryaCyan,
                  width: 2.5,
                ),
              ),
              child: QrImageView(
                data: _qrValue ?? '',
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Amount chip
          _buildAmountChip(),
          const SizedBox(height: 20),

          // Polling indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _zooryaCyan,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Waiting for payment confirmation...',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Do NOT close this screen until payment is confirmed.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAmountChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _zooryaCyan, width: 1.5),
      ),
      child: Text(
        'ETB ${widget.amount.toStringAsFixed(2)}',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _zooryaCyan,
        ),
      ),
    );
  }

  Widget _buildErrorBody() {
    return Padding(
      padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 72, color: Colors.red[300]),
          const SizedBox(height: 20),
          const Text(
            'QR Generation Failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _zooryaCyan,
                foregroundColor: _zooryaDarkBg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Go Back',
                style: TextStyle(
                  color: _zooryaDarkBg,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrLogo(BuildContext context) {
    final img = widget.imageUrl ?? '';
    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        height: 38,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackQrLogo(),
      );
    }
    if (img.startsWith('web_images/')) {
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        return Image.network(
          '$baseUrl/$img',
          height: 38,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackQrLogo(),
        );
      } catch (_) {
        return _fallbackQrLogo();
      }
    }
    return _fallbackQrLogo();
  }

  Widget _fallbackQrLogo() {
    return Image.asset(
      _methodLogo,
      height: 38,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.qr_code_rounded,
        size: 36,
        color: _zooryaCyan,
      ),
    );
  }
}
