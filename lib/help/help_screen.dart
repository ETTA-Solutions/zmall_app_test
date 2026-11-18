import 'package:flutter/material.dart';
import 'package:iconsx_plus/iconsx_plus.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/help/components/help_action_cards.dart';
import 'package:zmall/services/url_launcher_service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/profile/components/profile_list_tile.dart';
// import 'package:zmall/help/support_chat/support_chat_screen.dart';
import 'package:zmall/utils/size_config.dart';

class HelpScreen extends StatelessWidget {
  static String routeName = '/help';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: Text("Help & Support")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            getProportionateScreenHeight(kDefaultPadding),
          ),
          child: Column(
            spacing: getProportionateScreenHeight(kDefaultPadding),
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(kDefaultPadding),
                  vertical: getProportionateScreenHeight(kDefaultPadding),
                ),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  border: Border.all(color: kWhiteColor),
                  borderRadius: BorderRadius.circular(kDefaultPadding),
                ),
                child: Column(
                  spacing: kDefaultPadding / 4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Support",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        HelpActionCards(
                          onTap: () async {
                            await UrlLauncherService.makePhoneCall(
                              '+251967575757',
                            );
                          },
                          title: "Call Now",
                          iconColor: kGreenColor,
                          icon: HeroiconsSolid.phone,
                        ),
                        HelpActionCards(
                          onTap: () async {
                            await UrlLauncherService.openEmail(
                              "info@zmallshop.com",
                            );
                          },
                          title: "E-Mail",
                          iconColor: Colors.redAccent,
                          icon: HeroiconsSolid.envelope,
                        ),
                        HelpActionCards(
                          onTap: () async {
                            await UrlLauncherService.makePhoneCall('+2518707');
                          },
                          icon: Icons.support_agent_rounded,
                          title: "HOTLINE",
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(kDefaultPadding),
                  vertical: getProportionateScreenHeight(kDefaultPadding),
                ),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  border: Border.all(color: kWhiteColor),
                  borderRadius: BorderRadius.circular(kDefaultPadding),
                ),
                child: Column(
                  spacing: getProportionateScreenHeight(kDefaultPadding),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Social Media",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      // spacing: getProportionateScreenWidth(kDefaultPadding / 4),
                      children: [
                        //Instagram
                        HelpActionCards(
                          icon: FontAwesome.instagram_brand,
                          iconColor: Colors.redAccent,
                          title: "Instagram",
                          onTap: () async {
                            UrlLauncherService.openUrl(
                              await "https://www.instagram.com/zmall_delivery/?hl=en",
                            );
                          },
                        ),

                        //YouTube
                        // HelpActionCards(
                        //   icon: FontAwesome.youtube,
                        //   iconColor: Colors.redAccent,
                        //   title: "YouTube",
                        //   onTap: () {
                        //     Service.launchInWebViewOrVC(
                        //       "https://www.youtube.com/@zoorya_et",
                        //     );
                        //   },
                        // ),https://www.zmalldelivery.com
                        //Tiktok
                        HelpActionCards(
                          icon: FontAwesome.tiktok_brand,
                          iconColor: kBlackColor,
                          title: "Tiktok",
                          onTap: () async {
                            await UrlLauncherService.openUrl(
                              "https://www.tiktok.com/@zmall_delivery",
                            );
                          },
                        ),
                        //Facebook
                        HelpActionCards(
                          icon: FontAwesome.facebook_f_brand,
                          iconColor: Colors.blue,
                          title: "Facebook",
                          onTap: () async {
                            await UrlLauncherService.openUrl(
                              "https://www.facebook.com/Zmallshop/",
                            );
                          },
                        ),
                      ],
                    ),

                    //
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      // spacing: getProportionateScreenWidth(kDefaultPadding / 4),
                      children: [
                        //LinkedIn
                        HelpActionCards(
                          icon: FontAwesome.linkedin_brand,
                          iconColor: Colors.blue,
                          title: "LinkedIn",
                          onTap: () async {
                            await UrlLauncherService.openUrl(
                              "https://www.linkedin.com/company/zmall/",
                            );
                          },
                        ),
                        //X
                        //Follow us on
                        HelpActionCards(
                          icon: FontAwesome.x_twitter_brand,
                          iconColor: kBlackColor,
                          title: "X",
                          onTap: () async {
                            await UrlLauncherService.openUrl(
                              "https://x.com/Zmall_Delivery",
                            );
                          },
                        ),
                        //Website
                        HelpActionCards(
                          icon: HeroiconsOutline.globeAlt,
                          iconColor: Colors.blue,
                          title: "Website",
                          onTap: () async {
                            await UrlLauncherService.openInAppWebView(
                              "https://zmall.et/",
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ProfileListTile(
              //   icon: Icon(
              //     HeroiconsOutline.questionMarkCircle,
              //     color: kBlackColor,
              //   ),
              //   title: "FAQ",
              //   onTap: () {
              //     Navigator.pushNamed(context, FAQScreen.routeName);
              //   },
              // ),

              NewProfileListTile(
                hasBorder: true,
                icon: Icon(
                  // Icons.lock,
                  HeroiconsOutline.shieldCheck,
                  color: kBlackColor,
                ),
                title: "Privacy Policy",
                onTap: () async {
                  await UrlLauncherService.openInAppWebView(
                    "https://app.zmall.et/privacy.html",
                  );
                },
              ),
              NewProfileListTile(
                hasBorder: true,
                icon: Icon(
                  HeroiconsOutline.clipboardDocumentCheck,
                  // Icons.assignment,
                  color: kBlackColor,
                ),
                title: "Terms and Conditions",
                onTap: () async {
                  await UrlLauncherService.openInAppWebView(
                    "https://app.zmall.et/terms.html",
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
