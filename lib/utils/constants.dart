import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:encrypt/encrypt.dart' as Encrypt;
import 'package:flutter_spinkit/flutter_spinkit.dart';

// unknown
//  // const BASE_URL = "https://tele.zmallapp.com";
// Ethiopia old production
//  // const BASE_URL = "https://app.zmallapp.com"; //Eth production
//  // const BASE_URL = "http://159.65.147.111:8000"; //cloudocean server
//  // const BASE_URL_TEST = "https://test.zmallapp.com"; //old test domain

// south sudan production
const BASE_URL_JUBA = "https://juba.zmallapp.com"; //Juba Production
//  // const BASE_URL_JUBA = "http://196.189.124.241:8000"; //Juba Production
// south sudan test
//  // const BASE_URL_JUBA = "http://167.172.180.220:7000"; //test

// Ethiopia production
//  // const BASE_URL = "http://196.188.187.43:8000"; //new production

const BASE_URL_PROD = "https://app.zmall.et"; //Eth new domain

//  // const BASE_URL_HTTP = "http://159.65.147.111:8000";

// Ethiopia test
//  // const BASE_URL_TEST = "http://196.189.44.49:7000"; //test
const BASE_URL_TEST_OLD =
    "https://testapp.zmall.et"; //Etih new test.  the current test domain
//  // Blen
//  // const BASE_URL_TEST = "http://196.189.124.132:8000"; //test (blen)
//  // const new_test_zmall = "http://196.189.126.150:8002"; // new test blen
//

// const BASE_URL = BASE_URL_HTTP;
// const BASE_URL = kDebugMode ? BASE_URL_TEST : BASE_URL_PROD;
//

const BASE_URL_TEST =
    "https://testbackend.zmall.et"; //Eth new test.  the current test domain after july 29, 2026.
//
// const BASE_URL = BASE_URL_TEST;
const BASE_URL = BASE_URL_TEST;

// const ayat = "6a6b069856bef41124383c9e";
// const mexico = "6a6b0c4a56bef41124383ca2";

/// Zmall branch availability check (Odoo).
///
/// This endpoint lives on the Odoo server, NOT the regular Zmall backend.
const String kZmallOdooBaseUrl = "http://196.191.117.85:9070";

/// JSON field on each item (from the store API) carrying the Odoo
/// product.template id used by the availability endpoint.
const String kZmallOdooProductIdField = "odoo_product_id";

/// Maps Zmall store_id -> Odoo pos.config.zmall_branch_slug.
/// Fill these in with the real store ids and their branch slugs.
const Map<String, String> kZmallBranchSlugs = {
  "6a6b069856bef41124383c9e": "ayat",
  // "5b406b24d2ddf8062d11b787": "mexico",
  "6a6b0c4a56bef41124383ca2": "mexico",
};

/// Resolves the Odoo branch slug for a Zmall store, or null if not POS-linked.
String? zmallBranchSlugForStore(String? storeId) {
  if (storeId == null || storeId.isEmpty) return null;
  return kZmallBranchSlugs[storeId.trim()];
}

bool isOdooAvailabilityStore(String? storeId) =>
    zmallBranchSlugForStore(storeId) != null;

//

String appName = "ZMall";
String appUpdatedAt = "";
String appVersion = "3.2.10";
String appBuildNumber = "";
const kPrimaryColor = Colors.white;
const kWhiteColor = Color(0xFFF3F4F8);
const kYellowColor = Color(0xFFF7EA00);
const kGreenColor = Colors.green;
const kGreyColor = Color(0xFF707070);
const kBlackColor = Color(0xFF101010);
const worldCupColor = Color(0xFF791435);
const double kDefaultPadding = 15.0;

final double zmall_latitude = 8.999578803663903;
final double zmall_longitude = 38.769460522577134;

// Gemini chatbot config (used as fallback when the chat backend is down)
const String kGeminiApiKey = "AIzaSyDZD94UbvnltvJcALnZ7Ch4cn0No7EaEcI";
const String kGeminiModel = "gemini-3.6-flash";

final eKey = Encrypt.Key.fromUtf8("T-aie)c(ko,o=>ue1ir^UW&I90jm@@9!");
final b64key = Encrypt.Key.fromBase64(base64Encode(eKey.bytes));
final fernet = Encrypt.Fernet(b64key);
final encrypter = Encrypt.Encrypter(fernet);

DateTime worldCupStart = DateTime(2022, 11, 10);
DateTime worldCupEnd = DateTime(2022, 12, 13);

Color kSecondaryColor =
    DateTime.now().isBefore(worldCupEnd) &&
        DateTime.now().isAfter(worldCupStart)
    ? Color(0xFF791435)
    : Color(0xFFf11d3a);

String zmallLogo =
    DateTime.now().isBefore(worldCupEnd) &&
        DateTime.now().isAfter(worldCupStart)
    ? "images/zmall_worldcup.jpg"
    : "images/zmall.jpg";

