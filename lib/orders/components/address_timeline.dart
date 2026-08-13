import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/orders/components/order_detail.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class AddressTimelineNode extends StatelessWidget {
  final String title;
  final String address;
  final bool isPickup;
  final bool isLast;

  const AddressTimelineNode({
    super.key,
    required this.title,
    required this.address,
    required this.isPickup,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            SizedBox(
              width: getProportionateScreenWidth(16),
              height: getProportionateScreenHeight(16),
              child: Icon(
                HeroiconsOutline.mapPin,
                color: kSecondaryColor,
                size: getProportionateScreenHeight(kDefaultPadding),
              ),
            ),

            if (!isLast)
              CustomPaint(
                size: Size(2, getProportionateScreenHeight(40)),
                painter: DashedLinePainter(),
              ),
          ],
        ),

        SizedBox(width: getProportionateScreenWidth(kDefaultPadding)),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: getProportionateScreenHeight(12),
                  fontWeight: FontWeight.bold,
                  color: kGreyColor,
                ),
              ),

              SizedBox(height: getProportionateScreenHeight(4)),

              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: getProportionateScreenHeight(14),
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),

              if (!isLast) SizedBox(height: getProportionateScreenHeight(20)),
            ],
          ),
        ),
      ],
    );
  }
}
