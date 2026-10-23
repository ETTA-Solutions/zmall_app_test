import 'dart:async';
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/custom_back_button.dart';

class SubscriptionPaymentUssd extends StatefulWidget {
  const SubscriptionPaymentUssd({
    required this.url,
    required this.amount,
    required this.phone,
    required this.traceNo,
    this.title = "Telebirr",
    required this.userId,
    required this.serverToken,
  });
  final String url;
  final String title;
  final double amount;
  final String phone;
  final String traceNo;
  final String userId;
  final String serverToken;

  @override
  _SubscriptionPaymentUssdState createState() =>
      _SubscriptionPaymentUssdState();
}

class _SubscriptionPaymentUssdState extends State<SubscriptionPaymentUssd> {
  // bool _loading = false;
  String telebirrUrl = "";
  String uuid = "";

  @override
  void initState() {
    super.initState();
    _initTelebirr();
  }

  // Expiry before payment, so a renewal (already active) isn't mistaken for success
  String? _initialExpiry;
  bool _initiallyActive = false;

  void _initTelebirr() async {
    final before = await CoreServices.getSubscriptionDetail(
      userId: widget.userId,
      serverToken: widget.serverToken,
      context: context,
    );
    if (before != null && before['success'] == true) {
      _initialExpiry = before['subscription_expiry']?.toString();
      _initiallyActive = before['is_active'] == true;
    }

    var data = await initTelebirr();
    if (!mounted) return;
    if (data != null && data['result']?['success'] == true) {
      Service.showMessage(
        title:
            "${data['result']['message']}. Waiting for payment to be completed",
        error: false,
        duration: 6,
        context: context,
      );
      _verifyPayment();
    } else {
      Navigator.pop(context, false);
    }
  }

  // Poll subscription detail until the backend activates/extends the subscription
  void _verifyPayment() async {
    const maxAttempts = 60;
    const interval = Duration(seconds: 3);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(interval);
      if (!mounted) return;

      final data = await CoreServices.getSubscriptionDetail(
        userId: widget.userId,
        serverToken: widget.serverToken,
        context: context,
      );
      if (!mounted) return;
      debugPrint("telebirr ussd subscription poll #$i (initial active=$_initiallyActive, expiry=$_initialExpiry): $data");

      if (data != null && data['success'] == true && data['is_active'] == true) {
        final expiry = data['subscription_expiry']?.toString();
        if (!_initiallyActive || expiry != _initialExpiry) {
          Navigator.pop(context, true);
          return;
        }
      }
    }

    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: TextStyle(color: kBlackColor),
          ),
          leading: CustomBackButton(),
        ),
        body: Padding(
          padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay Using Telebirr',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Powered by Ethiotelecom',
                    style: TextStyle(fontSize: 21, color: Colors.black45),
                  ),
                ],
              ),
              Image.asset(
                "images/payment/telebirr.png",
                height: getProportionateScreenHeight(kDefaultPadding * 10),
                width: getProportionateScreenWidth(kDefaultPadding * 10),
              ),
              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding / 2),
              ),
              SpinKitPouringHourGlassRefined(color: kBlackColor),
              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding / 2),
              ),
              Text(
                "Please complete payment through the USSD prompt. \nWaiting for payment to be completed....",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ));
  }

  Future<dynamic> initTelebirr() async {
    // setState(() {
    //   _loading = true;
    // });
    var url = widget.url;

    final cleanTraceNo =
        widget.traceNo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    Map data = {
      "traceNo": cleanTraceNo.isNotEmpty
          ? cleanTraceNo
          : "ZM${DateTime.now().millisecondsSinceEpoch}",
      "amount": 1, // test 1 birr
      "phone": "251${widget.phone}",
      "payerId": "22",
      "appId": "4321",
      "apiKey": "90e503b019a811ef9bc8005056a4ed36",
      "zmall": true
    };
    /*  
    //Old configuration.
    //  Map data = {
    //   "trace_no": widget.traceNo,
    //   "amount": widget.amount,
    //   "phone": widget.phone,
    //   "appId": "1234"
    }; */

    var body = json.encode(data);
    // print("body $body");
    try {
      http.Response response = await http
          .post(
        Uri.parse(url),
        headers: <String, String>{
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: body,
      )
          .timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("The connection has timed out!");
        },
      );

      // print(json.decode(response.body));
      return json.decode(response.body);
    } catch (e) {
      // print(e);

      Service.showMessage(
        title:
            "Something went wrong. Please check your internet connection!",
        error: true,
        context: context,
      );
      return null;
    }
  }

  // Future<dynamic> verifyPayment() async {
  //   var url =
  //       "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/admin/check_paid_order";

  //   Map data = {
  //     "user_id": widget.userId,
  //     "server_token": widget.serverToken,
  //     "order_payment_id": widget.orderPaymentId
  //   };

  //   var body = json.encode(data);
  //   try {
  //     http.Response response = await http
  //         .post(
  //       Uri.parse(url),
  //       headers: <String, String>{
  //         "Content-Type": "application/json",
  //         "Accept": "application/json"
  //       },
  //       body: body,
  //     )
  //         .timeout(
  //       Duration(seconds: 10),
  //       onTimeout: () {
  //         throw TimeoutException("The connection has timed out!");
  //       },
  //     );

  //     return json.decode(response.body);
  //   } catch (e) {
  //     // print(e);

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       Service.showMessage(
  //           "Checking if payment is made. Please wait a moment...", true),
  //     );
  //     return null;
  //   }
  // }
}