const String zmallAiGif = "images/zmall_ai.gif";

final String deviceKey = 'AIzaSyBzMHLnXLbtLMi9rVFOR0eo5pbouBtxyjg';
final String iosKey = 'AIzaSyDAgZScAJfUHxahi_n4OpuI8HrTHVlirJk';
final apiKey = Platform.isIOS ? iosKey : deviceKey;

final otpInputDecorator = InputDecoration(
  contentPadding: EdgeInsets.symmetric(
    vertical: getProportionateScreenWidth(15.0),
  ),
  enabledBorder: outlineInputBorder(),
  focusedBorder: outlineInputBorder(),
  border: outlineInputBorder(),
);

OutlineInputBorder outlineInputBorder() {
  return OutlineInputBorder(
    borderSide: BorderSide(color: kGreyColor.withValues(alpha: 0.2)),
    borderRadius: BorderRadius.circular(5),
  );
}

final textFieldInputDecorator = InputDecoration(
  labelStyle: TextStyle(color: kGreyColor),
  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: kGreyColor)),
  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: kBlackColor)),
  border: OutlineInputBorder(
    borderSide: BorderSide(color: kBlackColor),
    borderRadius: BorderRadius.all(Radius.circular(12)),
  ),
);
Widget loadingIndicator({Color? color, double? size, Widget? child}) {
  return Center(
    child:
        child ??
        SpinKitFadingCircle(color: color ?? kPrimaryColor, size: size ?? 30.0),
  );
}

final boxShadow = BoxShadow(
  color: kWhiteColor,
  blurRadius: 3,
  spreadRadius: 2,
  offset: Offset(0, 2),
);
//old
// blurRadius: 0,
// color: Colors.black.withValues(alpha: 0.1),
// offset: Offset(1, 3));

final kDefaultShadow = BoxShadow(
  blurRadius: 8,
  spreadRadius: 0,
  offset: Offset(0, 4),
  color: kBlackColor.withValues(alpha: 0.08),
);
// BoxShadow(
//   color: Colors.black.withValues(alpha: 0.1),
//   blurRadius: 20,
//   offset: Offset(0, 10),

// //old
//   // offset: Offset(3, 3),
//   // blurRadius: 5,
//   // color: kBlackColor.withValues(alpha: 0.1),
// //  color: Color(0xFFE9E9E9).withValues(alpha: 0.56),
// );

class VerticalSpacing extends StatelessWidget {
  const VerticalSpacing({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: kDefaultPadding);
  }
}

final RegExp phoneValidatorRegExp = RegExp(r'^[9][0-9]{8}$');

// RegExp(r'^[97][0-9]{8}$');
final RegExp emailValidatorRegExp = RegExp(
  r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
);
final RegExp passwordRegex = RegExp(
  r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&#])[A-Za-z\d@$!%*?&#]{8,}$',
);

const String kPasswordErrorMessage =
    "Password must be at least 8 characters long, one uppercase letter, one lowercase letter, one number, and one special character (@, !, %, ?, &, \$, *, #).";
const String kEmailNullError = "Please Enter your email";
const String kInvalidEmailError = "Please Enter Valid Email";
const String kPassNullError = "Please Enter your password";
const String kShortPassError = "Password is too short";
const String kMatchPassError = "Passwords don't match";
const String kNameNullError = "Please Enter your name";
const String kNameLastNullError = "Please Enter your last name";
const String kPhoneNumberNullError = "Please Enter your phone number";
const String kPhoneInvalidError = "Please Enter a valid phone number";
const String kAddressNullError = "Please Enter your address";

final headingStyle = TextStyle(
  fontSize: getProportionateScreenWidth(kDefaultPadding * 1.5),
  fontWeight: FontWeight.bold,
  color: kBlackColor,
  height: 1.5,
);

final linearProgressIndicator = Container(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SpinKitWave(
        color: kSecondaryColor,
        size: getProportionateScreenWidth(kDefaultPadding),
      ),
      SizedBox(height: kDefaultPadding * 0.5),
      Text("Loading...", style: TextStyle(color: kBlackColor)),
    ],
  ),
);

