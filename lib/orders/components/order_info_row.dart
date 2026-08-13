import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class OrderInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;
  final bool moreText;

  const OrderInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
    this.moreText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: getProportionateScreenWidth(34),
            height: getProportionateScreenHeight(34),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: getProportionateScreenHeight(18),
              color: kSecondaryColor,
            ),
          ),
          SizedBox(width: getProportionateScreenWidth(12)),
        ],

        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: getProportionateScreenHeight(13),
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // SizedBox(width: getProportionateScreenWidth(kDefaultPadding/4)),


        Flexible(
          child: Text(
            value,
            textAlign:moreText?TextAlign.left: TextAlign.right,
            overflow: moreText ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: getProportionateScreenHeight(14),
              color: highlight ? kPrimaryColor : Colors.black87,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
