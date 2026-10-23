import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zmall/help/support_chat/components/chat_address_picker.dart';
import 'package:zmall/help/support_chat/components/zmall_ui.dart';
import 'package:zmall/help/support_chat/service/chat_basket.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Sticky "1 item · 800 ETB  from STORE   [Review & Checkout →]" bar.
/// Slides in when the basket fills and gives a little bump on every add.
class ChatBasketBar extends StatefulWidget {
  final ChatBasket basket;
  final String actionLabel;
  final VoidCallback onAction;

  const ChatBasketBar({
    super.key,
    required this.basket,
    required this.onAction,
    this.actionLabel = 'Review & Checkout →',
  });

  @override
  State<ChatBasketBar> createState() => _ChatBasketBarState();
}

class _ChatBasketBarState extends State<ChatBasketBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.basket.itemCount;
    widget.basket.addListener(_onBasketChanged);
  }

  @override
  void didUpdateWidget(covariant ChatBasketBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.basket != widget.basket) {
      oldWidget.basket.removeListener(_onBasketChanged);
      widget.basket.addListener(_onBasketChanged);
    }
  }

  void _onBasketChanged() {
    final count = widget.basket.itemCount;
    if (count > _lastCount) _bump.forward(from: 0);
    _lastCount = count;
    setState(() {});
  }

  @override
  void dispose() {
    widget.basket.removeListener(_onBasketChanged);
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final basket = widget.basket;
    final visible = basket.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
      child: !visible
          ? const SizedBox(key: ValueKey('empty'), width: double.infinity)
          : AnimatedBuilder(
              key: const ValueKey('bar'),
              animation: _bump,
              builder: (context, child) {
                final t = Curves.easeOut.transform(_bump.value);
                final scale = 1 + 0.035 * (1 - (2 * t - 1).abs());
                return Transform.scale(scale: scale, child: child);
              },
              child: ZCard(
                raised: true,
                accent: kSecondaryColor,
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(14),
                  vertical: getProportionateScreenHeight(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${basket.itemCount} item${basket.itemCount == 1 ? '' : 's'} · ',
                                ),
                                TextSpan(
                                  text: formatEtb(basket.subtotal),
                                  style: TextStyle(color: kSecondaryColor),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(14),
                              fontWeight: FontWeight.w700,
                              color: kZInk,
                            ),
                          ),
                          SizedBox(height: getProportionateScreenHeight(2)),
                          Text(
                            'from ${basket.store?.name ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(11.5),
                              color: kZMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: getProportionateScreenWidth(10)),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onAction();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSecondaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: getProportionateScreenWidth(16),
                          vertical: getProportionateScreenHeight(10),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        widget.actionLabel,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(13.5),
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
}

/// "Your Basket (STORE)" review panel with steppers, totals, delivery
/// address and the Instant Checkout button.
class ChatBasketPanel extends StatefulWidget {
  final ChatBasket basket;
  final VoidCallback onClose;
  final Future<void> Function() onCheckout;

  const ChatBasketPanel({
    super.key,
    required this.basket,
    required this.onClose,
    required this.onCheckout,
  });

  @override
  State<ChatBasketPanel> createState() => _ChatBasketPanelState();
}

class _ChatBasketPanelState extends State<ChatBasketPanel> {
  bool _checkingOut = false;

  Future<void> _checkout() async {
    if (_checkingOut) return;
    HapticFeedback.mediumImpact();
    // No address yet → ask for one before invoicing.
    if (await loadChatDeliveryAddress() == null) {
      if (!mounted) return;
      final picked = await ChatAddressPicker.show(context);
      if (picked == null || !mounted) return;
    }
    setState(() => _checkingOut = true);
    try {
      await widget.onCheckout();
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hPad = getProportionateScreenWidth(16);

    return ListenableBuilder(
      listenable: widget.basket,
      builder: (context, _) {
        final basket = widget.basket;
        if (basket.isEmpty) {
          // Last item removed (or order placed) → dismiss the panel.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onClose();
          });
          return const SizedBox.shrink();
        }

        return ZCard(
          raised: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                color: kZSurface,
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: getProportionateScreenHeight(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your Basket (${basket.store?.name ?? ''})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(15),
                          fontWeight: FontWeight.w700,
                          color: kZInk,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: widget.onClose,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(
                          horizontal: getProportionateScreenWidth(10),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        '× Close',
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(12.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kZBorder),

              // ── Lines ───────────────────────────────────────────
              for (final line in basket.lines)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: getProportionateScreenHeight(10),
                  ),
                  child: Row(
                    children: [
                      ZProductThumb(product: line.product, size: 40),
                      SizedBox(width: getProportionateScreenWidth(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: getProportionateScreenWidth(14),
                                fontWeight: FontWeight.w600,
                                color: kZInk,
                              ),
                            ),
                            Text(
                              '${formatEtb(line.product.price)} each',
                              style: TextStyle(
                                fontSize: getProportionateScreenWidth(11.5),
                                color: kZMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ZQtyStepper(
                        quantity: line.quantity,
                        onAdd: () => basket.add(basket.store!, line.product),
                        onRemove: () => basket.decrement(line.product),
                      ),
                      SizedBox(
                        width: getProportionateScreenWidth(76),
                        child: Text(
                          formatEtb(line.total),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(13),
                            fontWeight: FontWeight.w700,
                            color: kZInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Totals ──────────────────────────────────────────
              Container(
                color: kZSurface,
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: getProportionateScreenHeight(12),
                ),
                child: Column(
                  children: [
                    _totalRow(
                      'Items subtotal',
                      formatEtb(basket.subtotal),
                      emphasize: false,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: getProportionateScreenHeight(8),
                      ),
                      child: const _DashedDivider(),
                    ),
                    _totalRow(
                      'Price',
                      formatEtb(basket.subtotal),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kZBorder),

              // ── Delivery address ────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  getProportionateScreenHeight(14),
                  hPad,
                  getProportionateScreenHeight(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DELIVERY ADDRESS',
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11.5),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: kZMuted,
                      ),
                    ),
                    SizedBox(height: getProportionateScreenHeight(8)),
                    const ChatAddressField(),
                  ],
                ),
              ),
              const Divider(height: 1, color: kZBorder),

              // ── Checkout ────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  getProportionateScreenHeight(14),
                  hPad,
                  getProportionateScreenHeight(10),
                ),
                child: Column(
                  children: [
                    ZPrimaryButton(
                      label: 'Instant Checkout · ${formatEtb(basket.subtotal)}',
                      loading: _checkingOut,
                      onPressed: _checkout,
                    ),
                    SizedBox(height: getProportionateScreenHeight(8)),
                    Text(
                      'Powered by ZMall · Fast food delivery in Addis Ababa',
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11),
                        color: kZMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _totalRow(String label, String value, {required bool emphasize}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: getProportionateScreenWidth(emphasize ? 16 : 13),
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
              color: emphasize ? kZInk : kZMuted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: getProportionateScreenWidth(emphasize ? 16 : 13),
            fontWeight: FontWeight.w700,
            color: emphasize ? kSecondaryColor : kZInk,
          ),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 6).floor();
        return Row(
          children: List.generate(
            count,
            (i) => Expanded(
              child: Container(
                height: 1,
                color: i.isEven ? kZBorder : Colors.transparent,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens the basket review as its own sheet (from the chat screen's bar).
class ChatBasketSheet {
  static Future<void> show(
    BuildContext context, {
    required ChatBasket basket,
    required Future<void> Function() onCheckout,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        var closed = false;
        // Only pop while this sheet is the top route — once something else
        // (e.g. the chat's own popUntil) has closed it, a second pop would
        // close the chat screen instead.
        void close() {
          if (closed || !sheetContext.mounted) return;
          closed = true;
          if (ModalRoute.of(sheetContext)?.isCurrent ?? false) {
            Navigator.pop(sheetContext);
          }
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(getProportionateScreenWidth(12)),
            child: SingleChildScrollView(
              child: ChatBasketPanel(
                basket: basket,
                onClose: close,
                onCheckout: onCheckout,
              ),
            ),
          ),
        );
      },
    );
  }
}