const errorCodes = {
  "501": "Registration failed.",
  "502": "Email already registered.",
  "503": "Phone number already registered.",
  "505": "User already registered with social account.",
  "506": "User not registered with social account.",
  "511": "Login failed.",
  "512": "You are not registered.",
  "513": "Invalid password.",
  "521": "Update failed.",
  "522": "Device token update failed.",
  "523": "Logout failed.",
  "531": "Invalid referral code.",
  "532": "Already applied referral code.",
  "533": "Referral process failed.",
  "534": "User data not found.",
  "535": "Get order cart invoice failed.",
  "536": "Add amount to wallet failed.",
  "537": "Change wallet status failed.",
  "538": "Check payment failed.",
  "539": "Order history not found.",
  "540": "Order detail not found.",
  "541": "Invalid referral.",
  "542": "OTP verification failed.",
  "543": "Email and phone already registered.",
  "544": "Apply promo failed",
  "545": "Invalid promo code.",
  "546": "Invalid or expired promo code.",
  "547": "Invalid referral for your country.",
  "548": "Invoice not found.",
  "549": "Pending order payment...",
  "550": "Referral code out of uses. Limited in your country.",
  "551": "Promo code already used.",
  "552": "Promo code not for your city.",
  "553": "Your delivery charge is free. You can not apply promo.",
  "554": "Add favourite store failed.",
  "555": "Delete favourtie store failed.",
  "556": "Favourite store list not found.",
  "557": "Your order price is less than the store minimum order price.",
  "569": "Your wallet amount is negative.",
  "807": "Store review list not found.",
  "808": "Store review data not found.",
  "809": "Store review like failed.",
  "558": "Delivery service not available in your city.",
  "559": "Promo code used out of limit",
  "560": "Promo amount less than minimum amount limit.",
  "561": "Store list not found.",
  "999": "Invalid server token.",
  "1000": "Detail not found.",
  "2000": "Token expired",
  "2001": "Set password failed.",
  "2002": "Insufficient balance.",
  "2003": "Something went wrong.",
  "3000": "Please check with Amole.",
  //Order error code
  "651": "Order failed!",
  "652": "Order not found!",
  "653": "Set order status failed!",
  "654": "Request failed!",
  "655": "Change order status failed!",
  "656": "Cancel order failed!",
  "657": "Order cancel or reject by provider failed!",
  "658": "Order cancel or reject by store failed!",
  "659": "Order complete failed!",
  "660": "Order unique code invalid!",
  "661": "Order not ready!",
  "662": "Order already cancelled!",
  "663": "Order already accepted by another provider!",
  "664": "Something went wrong!",
  // Cart error code
  "961": "Add to cart failed!",
  "962": "Cart not found!",
  "963": "Update cart failed!",
  "964": "Delete cart failed!",
  "965": "Change delivery address failed!",
  // Country error code
  "801": "Country details not found!",
  "802": "Add country failed!",
  "803": "Country already exists!",
  "804": "Business not in your country!",
  "805": "Update failed!",
  // City error code
  "811": "City details not found!",
  "812": "Add city failed",
  "813": "Business not in your city!",
  "814": "Update failed!",
  // Product sceen error code
  "892": "Item not found!",
};

const order_status = {
  "1": "Waiting for store to accept",
  "101": "Cancelled by user",
  "3": "Order accepted",
  "103": "Store rejected",
  "104": "Store cancelled",
  "105": "Waiting to assign to delivery man",
  "5": "Waiting for store to prepare order",
  "7": "Preparing order",
  "9": "Waiting for delivery",
  "109": "No delivery man assigned",
  "110": "Not answered",
  "11": "Delivery man accepted request",
  "111": "Delivery man rejected",
  "112": "Delivery man cancelled",
  "13": "Delivery man going to store",
  "15": "Delivery man arrived at the store",
  "17": "Delivery man picked order",
  "19": "Delivery man started delivery",
  "21": "Delivery man arrived at your location",
  "23": "Delivery man completed delivery",
  "25": "Order completed",
  "998": "Store created order",
};

const country_id = {
  "Ethiopia": "5b3f76f2022985030cd3a437",
  "South Sudan": "62fef1d6ae93d51e87b468aa",
};
const store_delivery_id = {"DonationID": "66472227b2f9514de2636266"};

// Misaka (Food Store) filter IDs
const String kMisakaCityId = "5b406b46d2ddf8062d11b788";
const String kMisakaStoreDeliveryId = "5b406b24d2ddf8062d11b787";
const double kMisakaDefaultLatitude = 8.9996524;
const double kMisakaDefaultLongitude = 38.7698875;

/// For ADDRESS VALIDATION SERVICE
/// Minimum distance in meters to consider two addresses as different.
final double kMinimumDistanceThreshold = 0.1; // 100 meters

/// Telebirr-InApp Trace Number Filteration Key
final String kTelebirrInAppTraceKey = "ZInapp"; //ZTelebirrInApp";

/// ---- B2C Wallet Refund to telebirr endpoints ---- ///
const String kRefundGenerateOtpEndpoint = "/api/user/send_refund_otp";
const String kRefundVerifyOtpEndpoint = "/api/user/verify_refund_otp";
const String kRefundProcessEndpoint = "/api/admin/enable_wallet_refund";
const int kRefundOtpCountdownSeconds = 60;

/// ---- Proximity Order Radius ---- ///
const double kProximityRadius =
    5.0; // near by orders within 5km radius fallback

/// ======= Playstore and Appstore Id's ====== ///
final apple_id = '1450910679';
final playstore_id = 'com.zmall.user';
