// widgets/product_item_card.dart
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/store/components/image_container.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class ProductItemCard extends StatelessWidget {
  final dynamic item;
  final bool isOpen;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const ProductItemCard({
    super.key,
    required this.item,
    required this.isOpen,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.circular(kDefaultPadding),
      ),
      padding: EdgeInsets.symmetric(
        vertical: getProportionateScreenHeight(kDefaultPadding / 4),
        horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Image
            item['image_url'] != null && item['image_url'].length > 0
                ? ImageContainer(
                    url: "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${item['image_url'][0]}",
                  )
                : ImageContainer(url: "https://ibb.co/vkhzjd6"),

            SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Service.capitalizeFirstLetters(item['name'] ?? ''),
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(kDefaultPadding * .9),
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                    softWrap: true,
                  ),
                  if (item['details'] != null && item['details'].toString().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: getProportionateScreenHeight(kDefaultPadding / 5),
                      ),
                      child: Text(
                        item['details'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: kGreyColor,
                            ),
                      ),
                    ),
                  SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 5)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${Service.getPrice(item).isNotEmpty ? Service.getPrice(item) : 0} ${Provider.of<ZMetaData>(context, listen: false).currency}",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: kBlackColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      // Add button
                      GestureDetector(
                        onTap: onAddTap,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: kDefaultPadding / 2,
                            vertical: kDefaultPadding / 3,
                          ),
                          child: Row(
                            children: [
                              Icon(size: 14, HeroiconsOutline.plus, color: kSecondaryColor),
                              SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 4)),
                              Text("Add", style: TextStyle(fontSize: 14, color: kSecondaryColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}