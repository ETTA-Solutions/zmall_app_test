import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
    required this.hasItems,
    this.noMoreText = "No more products",
  });

  final bool isLoadingMore;
  final bool hasMore;
  final bool hasItems;
  final String noMoreText;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: kDefaultPadding),
        child: Center(
          child: SpinKitWave(
            color: kSecondaryColor,
            size: getProportionateScreenWidth(kDefaultPadding),
          ),
        ),
      );
    }

    // if (!hasMore && hasItems) {
    //   return Padding(
    //     padding: EdgeInsets.symmetric(
    //       vertical: getProportionateScreenHeight(kDefaultPadding),
    //     ),
    //     child: Center(
    //       child: Text(
    //         noMoreText,
    //         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    //           color: Colors.grey,
    //           fontWeight: FontWeight.w500,
    //         ),
    //       ),
    //     ),
    //   );
    // }

    return const SizedBox.shrink();
  }
}
