import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:provider/provider.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/global/order/global_order.dart';
import 'package:zmall/help/help_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/profile/components/profile_list_tile.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/store/components/image_container.dart';

class GlobalProfile extends StatefulWidget {
  @override
  State<GlobalProfile> createState() => _GlobalProfileState();
}

class _GlobalProfileState extends State<GlobalProfile> {
  AbroadData? abroadData;
  String username = "";
  String email = "";
  late User user;
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    getAbroadUser();
  }

  void getAbroadUser() async {
    var data = await Service.read('abroad_user');
    if (data != null) {
      setState(() {
        abroadData = AbroadData.fromJson(data);
      });
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: kPrimaryColor,
            title: Text("Dear Esteemed User,"),
            content: Wrap(
              children: [
                Text("Please complete registration..."),
                Container(
                  height: getProportionateScreenHeight(kDefaultPadding / 2),
                ),
                TextField(
                  style: TextStyle(color: kBlackColor),
                  keyboardType: TextInputType.text,
                  onChanged: (val) {
                    username = val;
                  },
                  decoration: textFieldInputDecorator.copyWith(
                    labelText: username.isNotEmpty ? username : "Full Name",
                  ),
                ),
                Container(
                  height: getProportionateScreenHeight(kDefaultPadding),
                ),
                TextField(
                  style: TextStyle(color: kBlackColor),
                  keyboardType: TextInputType.text,
                  onChanged: (val) {
                    email = val;
                  },
                  decoration: textFieldInputDecorator.copyWith(
                    labelText: email.isNotEmpty ? email : "Email",
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: Text(
                  "Save Now",
                  style: TextStyle(
                    color: kSecondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  if (username.isNotEmpty && email.isNotEmpty) {
                    var abroadUser = AbroadData(
                      abroadName: username,
                      abroadEmail: email,
                      abroadPhone: user.phoneNumber,
                    );
                    setState(() {
                      abroadData = abroadUser;
                    });
                    // debugPrint(abroadData!.toJson());
                    await Service.save('abroad_user', abroadData!.toJson());
                    Navigator.of(context).pop();
                    Service.showMessage(
                      context: context,
                      title: "User data successfully updated",
                      error: false,
                    );
                  } else {
                    // Navigator.of(context).pop();
                    Service.showMessage(
                      context: context,
                      title: "Please add the necessary information",
                      error: true,
                    );
                  }
                  // Service.launchInWebViewOrVC("http://onelink.to/vnchst");
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   title: Text("Profile", style: TextStyle(color: kBlackColor)),
      //   elevation: 1.0,
      // ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: getProportionateScreenHeight(kDefaultPadding / 2),
            horizontal: getProportionateScreenHeight(kDefaultPadding),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(
                  getProportionateScreenWidth(kDefaultPadding),
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(
                    getProportionateScreenWidth(kDefaultPadding),
                  ),
                ),
                child: Column(
                  children: [
                    ImageContainer(
                      url:
                          "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/",
                    ),
                    SizedBox(
                      height: getProportionateScreenHeight(kDefaultPadding / 2),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          abroadData != null ? abroadData!.abroadName! : "",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        abroadData != null && abroadData!.abroadPhone != null
                            ? Icon(
                                HeroiconsSolid.checkBadge,
                                color: kSecondaryColor,
                                size: getProportionateScreenWidth(
                                  kDefaultPadding,
                                ),
                              )
                            : Container(),
                      ],
                    ),
                    Text(
                      abroadData != null
                          ? abroadData!.abroadPhone.toString()
                          : "",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      abroadData != null ? abroadData!.abroadEmail! : "",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    // TextButton(
                    //   onPressed: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) => EditProfile(
                    //           userData: userData,
                    //         ),
                    //       ),
                    //     ).then((value) => getUser());
                    //     debugPrint(userData['user']);
                    //   },
                    //   child: Text("Edit"),
                    // ),
                  ],
                ),
              ),

              _userActionCard(
                textTheme: Theme.of(context).textTheme,
                title: "Services",
                backgroundColor: kPrimaryColor,
                topMargin: getProportionateScreenHeight(kDefaultPadding * 2),
                children: [
                  NewProfileListTile(
                    icon: Icon(
                      HeroiconsOutline.shoppingBag,
                      color: kSecondaryColor,
                    ),
                    title: "My Orders",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return GlobalOrder();
                          },
                        ),
                      );
                    },
                  ),
                  Divider(color: kWhiteColor, height: 1),
                  NewProfileListTile(
                    icon: Icon(
                      HeroiconsOutline.questionMarkCircle,
                      color: kSecondaryColor,
                    ),
                    title: "Help",
                    onTap: () {
                      Navigator.pushNamed(context, HelpScreen.routeName);
                    },
                  ),
                ],
              ),
              _userActionCard(
                textTheme: Theme.of(context).textTheme,
                title: "Social",
                backgroundColor: kPrimaryColor,
                topMargin: getProportionateScreenHeight(kDefaultPadding / 2),
                children: [
                  NewProfileListTile(
                    icon: Icon(
                      FontAwesome.instagram_brand,
                      color: kSecondaryColor,
                    ),
                    title: "Follow us on Instagram",
                    onTap: () {
                      Service.launchInWebViewOrVC(
                        "https://www.instagram.com/zmall_delivery/?hl=en",
                      );
                    },
                  ),
                  Divider(color: kWhiteColor, height: 1),
                  NewProfileListTile(
                    icon: Icon(
                      FontAwesome.facebook_f_brand,
                      color: Colors.blue,
                    ),
                    title: "Follow us on Facebook",
                    onTap: () {
                      Service.launchInWebViewOrVC(
                        "https://www.facebook.com/Zmallshop/",
                      );
                    },
                  ),
                ],
              ),
              _userActionCard(
                textTheme: Theme.of(context).textTheme,
                title: "Danger zone",
                backgroundColor: kPrimaryColor,
                topMargin: getProportionateScreenHeight(kDefaultPadding / 1.5),
                children: [
                  NewProfileListTile(
                    icon: Icon(
                      HeroiconsOutline.arrowLeftStartOnRectangle,
                      color: kSecondaryColor,
                    ),
                    title: Provider.of<ZLanguage>(
                      context,
                      listen: false,
                    ).logout,
                    onTap: () {
                      setState(() {
                        isLoading = true;
                      });
                      _showDialog();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userActionCard({
    required String title,
    required TextTheme textTheme,
    required List<Widget> children,
    double? spacing,
    Color? backgroundColor = kPrimaryColor,
    double? topMargin,
  }) {
    return Container(
      margin:
          EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(kDefaultPadding),
            // vertical: getProportionateScreenHeight(kDefaultPadding / 4)
          ).copyWith(
            top: topMargin,
            bottom: getProportionateScreenHeight(kDefaultPadding / 1.5),
          ),
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding / 4),
        vertical: getProportionateScreenHeight(kDefaultPadding / 4),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: kWhiteColor),
        borderRadius: BorderRadius.circular(kDefaultPadding * 1.2),
      ),
      child: Column(
        spacing: spacing ?? getProportionateScreenHeight(kDefaultPadding / 2),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
        // children: [
        //   // Text(
        //   //   title,
        //   //   style: textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
        //   // ),
        //   ...children,
        // ],
      ),
    );
  }

  void _showDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kPrimaryColor,
          title: Text("Logout"),
          content: Text("Are you sure you want to logout?"),
          actions: <Widget>[
            TextButton(
              child: Text(
                "Think about it!",
                style: TextStyle(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  isLoading = false;
                });
              },
            ),
            TextButton(
              child: Text("Sure", style: TextStyle(color: kBlackColor)),
              onPressed: () async {
                Navigator.of(context).pop();
                await Service.remove("abroad_user");
                await Service.remove("abroad_cart");
                Navigator.pushReplacementNamed(context, '/global');
              },
            ),
          ],
        );
      },
    );
  }
}
