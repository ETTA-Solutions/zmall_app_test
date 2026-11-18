import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// "Perfect Pairing for Your Order!" strip fed by `combo_recommendations`.
/// Each card is an item from a nearby complementary store; tapping Add starts
/// a combo with that store as the second store (handled by [onAdd]).
class ComboPairingStrip extends StatelessWidget {
  const ComboPairingStrip({
    super.key,
    required this.recommendations,
    required this.baseUrl,
    required this.currency,
    required this.onAdd,
    this.busyItemId,
    this.title = 'Perfect Pairing for Your Order!',
  });

  final List<Map<String, dynamic>> recommendations;
  final String baseUrl;
  final String currency;
  final void Function(Map<String, dynamic> rec) onAdd;

  /// item_id currently being added (shows a spinner, blocks double taps).
  final String? busyItemId;

  /// Heading above the strip.
  final String title;

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();
    final imgSize = getProportionateScreenWidth(kDefaultPadding * 3);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: getProportionateScreenHeight(kDefaultPadding / 2),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: kBlackColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.12,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
              vertical: getProportionateScreenHeight(kDefaultPadding / 2),
            ),
            separatorBuilder: (_, __) =>
                SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              final id = '${rec['item_id']}';
              final busy = busyItemId == id;
              final image = '${rec['image'] ?? ''}';
              final price = (rec['price'] as num?)?.toDouble() ?? 0.0;
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kWhiteColor),
                  borderRadius: BorderRadius.circular(kDefaultPadding),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
                  vertical: getProportionateScreenHeight(kDefaultPadding / 3),
                ),
                child: Row(
                  spacing: getProportionateScreenHeight(kDefaultPadding / 3),
                  children: [
                    CachedNetworkImage(
                      imageUrl: image.isEmpty ? '' : '$baseUrl/$image',
                      imageBuilder: (_, provider) => Container(
                        width: imgSize,
                        height: imgSize,
                        decoration: BoxDecoration(
                          color: kWhiteColor,
                          borderRadius: BorderRadius.circular(
                            getProportionateScreenHeight(kDefaultPadding),
                          ),
                          image: DecorationImage(
                            fit: BoxFit.contain,
                            image: provider,
                          ),
                        ),
                      ),
                      placeholder: (_, __) => SizedBox(
                        width: imgSize,
                        height: imgSize,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => SizedBox(
                        width: imgSize,
                        height: imgSize,
                        child: Icon(
                          HeroiconsOutline.photo,
                          color: kGreyColor,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: getProportionateScreenWidth(
                          kDefaultPadding * 8,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rec['name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(
                                kDefaultPadding * 0.9,
                              ),
                              color: kBlackColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${price.toStringAsFixed(2)} $currency'
                            '${(rec['store_name'] ?? '').toString().isEmpty ? '' : ' · ${rec['store_name']}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: kGreyColor),
                          ),
                          GestureDetector(
                            onTap: busyItemId != null ? null : () => onAdd(rec),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: getProportionateScreenWidth(
                                  kDefaultPadding / 4,
                                ),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      spacing: getProportionateScreenWidth(
                                        kDefaultPadding / 3,
                                      ),
                                      children: [
                                        Icon(
                                          HeroiconsOutline.plus,
                                          size: 20,
                                          color: kSecondaryColor,
                                        ),
                                        Text(
                                          'Add',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontSize: 14,
                                                color: kSecondaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
