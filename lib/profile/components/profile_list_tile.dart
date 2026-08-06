import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class ProfileListTile extends StatelessWidget {
  const ProfileListTile({
    super.key,
    this.subtitle,
    this.titleColor,
    this.borderColor,
    required this.icon,
    required this.title,
    required this.onTap,
    this.showTrailing = true,
    this.trailing,
    this.margin,
  });

  final Icon icon;
  final String title;
  final Widget? subtitle;
  final Color? titleColor;
  final Color? borderColor;
  final bool showTrailing;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 0,
        horizontal: getProportionateScreenHeight(kDefaultPadding / 8),
      ),
      margin: margin,
      decoration: BoxDecoration(
        color: titleColor != null
            ? titleColor!.withValues(alpha: 0.1)
            : kPrimaryColor,
        border: Border.all(
          color: titleColor != null
              ? titleColor!.withValues(alpha: 0.1)
              : borderColor ?? kWhiteColor,
        ),
        borderRadius: BorderRadius.circular(kDefaultPadding),
      ),
      child: ListTile(
        subtitle: subtitle,
        leading: IconTheme(
          data: IconThemeData(
            size: 22,
            color: titleColor ?? kBlackColor,
            //  kSecondaryColor
          ),
          child: icon,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: titleColor ?? kBlackColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        tileColor: kPrimaryColor,
        // trailing: showTrailing
        //     ? Icon(
        //         size: 18,
        //         HeroiconsSolid.chevronRight,
        //         color: titleColor ?? kBlackColor)
        //     : null,
        trailing:
            trailing ??
            (showTrailing
                ? Icon(
                    size: 18,
                    HeroiconsSolid.chevronRight,
                    color: titleColor ?? kBlackColor,
                  )
                : null),
        onTap: onTap,
        leadingAndTrailingTextStyle: TextStyle(fontSize: 10),
      ),
    );
  }
}

class NewProfileListTile extends StatelessWidget {
  const NewProfileListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.titleColor,
    this.borderColor,
    this.trailing,
    this.margin,
    this.hasBorder = false,
    this.showTrailing = true,
    this.iconColor,
  });

  final Icon icon;
  final String title;
  final Widget? subtitle;
  final Color? titleColor;
  final Color? iconColor;
  final Color? borderColor;
  final Widget? trailing;
  final bool showTrailing;
  final bool? hasBorder;
  final EdgeInsetsGeometry? margin;
  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = titleColor ?? kBlackColor;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: titleColor != null
            ? titleColor!.withValues(alpha: .08)
            : kPrimaryColor,
        borderRadius: BorderRadius.circular(14),
        border: (hasBorder ?? true)
            ? Border.all(
                color: titleColor != null
                    ? titleColor!.withValues(alpha: .12)
                    : borderColor ?? Colors.grey.withValues(alpha: .12),
              )
            : Border.all(color: Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ListTile(
            minVerticalPadding: 0,

            // contentPadding: const EdgeInsets.symmetric(
            //   horizontal: 14,
            //   vertical: 4,
            // ),
            leading: Container(
              width: getProportionateScreenWidth(38),
              height: getProportionateScreenHeight(38),
              decoration: BoxDecoration(
                color: kWhiteColor,
                // kSecondaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: icon,
            ),

            // Container(
            //   width: 40,
            //   height: 40,
            //   decoration: BoxDecoration(
            //     color:kWhiteColor,
            //     shape: BoxShape.circle,
            //     // borderRadius: BorderRadius.circular(10),
            //   ),
            //   child: IconTheme(
            //     data: IconThemeData(
            //       size: 20,
            //       color: iconColor ?? kBlackColor,
            //     ),
            //     child: icon,
            //   ),
            // ),
            title: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),

            subtitle: subtitle,

            trailing:
                trailing ??
                (showTrailing
                    ? Icon(
                        HeroiconsSolid.chevronRight,
                        size: 16,
                        color: Colors.grey.shade500,
                      )
                    : null),
          ),
        ),
      ),
    );
  }
}
