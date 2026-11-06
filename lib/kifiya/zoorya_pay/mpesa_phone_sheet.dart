import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _mpesaGreen = Color(0xFF00A650);
const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);

/// Normalizes a phone to local format: +2517.. / 2517.. / 7.. → 07..
String normalizeEthPhone(String raw) {
  var p = raw.replaceAll(RegExp(r'[\s-]'), '');
  if (p.startsWith('+251')) {
    p = '0${p.substring(4)}';
  } else if (p.startsWith('251') && p.length > 9) {
    p = '0${p.substring(3)}';
  } else if (p.isNotEmpty && !p.startsWith('0')) {
    p = '0$p';
  }
  return p;
}

/// True for a valid Safaricom / M-PESA number: 07XXXXXXXX (10 digits).
bool isMpesaPhone(String raw) =>
    RegExp(r'^07\d{8}$').hasMatch(normalizeEthPhone(raw));

/// Bottom sheet that asks for an M-PESA (07...) number.
/// Returns the number as `07XXXXXXXX`, or null if the user closed it.
Future<String?> showMpesaPhoneSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MpesaPhoneSheet(),
  );
}

class _MpesaPhoneSheet extends StatefulWidget {
  const _MpesaPhoneSheet();

  @override
  State<_MpesaPhoneSheet> createState() => _MpesaPhoneSheetState();
}

class _MpesaPhoneSheetState extends State<_MpesaPhoneSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _text => _controller.text;
  bool get _isValid => RegExp(r'^07\d{8}$').hasMatch(_text);

  /// Show an error only when the input clearly can't become a 07 number.
  String? get _error {
    if (_text.isEmpty) return null;
    if (!_text.startsWith('0')) return 'Must start with 07';
    if (_text.length >= 2 && !_text.startsWith('07')) {
      return 'Must start with 07';
    }
    return null;
  }

  void _submit() {
    if (_isValid) Navigator.pop(context, _text);
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final error = _error;
    final borderColor = error != null
        ? Colors.redAccent
        : (focused ? _mpesaGreen : Colors.transparent);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _mpesaGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'images/payment/new_payment/mpesa.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.phone_android_rounded,
                        color: _mpesaGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'M-PESA number',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter a Safaricom number (07…)',
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Phone field
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: focused ? Colors.white : const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_iphone_rounded,
                      color: (focused || _text.isNotEmpty)
                          ? _mpesaGreen
                          : const Color(0xFFB0B5BE),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '07XX XXX XXX',
                          hintStyle: TextStyle(
                            color: Color(0xFFCDD1D8),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: _isValid
                          ? const Icon(
                              Icons.check_circle_rounded,
                              key: ValueKey('ok'),
                              color: _mpesaGreen,
                              size: 22,
                            )
                          : _text.isNotEmpty
                          ? GestureDetector(
                              key: const ValueKey('clear'),
                              onTap: _controller.clear,
                              child: const Icon(
                                Icons.cancel_rounded,
                                color: Color(0xFFB0B5BE),
                                size: 20,
                              ),
                            )
                          : const SizedBox(key: ValueKey('none'), width: 22),
                    ),
                  ],
                ),
              ),

              // Error line (only when wrong)
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                child: error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              error,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 22),

              // Pay button
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _isValid ? _mpesaGreen : const Color(0xFFD9DCE1),
                  boxShadow: _isValid
                      ? [
                          BoxShadow(
                            color: _mpesaGreen.withValues(alpha: 0.30),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isValid ? _submit : null,
                    child: const Center(
                      child: Text(
                        'Pay with M-PESA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
