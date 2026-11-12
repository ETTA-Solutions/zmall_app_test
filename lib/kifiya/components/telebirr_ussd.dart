// =============================================================================
// ORIGINAL TELEBIRR USSD  (Ethio Telecom via Odoo — NOT ZooryaPay)
// =============================================================================
// This is the original telebirr USSD flow, restored as-is from the
// `ai_mcp_combo` branch. Keep it stand-alone.
//
//   * Opened from kifiya_screen.dart when the backend payment gateway name is
//     "tele birr" (the gateway name comes from the backend, the UI only
//     displays it).
//   * Init  : POST widget.url  (Odoo: http://196.189.44.60:8069/telebirr/ussd/send_sms)
//             body: traceNo, amount, phone "251…", payerId, appId, apiKey,
//             zmall, channel.
//   * Verify: POST {baseUrl}/admin/check_paid_order, polled every 2s until
//             success == true, then the screen pops and kifiya_screen calls
//             _boaVerify() (which creates the order).
//
// The NEW ZooryaPay telebirr USSD (method key "telebirr" under the
// ZOORYA-PAY gateway) is a different flow with its own screen:
//   lib/kifiya/zoorya_pay/zoorya_telebirr_ussd_screen.dart (ZooryaTelebirrUssd)
// Do not add ZooryaPay logic here.
// =============================================================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';

class TelebirrUssd extends StatefulWidget {
  const TelebirrUssd({
    required this.url,
    required this.hisab,
    required this.phone,
    required this.traceNo,
    required this.orderPaymentId,
    this.title = "telebirr",
    this.isAbroad = false,
    required this.serverToken,
    required this.userId,
  });
  final String url;
  final String title;
  final double hisab;
  final String phone;
  final String traceNo;
  final String orderPaymentId;
  final bool isAbroad;
  final String userId;
  final String serverToken;

  @override
  _TelebirrUssdState createState() => _TelebirrUssdState();
}

