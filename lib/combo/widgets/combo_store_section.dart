import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/combo/models/combo_cart.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/notifications/notification_store.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/store/components/image_container.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/order_status_row.dart';

/// Cart section for the second store of a combo order.
///
/// Edits [comboCart] in place, then calls [onChanged] so the parent can save
/// it and update totals.
class ComboStoreSection extends StatelessWidget {
  const ComboStoreSection({
    super.key,
    required this.comboCart,
    required this.storeName,
    required this.onChanged,
    this.onReturnFromStore,
  });

  final ComboCart comboCart;
  final String storeName;
  final VoidCallback onChanged;
  final VoidCallback? onReturnFromStore;

  @override
  Widget build(BuildContext context) {
    final items = comboCart.second.items ?? [];
    final currency = Provider.of<ZMetaData>(context, listen: false).currency;
    final subtotal = items.fold<double>(0, (sum, i) => sum + (i.price ?? 0));

    return Padding(
      padding: EdgeInsets.only(
        top: getProportionateScreenHeight(kDefaultPadding / 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: getProportionateScreenHeight(kDefaultPadding / 3),
        children: [
          Container(
            padding: EdgeInsets.all(
              getProportionateScreenWidth(kDefaultPadding / 2),
            ),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(kDefaultPadding),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OrderStatusRow(
                    title: "Second store · same delivery",
                    iconBackgroundColor: kPrimaryColor,
                    icon: HeroiconsOutline.buildingStorefront,
                    fontSize: getProportionateScreenHeight(14),
                    value: storeName.isNotEmpty
                        ? Service.capitalizeFirstLetters(storeName)
                        : "Store 2",
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        kDefaultPadding / 1.5,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationStore(
                          storeId: comboCart.second.storeId!,
                        ),
                      ),
                    ).then((_) => onReturnFromStore?.call());
                  },
                  child: Text(
                    "Add more?",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          for (int index = 0; index < items.length; index++)
            _itemRow(context, index, currency),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
              ),
              child: Text(
                "Subtotal: $currency ${subtotal.toStringAsFixed(2)}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kGreyColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, int index, String? currency) {
    final item = comboCart.second.items![index];
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
        vertical: getProportionateScreenHeight(kDefaultPadding / 4),
      ),
      decoration: BoxDecoration(
        color: kPrimaryColor,
        border: Border.all(color: kWhiteColor, width: 2),
        borderRadius: BorderRadius.circular(kDefaultPadding),
      ),
      child: Row(
        children: [
          ImageContainer(url: item.imageURL),
          SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: getProportionateScreenHeight(kDefaultPadding / 5),
              children: [
                Text(
                  Service.capitalizeFirstLetters(item.itemName ?? ""),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                  softWrap: true,
                ),
                Text(
                  "$currency ${(item.price ?? 0).toStringAsFixed(2)}",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: kGreyColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.noteForItem.isNotEmpty) Text(item.noteForItem),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: item.quantity != 1 ? kSecondaryColor : kGreyColor,
                    ),
                    onPressed: () {
                      if (item.quantity == 1) {
                        Service.showMessage(
                          context: context,
                          title: "Minimum order quantity is 1!",
                          error: true,
                        );
                        return;
                      }
                      _setQuantity(index, item.quantity! - 1);
                    },
                  ),
                  Text(
                    "${item.quantity}",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: kBlackColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: kSecondaryColor),
                    onPressed: () => _setQuantity(index, item.quantity! + 1),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  comboCart.second.items!.removeAt(index);
                  onChanged();
                },
                child: Text(
                  Provider.of<ZLanguage>(context).remove,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 12,
                    color: kSecondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setQuantity(int index, int quantity) {
    final item = comboCart.second.items![index];
    final unitPrice = item.price! / item.quantity!;
    item.quantity = quantity;
    item.price = unitPrice * quantity;
    onChanged();
  }
}
