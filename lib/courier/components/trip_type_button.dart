import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class TripTypeButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const TripTypeButton({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            vertical: getProportionateScreenHeight(kDefaultPadding * 0.85),
          ),
          decoration: BoxDecoration(
            color: isSelected ? kSecondaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(
              getProportionateScreenWidth(kDefaultPadding),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: getProportionateScreenWidth(18),
                color: isSelected
                    ? kWhiteColor
                    : kGreyColor.withValues(alpha: 0.7),
              ),
              SizedBox(width: getProportionateScreenWidth(8)),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? kWhiteColor
                      : kGreyColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: getProportionateScreenHeight(14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