class _TelebirrUssdState extends State<TelebirrUssd> {
  bool _loading = false;
  String telebirrUrl = "";
  String uuid = "";
  int _verifyAttempt = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('==================== [TelebirrUssd] INIT ====================');
    debugPrint('[TelebirrUssd] Widget Params:');
    debugPrint('[TelebirrUssd]   url: ${widget.url}');
    debugPrint('[TelebirrUssd]   phone: ${widget.phone}');
    debugPrint('[TelebirrUssd]   traceNo: ${widget.traceNo}');
    debugPrint('[TelebirrUssd]   hisab: ${widget.hisab}');
    debugPrint('[TelebirrUssd]   orderPaymentId: ${widget.orderPaymentId}');
    debugPrint('[TelebirrUssd]   userId: ${widget.userId}');
    debugPrint('[TelebirrUssd]   title: ${widget.title}');
    debugPrint('[TelebirrUssd]   isAbroad: ${widget.isAbroad}');
    debugPrint('=============================================================');
    _initTelebirr();
  }

  void _initTelebirr() async {
    debugPrint('[TelebirrUssd] Calling initTelebirr()...');
    var data = await initTelebirr();
    debugPrint('[TelebirrUssd] initTelebirr returned: $data');
    if (!mounted) return;

    if (data != null &&
        data['result'] != null &&
        data['result']['success'] == true) {
      debugPrint(
        '[TelebirrUssd] ✅ Init successful: ${data['result']['message']}',
      );
      Service.showMessage(
        context: context,
        title:
            "${data['result']['message']}. Waiting for payment to be completed",
        error: false,
        duration: 6,
      );
      _verifyPayment();
    } else {
      debugPrint('[TelebirrUssd] ❌ Init failed or unapproved: $data');
      final errorMsg =
          (data != null &&
                  data['result'] != null &&
                  data['result']['message'] != null)
              ? data['result']['message'].toString()
              : "Telebirr USSD initialization failed";
      Service.showMessage(
        context: context,
        title: errorMsg,
        error: true,
        duration: 6,
      );
    }
  }

  void _verifyPayment() async {
    if (!mounted) return;
    _verifyAttempt++;
    debugPrint(
      '[TelebirrUssd] 🔄 Verify payment polling attempt #$_verifyAttempt...',
    );
    var data = await verifyPayment();
    debugPrint(
      '[TelebirrUssd] Verify attempt #$_verifyAttempt response: $data',
    );
    if (!mounted) return;

    if (data != null && data['success'] == true) {
      debugPrint(
        '[TelebirrUssd] ✅ Payment verified successfully! Closing screen.',
      );
      Navigator.pop(context);
    } else {
      debugPrint(
        '[TelebirrUssd] ⏳ Payment not yet completed. Re-checking in 2 seconds...',
      );
      await Future.delayed(
        Duration(seconds: 2),
      );
      if (mounted) {
        _verifyPayment();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: kBlackColor)),
        elevation: 1.0,
        // leading: TextButton(
        //   child: Text("Done"),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay Using telebirr',
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
        ),
      ),
    );
  }

  Future<dynamic> initTelebirr() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    var url = widget.url;

    //New configuration
    Map data = {
      "traceNo": widget.traceNo,
      "amount": widget.hisab,
      "phone": "251${widget.phone}",
      "payerId": "22",
      "appId": "1234",
      "apiKey": "90e503b019a811ef9bc8005056a4ed36",
      "zmall": true,
      "channel": "zmalltest",
    };

    /*  
    //Old configuration.
    //  Map data = {
    //   "trace_no": widget.traceNo,
    //   "amount": widget.hisab,
    //   "phone": widget.phone,
    //   "appId": "1234"
    }; */

    var body = json.encode(data);
    debugPrint('[TelebirrUssd] ─── initTelebirr Request ───');
    debugPrint('[TelebirrUssd] POST URL: $url');
    debugPrint(
      '[TelebirrUssd] Headers: {"Content-Type": "application/json", "Accept": "application/json"}',
    );
    debugPrint('[TelebirrUssd] Request Body: $body');
    debugPrint('[TelebirrUssd] ────────────────────────────');

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
            Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[TelebirrUssd] ⚠️ Request timed out after 10s!');
              throw TimeoutException("The connection has timed out!");
            },
          );

      debugPrint('[TelebirrUssd] ─── initTelebirr Response ───');
      debugPrint('[TelebirrUssd] Status Code: ${response.statusCode}');
      debugPrint('[TelebirrUssd] Raw Body: ${response.body}');
      debugPrint('[TelebirrUssd] ─────────────────────────────');

      return json.decode(response.body);
    } catch (e, stackTrace) {
      debugPrint('[TelebirrUssd] ❌ Error in initTelebirr: $e');
      debugPrint('[TelebirrUssd] StackTrace: $stackTrace');

      if (mounted) {
        Service.showMessage(
          context: context,
          title: "Something went wrong. Please check your internet connection!",
          error: true,
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          this._loading = false;
        });
      }
    }
  }

  Future<dynamic> verifyPayment() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/admin/check_paid_order";

    Map data = {
      "user_id": widget.userId,
      "server_token": widget.serverToken,
      "order_payment_id": widget.orderPaymentId,
    };

    var body = json.encode(data);
    debugPrint('[TelebirrUssd] ─── verifyPayment Request ───');
    debugPrint('[TelebirrUssd] POST URL: $url');
    debugPrint('[TelebirrUssd] Request Body: $body');
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
            Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[TelebirrUssd] ⚠️ verifyPayment timed out after 10s');
              throw TimeoutException("The connection has timed out!");
            },
          );

      debugPrint(
        '[TelebirrUssd] verifyPayment Status: ${response.statusCode}',
      );
      debugPrint('[TelebirrUssd] verifyPayment Raw Body: ${response.body}');
      return json.decode(response.body);
    } catch (e, stackTrace) {
      debugPrint('[TelebirrUssd] ❌ Error in verifyPayment: $e');
      debugPrint('[TelebirrUssd] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          this._loading = false;
        });

        Service.showMessage(
          context: context,
          title: "Checking if payment is made. Please wait a moment...",
          error: true,
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          this._loading = false;
        });
      }
    }
  }
}
