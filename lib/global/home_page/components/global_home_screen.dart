import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fl_location/fl_location.dart';
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/home/magazine/screens/magazine_list_screen.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/services/app_update_service.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/global/aliexpress/global_ali_product_screen.dart';
import 'package:zmall/global/items/global_items.dart';
import 'package:zmall/global/stores/global_stores.dart';
import 'package:zmall/home/components/custom_banner.dart';
import 'package:zmall/home/components/offer_card.dart';
import 'package:zmall/main.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/widgets/section_title.dart';

class GlobalHomeScreen extends StatefulWidget {
  // const GlobalHomeScreen({
  //   // required this.user,
  // });

  // final User user;

  @override
  _GlobalHomeScreenState createState() => _GlobalHomeScreenState();
}

class _GlobalHomeScreenState extends State<GlobalHomeScreen> {
  User? user;
  AbroadData? abroadData;
  String username = "";
  String email = "";
  String city = "";

  bool _loading = false;
  var categoriesResponse;
  late double latitude, longitude;
  var responseData;
  var categories;
  var promotionalItems;
  List<bool> isPromotionalItemOpen = [];

  Map<String, dynamic>? magazineService;
  bool hasMagazine = false;
  LocationPermission _permissionStatus = LocationPermission.denied;

  void _requestLocationPermission() async {
    _permissionStatus = await FlLocation.checkLocationPermission();
    if (_permissionStatus == LocationPermission.always ||
        _permissionStatus == LocationPermission.whileInUse) {
      // Location permission granted, continue with location-related tasks
      getLocation();
    } else {
      // Handle permission denial
      Service.showMessage(
        context: context,
        title: "Location permission denied. Please enable and try again",
        error: true,
      );
      FlLocation.requestLocationPermission();
    }
  }

  void getLocation() async {
    var currentLocation = await FlLocation.getLocation();
    if (mounted) {
      setState(() {
        latitude = currentLocation.latitude;
        longitude = currentLocation.longitude;
      });
      Provider.of<ZMetaData>(
        context,
        listen: false,
      ).setLocation(currentLocation.latitude, currentLocation.longitude);
    }
  }

  void _doLocationTask() async {
    LocationPermission _permissionStatus =
        await FlLocation.checkLocationPermission();
    if (_permissionStatus == LocationPermission.whileInUse ||
        _permissionStatus == LocationPermission.always) {
      if (await FlLocation.isLocationServicesEnabled) {
        getLocation();
      } else {
        LocationPermission serviceStatus =
            await FlLocation.requestLocationPermission();
        if (serviceStatus == LocationPermission.always ||
            serviceStatus == LocationPermission.whileInUse) {
          getLocation();
        } else {
          Service.showMessage(
            context: context,
            title: "Location service disabled. Please enable and try again",
            error: true,
          );
        }
      }
    } else {
      _requestLocationPermission();
    }
  }

