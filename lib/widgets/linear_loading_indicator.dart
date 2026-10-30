import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class LinearLoadingIndicator extends StatelessWidget {
  final String? title;
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? iconColor;
  final Color? backgroundColor;

  const LinearLoadingIndicator({
    super.key,
    this.title,
    this.width,
    this.height,
    this.fontSize,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: height ?? getProportionateScreenHeight(kDefaultPadding * 5),
        minWidth: width ?? getProportionateScreenWidth(kDefaultPadding * 5),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(kDefaultPadding),
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? kGreyColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(kDefaultPadding),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: getProportionateScreenHeight(kDefaultPadding / 2),
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              iconColor ?? kSecondaryColor,
            ),
          ),
          Text(
            title ?? "Loading...",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: kPrimaryColor,
              fontSize: fontSize ?? 14,
            ),
          ),
        ],
      ),
    );
  }
}
