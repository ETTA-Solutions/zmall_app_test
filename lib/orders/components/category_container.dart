import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class CategoryContainer extends StatelessWidget {
  const CategoryContainer({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          width: 2,
          color: kWhiteColor,
          // kBlackColor.withValues(alpha: 0.1),
        ),
        // color: kPrimaryColor,
        borderRadius: BorderRadius.circular(
          getProportionateScreenWidth(kDefaultPadding / 2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          getProportionateScreenWidth(kDefaultPadding / 2.5),
        ),
        child: Text(
          title,
          style: TextStyle(color: kBlackColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
