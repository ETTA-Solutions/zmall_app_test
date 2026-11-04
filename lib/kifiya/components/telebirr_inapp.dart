import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';

class TelebirrInApp extends StatefulWidget {
  const TelebirrInApp({
    required this.amount,
    required this.phone,
    required this.traceNo,
    required this.context,
  });
  final double amount;
  final String phone;
  final String traceNo;
  final BuildContext context;

  @override
  _TelebirrInAppState createState() => _TelebirrInAppState();
}

class _TelebirrInAppState extends State<TelebirrInApp> {
  static const MethodChannel _channel = MethodChannel(
    'telebirrInAppSdkChannel',
  );

  Future<dynamic> placeOrderIOS({
    required String receiveCode,
    required String appId,
    required String shortCode,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'receiveCode': receiveCode,
        'appId': appId,
        'shortCode': shortCode,
      };
      debugPrint(
        '[TelebirrInApp][iOS] Invoking native placeOrder with arguments: $arguments',
      );

      final response = await _channel.invokeMethod('placeOrder', arguments);
      debugPrint('[TelebirrInApp][iOS] Native iOS Response: $response');

      // Check if the response is a map and contains status and code
      if (response != null && response.isNotEmpty) {
        final int code = int.tryParse(response['code'].toString()) ?? -1;
        debugPrint(
          '[TelebirrInApp][iOS] Parsed code: $code, status: ${response['status']}, errMsg: ${response['errMsg']}',
        );
        Map<String, dynamic> _paymentResult = {
          "code": code,
          "status": response['status'].toString(),
          "traceNo": widget.traceNo,
          "message": response['errMsg'].toString(),
        };

        _handlePaymentResponse(code: code);
        Future.delayed(
          Duration(seconds: 2),
          () => Navigator.pop(context, _paymentResult),
        );
      } else {
        // Unexpected response format
        debugPrint(
          '[TelebirrInApp][iOS] Unexpected empty/null response from native SDK',
        );
        _handlePaymentResponse(code: -1);
        Future.delayed(
          Duration(seconds: 2),
          () => Navigator.pop(context, false),
        );
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[TelebirrInApp][iOS] PlatformException caught: code=${e.code}, message=${e.message}, details=${e.details}',
      );
      int errorCode = -1;
      if (e.details is Map && e.details["code"] != null) {
        errorCode = int.tryParse(e.details["code"].toString()) ?? -1;
      }
      _handlePaymentResponse(code: errorCode, errorMessage: e.message);
      Future.delayed(Duration(seconds: 2), () => Navigator.pop(context, false));
    } catch (e, stackTrace) {
      debugPrint(
        '[TelebirrInApp][iOS] Unexpected error in placeOrderIOS: $e\n$stackTrace',
      );
      _handlePaymentResponse(code: -1);
      Future.delayed(Duration(seconds: 2), () => Navigator.pop(context, false));
    }
  }

  Future<dynamic> placeOrder({
    required String receiveCode,
    required String appId,
    required String shortCode,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'receiveCode': receiveCode,
        'appId': appId,
        'shortCode': shortCode,
      };
      debugPrint(
        '[TelebirrInApp][Android] Invoking native placeOrder with arguments: $arguments',
      );

      final dynamic response = await _channel.invokeMethod(
        'placeOrder',
        arguments,
      );

      debugPrint('[TelebirrInApp][Android] Native Android Response: $response');

      // Check if the response is a map and contains status and code
      if (response != null && response is Map && response.isNotEmpty) {
        final int code = int.tryParse(response['code'].toString()) ?? -1;
        debugPrint(
          '[TelebirrInApp][Android] Parsed code: $code, status: ${response['status']}, errMsg: ${response['errMsg']}',
        );
        Map<String, dynamic> _paymentResult = {
          "code": code,
          "status": response['status'].toString(),
          "traceNo": widget.traceNo,
          "message": response['errMsg'].toString(),
        };

        if (code == 0) {
          _handlePaymentResponse(code: code);
          Future.delayed(
            Duration(seconds: 2),
            () => Navigator.pop(context, _paymentResult),
          );
        } else {
          _handlePaymentResponse(code: code != -1 ? code : -99);
          Future.delayed(
            Duration(seconds: 2),
            () => Navigator.pop(context, _paymentResult),
          );
        }
      } else {
        // Unexpected response format
        debugPrint(
          '[TelebirrInApp][Android] Unexpected empty/null response from native SDK',
        );
        _handlePaymentResponse(code: -1);
        Future.delayed(
          Duration(seconds: 2),
          () => Navigator.pop(context, false),
        );
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[TelebirrInApp][Android] PlatformException caught: code=${e.code}, message=${e.message}, details=${e.details}',
      );
      int errorCode = -1;
      if (e.details is Map && e.details["code"] != null) {
        errorCode = int.tryParse(e.details["code"].toString()) ?? -1;
      }
      _handlePaymentResponse(code: errorCode, errorMessage: e.message);
      Future.delayed(Duration(seconds: 2), () => Navigator.pop(context, false));
    } catch (e, stackTrace) {
      debugPrint(
        '[TelebirrInApp][Android] Unexpected error in placeOrder: $e\n$stackTrace',
      );
      _handlePaymentResponse(code: -1);
      Future.delayed(Duration(seconds: 2), () => Navigator.pop(context, false));
    }
  }

  // Function to handle payment response based on the response code or message
  void _handlePaymentResponse({required int code, String? errorMessage}) {
    String message;
    bool isError = false;
    if (errorMessage != null) {
      // If there's an error message, show it
      message = errorMessage;
      isError = true;
    } else {
      // Handle different response codes
      switch (code) {
        case 0:
          message =
              "✅ Payment successful! Your transaction has been completed successfully. Thank you for using our service!";
          isError = false;
          break;
        case -1:
          message = "❌ Unknown error occurred. Please try again.";
          isError = true;
          break;
        case -2:
          message =
              "⚠️ There seems to be an issue with your input. Please double-check the parameters you provided and try again.";
          isError = true;
          break;
        case -3:
          message =
              "⚠️ Payment was cancelled by the user. If this was not intentional, please try again to complete the payment.";
          isError = true;
          break;
        case -10:
          message =
              "⚠️ It looks like telebirr is not installed on your device. Please install it and try again.";
          isError = true;
          break;
        case -11:
          message =
              "⚠️ The current version of telebirr doesn't support this feature. Please upgrade your telebirr app to the latest version and try again.";
          isError = true;
          break;
        case -99:
          message = "⚠️ Payment is not confirmed";
          isError = true;
          break;
        default:
          message = "❌  Unknown error occurred. Please try again.";
          isError = true;
          break;
      }
    }
    debugPrint(
      '[TelebirrInApp] _handlePaymentResponse: code=$code, errorMessage=$errorMessage -> isError=$isError, message="$message"',
    );

    // Display the message in the UI
    Service.showMessage(
      context: context,
      title: message,
      error: isError,
      duration: 3,
    );
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[TelebirrInApp] Initializing TelebirrInApp for amount=${widget.amount}, traceNo=${widget.traceNo}, phone=${widget.phone}',
    );
    getRreceiveCode(
      amount: "${widget.amount}",
      traceNo: widget.traceNo,
      phone: widget.phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("telebirr inapp", style: TextStyle(color: kBlackColor)),
        centerTitle: true,
        leading: BackButton(
          onPressed: () {
            debugPrint('[TelebirrInApp] User clicked back button');
            Navigator.pop(context, false);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Initiating Payment',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: kBlackColor,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    height: getProportionateScreenHeight(kDefaultPadding / 4),
                  ),
                  Text(
                    'Powered by Ethiotelecom',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: kGreyColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding * 2),
              ),

              // Telebirr Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  getProportionateScreenWidth(kDefaultPadding / 2),
                ),
                child: Image.asset(
                  "images/payment/telebirr.png",
                  height: getProportionateScreenHeight(kDefaultPadding * 12),
                  width: getProportionateScreenWidth(kDefaultPadding * 12),
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding * 2),
              ),

              // Loading Indicator
              SpinKitPouringHourGlassRefined(
                color: kGreyColor,
                size: getProportionateScreenWidth(kDefaultPadding * 3),
              ),
              SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),

              // Loading Text
              Text(
                "Waiting for your payment to be confirmed...",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kBlackColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding / 2),
              ),
              Text(
                "Please complete the transaction in the Telebirr app.",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: kGreyColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<dynamic> getRreceiveCode({
    required String amount,
    required String traceNo,
    required String phone,
  }) async {
    final deviceType = Platform.isIOS ? "iOS" : "android";
    var baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    var url = "$baseUrl/api/telebirr_inapp/create_order";
    Map data = {
      "traceNo": traceNo,
      "phone": phone,
      "amount": amount,
      "description": "ZMall_telebirr_inapp",
      "isInapp": true,
    };
    var body = json.encode(data);
    debugPrint(
      '[TelebirrInApp] getRreceiveCode -> POST $url\nPayload: $body\nDevice: $deviceType',
    );
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

      debugPrint(
        '[TelebirrInApp] getRreceiveCode response status: ${response.statusCode}, body: ${response.body}',
      );
      var responseData = json.decode(response.body);

      if (responseData != null &&
          responseData['createOrderResult'] != null &&
          responseData['createOrderResult']['result']
                  ?.toString()
                  .toLowerCase() ==
              'success') {
        final appId = responseData["appId"]?.toString() ?? "";
        final shortCode = responseData["shortCode"]?.toString() ?? "";
        final receiveCode =
            responseData['createOrderResult']?['biz_content']?['receiveCode']
                ?.toString() ??
            "";
        debugPrint(
          '[TelebirrInApp] create_order success: appId=$appId, shortCode=$shortCode, receiveCode=$receiveCode',
        );

        //////check platform and call function based on the device placeOrderAndroid or placeOrderIos
        if (deviceType == "android") {
          placeOrder(
            appId: appId,
            shortCode: shortCode,
            receiveCode: receiveCode,
          );
        } else {
          placeOrderIOS(
            appId: appId,
            shortCode: shortCode,
            receiveCode: receiveCode,
          );
        }
      } else {
        debugPrint(
          '[TelebirrInApp] create_order returned error response: $responseData',
        );
        _handlePaymentResponse(
          code: -1,
          errorMessage: responseData?['createOrderResult']?['message']
              ?.toString(),
        );
      }
      return responseData;
    } catch (e, stackTrace) {
      debugPrint('[TelebirrInApp] Error in getRreceiveCode: $e\n$stackTrace');
      _handlePaymentResponse(
        code: -1,
        errorMessage: "Error initiating payment: $e",
      );
      return null;
    }
  }
}
