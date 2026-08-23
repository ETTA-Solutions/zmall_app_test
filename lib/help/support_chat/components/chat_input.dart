import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final VoidCallback? onQuickRepliesToggle;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
    this.onQuickRepliesToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(kDefaultPadding / 1.5),
        getProportionateScreenHeight(kDefaultPadding / 2),
        getProportionateScreenWidth(kDefaultPadding / 1.5),
        getProportionateScreenHeight(kDefaultPadding / 2),
      ),
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.all(getProportionateScreenWidth(6)),
          decoration: BoxDecoration(
            color: kPrimaryColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kBlackColor.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: kBlackColor.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Quick Replies Button
              if (onQuickRepliesToggle != null)
                GestureDetector(
                  onTap: onQuickRepliesToggle,
                  child: Container(
                    width: getProportionateScreenWidth(42),
                    height: getProportionateScreenWidth(42),
                    decoration: BoxDecoration(
                      color: kSecondaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      HeroiconsOutline.sparkles,
                      color: kSecondaryColor,
                      size: getProportionateScreenWidth(19),
                    ),
                  ),
                ),
              if (onQuickRepliesToggle != null)
                SizedBox(width: getProportionateScreenWidth(6)),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: "Type your message...",
                    hintStyle: TextStyle(
                      color: kGreyColor.withValues(alpha: 0.6),
                      fontSize: getProportionateScreenWidth(13),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: getProportionateScreenWidth(kDefaultPadding),
                      vertical: getProportionateScreenHeight(
                        kDefaultPadding / 1.5,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(14),
                    color: kBlackColor,
                  ),
                ),
              ),
              SizedBox(width: getProportionateScreenWidth(6)),
              GestureDetector(
                onTap: isLoading ? null : _handleSend,
                child: Container(
                  width: getProportionateScreenWidth(42),
                  height: getProportionateScreenWidth(42),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kSecondaryColor,
                        kSecondaryColor.withValues(alpha: 0.85),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: isLoading
                      ? Padding(
                          padding: EdgeInsets.all(
                            getProportionateScreenWidth(kDefaultPadding / 1.5),
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              kPrimaryColor,
                            ),
                          ),
                        )
                      : Icon(
                          HeroiconsSolid.paperAirplane,
                          color: kPrimaryColor,
                          size: getProportionateScreenWidth(20),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSend() {
    if (controller.text.trim().isNotEmpty && !isLoading) {
      onSend();
    }
  }
}
