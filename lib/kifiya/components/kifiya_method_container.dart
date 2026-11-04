import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
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
                  child: _buildMethodIcon(context),
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

  Widget _buildMethodIcon(BuildContext context) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.contain,
        width: getProportionateScreenWidth(40),
        height: getProportionateScreenWidth(40),
        errorBuilder: (_, __, ___) => _buildFallbackAsset(),
      );
    }
    if (imagePath.startsWith('web_images/')) {
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        return Image.network(
          '$baseUrl/$imagePath',
          fit: BoxFit.contain,
          width: getProportionateScreenWidth(40),
          height: getProportionateScreenWidth(40),
          errorBuilder: (_, __, ___) => _buildFallbackAsset(),
        );
      } catch (_) {
        return _buildFallbackAsset();
      }
    }
    return _buildFallbackAsset();
  }

  Widget _buildFallbackAsset() {
    final lower = imagePath.toLowerCase();
    String fallback = 'images/payment/default_payment.png';
    if (lower.contains('telebirr')) {
      fallback = 'images/payment/new_payment/telebirr.png';
    } else if (lower.contains('mpesa')) {
      fallback = 'images/payment/new_payment/mpesa.png';
    } else if (lower.contains('nib')) {
      fallback = 'images/payment/new_payment/nib_bank.png';
    } else if (lower.contains('zemen')) {
      fallback = 'images/payment/new_payment/zemen.png';
    } else if (lower.contains('ethswitch')) {
      fallback = 'images/payment/new_payment/ethswitch.png';
    } else if (lower.contains('dashen')) {
      fallback = 'images/payment/dashen.png';
    }

    return Image.asset(
      imagePath.isNotEmpty &&
              !imagePath.startsWith('web_images/') &&
              !imagePath.startsWith('http')
          ? imagePath
          : fallback,
      fit: BoxFit.contain,
      width: getProportionateScreenWidth(40),
      height: getProportionateScreenWidth(40),
      errorBuilder: (_, __, ___) => Image.asset(
        'images/payment/default_payment.png',
        fit: BoxFit.contain,
        width: getProportionateScreenWidth(40),
        height: getProportionateScreenWidth(40),
      ),
    );
  }
}
