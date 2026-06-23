import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/custom_tag.dart';

class TeamContainer extends StatelessWidget {
  const TeamContainer({
    super.key,
    required this.teamName,
    required this.gameType,
  });

  final String teamName;
  // Added: needed to distinguish between World Cup (nation/) and club (pl_logos/) logos
  final String gameType;

  // Routes to nation/ folder for World Cup, pl_logos/ for club games
  String get _logoPath {
    final code = teamName.trim(); // trim any trailing/leading spaces from API data
    if (gameType.toLowerCase().contains('world')) {
      return "images/pl_logos/nation/${code.toUpperCase()}.png"; // e.g. nation/GER.png
    }
    return "images/pl_logos/${code.toLowerCase()}.png"; // e.g. pl_logos/che.png
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: getProportionateScreenHeight(kDefaultPadding * 3),
            width: getProportionateScreenWidth(kDefaultPadding * 3),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_logoPath),
                fit: BoxFit.fill,
              ),
              shape: BoxShape.rectangle,
              color: kPrimaryColor.withValues(alpha: 0.6),
              borderRadius:
                  BorderRadius.circular(getProportionateScreenHeight(5)),
            ),
          ),
          SizedBox(
            height: getProportionateScreenHeight(kDefaultPadding / 2),
          ),
          CustomTag(
            color: Colors.transparent,
            text: teamName.toUpperCase(),
          ),
        ],
      ),
    );
  }
}
