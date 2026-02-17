import 'dart:async';
import 'dart:convert';
import 'package:fl_location/fl_location.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/global/global.dart';
import 'package:zmall/global/home_page/global_home.dart';
import 'package:zmall/main.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:flutter/material.dart';
import 'package:zmall/utils/tab_screen.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:http/http.dart' as http;
import 'package:zmall/login/login_screen.dart';
import 'component/loader.dart';
import 'component/splash_container.dart';

class SplashScreen extends StatefulWidget {
  static String routeName = '/splash';

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool logged = false;
  late String imageUrl, urlLink, adId;
  bool loading = true;
  String _projectVersion = '';
  LocationPermission _permissionStatus = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    getLang();
    getMetaData();
    initPlatformState();
    isLogged();
    getAd();
    _doLocationTask();
    MyApp.analytics.logAppOpen();
    loader(8);
  }

  void getLang() async {
    var data = await Service.read('lang');
    // debugPrint("Checking language");
    if (mounted) {
      if (data == null) {
        Provider.of<ZLanguage>(context, listen: false).changeLanguage('en_US');
      } else {
        Provider.of<ZLanguage>(context, listen: false).changeLanguage(data);
      }
    }
  }

  void fetchAd() async {
    await getAd();
  }

  void _requestLocationPermission() async {
    _permissionStatus = await FlLocation.checkLocationPermission();
    if (_permissionStatus == LocationPermission.always ||
        _permissionStatus == LocationPermission.whileInUse) {
      // Location permission granted, continue with location-related tasks
      getLocation();
    } else {
      // Handle permission denial
      if (mounted) {
        Service.showMessage(
          context: context,
          title: "Location permission denied. Please enable and try again",
          error: true,
        );
      }
      FlLocation.requestLocationPermission();
    }
  }

  void getLocation() async {
    var currentLocation = await FlLocation.getLocation();
    // debugPrint("Checking location.....");
    if (mounted) {
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
          if (mounted) {
            Service.showMessage(
              context: context,
              title: "Location service disabled. Please enable and try again",
              error: true,
            );
          }
        }
      }
    } else {
      _requestLocationPermission();
    }
  }

  void getMetaData() async {
    String? country = await Service.read("country");

    if (mounted) {
      if (country != null) {
        Provider.of<ZMetaData>(
          context,
          listen: false,
        ).changeCountrySettings(country);
      } else {
        Provider.of<ZMetaData>(
          context,
          listen: false,
        ).changeCountrySettings("Ethiopia");
      }
    }
  }

  void _getAppKeys() async {
    var data = await getAppKeys();
    if (data != null && data['success']) {
      // debugPrint("Saving data....");
      Service.saveBool("is_closed", data['message_flag']);
      Service.save("closed_message", data['message']);
      Service.save("ios_app_version", data['ios_user_app_version_code']);
      Service.saveBool(
        "ios_update_dialog",
        data['is_ios_user_app_open_update_dialog'],
      );
      Service.saveBool(
        "ios_force_update",
        data['is_ios_user_app_force_update'],
      );
    }
  }

  initPlatformState() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String projectVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      projectVersion = packageInfo.version;
    } on PlatformException {
      projectVersion = 'Failed to get project version.';
    }

    if (!mounted) return;

    setState(() {
      _projectVersion = projectVersion;
    });
    if (_projectVersion.isNotEmpty) {
      Service.save('version', _projectVersion);
      _getAppKeys();
    }
  }

  Future<Timer> loader(int seconds) async {
    return Timer(Duration(seconds: seconds), onDoneLoading);
  }

  onDoneLoading() async {
    bool? isGlobal = await Service.readBool('is_global');
    var abroadData = await Service.read('abroad_user');
    if (mounted) {
      try {
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(
        //     builder: (context) => FirebaseAuth.instance.currentUser != null
        //         ? GlobalHome(
        //             user: FirebaseAuth.instance.currentUser,
        //           )
        //         : GlobalScreen(),
        //   ),
        // );
        isGlobal != null && isGlobal == true
            ? Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) =>
                      abroadData != null ? GlobalHome() : GlobalScreen(),
                ),
              )
            : Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) =>
                      logged ? TabScreen(isLaunched: true) : LoginScreen(),
                ),
              );
      } catch (e) {
        // debugPrint("Ad skipped...");
      }
    }
  }

  void isLogged() async {
    var data = await Service.readBool('logged');
    if (mounted) {
      if (data != null) {
        setState(() {
          logged = data;
        });
      } else {
        // debugPrint("No logged user found");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: kSecondaryColor,
      body: Center(
        child: loading
            ? Loader()
            : SplashContainer(
                urlLink: urlLink,
                imageUrl: imageUrl,
                adId: adId,
                logged: logged,
              ),
      ),
    );
  }

  Future<String> getAd() async {
    final baseUrl =
        Provider.of<ZMetaData>(context, listen: false).baseUrl;
    var url = Uri.parse("$baseUrl/admin/get_all_advertises");
    debugPrint("###[SPLASH] Fetching ads from: $url");
    try {
      http.Response response = await http
          .post(
            url,
            headers: <String, String>{
              'Device': 'ios',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      debugPrint("###[SPLASH] HTTP status: ${response.statusCode}, content-type: ${response.headers['content-type']}");
      debugPrint("###[SPLASH] Response body (first 300 chars): ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}");
      if (response.statusCode != 200) {
        debugPrint("###[SPLASH] Server returned status ${response.statusCode}");
        loader(5);
        return "failed";
      }

      dynamic data;
      try {
        data = json.decode(response.body);
      } on FormatException catch (e) {
        debugPrint("###[SPLASH] JSON parse error: $e");
        loader(5);
        return "failed";
      }

      debugPrint("###[SPLASH] API response success: ${data['success']}, ads count: ${data['advertises']?.length ?? 0}");

      if (
          data['success'] == true &&
          data['advertises'] != null &&
          data['advertises'].length > 0) {
        // Filter to only visible ads, then take the last one
        final allAds = data['advertises'] as List;
        final visibleAds = allAds
            .where((ad) => ad['is_ads_visible'] == true)
            .toList();
        debugPrint("###[SPLASH] Total ads: ${allAds.length}, Visible ads: ${visibleAds.length}");

        if (visibleAds.isEmpty) {
          debugPrint("###[SPLASH] No visible ads found");
          return "success";
        }

        final ad = visibleAds.last;
        debugPrint("###[SPLASH] Full ad keys: ${ad.keys.toList()}");
        debugPrint("###[SPLASH] image_url: ${ad['image_url']}");
        final rawImageUrl = ad['image_url']
            ?.toString() ?? '';
        final adImageUrl = rawImageUrl.startsWith('http')
            ? rawImageUrl
            : "$baseUrl/$rawImageUrl";
        debugPrint("###[SPLASH] Selected ad ID: ${ad['_id']}");
        debugPrint("###[SPLASH] Final Image URL: $adImageUrl");

        if (!mounted) return "failed";

        setState(() {
          imageUrl = adImageUrl;
          urlLink = ad['store_id'] != null
              ? 'store/${ad['store_id']}'
              : 'item/${ad['item_id']}';
          adId = ad['_id'];
          loading = !loading;
        });
        loader(3);
        debugPrint("###[SPLASH] Ad loaded successfully, showing splash container");
      } else {
        debugPrint("###[SPLASH] No ads available or API failed");
      }
      return "success";
    } catch (e) {
      debugPrint("###[SPLASH] ERROR: $e");
      loader(5);
      return "failed";
    }
  }

  //   // Mock data for testing
  //   try {
  //     final byteData = await rootBundle.load('images/zmall.jpg');
  //     if (mounted) {
  //       setState(() {
  //         bytes = byteData.buffer.asUint8List();
  //         urlLink = 'item/REPLACE_WITH_REAL_ITEM_ID';
  //         adId = 'mock_ad_001';
  //         loading = !loading;
  //       });
  //     }
  //     return "success";
  //   } catch (e) {
  //     loader(5);
  //     return "failed";
  //   }
  // }

  Future<dynamic> getAppKeys() async {
    var url = Uri.parse(
      "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/admin/get_app_keys",
    );

    try {
      http.Response response = await http
          .post(url)
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      if (json.decode(response.body) != null &&
          json.decode(response.body)['success']) {
        var data = {
          "success": json.decode(response.body)['success'],
          "message_flag": json.decode(
            response.body,
          )['app_keys']['message_flag'],
          "ios_user_app_version_code": json.decode(
            response.body,
          )['app_keys']['ios_user_app_version_code'],
          "message": json.decode(response.body)['app_keys']['message'],
          // "ios_user_app_version_code": json.decode(response.body)['app_keys']
          // ['ios_user_app_version_code'],
          "is_ios_user_app_open_update_dialog": json.decode(
            response.body,
          )['app_keys']['is_ios_user_app_open_update_dialog'],
          "is_ios_user_app_force_update": json.decode(
            response.body,
          )['app_keys']['is_ios_user_app_force_update'],
        };
        return data;
      } else {
        var data = {"success": false};
        return data;
      }
    } catch (e) {
      // debugPrint(e);
      return null;
    }
  }
}