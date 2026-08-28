import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zmall/help/support_chat/components/food_recommendation_card.dart';
import 'package:zmall/help/support_chat/components/store_carousel.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/models/chat_message.dart';
import 'package:zmall/store/components/image_container.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final String? imageUrl;
  final VoidCallback? onLongPress;
  final VoidCallback? onViewCart;
  final ValueChanged<MockProduct>? onProductTap;
  final ValueChanged<MockProduct>? onAddToCart;
  final List<MockProduct> matchedProducts;
  final MockStore? matchedStore;
  final bool showProducts;
  /// When true the store-list vertical card is shown.
  /// When false (food/item query) the horizontal product swipe cards are shown.
  final bool isStoreOnly;

  const ChatBubble({
    super.key,
    required this.message,
    this.imageUrl,
    this.onLongPress,
    this.onViewCart,
    this.onProductTap,
    this.onAddToCart,
    this.matchedProducts = const [],
    this.matchedStore,
    this.showProducts = true,
    this.isStoreOnly = false,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isCopied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.message.message));
    setState(() => _isCopied = true);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          backgroundColor: kBlackColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _handlePhoneCall(String phone) async {
    final uri = Uri(
      scheme: 'tel',
      path: phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''),
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _handleUrl(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(16),
        vertical: getProportionateScreenHeight(5),
      ),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // ── Bot identity chip (above bubble, bot only) ──────────────
          if (!isUser)
            Padding(
              padding: EdgeInsets.only(bottom: getProportionateScreenHeight(5)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: getProportionateScreenWidth(18),
                    height: getProportionateScreenWidth(18),
                    decoration: BoxDecoration(
                      color: kSecondaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'Z',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: getProportionateScreenWidth(9),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: getProportionateScreenWidth(6)),
                  Text(
                    'ZMall AI',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(11.5),
                      fontWeight: FontWeight.w600,
                      color: kGreyColor,
                    ),
                  ),
                ],
              ),
            ),

          // ── Bubble ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: GestureDetector(
                  onLongPress: widget.onLongPress,
                  child: isUser ? _buildUserBubble() : _buildBotBubble(),
                ),
              ),
              if (isUser) ...[
                SizedBox(width: getProportionateScreenWidth(8)),
                _buildUserAvatar(),
              ],
            ],
          ),

          // ── Store card OR horizontal product cards ───────────────
          if (!isUser &&
              (widget.matchedProducts.isNotEmpty ||
                  widget.matchedStore != null)) ...[
            SizedBox(height: getProportionateScreenHeight(6)),
            if (widget.isStoreOnly)
              // Store query → vertical scrollable list of all stores inline
              const StoreCarousel()
            else
              // Food/item query → horizontal swipe cards
              FoodRecommendationRow(
                products: widget.matchedProducts.isNotEmpty
                    ? widget.matchedProducts
                    : getStoreProducts(
                        widget.matchedStore?.id ?? mockStores.first.id),
                onViewCart: widget.onViewCart,
                onProductTap: widget.onProductTap,
                onAddToCart: widget.onAddToCart,
              ),
          ] else if (!isUser && widget.message.showCartAction) ...[
            SizedBox(height: getProportionateScreenHeight(8)),
            _buildCartActionButton(),
          ],

          // ── Timestamp row (bot) ──────────────────────────────────────
          if (!isUser)
            Padding(
              padding: EdgeInsets.only(top: getProportionateScreenHeight(4)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(10.5),
                      color: kGreyColor.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(width: getProportionateScreenWidth(10)),
                  GestureDetector(
                    onTap: _copyToClipboard,
                    child: Icon(
                      _isCopied
                          ? HeroiconsSolid.check
                          : HeroiconsOutline.clipboardDocument,
                      size: getProportionateScreenWidth(13),
                      color: _isCopied
                          ? kGreenColor
                          : kGreyColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

          // ── Timestamp (user) ─────────────────────────────────────────
          if (isUser)
            Padding(
              padding: EdgeInsets.only(
                right: getProportionateScreenWidth(38),
                top: getProportionateScreenHeight(3),
              ),
              child: Text(
                _formatTime(widget.message.timestamp),
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(10.5),
                  color: kGreyColor.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Bot bubble: kWhiteColor bg, thin light border ─────────────────────────
  Widget _buildBotBubble() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(14),
        vertical: getProportionateScreenHeight(11),
      ),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: kGreyColor.withValues(alpha: 0.12), width: 1),
      ),
      child: _buildFormattedContent(widget.message.message),
    );
  }

  // ── User bubble: kSecondaryColor (ZMall red) ──────────────────────────────
  Widget _buildUserBubble() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(14),
        vertical: getProportionateScreenHeight(11),
      ),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        widget.message.message,
        style: TextStyle(
          color: Colors.white,
          fontSize: getProportionateScreenWidth(14),
          height: 1.45,
        ),
      ),
    );
  }

  // ── Checkout-style cart button: kSecondaryColor filled ───────────────────
  Widget _buildCartActionButton() {
    return GestureDetector(
      onTap: widget.onViewCart,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(20),
          vertical: getProportionateScreenHeight(12),
        ),
        decoration: BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HeroiconsSolid.shoppingCart,
              color: Colors.white,
              size: getProportionateScreenWidth(16),
            ),
            SizedBox(width: getProportionateScreenWidth(8)),
            Text(
              'Checkout',
              style: TextStyle(
                color: Colors.white,
                fontSize: getProportionateScreenWidth(13.5),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── User avatar ───────────────────────────────────────────────────────────
  Widget _buildUserAvatar() {
    return Container(
      width: getProportionateScreenWidth(28),
      height: getProportionateScreenWidth(28),
      decoration: BoxDecoration(color: kWhiteColor, shape: BoxShape.circle),
      child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
          ? ClipOval(child: ImageContainer(url: widget.imageUrl))
          : Icon(
              Icons.person,
              color: kGreyColor,
              size: getProportionateScreenWidth(16),
            ),
    );
  }

  // ── Rich text formatter ───────────────────────────────────────────────────

  Widget _buildFormattedContent(String text) {
    final lines = text.split('\n');
    final blocks = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        if (blocks.isNotEmpty && i < lines.length - 1) {
          blocks.add(SizedBox(height: getProportionateScreenHeight(5)));
        }
        continue;
      }
      final t = line.trim();

      // Heading
      if (t.startsWith('#')) {
        blocks.add(
          Padding(
            padding: EdgeInsets.only(
              top: getProportionateScreenHeight(4),
              bottom: getProportionateScreenHeight(2),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: getProportionateScreenHeight(14),
                  decoration: BoxDecoration(
                    color: kSecondaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(7)),
                Expanded(
                  child: Text(
                    _strip(t.replaceAll(RegExp(r'^#+\s*'), '')),
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(13.5),
                      fontWeight: FontWeight.w700,
                      color: kBlackColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Quote
      if (t.startsWith('>')) {
        blocks.add(
          Container(
            margin: EdgeInsets.symmetric(
              vertical: getProportionateScreenHeight(3),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(10),
              vertical: getProportionateScreenHeight(7),
            ),
            decoration: BoxDecoration(
              color: kSecondaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: kSecondaryColor, width: 3),
              ),
            ),
            child: _buildRichSpan(t.replaceFirst(RegExp(r'^>\s*'), '')),
          ),
        );
        continue;
      }

      // Numbered list
      final numMatch = RegExp(r'^(\d+)[\.\)]\s+(.*)$').firstMatch(t);
      if (numMatch != null) {
        blocks.add(
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: getProportionateScreenHeight(2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: getProportionateScreenWidth(18),
                  height: getProportionateScreenWidth(18),
                  margin: EdgeInsets.only(top: getProportionateScreenHeight(1)),
                  decoration: BoxDecoration(
                    color: kSecondaryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    numMatch.group(1)!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: getProportionateScreenWidth(9.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(8)),
                Expanded(child: _buildRichSpan(numMatch.group(2)!)),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet list
      if (t.startsWith('* ') || t.startsWith('- ') || t.startsWith('• ')) {
        final item = t.replaceFirst(RegExp(r'^[\*\-\•]\s*'), '');
        blocks.add(
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: getProportionateScreenHeight(2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(
                    top: getProportionateScreenHeight(6),
                    left: getProportionateScreenWidth(3),
                    right: getProportionateScreenWidth(8),
                  ),
                  width: getProportionateScreenWidth(5),
                  height: getProportionateScreenWidth(5),
                  decoration: BoxDecoration(
                    color: kSecondaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: _buildRichSpan(item)),
              ],
            ),
          ),
        );
        continue;
      }

      // Normal paragraph
      blocks.add(
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: getProportionateScreenHeight(1),
          ),
          child: _buildRichSpan(t),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  Widget _buildRichSpan(String text) {
    final base = TextStyle(
      color: kBlackColor,
      fontSize: getProportionateScreenWidth(13.5),
      height: 1.5,
    );
    final spans = <InlineSpan>[];
    final tokenRe = RegExp(r'(\*\*(.+?)\*\*|`([^`]+)`)', dotAll: true);
    int last = 0;

    for (final m in tokenRe.allMatches(text)) {
      if (m.start > last) {
        spans.addAll(
          _inlineEntities(_strip(text.substring(last, m.start)), base),
        );
      }
      final raw = m.group(0)!;
      if (raw.startsWith('**')) {
        spans.add(
          TextSpan(
            text: raw.substring(2, raw.length - 2),
            style: base.copyWith(
              fontWeight: FontWeight.w700,
              color: kBlackColor,
            ),
          ),
        );
      } else {
        final code = raw.substring(1, raw.length - 1);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: kSecondaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: getProportionateScreenWidth(11),
                  fontWeight: FontWeight.w600,
                  color: kSecondaryColor,
                ),
              ),
            ),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.addAll(_inlineEntities(_strip(text.substring(last)), base));
    }
    return Text.rich(TextSpan(children: spans));
  }

  String _strip(String t) => t.replaceAll('*', '');

  List<InlineSpan> _inlineEntities(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(
      r'(ETB\s*\d+(?:\.\d{2})?|\d+\s*(?:Birr|birr|ETB|Br)|(?:\+251|09)\s*[\d\s\-]{7,12}|https?://[^\s]+)',
      caseSensitive: false,
    );
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      final e = m.group(0)!;
      if (RegExp(r'(ETB|Birr|Br)', caseSensitive: false).hasMatch(e)) {
        spans.add(_priceSpan(e, base));
      } else if (RegExp(r'(\+251|09)').hasMatch(e)) {
        spans.add(_phoneSpan(e, base));
      } else if (e.startsWith('http')) {
        spans.add(_urlSpan(e, base));
      } else {
        spans.add(TextSpan(text: e, style: base));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return spans;
  }

  // Price tag — green tint (kept neutral, matches real-world price context)
  InlineSpan _priceSpan(String text, TextStyle base) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: kGreenColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: kGreenColor.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            HeroiconsSolid.tag,
            size: getProportionateScreenWidth(10),
            color: kGreenColor,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: base.copyWith(
              fontSize: getProportionateScreenWidth(11),
              fontWeight: FontWeight.w700,
              color: kGreenColor,
            ),
          ),
        ],
      ),
    ),
  );

  InlineSpan _phoneSpan(String text, TextStyle base) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: GestureDetector(
      onTap: () => _handlePhoneCall(text),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kSecondaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: kSecondaryColor.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HeroiconsSolid.phone,
              size: getProportionateScreenWidth(10),
              color: kSecondaryColor,
            ),
            const SizedBox(width: 3),
            Text(
              text,
              style: base.copyWith(
                fontSize: getProportionateScreenWidth(11),
                fontWeight: FontWeight.w700,
                color: kSecondaryColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  InlineSpan _urlSpan(String text, TextStyle base) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: GestureDetector(
      onTap: () => _handleUrl(text),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: kGreyColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HeroiconsOutline.arrowTopRightOnSquare,
              size: getProportionateScreenWidth(11),
              color: kSecondaryColor,
            ),
            const SizedBox(width: 3),
            Text(
              'Open Link',
              style: base.copyWith(
                fontSize: getProportionateScreenWidth(11),
                fontWeight: FontWeight.w600,
                color: kSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _formatTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(ts);
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd, HH:mm').format(ts);
  }
}
