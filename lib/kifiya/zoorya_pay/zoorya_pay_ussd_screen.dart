import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// ZOORYA-PAY USSD waiting screen.
/// Used for: telebirr, mpesa, nib, zemen, ethswitch
///
/// Features authentic native telebirr brand UI when method == 'telebirr',
/// and tailored brand styling for M-PESA, NIB, Zemen, and EthSwitch.
class ZooryaPayUssdScreen extends StatefulWidget {
  const ZooryaPayUssdScreen({
    Key? key,
    required this.method,
    required this.displayName,
    required this.amount,
    required this.userId,
    required this.serverToken,
    required this.uniqueId,
    required this.orderPaymentId,
    required this.phoneNumber,
  }) : super(key: key);

  /// ZOORYA-PAY method key: 'telebirr', 'mpesa', 'nib', 'zemen', 'ethswitch'
  final String method;

  /// Human-readable name shown in the AppBar title
  final String displayName;

  final double amount;
  final String userId;
  final String serverToken;

  /// order_payment unique_id  (used in /api/zooryapay/pay payload)
  final String uniqueId;

  /// order_payment_id  (used in /admin/check_paid_order payload)
  final String orderPaymentId;

  /// Phone number (e.g. "912345678")
  final String phoneNumber;

  @override
  State<ZooryaPayUssdScreen> createState() => _ZooryaPayUssdScreenState();
}

class _ZooryaPayUssdScreenState extends State<ZooryaPayUssdScreen> {
  bool _payInitiated = false;
  bool _payError = false;
  String _errorMessage = '';
  int _pollAttempt = 0;

