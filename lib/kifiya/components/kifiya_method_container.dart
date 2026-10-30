import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';

class KifiyaMethodContainer extends StatelessWidget {
  const KifiyaMethodContainer({
    super.key,
    required this.selected,
    required this.title,
    required this.kifiyaMethod,
    required this.imagePath,
    required this.press,
    this.isSoon = false,
  });

  final bool selected;
  final int kifiyaMethod;
  final String title;
  final String imagePath;
  final GestureTapCallback press;
  final bool isSoon;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      // alignment: Alignment.center,
      width: getProportionateScreenWidth(100),
      height: getProportionateScreenWidth(100),
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding / 4),
        vertical: getProportionateScreenHeight(kDefaultPadding / 4),
      ),

      decoration: BoxDecoration(
        color: kPrimaryColor,
        border: Border.all(
          width: 2,
          color: selected ? kSecondaryColor : kWhiteColor,
        ),
        borderRadius: BorderRadius.circular(
          getProportionateScreenWidth(kDefaultPadding),
        ),
      ),
      child: InkWell(
        onTap: press,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: getProportionateScreenHeight(kDefaultFontSize / 2),
            children: [
              Container(
                width: getProportionateScreenWidth(70),
                height: getProportionateScreenWidth(60),
                decoration: BoxDecoration(
                  // color: kWhiteColor,
                  color: Color(0xFF667EEA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Image.asset(
                    fit: BoxFit.contain,
                    imagePath.isNotEmpty
                        ? imagePath
                        : 'images/payment/default_payment.png',
                    width: getProportionateScreenWidth(40),
                    height: getProportionateScreenWidth(40),
                  ),
                ),
              ),
              Text(
                title.toLowerCase().contains("tele birr")
                    ? "USSD"
                    : title.toLowerCase().contains("telebirr reference")
                    ? "Reference"
                    : title.toLowerCase().contains("telebirr inapp") ||
                        title.toLowerCase().contains("telebirr in app") ||
                        title.toLowerCase().contains("telebirr in-app")
                    ? "InApp"
                    : Service.capitalizeFirstLetters(title),
                textAlign: TextAlign.center,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  color: kBlackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!isSoon) return card;

    return Opacity(
      opacity: 0.65,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kSecondaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Soon",
                style: TextStyle(
                  color: kPrimaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
