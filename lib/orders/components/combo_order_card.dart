import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/orders/models/combo_order_entry.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

// ---------------------------------------------------------------------------
// ComboOrderCard (§13.2)
// ---------------------------------------------------------------------------
// Card widget for a two-store combo order in active orders and order history.
// Shows dual store images, combined store names, both order numbers,
// derived combo status, and combined total price.
// ---------------------------------------------------------------------------

class ComboOrderCard extends StatelessWidget {
  const ComboOrderCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.isHistory = false,
  });

  final OrderEntry entry;
  final VoidCallback onTap;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<ZMetaData>(context, listen: false).currency;
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final statusInfo = getComboStatus(entry.comboOrders);
    final images = entry.storeImages;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kDefaultPadding),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: kPrimaryColor,
          border: Border.all(color: kWhiteColor),
          borderRadius: BorderRadius.circular(kDefaultPadding),
        ),
        padding: EdgeInsets.symmetric(
          vertical: getProportionateScreenHeight(kDefaultPadding / 2),
          horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dual store overlapping images
            _buildStoreImages(baseUrl, images),
            SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 1.5)),
            // Middle info column
            Expanded(
              flex: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store names + Combo tag
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.combinedStoreName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: kBlackColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(left: 4),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kSecondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "2 Stores",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kSecondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 6)),
                  // Order numbers
                  Text(
                    entry.orderNumbersLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: kGreyColor,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 6)),
                  // Date
                  Text(
                    isHistory ? entry.formattedHistoryDate : entry.formattedDate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kGreyColor,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 6)),
                  // Status
                  Text(
                    statusInfo.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusInfo.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            // Price column
            Text(
              "$currency ${entry.totalPrice.toStringAsFixed(2)}",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: kBlackColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreImages(String baseUrl, List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: getProportionateScreenHeight(kDefaultPadding * 2.8),
        width: getProportionateScreenWidth(kDefaultPadding * 2.8),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(HeroiconsOutline.buildingStorefront, color: kGreyColor),
      );
    }

    if (images.length == 1) {
      return Container(
        height: getProportionateScreenHeight(kDefaultPadding * 2.8),
        width: getProportionateScreenWidth(kDefaultPadding * 2.8),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: NetworkImage("$baseUrl/${images[0]}"),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Overlapping two store images
    final size = getProportionateScreenWidth(kDefaultPadding * 2.2);
    return SizedBox(
      height: getProportionateScreenHeight(kDefaultPadding * 2.8),
      width: getProportionateScreenWidth(kDefaultPadding * 3.4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                color: kWhiteColor,
                shape: BoxShape.circle,
                border: Border.all(color: kPrimaryColor, width: 2),
                image: DecorationImage(
                  image: NetworkImage("$baseUrl/${images[0]}"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            left: getProportionateScreenWidth(kDefaultPadding * 1.2),
            bottom: 0,
            child: Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                color: kWhiteColor,
                shape: BoxShape.circle,
                border: Border.all(color: kPrimaryColor, width: 2),
                image: DecorationImage(
                  image: NetworkImage("$baseUrl/${images[1]}"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