  // Primary brand colour per method:
  // - ethswitch: Orange
  // - zemen: Red
  // - nib: Brown
  // - mpesa: Safaricom Green
  // - telebirr: Telebirr Blue
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
      case 'mpesa':
        return const Color(0xFF008542); // Safaricom Green
      case 'telebirr':
      case 'telebirr_qr':
      default:
        return const Color(0xFF00A651); // Official Telebirr Green
    }
  }

  // Secondary / Accent colour per method
  Color get _methodSecondaryColor {
    switch (widget.method) {
      case 'zemen':
      case 'zemen_qr':
        return const Color(0xFF1A1A1A); // Zemen Black
      case 'nib':
      case 'nib_qr':
        return const Color(0xFFFEB914); // Nib Yellow / Gold
      case 'ethswitch':
      case 'ethswitch_qr':
        return const Color(0xFF142548); // EthSwitch Navy
      case 'telebirr':
      case 'telebirr_qr':
        return const Color(0xFFFFC30E); // Telebirr Yellow / Gold
      case 'mpesa':
      default:
        return const Color(0xFF004D25); // Safaricom Dark Green
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
      case 'mpesa':
        return 'images/payment/new_payment/mpesa.png';
      case 'telebirr':
      case 'telebirr_qr':
      default:
        return 'images/payment/new_payment/telebirr.png';
    }
  }

  // Method brand subtitle
  String get _methodSubtitle {
    switch (widget.method) {
      case 'ethswitch':
      case 'ethswitch_qr':
        return 'Powered by EthSwitch';
      case 'zemen':
      case 'zemen_qr':
        return 'Zemen Bank';
      case 'nib':
      case 'nib_qr':
        return 'Nib International Bank';
      case 'telebirr':
      case 'telebirr_qr':
        return 'Powered by Ethio telecom';
      case 'mpesa':
        return 'Powered by Safaricom Ethiopia';
      default:
        return 'Digital Payment';
    }
  }

  @override
  void initState() {
    super.initState();
    _initiatePay();
  }

  Future<void> _initiatePay() async {
    debugPrint('[ZooryaPayUssd] Initiating pay — method=${widget.method}');
    final result = await ZooryaPayService.pay(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      method: widget.method,
      uniqueId: widget.uniqueId,
      amount: widget.amount,
      phoneNumber: widget.phoneNumber,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _payError = true;
        _errorMessage =
            'Could not connect to ZOORYA-PAY. Please check your internet connection.';
      });
      return;
    }

    if (result['success'] == true) {
      debugPrint('[ZooryaPayUssd] Pay initiated successfully. Starting poll.');
      setState(() {
        _payInitiated = true;
      });
      if (mounted) {
        Service.showMessage(
          context: context,
          title:
              'Payment request sent to ${widget.displayName}. '
              'Please complete the payment on your phone.',
          error: false,
          duration: 6,
        );
      }
      _pollPaymentStatus();
    } else {
      final msg = result['message']?.toString() ??
          'Payment initiation failed. Please try again.';
      debugPrint('[ZooryaPayUssd] Pay failed: $msg');
      setState(() {
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

  void _pollPaymentStatus() async {
    if (!mounted) return;
    _pollAttempt++;
    debugPrint(
      '[ZooryaPayUssd] Poll attempt #$_pollAttempt for orderPaymentId=${widget.orderPaymentId}',
    );

    final result = await ZooryaPayService.checkPaidOrder(
      context: context,
      userId: widget.userId,
      serverToken: widget.serverToken,
      orderPaymentId: widget.orderPaymentId,
    );

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      debugPrint('[ZooryaPayUssd] Payment confirmed! Closing screen.');
      Navigator.pop(context);
    } else {
      debugPrint('[ZooryaPayUssd] Not paid yet. Retrying in 2s...');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _pollPaymentStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTelebirr = widget.method == 'telebirr';

    return Scaffold(
      backgroundColor: isTelebirr ? const Color(0xFFF4F9F5) : null,
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
                    'telebirr USSD',
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
        backgroundColor: isTelebirr ? const Color(0xFF00A651) : _methodColor,
        flexibleSpace: isTelebirr
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF006837), // Deep Telebirr green
                      Color(0xFF00A651), // Official telebirr green
                      Color(0xFF2BB673), // Bright telebirr green
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              )
            : null,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: _payError
            ? _buildErrorBody()
            : isTelebirr
                ? _buildTelebirrWaitingBody()
                : _buildGenericWaitingBody(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTIC TELEBIRR UI WAITING BODY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTelebirrWaitingBody() {
    final formattedPhone = widget.phoneNumber.isNotEmpty
        ? (widget.phoneNumber.startsWith('0') ||
                widget.phoneNumber.startsWith('+')
            ? widget.phoneNumber
            : '0${widget.phoneNumber}')
        : '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Top Curved Gradient Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(20),
              vertical: getProportionateScreenHeight(16),
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF006837),
                  Color(0xFF00A651),
                  Color(0xFF2BB673),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A651).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // telebirr White Logo Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'images/payment/new_payment/telebirr.png',
                    height: getProportionateScreenHeight(48),
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(10)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC30E), // telebirr Yellow
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Powered by Ethio telecom',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(4)),
              ],
            ),
          ),

          // ── Payment Summary Card ──
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(16),
              vertical: getProportionateScreenHeight(14),
            ),
            padding: EdgeInsets.all(getProportionateScreenWidth(20)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF00A651).withValues(alpha: 0.18),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A651).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Merchant Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.store_mall_directory_rounded,
                        color: Color(0xFF00A651),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ZMall Online Delivery',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D233A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(14)),

                // Total Amount
                const Text(
                  'Amount to Pay',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black45,
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(4)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'ETB ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00A651),
                      ),
                    ),
                    Text(
                      widget.amount.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00A651),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(16)),

                Divider(color: Colors.grey.shade200, height: 1),
                SizedBox(height: getProportionateScreenHeight(12)),

                // Account & Method Rows
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'telebirr Phone',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          size: 15,
                          color: Color(0xFF00A651),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedPhone,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D233A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'USSD Direct Debit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D233A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── USSD Push Prompt Guide Card ──
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(16),
            ),
            padding: EdgeInsets.all(getProportionateScreenWidth(16)),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00A651).withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00A651),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pin_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'USSD Prompt Sent to Phone',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF006837),
                            ),
                          ),
                          Text(
                            'Complete authorization on your phone',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC30E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '*127#',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4A3400),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getProportionateScreenHeight(14)),

                // 3 Steps
                _buildTelebirrStep(
                  '1',
                  'Check your phone screen for the telebirr USSD pop-up',
                ),
                SizedBox(height: getProportionateScreenHeight(8)),
                _buildTelebirrStep(
                  '2',
                  'Enter your 4-digit telebirr PIN',
                ),
                SizedBox(height: getProportionateScreenHeight(8)),
                _buildTelebirrStep(
                  '3',
                  'Press "Send" or "OK" to approve the payment',
                ),
              ],
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(24)),

          // ── Spinner & Waiting Indicator ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitWave(
                color: const Color(0xFF00A651),
                size: 28,
              ),
              const SizedBox(width: 14),
              Text(
                _payInitiated
                    ? 'Waiting for telebirr PIN...'
                    : 'Initiating telebirr request...',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00A651),
                ),
              ),
            ],
          ),
          SizedBox(height: getProportionateScreenHeight(20)),

          // ── Warning Badge ──
          if (_payInitiated)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC30E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFC30E).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF8A5A00),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please keep this screen open until the transaction completes.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF5A3B00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: getProportionateScreenHeight(16)),

          // ── Security Reassurance Footer ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.security_rounded,
                color: Color(0xFF00A651),
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'Secured by Ethio telecom telebirr payment gateway',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: getProportionateScreenHeight(24)),
        ],
      ),
    );
  }

  Widget _buildTelebirrStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF00A651),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0D233A),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERIC BRAND WAITING BODY (M-PESA, NIB, ZEMEN, ETHSWITCH)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGenericWaitingBody() {
    final formattedPhone = widget.phoneNumber.isNotEmpty
        ? (widget.phoneNumber.startsWith('0') ||
                widget.phoneNumber.startsWith('+')
            ? widget.phoneNumber
            : '0${widget.phoneNumber}')
        : '';

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: getProportionateScreenHeight(10)),

          // ── Brand Card with Logo ──
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(16),
            ),
            padding: EdgeInsets.symmetric(
              vertical: getProportionateScreenHeight(20),
              horizontal: getProportionateScreenWidth(20),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.method == 'zemen'
                    ? const Color(0xFF1A1A1A).withValues(alpha: 0.25)
                    : widget.method == 'nib'
                        ? const Color(0xFFFEB914).withValues(alpha: 0.6)
                        : _methodColor.withValues(alpha: 0.20),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: _methodColor.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Image.asset(
                  _methodLogo,
                  height: getProportionateScreenHeight(65),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 54,
                    color: _methodColor,
                  ),
                ),
                SizedBox(height: getProportionateScreenHeight(12)),
                _buildSubtitleBadge(),
              ],
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(28)),

          // Animated spinner
          SpinKitWave(
            color: _payInitiated ? _methodColor : kSecondaryColor,
            size: 38,
          ),
          SizedBox(height: getProportionateScreenHeight(24)),

          // Status Title
          Text(
            _payInitiated
                ? _getSuccessTitle()
                : 'Connecting to ${widget.displayName}...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _methodColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getProportionateScreenHeight(12)),

          // Instructions text
          Text(
            _payInitiated
                ? _getInstructionText(formattedPhone)
                : 'Please wait while we initiate your payment...',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getProportionateScreenHeight(28)),

          // Amount chip
          _buildAmountChip(),
          SizedBox(height: getProportionateScreenHeight(22)),

          if (_payInitiated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Do NOT close this screen until payment is confirmed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a customized subtitle badge per brand
  Widget _buildSubtitleBadge() {
    if (widget.method == 'zemen' || widget.method == 'zemen_qr') {
      // Zemen Bank: Red badge with Black border and text
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: _methodSecondaryColor, // Black
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _methodColor, width: 1.2),
        ),
        child: const Text(
          'Zemen Bank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    if (widget.method == 'nib' || widget.method == 'nib_qr') {
      // Nib Bank: Yellow badge with Brown text
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: _methodSecondaryColor, // Yellow
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _methodColor, width: 1.2),
        ),
        child: Text(
          'Nib International Bank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _methodColor, // Brown
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    if (widget.method == 'ethswitch' || widget.method == 'ethswitch_qr') {
      // EthSwitch: Orange badge with Navy accent
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF37423).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF37423), width: 1.2),
        ),
        child: const Text(
          'Powered by EthSwitch',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF37423),
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    // Default (mpesa)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _methodColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _methodSubtitle,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _methodColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Builds customized amount chip per brand
  Widget _buildAmountChip() {
    Color chipBg = _methodColor.withValues(alpha: 0.08);
    Color chipBorder = _methodColor.withValues(alpha: 0.25);
    Color chipText = _methodColor;

    if (widget.method == 'zemen' || widget.method == 'zemen_qr') {
      chipBg = const Color(0xFFD3214B).withValues(alpha: 0.08);
      chipBorder = const Color(0xFF1A1A1A).withValues(alpha: 0.4);
      chipText = const Color(0xFFD3214B);
    } else if (widget.method == 'nib' || widget.method == 'nib_qr') {
      chipBg = const Color(0xFFFEB914).withValues(alpha: 0.20);
      chipBorder = const Color(0xFF8A4D21).withValues(alpha: 0.5);
      chipText = const Color(0xFF8A4D21);
    } else if (widget.method == 'ethswitch' || widget.method == 'ethswitch_qr') {
      chipBg = const Color(0xFFF37423).withValues(alpha: 0.08);
      chipBorder = const Color(0xFFF37423).withValues(alpha: 0.4);
      chipText = const Color(0xFFF37423);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: chipBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Amount: ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          Text(
            'ETB ${widget.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: chipText,
            ),
          ),
        ],
      ),
    );
  }

  String _getSuccessTitle() {
    switch (widget.method) {
      case 'zemen':
        return 'Zemen Bank USSD Request Sent!';
      case 'nib':
        return 'Nib Bank USSD Request Sent!';
      case 'ethswitch':
        return 'EthSwitch USSD Request Sent!';
      default:
        return 'USSD Request Sent!';
    }
  }

  String _getInstructionText(String phone) {
    switch (widget.method) {
      case 'zemen':
        return 'A USSD push notification has been sent to $phone.\n\n'
            'Please check your phone and enter your Zemen mobile banking PIN to approve the payment.\n\n'
            'Waiting for payment confirmation...';
      case 'nib':
        return 'A USSD push notification has been sent to $phone.\n\n'
            'Please check your phone and enter your Nib Bank PIN to approve the payment.\n\n'
            'Waiting for payment confirmation...';
      case 'ethswitch':
        return 'A USSD prompt has been sent to $phone.\n\n'
            'Please complete your payment through the prompt.\n\n'
            'Waiting for payment confirmation...';
      default:
        return 'A USSD prompt has been sent to $phone.\n\n'
            'Please complete your payment through the prompt.\n\n'
            'Waiting for payment confirmation...';
    }
  }

  Widget _buildErrorBody() {
    return Padding(
      padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 72, color: Colors.red[400]),
          const SizedBox(height: 20),
          const Text(
            'Payment Failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
