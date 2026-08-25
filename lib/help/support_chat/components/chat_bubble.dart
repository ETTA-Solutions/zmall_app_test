import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zmall/help/support_chat/components/food_recommendation_card.dart';
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

  /// Matched food products for this message (shown as cards when non-empty)
  final List<MockProduct> matchedProducts;

  const ChatBubble({
    super.key,
    required this.message,
    this.imageUrl,
    this.onLongPress,
    this.onViewCart,
    this.onProductTap,
    this.onAddToCart,
    this.matchedProducts = const [],
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isCopied = false;
  int _feedbackState = 0; // 0: none, 1: thumbs up, -1: thumbs down

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.message.message));
    setState(() {
      _isCopied = true;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              HeroiconsSolid.checkCircle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              "Copied to clipboard",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1F2937),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  void _handleFeedback(int feedback) {
    setState(() {
      _feedbackState = _feedbackState == feedback ? 0 : feedback;
    });

    if (_feedbackState != 0) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            feedback == 1
                ? "Thanks for your positive feedback! 👍"
                : "Thanks for your feedback, we'll keep improving! ✍️",
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          backgroundColor: const Color(0xFF1F2937),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handlePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.82;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(kDefaultPadding / 3.5),
      ),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: isUser ? widget.onLongPress : null,
                    child: isUser
                        ? _buildUserBubble()
                        : _buildBotBubble(context),
                  ),
                  if (!isUser && widget.matchedProducts.isNotEmpty) ...[
                    SizedBox(height: getProportionateScreenHeight(12)),
                    FoodRecommendationRow(
                      products: widget.matchedProducts,
                      onViewCart: widget.onViewCart,
                      onProductTap: widget.onProductTap,
                      onAddToCart: widget.onAddToCart,
                    ),
                  ] else if (!isUser && widget.message.showCartAction) ...[
                    SizedBox(height: getProportionateScreenHeight(12)),
                    _buildCartActionButton(),
                  ],
                  if (isUser) ...[
                    SizedBox(height: getProportionateScreenHeight(4)),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(widget.message.timestamp),
                            style: TextStyle(
                              color: kGreyColor.withValues(alpha: 0.7),
                              fontSize: getProportionateScreenWidth(10),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: getProportionateScreenWidth(4)),
                          Icon(
                            HeroiconsSolid.checkCircle,
                            size: getProportionateScreenWidth(11),
                            color: kSecondaryColor.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: getProportionateScreenWidth(8)),
            _buildAvatar(isBot: false),
          ],
        ],
      ),
    );
  }

  Widget _buildBotBubble(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(22),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(22),
            ),
            border: Border.all(
              color: kSecondaryColor.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: kSecondaryColor.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              getProportionateScreenWidth(14),
              getProportionateScreenHeight(12),
              getProportionateScreenWidth(14),
              getProportionateScreenHeight(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFormattedContent(widget.message.message),
                SizedBox(height: getProportionateScreenHeight(10)),
                _buildBotFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotFooter(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: getProportionateScreenHeight(6)),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: kSecondaryColor.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  HeroiconsOutline.clock,
                  size: getProportionateScreenWidth(11),
                  color: kGreyColor.withValues(alpha: 0.7),
                ),
                SizedBox(width: getProportionateScreenWidth(3.5)),
                Flexible(
                  child: Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      color: kGreyColor.withValues(alpha: 0.7),
                      fontSize: getProportionateScreenWidth(10),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _copyToClipboard(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    _isCopied
                        ? HeroiconsSolid.check
                        : HeroiconsOutline.clipboardDocument,
                    size: getProportionateScreenWidth(14),
                    color: _isCopied ? kGreenColor : kGreyColor,
                  ),
                ),
              ),
              SizedBox(width: getProportionateScreenWidth(4)),
              InkWell(
                onTap: () => _handleFeedback(1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    _feedbackState == 1
                        ? HeroiconsSolid.handThumbUp
                        : HeroiconsOutline.handThumbUp,
                    size: getProportionateScreenWidth(14),
                    color: _feedbackState == 1 ? kGreenColor : kGreyColor,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _handleFeedback(-1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    _feedbackState == -1
                        ? HeroiconsSolid.handThumbDown
                        : HeroiconsOutline.handThumbDown,
                    size: getProportionateScreenWidth(14),
                    color: _feedbackState == -1 ? kSecondaryColor : kGreyColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Parses text into structured blocks: Headings, Bullet Lists, Numbered Lists,
  /// Quotes/Tips, and Paragraphs with formatted inline tokens.
  Widget _buildFormattedContent(String text) {
    final lines = text.split('\n');
    final blockWidgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        // Space between paragraphs
        if (blockWidgets.isNotEmpty && i < lines.length - 1) {
          blockWidgets.add(SizedBox(height: getProportionateScreenHeight(6)));
        }
        continue;
      }

      final trimmed = line.trim();

      // Heading block (e.g. ### Header or ## Header or # Header)
      if (trimmed.startsWith('#')) {
        final headingText = _stripStrayAsterisks(
          trimmed.replaceAll(RegExp(r'^#+\s*'), ''),
        );
        blockWidgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: getProportionateScreenHeight(4),
              bottom: getProportionateScreenHeight(4),
            ),
            child: Row(
              children: [
                Container(
                  width: getProportionateScreenWidth(3),
                  height: getProportionateScreenHeight(14),
                  decoration: BoxDecoration(
                    color: kSecondaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(6)),
                Expanded(
                  child: Text(
                    headingText,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(13.5),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Quote / Callout block (e.g. > Note: ...)
      if (trimmed.startsWith('>')) {
        final quoteText = trimmed.replaceFirst(RegExp(r'^>\s*'), '');
        blockWidgets.add(
          Container(
            margin: EdgeInsets.symmetric(
              vertical: getProportionateScreenHeight(4),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(10),
              vertical: getProportionateScreenHeight(8),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: kSecondaryColor, width: 3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  HeroiconsOutline.informationCircle,
                  size: getProportionateScreenWidth(16),
                  color: kSecondaryColor,
                ),
                SizedBox(width: getProportionateScreenWidth(8)),
                Expanded(child: _buildRichTextSpan(quoteText, isQuote: true)),
              ],
            ),
          ),
        );
        continue;
      }

      // Numbered List block (e.g. 1. Item or 2) Item)
      final numMatch = RegExp(r'^(\d+)[\.\)]\s+(.*)$').firstMatch(trimmed);
      if (numMatch != null) {
        final number = numMatch.group(1)!;
        final itemText = numMatch.group(2)!;
        blockWidgets.add(
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: getProportionateScreenHeight(3),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: getProportionateScreenWidth(19),
                  height: getProportionateScreenWidth(19),
                  margin: EdgeInsets.only(top: getProportionateScreenHeight(1)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kSecondaryColor,
                        kSecondaryColor.withValues(alpha: 0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: getProportionateScreenWidth(10),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(8)),
                Expanded(child: _buildRichTextSpan(itemText)),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet List block (e.g. * item, - item, • item)
      if (trimmed.startsWith('* ') ||
          trimmed.startsWith('- ') ||
          trimmed.startsWith('• ')) {
        final itemText = trimmed.replaceFirst(RegExp(r'^[\*\-\•]\s*'), '');
        blockWidgets.add(
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: getProportionateScreenHeight(2.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(
                    top: getProportionateScreenHeight(6),
                    left: getProportionateScreenWidth(4),
                    right: getProportionateScreenWidth(8),
                  ),
                  width: getProportionateScreenWidth(6),
                  height: getProportionateScreenWidth(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kSecondaryColor, const Color(0xFFF97316)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.3),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildRichTextSpan(itemText)),
              ],
            ),
          ),
        );
        continue;
      }

      // Regular Paragraph line
      blockWidgets.add(
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: getProportionateScreenHeight(1.5),
          ),
          child: _buildRichTextSpan(trimmed),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blockWidgets,
    );
  }

  /// Parses inline markdown, prices, phone numbers, and links into rich spans
  Widget _buildRichTextSpan(String text, {bool isQuote = false}) {
    final baseStyle = TextStyle(
      color: isQuote ? const Color(0xFF334155) : const Color(0xFF1E293B),
      fontSize: getProportionateScreenWidth(12.5),
      height: 1.55,
      letterSpacing: 0.1,
    );

    final spans = <InlineSpan>[];

    // Regex pattern for bold tokens `**...**` and code tokens `` `...` ``
    final tokenPattern = RegExp(r'(\*\*(.+?)\*\*|`([^`]+)`)', dotAll: true);
    int lastEnd = 0;

    for (final match in tokenPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        final plain = _stripStrayAsterisks(
          text.substring(lastEnd, match.start),
        );
        spans.addAll(_parseInlineEntities(plain, baseStyle));
      }

      final raw = match.group(0)!;
      if (raw.startsWith('**') && raw.endsWith('**')) {
        final boldContent = raw.substring(2, raw.length - 2);
        spans.add(
          TextSpan(
            text: boldContent,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        );
      } else if (raw.startsWith('`') && raw.endsWith('`')) {
        final codeContent = raw.substring(1, raw.length - 1);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                codeContent,
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

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = _stripStrayAsterisks(text.substring(lastEnd));
      spans.addAll(_parseInlineEntities(remaining, baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }

  /// Removes any leftover markdown asterisks (e.g. unmatched `*` or `**`)
  /// so they never show up as literal characters in the chat.
  String _stripStrayAsterisks(String text) {
    return text.replaceAll('*', '');
  }

  /// Parses prices (e.g. ETB 150), phones (e.g. +251 96 757 5757), and links
  List<InlineSpan> _parseInlineEntities(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];

    // Detect ETB prices, phone numbers, and URLs
    final pattern = RegExp(
      r'(ETB\s*\d+(?:\.\d{2})?|\d+\s*(?:Birr|birr|ETB|Br)|(?:\+251|09)\s*[\d\s\-]{7,12}|https?://[^\s]+)',
      caseSensitive: false,
    );

    int lastIndex = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final entity = match.group(0)!;

      // Price Tag Highlight
      if (RegExp(r'(ETB|Birr|Br)', caseSensitive: false).hasMatch(entity)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    HeroiconsSolid.tag,
                    size: getProportionateScreenWidth(10),
                    color: const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    entity,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(11),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      // Phone Number Tap-to-Call
      else if (RegExp(r'(\+251|09)').hasMatch(entity)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              onTap: () => _handlePhoneCall(entity),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF93C5FD),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      HeroiconsSolid.phone,
                      size: getProportionateScreenWidth(10),
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      entity,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D4ED8),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      // URL Tap-to-Open
      else if (entity.startsWith('http')) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              onTap: () => _handleUrl(entity),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
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
                      "Open Link",
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11),
                        fontWeight: FontWeight.w600,
                        color: kSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: entity, style: baseStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }

  Widget _buildUserBubble() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(16),
        vertical: getProportionateScreenHeight(12),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kSecondaryColor,
            kSecondaryColor.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(6),
        ),
        boxShadow: [
          BoxShadow(
            color: kSecondaryColor.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        widget.message.message,
        style: TextStyle(
          color: kPrimaryColor,
          fontSize: getProportionateScreenWidth(13.5),
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildCartActionButton() {
    return InkWell(
      onTap: widget.onViewCart,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(kDefaultPadding / 1.1),
          vertical: getProportionateScreenHeight(kDefaultPadding / 2.2),
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.38),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                HeroiconsSolid.shoppingCart,
                color: Colors.white,
                size: getProportionateScreenWidth(15),
              ),
            ),
            SizedBox(width: getProportionateScreenWidth(8)),
            Text(
              "View Cart & Checkout",
              style: TextStyle(
                color: Colors.white,
                fontSize: getProportionateScreenWidth(12.5),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(width: getProportionateScreenWidth(4)),
            Icon(
              HeroiconsSolid.chevronRight,
              color: Colors.white.withValues(alpha: 0.9),
              size: getProportionateScreenWidth(14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({required bool isBot}) {
    return Container(
      width: getProportionateScreenWidth(32),
      height: getProportionateScreenWidth(32),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: kGreyColor.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
          ? ClipOval(child: ImageContainer(url: widget.imageUrl))
          : Icon(
              Icons.person,
              color: kGreyColor,
              size: getProportionateScreenWidth(18),
            ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, HH:mm').format(timestamp);
    }
  }
}
