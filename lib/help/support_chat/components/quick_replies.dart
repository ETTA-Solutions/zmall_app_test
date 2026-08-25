import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class QuickReplies extends StatelessWidget {
  final Function(String) onReplyTap;

  const QuickReplies({super.key, required this.onReplyTap});

  static final List<QuickReply> replies = [
    QuickReply(text: "Show me pizza", icon: HeroiconsOutline.fire),
    QuickReply(text: "Show me burgers", icon: HeroiconsOutline.fire),
    QuickReply(text: "Show me coffee", icon: HeroiconsOutline.cake),
    QuickReply(text: "Where is my order?", icon: HeroiconsOutline.mapPin),
    QuickReply(
      text: "Show me my last order",
      icon: HeroiconsOutline.shoppingBag,
    ),
    QuickReply(
      text: "What is my order status",
      icon: HeroiconsOutline.clipboardDocumentCheck,
    ),
    QuickReply(
      text: "What are today's special offers?",
      icon: HeroiconsOutline.sparkles,
    ),
    QuickReply(
      text: "Show me restaurants near me",
      icon: HeroiconsOutline.buildingStorefront,
    ),
    QuickReply(
      text: "Show me top selling stores this week",
      icon: HeroiconsOutline.fire,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: getProportionateScreenWidth(kDefaultPadding),
        right: getProportionateScreenWidth(kDefaultPadding),
        top: getProportionateScreenHeight(kDefaultPadding / 3),
        bottom: getProportionateScreenHeight(kDefaultPadding / 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kSecondaryColor.withValues(alpha: 0.15),
                      kSecondaryColor.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  HeroiconsSolid.sparkles,
                  color: kSecondaryColor,
                  size: getProportionateScreenWidth(13),
                ),
              ),
              SizedBox(width: getProportionateScreenWidth(6)),
              Text(
                "Suggested Questions",
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(12),
                  fontWeight: FontWeight.w700,
                  color: kBlackColor.withValues(alpha: 0.75),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          SizedBox(height: getProportionateScreenHeight(8)),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: getProportionateScreenHeight(110),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Wrap(
                spacing: getProportionateScreenWidth(8),
                runSpacing: getProportionateScreenHeight(8),
                children: replies
                    .map(
                      (reply) => _QuickReplyChip(
                        reply: reply,
                        onTap: () => onReplyTap(reply.text),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final QuickReply reply;
  final VoidCallback onTap;

  const _QuickReplyChip({required this.reply, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(12),
            vertical: getProportionateScreenHeight(8),
          ),
          decoration: BoxDecoration(
            color: kPrimaryColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: kSecondaryColor.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: kSecondaryColor.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: getProportionateScreenWidth(20),
                height: getProportionateScreenWidth(20),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  reply.icon,
                  size: getProportionateScreenWidth(12),
                  color: kSecondaryColor,
                ),
              ),
              SizedBox(width: getProportionateScreenWidth(6)),
              Text(
                reply.text,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(11.5),
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickReply {
  final String text;
  final IconData icon;

  QuickReply({required this.text, required this.icon});
}