  @override
  void initState() {
    super.initState();
    CoreServices.registerNotification(context);
    MyApp.messaging.triggerEvent("at_home");
    FirebaseMessaging.instance.subscribeToTopic("abroad");
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // debugPrint("Opened by notification");
      MyApp.analytics.logEvent(name: "notification_open");
    });
    getAbroadUser();
    _doLocationTask();
    _getPromotionalItems();
    checkAbroad();
  }

  Future<dynamic> getCategoryList(
    double longitude,
    double latitude,
    String countryCode,
    String countryName,
  ) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_delivery_list_for_nearest_city";

    //
    Map data = {
      "latitude": latitude,
      "longitude": longitude,
      "country": countryName,
      "country_code": countryCode,
      "isGlobal": true,
    };
    var body = json.encode(data);
    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      // debugPrint("RES ${json.decode(response.body)}");
      await Service.save('categories', json.decode(response.body));
      return json.decode(response.body);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Connection timeout! Please check your internet connection!",
          ),
          backgroundColor: kSecondaryColor,
        ),
      );
      return null;
    }
  }

  void checkAbroad() async {
    setState(() {
      _loading = true;
    });
    _getAppKeys();
    var data = await getCategoryList(
      38.768154,
      9.004188,
      "5b3f76f2022985030cd3a437",
      "Ethiopia",
    );
    if (data != null && data['success']) {
      if (mounted) {
        setState(() {
          categories = data['deliveries'];
          responseData = data;
          Service.save('categories', categories);
        });
      }
      // debugPrint("categories $categories");
      _checkMagazineService();
    }
    setState(() {
      _loading = false;
    });
  }

  void _getPromotionalItems() async {
    setState(() {
      _loading = true;
    });
    try {
      // Ensure app metadata is loaded before checking store status
      _getAppKeys();
      isPromotionalItemOpen.clear();

      var data = await CoreServices.getPromotionalItems(
        isGlobal: true,
        userId: "",
        serverToken: "",
        ctx: context,
        userLocation: [
          Provider.of<ZMetaData>(context, listen: false).latitude,
          Provider.of<ZMetaData>(context, listen: false).longitude,
        ],
      );

      if (data != null && data['success']) {
        // debugPrint("Fetched promotional Items....");
        if (mounted) {
          // debugPrint(data);
          Service.save('p_items', data);
          setState(() {
            promotionalItems = data;
          });
        }
      } else {
        // Fetch failed or success: false, try loading from cache
        await getLocalPromotionalItems();
      }
      // only proceed to check store status if promotional items were fetched
      if (promotionalItems != null &&
          promotionalItems['promotional_items'] != null) {
        var items = promotionalItems['promotional_items'];
        // Re-clear to be safe before refilling
        isPromotionalItemOpen.clear();

        for (int i = 0; i < promotionalItems['promotional_items'].length; i++) {
          bool isPromoItOpen = await Service.isStoreOpen(items[i]);
          isPromotionalItemOpen.add(isPromoItOpen);
        }
      } else {
        // Initialize empty list if no items found to prevent
        promotionalItems = {"success": false, "promotional_items": []};
      }
    } catch (e) {
      // TODO
      //On crash, try cache as last re-sort
      // debugPrint("Error fetching promotional items: $e");
      await getLocalPromotionalItems();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  ///=======================================
  /// PROMOTIONAL ITEMS - STORE OPEN CHECKER
  /// * This function checks if each store associated with the promotional items
  /// * is currently open and updates the isPromotionalItemOpen list accordingly.
  /// * This ensures that only promotional items from open stores are displayed
  /// * to the user.
  ///=======================================
  Future<void> _checkStoresOpen() async {
    isPromotionalItemOpen.clear();
    if (promotionalItems != null &&
        promotionalItems['promotional_items'] != null) {
      for (var item in promotionalItems['promotional_items']) {
        bool isOpen = await Service.isStoreOpen(item);
        isPromotionalItemOpen.add(isOpen);
      }
    }
  }

  Future<void> getLocalPromotionalItems() async {
    try {
      var data = await Service.read('p_items');
      if (data != null && data is Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            promotionalItems = data;
            // _loading = false; //? logic moved to finally block
          });
          await _checkStoresOpen();
        }
      }
    } catch (e) {
      // TODO
      //ignore
      // debugPrint("Error loading cached promotional items: $e");
    }
  }

  // void getUser() async {
  //   var data = await Service.read('abroad_user');

  //   getAbroadUser();
  // }

  void getAbroadUser() async {
    var data = await Service.read('abroad_user');
    if (data != null) {
      abroadData = AbroadData.fromJson(data);
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
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (val) {
                    email = val;
                  },
                  decoration: textFieldInputDecorator.copyWith(
                    labelText: email.isNotEmpty ? email : "Email",
                  ),
                ),
                // Container(
                //   height: getProportionateScreenHeight(kDefaultPadding),
                // ),
                // TextField(
                //   style: TextStyle(color: kBlackColor),
                //   keyboardType: TextInputType.text,
                //   onChanged: (val) {
                //     city = val;
                //   },
                //   decoration: textFieldInputDecorator?.copyWith(
                //       labelText: city.isNotEmpty ? city : "City"),
                // ),
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
                      abroadPhone: user!.phoneNumber,
                    );
                    setState(() {
                      abroadData = abroadUser;
                    });
                    await Service.save('abroad_user', abroadData!.toJson());
                    Navigator.of(context).pop();
                    // bool success =
                    //     await FirebaseCoreServices.addDataToUserProfile(
                    //         user.uid,
                    //         {
                    //           "full_name": username,
                    //           "email": email,
                    //           "city": city,
                    //         },
                    //         isUpdate: true);
                    // if (success) {
                    //   Navigator.of(context).pop();
                    //   ScaffoldMessenger.of(context).showSnackBar(
                    //       Service.showMessage(
                    //           "User data successfully updated", false));
                    // } else {
                    //   ScaffoldMessenger.of(context).showSnackBar(
                    //       Service.showMessage(
                    //           "Something went wrong, data wasn't saved", true));
                    // }
                  } else {
                    // Navigator.of(context).pop();

                    Service.showMessage(
                      context: context,
                      title: "Please add the necessary information",
                      error: true,
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _getAppKeys() async {
    await AppUpdateService.fetchAndCheck(
      context,
      onMessageFlag: (message) {
        if (mounted) {
          Service.showMessage(
            context: context,
            title: "$message We deliver your order once we resume our service.",
            error: false,
            duration: 4,
          );
        }
      },
    );
  }

  // Tag checking logic
  bool _shouldHideServiceOnGlobal(Map<String, dynamic> service) {
    final tags = service['famous_products_tags'] as List?;
    if (tags == null || tags.isEmpty) return false;

    // Tags to hid Global Zmall
    final hiddenTags = [
      // Recap tags
      'recap',
      'wrapped',
      'yearly_recap',
      // Confetti/Celebration tags
      'new year',
      'confetti',
      'festival',
      'celebration',
      'new year celebration',
      // Magazine tags
      'magazine',
      // Holiday splash tags
      'holiday_splash',
      'holiday',
      'splash',

      // Order near you
      'near_you',
      'orders near you',
    ];

    return tags.any((tag) => hiddenTags.contains(tag.toString().toLowerCase()));
  }

  void _checkMagazineService() {
    if (categories == null || categories.isEmpty) {
      setState(() {
        hasMagazine = false;
        magazineService = null;
      });

      return;
    }

    // debugPrint(' [Magazine Check] Scanning ${categories.length} categories for magazine service...');

    for (var category in categories) {
      final tags = category['famous_products_tags'] as List?;
      bool isMagazine =
          tags?.any(
            (tag) =>
                tag.toString().toLowerCase() == 'magazine' ||
                tag.toString().toLowerCase().contains('magazine'),
          ) ??
          false;
      // debugPrint(' [Magazine Check] Checking category: ${category['delivery_name']} with tags: $tags');
      if (isMagazine) {
        // debugPrint(' [Magazine Found] ========================');
        // debugPrint(' Name: ${category['delivery_name']}');
        // debugPrint('==========================================');
        setState(() {
          hasMagazine = true;
          magazineService = Map<String, dynamic>.from(category);
        });
        return;
      }
    }

    // debugPrint(' [Magazine Check] No magazine service found in categories.');
    setState(() {
      hasMagazine = false;
      magazineService = null;
    });
  }

  /// MAGAZINE NAVIGATION HANDLER
  void _openMagazineScreen() async {
    // Check if global user is registered
    if (abroadData == null) {
      Service.showMessage(
        context: context,
        title: "Please complete registration to access magazines",
        error: true,
      );
      getAbroadUser();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MagazineListScreen(
          title: magazineService!['delivery_name'] ?? "Z-Magazine",
          isGlobalUser: true,
          globalUserName: abroadData!.abroadName,
          globalUserEmail: abroadData!.abroadEmail,

          userData: null,
          userId: abroadData!.abroadEmail,
          serverToken: null,
        ),
      ),
    ).then((value) {
      checkAbroad();
    });
  }

  ///////////New Features
  Future<void> _onRefresh() async {
    CoreServices.registerNotification(context);
    MyApp.messaging.triggerEvent("at_home");
    FirebaseMessaging.instance.subscribeToTopic("abroad");
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // debugPrint("Opened by notification");
      MyApp.analytics.logEvent(name: "notification_open");
    });
    getAbroadUser();
    _doLocationTask();
    _getPromotionalItems();
  }

  int getServiceIndex(String serviceName) {
    if (categories == null) {
      return -1;
    }
    int index = categories.indexWhere(
      (service) =>
          service['delivery_name']?.toString().toLowerCase() ==
          serviceName.toLowerCase(),
    );
    return index;
  }

  bool isNetworkImage(String serviceName) {
    if (categories == null) {
      return false;
    }
    bool isNetwork =
        getServiceIndex(serviceName) != -1 &&
        categories[getServiceIndex(serviceName)]['image_url']
            .toString()
            .isNotEmpty;
    return isNetwork;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: kPrimaryColor,
        backgroundColor: kSecondaryColor,
        onRefresh: _onRefresh,
        child: ModalProgressHUD(
          inAsyncCall: _loading,
          color: kPrimaryColor,
          progressIndicator: LinearLoadingIndicator(),
          child: categories != null
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===================== MODERN HEADER =====================
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A1A2E),
                              Color(0xFF16213E),
                              Color(0xFF0F3460),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              getProportionateScreenWidth(20),
                              getProportionateScreenHeight(12),
                              getProportionateScreenWidth(20),
                              getProportionateScreenHeight(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top: Logo
                                Row(
                                  children: [
                                    Text(
                                      "Z",
                                      style: TextStyle(
                                        color: kSecondaryColor,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    Text(
                                      "Mall",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kSecondaryColor.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: kSecondaryColor.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        "GLOBAL",
                                        style: TextStyle(
                                          color: kSecondaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(
                                  height: getProportionateScreenHeight(20),
                                ),

                                // Profile + Welcome (meaningful section)
                                Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            kSecondaryColor,
                                            kSecondaryColor.withValues(
                                              alpha: 0.75,
                                            ),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: kSecondaryColor.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          abroadData?.abroadName?.isNotEmpty ==
                                                  true
                                              ? abroadData!.abroadName![0]
                                                    .toUpperCase()
                                              : "G",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 14),

                                    // Welcome texts
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            abroadData != null
                                                ? "Welcome back"
                                                : "Welcome to ZMall",
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.65,
                                              ),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            abroadData != null
                                                ? abroadData!.abroadName!
                                                : "Global Shopping",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.4,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // ===================== PROMOTIONAL ITEMS =====================
                      if (promotionalItems != null &&
                          promotionalItems['success'] == true &&
                          promotionalItems['promotional_items'] != null &&
                          promotionalItems['promotional_items'].isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                getProportionateScreenWidth(kDefaultPadding),
                                getProportionateScreenHeight(
                                  kDefaultPadding * 1.2,
                                ),
                                getProportionateScreenWidth(kDefaultPadding),
                                getProportionateScreenHeight(
                                  kDefaultPadding * 0.6,
                                ),
                              ),
                              child: SectionTitle(
                                sectionTitle: "Specials for your loved ones",
                                subTitle: " ",
                              ),
                            ),
                            SizedBox(
                              height: getProportionateScreenHeight(
                                kDefaultPadding * 11,
                              ),
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(
                                  horizontal: getProportionateScreenWidth(
                                    kDefaultPadding,
                                  ),
                                ),
                                itemCount: isPromotionalItemOpen.length,
                                separatorBuilder: (_, __) => SizedBox(
                                  width: getProportionateScreenWidth(
                                    kDefaultPadding * 0.7,
                                  ),
                                ),
                                itemBuilder: (context, index) {
                                  final item =
                                      promotionalItems['promotional_items'][index];
                                  return Container(
                                    width: getProportionateScreenWidth(135),

                                    decoration: BoxDecoration(
                                      color: kPrimaryColor,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.07,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: SpecialOfferCard(
                                      isOpen: isPromotionalItemOpen[index],
                                      imageUrl:
                                          item['image_url'] != null &&
                                              item['image_url'].isNotEmpty
                                          ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${item['image_url'][0]}"
                                          : "www.google.com",
                                      itemName: "${item['name']}\n",
                                      newPrice:
                                          "${item['price'].toStringAsFixed(2)}\t",
                                      originalPrice:
                                          "${item['new_price'].toStringAsFixed(2)}",
                                      isDiscounted: item['discount'],
                                      storeName: item['store_name'],
                                      specialOffer: item['special_offer'],
                                      storePress: () {},
                                      press: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => GlobalItem(
                                              item: item,
                                              location: item['store_location'],
                                              isOpen: true,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                      SizedBox(
                        height: getProportionateScreenHeight(
                          kDefaultPadding * 0.8,
                        ),
                      ),

                      // ===================== ALIEXPRESS BANNER =====================
                      if (categories != null &&
                          categories.any(
                            (d) =>
                                d['delivery_name']?.toString().toLowerCase() ==
                                'aliexpress',
                          ))
                        _buildPremiumBanner(
                          context: context,
                          title: "AliExpress",
                          imageUrl: isNetworkImage("aliexpress")
                              ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${categories[getServiceIndex("aliexpress")]['image_url']}"
                              : "images/aliexpress-banner.png",
                          isNetwork: isNetworkImage("aliexpress"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GlobalAliProductListScreen(),
                              ),
                            ).then((_) {
                              if (abroadData != null) {
                                checkAbroad();
                                _getPromotionalItems();
                              }
                            });
                          },
                        ),

                      // ===================== MAGAZINE BANNER =====================
                      if (hasMagazine && magazineService != null)
                        _buildPremiumBanner(
                          context: context,
                          title:
                              magazineService!['delivery_name'] ?? 'Z-Magazine',
                          imageUrl:
                              magazineService!['image_url'] != null &&
                                  magazineService!['image_url']
                                      .toString()
                                      .isNotEmpty
                              ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${magazineService!['image_url']}"
                              : "images/zmagazine-banner.png",
                          isNetwork:
                              magazineService!['image_url'] != null &&
                              magazineService!['image_url']
                                  .toString()
                                  .isNotEmpty,
                          onTap: _openMagazineScreen,
                        ),

                      // ===================== CATEGORIES GRID =====================
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          getProportionateScreenWidth(kDefaultPadding),
                          getProportionateScreenHeight(kDefaultPadding * 0.8),
                          getProportionateScreenWidth(kDefaultPadding),
                          getProportionateScreenHeight(kDefaultPadding * 0.4),
                        ),
                        child: SectionTitle(
                          sectionTitle: "What would you like to order?",
                          subTitle: " ",
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: getProportionateScreenWidth(
                            kDefaultPadding,
                          ),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount:
                              categories
                                  ?.where(
                                    (d) =>
                                        d['delivery_name']
                                                ?.toString()
                                                .toLowerCase() !=
                                            'aliexpress' &&
                                        !_shouldHideServiceOnGlobal(d),
                                  )
                                  .length ??
                              0,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                // ← corrected
                                crossAxisCount: 3,
                                crossAxisSpacing: 10, // was 14
                                mainAxisSpacing: 10, // was 14
                                childAspectRatio: 1.08, // ← try this
                              ),
                          itemBuilder: (context, index) {
                            final filtered = categories!
                                .where(
                                  (d) =>
                                      d['delivery_name']
                                              ?.toString()
                                              .toLowerCase() !=
                                          'aliexpress' &&
                                      !_shouldHideServiceOnGlobal(d),
                                )
                                .toList();

                            final category = filtered[index];

                            // Safe values
                            final String deliveryName =
                                category['delivery_name']?.toString() ??
                                'Unknown';
                            final String imagePath =
                                category['image_url']?.toString() ?? '';
                            final String imageUrl = imagePath.isNotEmpty
                                ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/$imagePath"
                                : '';

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GlobalStore(
                                      cityId: responseData['city']['_id'],
                                      storeDeliveryId: category['_id'],
                                      category: category,
                                      latitude: latitude,
                                      longitude: longitude,
                                      isStore: false,
                                      companyId: null,
                                    ),
                                  ),
                                ).then((_) {
                                  checkAbroad();
                                  _getPromotionalItems();
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kPrimaryColor,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.12),
                                  ),
                                ),
                                padding: EdgeInsets.all(
                                  getProportionateScreenWidth(
                                    kDefaultPadding * 0.6,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              imageBuilder:
                                                  (
                                                    context,
                                                    imageProvider,
                                                  ) => Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      image: DecorationImage(
                                                        image: imageProvider,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                              placeholder: (_, __) => const Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                        kWhiteColor,
                                                      ),
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      image: const DecorationImage(
                                                        image: AssetImage(
                                                          'images/zmall_sm.png',
                                                        ),
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                image: const DecorationImage(
                                                  image: AssetImage(
                                                    'images/zmall_sm.png',
                                                  ),
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                    ),
                                    SizedBox(
                                      height: getProportionateScreenHeight(2),
                                    ),
                                    Text(
                                      Service.capitalizeFirstLetters(
                                        deliveryName,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: kBlackColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(
                        height: getProportionateScreenHeight(
                          kDefaultPadding * 2,
                        ),
                      ),
                    ],
                  ),
                )
              : _loading
              ? const SizedBox()
              : Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionateScreenWidth(
                        kDefaultPadding * 3,
                      ),
                    ),
                    child: CustomButton(
                      title: "Retry",
                      press: checkAbroad,
                      color: kSecondaryColor,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _headerIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _buildPremiumBanner({
    required BuildContext context,
    required String title,
    required String imageUrl,
    required bool isNetwork,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(kDefaultPadding * 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: getProportionateScreenHeight(kDefaultPadding * 0.45),
            ),
            child: SectionTitle(sectionTitle: title, subTitle: " "),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomBanner(
                  isNetworkImage: isNetwork,
                  imageUrl: imageUrl,
                  title: title,
                  subtitle: "",
                  press: onTap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
