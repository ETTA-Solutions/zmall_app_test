import 'package:flutter/material.dart';
import 'package:zmall/help/support_chat/components/bot_avatar.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class QuickReplies extends StatelessWidget {
  final Function(String) onReplyTap;

  const QuickReplies({super.key, required this.onReplyTap});

  static final List<String> _replies = [
    '🏪 Stores near me',
    '🍕 Show me pizza',
    '🍔 Show me burgers',
    '☕ Show me coffee',
    '📦 Where is my order?',
    '🛵 Track my delivery',
    '💳 Payment methods',
    '🔥 Special offers',
    '🍗 Chicken wings',
    '💸 Refund policy',
    '📞 Talk to support',
  ];

  static String _queryFrom(String chip) =>
      chip.replaceAll(RegExp(r'^[\p{Emoji}\s]+', unicode: true), '').trim();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: getProportionateScreenHeight(6)),
          SizedBox(
            height: getProportionateScreenHeight(36),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(16),
              ),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _replies.length,
              separatorBuilder: (_, __) =>
                  SizedBox(width: getProportionateScreenWidth(8)),
              itemBuilder: (context, i) {
                final chip = _replies[i];
                return GestureDetector(
                  onTap: () {
                    final query = _queryFrom(chip);
                    debugPrint("⚡ [QUICK REPLIES] Chip tapped: \"$chip\" -> query: \"$query\"");
                    onReplyTap(query);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionateScreenWidth(14),
                      vertical: getProportionateScreenHeight(7),
                    ),
                    decoration: BoxDecoration(
                      color: kChatSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(12.5),
                        fontWeight: FontWeight.w500,
                        color: kBlackColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(4)),
        ],
      ),
    );
  }
}

class QuickReply {
  final String text;
  final IconData icon;
  const QuickReply({required this.text, required this.icon});
}
