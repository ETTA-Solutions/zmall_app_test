// ignore_for_file: deprecated_member_use, unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/kifiya/components/starpay_screen.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/kifiya/components/addis_pay.dart';
import 'package:zmall/kifiya/components/amole_screen.dart';
import 'package:zmall/kifiya/components/cbe_ussd.dart';
import 'package:zmall/kifiya/components/chapa_screen.dart';
import 'package:zmall/kifiya/components/cyber_source.dart';
import 'package:zmall/kifiya/cybersource/cybersource_webview.dart';
import 'package:zmall/kifiya/cybersource/cybersource_service.dart';
import 'package:zmall/kifiya/components/dashen_master_card.dart';
import 'package:zmall/kifiya/components/ethswitch_screen.dart';
import 'package:zmall/kifiya/components/etta_card_screen.dart';
import 'package:zmall/kifiya/components/santimpay_screen.dart';
import 'package:zmall/kifiya/components/telebirr_inapp.dart';
import 'package:zmall/kifiya/components/telebirr_ussd.dart';
import 'package:zmall/kifiya/components/wegagen_ussd.dart';
import 'package:zmall/kifiya/components/yagoutpay.dart';
import 'package:zmall/kifiya/zoorya_pay/mpesa_phone_sheet.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_mpesa_screen.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_otp_screen.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_qr_screen.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_service.dart';
import 'package:zmall/kifiya/zoorya_pay/zoorya_pay_ussd_screen.dart';
import 'package:zmall/kifiya/kifiya_verification.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/widgets/order_status_row.dart';
import 'package:zmall/utils/random_digits.dart';
import 'package:zmall/combo/models/combo_cart.dart';
import 'package:zmall/combo/services/combo_service.dart';
import 'package:zmall/report/report_screen.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';
import 'components/kifiya_method_container.dart';
import 'components/telebirr_screen.dart';
import 'package:zmall/services/image_upload_service.dart';
import 'package:zmall/models/combo_payment_context.dart';

class KifiyaScreen extends StatefulWidget {
  static String routeName = '/kifiya';

  KifiyaScreen({
    this.vehicleId,
    this.onlyCashless = false,
    @required this.price,
    this.isCourier = false,
    @required this.orderPaymentId,
    @required this.orderPaymentUniqueId,
    this.userpickupWithSchedule,
    bool isCombo = false,
    String? comboId,
    String? storeAOrderPaymentId,
    String? storeBOrderPaymentId,
    String? storeACartId,
    String? storeBCartId,
    this.combo,
  }) : isCombo = isCombo || combo != null,
       comboId = combo != null ? combo.comboId : comboId,
       storeAOrderPaymentId = combo != null
           ? combo.storeA.orderPaymentId
           : storeAOrderPaymentId,
       storeBOrderPaymentId = combo != null
           ? combo.storeB.orderPaymentId
           : storeBOrderPaymentId,
       storeACartId = combo != null ? combo.storeA.cartId : storeACartId,
       storeBCartId = combo != null ? combo.storeB.cartId : storeBCartId;

  final double? price;
  final bool? isCourier;
  final String? vehicleId;
  final bool? onlyCashless;
  final String? orderPaymentId;
  final String? orderPaymentUniqueId;
  final bool? userpickupWithSchedule;
  final bool isCombo;
  final String? comboId;
  final String? storeAOrderPaymentId;
  final String? storeBOrderPaymentId;
  final String? storeACartId;
  final String? storeBCartId;
  final ComboPaymentContext? combo;

  @override
  _KifiyaScreenState createState() => _KifiyaScreenState();
}

class _KifiyaScreenState extends State<KifiyaScreen> {
  bool _loading = true;
  bool _placeOrder = false;
  // Telebirr in-app: prevents a confirmed payment from creating the order
  // more than once (fixed traceNo + always-poll allowed re-entry to re-confirm
  // the same payment). Only used by the Telebirr in-app flow.
  bool _orderPlaced = false;
  bool paidBySender = true;
  late Cart cart;
  AliExpressCart? aliexpressCart;
  List<String> itemIds = [];
  List<int> productIds = [];
  var paymentResponse;
  var orderResponse;
  var services;
  var courierCart;
  var imagePath;
  var userData;
  var aliExpressAccessToken;
  int kifiyaMethod = -1;
  double topUpAmount = 0.0;
  double currentBalance = 0.0;
  late String otp;
  late String uuid;
  bool isCourierSchedule = false;
  late String courierScheduleDate;
  String inAppTraceNumber = "";
  String _selectedPaymentMethod = "";

  Widget linearProgressIndicator = Container(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SpinKitWave(
          color: kSecondaryColor,
          size: getProportionateScreenWidth(kDefaultPadding),
        ),
        SizedBox(height: kDefaultPadding * 0.5),
        Text(
          "Gathering payment options...",
          style: TextStyle(color: kBlackColor),
        ),
      ],
    ),
  );

  @override
  void initState() {
    super.initState();

    // _loadPackageInfo();
    getUser();
    if (widget.onlyCashless != null && widget.onlyCashless == true) {
      kifiyaMethod = -1;
    }
    uuid = widget.orderPaymentUniqueId!;
  }

  /// Poll Telebirr query API to confirm in-app payment.
  /// Returns true when the backend reports a paid/success state.
  ///
  /// Bounded: polls every [intervalSeconds] until a terminal PAID/FAILED
  /// result, until the widget unmounts, or until [maxAttempts] requests have
  /// been made — whichever comes first. This prevents an endless poll (and the
  /// server load it causes) when a payment stays PENDING or the endpoint is
  /// unreachable. Exhausting the attempts returns false (treated as
  /// "not confirmed" by the caller).
  /// Default: 6 attempts x 1s (~6 seconds) of coverage when the endpoint
  /// responds quickly; longer if requests are slow (each request can take up
  /// to its 10s timeout before the next attempt).
  Future<bool> pollTelebirrStatus({
    required String merchOrderId,
    int intervalSeconds = 1,
    int maxAttempts = 6,
  }) async {
    debugPrint(
      '🔍 [Telebirr] Polling status for merchOrderId: $merchOrderId (maxAttempts=$maxAttempts, interval=${intervalSeconds}s)',
    );

    if (!mounted) return false;

    setState(() {
      _loading = true;
      linearProgressIndicator = Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitWave(
              color: kSecondaryColor,
              size: getProportionateScreenWidth(kDefaultPadding),
            ),
            SizedBox(height: kDefaultPadding * 0.5),
            Text(
              "Checking Telebirr payment...",
              style: TextStyle(color: kBlackColor),
            ),
          ],
        ),
      );
    });

    // const String url = "https://pgw.shekla.app/teleInapp/query"; // old prod
    //
    // const String url = "https://pgw.shekla.app/teleInapp/test_query"; //test endpoint
    //
    // const String url = "https://pgw.shekla.app/teleInapp/prod_query"; //new prod
    //
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/telebirr_inapp/query";
    //

    var attempt = 0;

    while (mounted && attempt < maxAttempts) {
      attempt += 1;
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: <String, String>{
                "Content-Type": "application/json",
                "Accept": "application/json",
              },
              body: json.encode({"merch_order_id": merchOrderId}),
            )
            .timeout(Duration(seconds: 10));

        if (!mounted) return false;

        final data = json.decode(response.body);
        debugPrint('[Telebirr] Poll #$attempt response raw: $data');
        String? status;
        bool? success;
        String? message;

        if (data is Map) {
          status = (data['status'] ?? data['trade_status'] ?? data['result'])
              ?.toString();
          success = data['success'] as bool?;
          message = data['message']?.toString();
        }

        debugPrint(
          '📊 [Telebirr] Poll #$attempt => status: $status, success: $success, message: $message',
        );

        if (status != null) {
          final upperStatus = status.toUpperCase();
          if ((upperStatus.contains('PAID') ||
                  upperStatus.contains('SUCCESS')) &&
              success == true) {
            debugPrint('✅ [Telebirr] Payment confirmed on attempt #$attempt');
            if (mounted) setState(() => _loading = false);
            return true;
          }

          if (upperStatus.contains('FAILED') ||
              upperStatus.contains('FAIL') ||
              success == false) {
            debugPrint(
              '❌ [Telebirr] Payment failed status received on attempt #$attempt: $status',
            );
            if (mounted) setState(() => _loading = false);
            return false;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [Telebirr] Poll error (retrying attempt #$attempt): $e');
      }

      await Future.delayed(Duration(seconds: intervalSeconds));
    }

    debugPrint(
      '⏳ [Telebirr] Polling reached max attempts ($maxAttempts) without conclusive status',
    );

    if (mounted) setState(() => _loading = false);
    return false;
  }

  // Future<void> _loadPackageInfo() async {
  //   final packageInfo = await PackageInfo.fromPlatform();
  //   setState(() {
  //     _appVersion = packageInfo.version;
  //     // _buildNumber = packageInfo.buildNumber;
  //   });
  // }

  void _userDetails() async {
    var usrData = await userDetails();
    if (!mounted) return;
    if (usrData != null && usrData['success']) {
      setState(() {
        userData = usrData;
        currentBalance = double.parse(userData['user']['wallet'].toString());
      });
      Service.save('user', userData);
    }
  }

  // void getUser() async {
  //   var data = await Service.read('user');

  //   if (data != null) {
  //     setState(() {
  //       userData = data;
  //       currentBalance = double.parse(userData['user']['wallet'].toString());
  //     });
  //     getCart();
  //   }
  // }
  void getUser() async {
    var data = await Service.read('user');
    var aliAcct = await Service.read('ali_access_token');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        userData = data;
        currentBalance = double.parse(userData['user']['wallet'].toString());
        // Only assign aliExpressAccessToken if aliAcct is not null or empty
        if (aliAcct != null && aliAcct.isNotEmpty) {
          aliExpressAccessToken = aliAcct;
        } else {
          // debugPrint("aliExpress Access Token not found>>>");
        }
      });
      getCart();
    }
  }

  // void getCart() async {
  //   if (widget.isCourier!) {
  //     var data = await Service.read('courier');
  //     if (data != null) {
  //       setState(() {
  //         courierCart = data;
  //         _getPaymentGateway();
  //         getServices();
  //         getImages();
  //         getCourierKefay();
  //         getCourierSchedule();
  //         getCourierScheduleDate();
  //       });
  //     }
  //   } else {
  //     var data = await Service.read('cart');
  //     if (data != null) {
  //       setState(() {
  //         cart = Cart.fromJson(data);
  //         _getPaymentGateway();
  //       });
  //     }
  //   }
  // }
  void getCart() async {
    if (widget.isCourier != null && widget.isCourier == true) {
      var data = await Service.read('courier');
      if (!mounted) return;
      if (data != null) {
        setState(() {
          courierCart = data;
          _getPaymentGateway();
          getServices();
          getImages();
          getCourierKefay();
          getCourierSchedule();
          getCourierScheduleDate();
        });
        //debugPrint("courierCart CART>>> ${courierCart!}");
      }
    } else {
      var data = await Service.read('cart');
      var aliCart = await Service.read('aliexpressCart');
      if (!mounted) return;
      if (data != null) {
        setState(() {
          cart = Cart.fromJson(data);
          // Only set values from aliCart if aliCart is not null
          if (aliCart != null) {
            aliexpressCart = AliExpressCart.fromJson(aliCart);
            itemIds = aliexpressCart!.itemIds!;
            productIds = aliexpressCart!.productIds!;
          }
          // debugPrint("ALI CART>>> ${aliexpressCart!.toJson()}");
        });
        _getPaymentGateway();
      }
    }
  }

  void getServices() async {
    var data = await Service.read('services');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        services = data;
      });
    }
  }

  void getImages() async {
    var data = await Service.read('images');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        imagePath = List<String>.from(data);
      });
    }
  }

  void getCourierSchedule() async {
    var data = await Service.readBool('is_schedule');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        isCourierSchedule = data;
      });
    }
  }

  void getCourierScheduleDate() async {
    var data = await Service.read('schedule_start');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        courierScheduleDate = data;
      });
    }
  }

  void getCourierKefay() async {
    var data = await Service.readBool('courier_paid_by_sender');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        paidBySender = data;
      });
    }
  }

  /// SECURITY FIX: Validates that all courier images exist, are accessible,
  /// have valid formats, and are within size limits before payment.
  /// Returns true if validation passes, false if any image fails.
  /// Delegates all validation logic to [ImageUploadService.validateBatch].
  Future<bool> _validateCourierImagesBeforePayment() async {
    // Skip validation for non-courier orders
    if (widget.isCourier != true) {
      return true;
    }

    // If no images attached, validation passes (images are optional)
    if (imagePath == null || imagePath.length == 0) {
      return true;
    }

    final batch = await ImageUploadService.validateBatch(imagePath);

    if (batch.hasIssues && batch.allFailed) {
      // Clear invalid images from storage
      await Service.remove('images');

      Service.showMessage(
        context: context,
        title:
            "Image issue: ${batch.summary}. "
            "Please go back and re-select your images.",
        error: true,
        duration: 5,
      );

      return false;
    }

    if (batch.hasIssues) {
      // Some images invalid — clear storage and let user re-select
      await Service.remove('images');

      Service.showMessage(
        context: context,
        title:
            "Image issue: ${batch.summary}. "
            "Please go back and re-select your images.",
        error: true,
        duration: 5,
      );

      return false;
    }

    return true;
  }

  void _getPaymentGateway() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _placeOrder = true;
    });

    debugPrint('╔══════════════════════════════════════════════════╗');
    debugPrint('║        [PAYMENT GATEWAY] Fetching...             ║');
    debugPrint('╚══════════════════════════════════════════════════╝');

    await getPaymentGateway();

    if (!mounted) return;
    if (paymentResponse != null && paymentResponse['success']) {
      // ── Print every gateway returned by the backend ──────────────────────
      final List<dynamic> gateways = paymentResponse['payment_gateway'] ?? [];
      debugPrint('┌─────────────────────────────────────────────────────');
      debugPrint(
        '│ [PAYMENT GATEWAY] ✅ Success — ${gateways.length} gateway(s) returned',
      );
      debugPrint('│ wallet balance : ${paymentResponse['wallet']}');
      debugPrint('├─────────────────────────────────────────────────────');
      for (int i = 0; i < gateways.length; i++) {
        final g = gateways[i];
        debugPrint(
          '│  [$i] name="${g['name']}"  _id=${g['_id']}  type=${g['payment_type'] ?? g['type'] ?? '-'}',
        );
      }
      debugPrint('└─────────────────────────────────────────────────────');

      setState(() {
        _loading = false;
        _placeOrder = false;
      });
      await useBorsa();
    } else {
      debugPrint('┌─────────────────────────────────────────────────────');
      debugPrint('│ [PAYMENT GATEWAY] ❌ Failed');
      debugPrint('│ response : $paymentResponse');
      debugPrint('└─────────────────────────────────────────────────────');
      setState(() {
        _loading = false;
        _placeOrder = false;
      });
      if (paymentResponse != null && paymentResponse['error_code'] == 999) {
        await Service.saveBool('logged', false);
        await Service.remove('user');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
  }

  void _createCourierOrder() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _placeOrder = true;
    });
    await createCourierOrder();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _placeOrder = false;
    });
  }

  void _createAliexpressOrder() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _placeOrder = true;
    });
    var data = await createAliexpressOrder();
    if (!mounted) return;
    if (data != null &&
        data['success'] &&
        data['data']['error_response'] == null &&
        data['data']['aliexpress_ds_order_create_response']['result']['is_success']) {
      List<dynamic>? orderIds =
          data['data']['aliexpress_ds_order_create_response']['result']['order_list']['number'];
      _createOrder(orderIds: orderIds);
    } else {
      setState(() {
        _loading = false;
        _placeOrder = false;
      });
      Service.showMessage(
        context: context,
        title: "Faild to create the order! please try again.",
        error: true,
      );
    }
  }

  void _createOrder({List<dynamic>? orderIds}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _placeOrder = true;
    });
    try {
      var data = await createOrder(orderIds: orderIds);
      // debugPrint( "order data>> $data\n_selectedPaymentMethod $_selectedPaymentMethod");
      if (!mounted) return;
      if (data != null && data['success']) {
        if (data['duplicate'] != null && data['duplicate'] == true) {
          debugPrint(
            '[COMBO-DEBUG] ⚠ Step 4: duplicate order detected — combo_id=${data['combo_id']}',
          );
          // duplicate logic
          Service.showMessage(
            context: context,
            title:
                "This order has already been placed. Please check your order history.",
            // error: true,
          );
        } else {
          debugPrint(
            '[COMBO-DEBUG] ✓ Step 4: order created successfully\n'
            '  combo_id        : ${data['combo_id']}\n'
            '  store_a order_id: ${data['store_a']?['order_id']}\n'
            '  store_b order_id: ${data['store_b']?['order_id']}\n'
            '  order_unique_ids: ${data['order_unique_ids']}',
          );
          try {
            debugPrint(
              '📍 [ORDER PLACED] Items/Store Location: '
              'Lat: ${cart.storeLocation?.lat}, Long: ${cart.storeLocation?.long}',
            );
          } catch (_) {}
          Service.showMessage(
            context: context,
            title: "Order successfully created",
            error: false,
          );
          await Service.remove('cart');
          await Service.remove('aliexpressCart');
          if (widget.isCombo) {
            await ComboCart.clear();
            try {
              final orderA = data['store_a']?['order_id']?.toString();
              final orderB = data['store_b']?['order_id']?.toString();
              final orderIds = [
                if (orderA != null && orderA.isNotEmpty) orderA,
                if (orderB != null && orderB.isNotEmpty) orderB,
              ];
              final uniqueIds = data['order_unique_ids'] is List
                  ? List.from(data['order_unique_ids'])
                  : [];
              final cId = data['combo_id']?.toString() ?? widget.comboId ?? "";
              if (cId.isNotEmpty && orderIds.isNotEmpty) {
                final existingRaw = await Service.read('combo_orders');
                List<dynamic> existingList = [];
                if (existingRaw is List) {
                  existingList = List.from(existingRaw);
                } else if (existingRaw is String) {
                  try {
                    existingList = List.from(jsonDecode(existingRaw));
                  } catch (_) {}
                }
                existingList.insert(0, {
                  'combo_id': cId,
                  'order_ids': orderIds,
                  'order_unique_ids': uniqueIds,
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (existingList.length > 50) {
                  existingList = existingList.sublist(0, 50);
                }
                await Service.save('combo_orders', existingList);
              }
            } catch (e) {
              debugPrint("Failed to persist combo_orders: $e");
            }
          }
          if (!mounted) return;

          final orderIdsList =
              widget.isCombo && data['order_unique_ids'] is List
              ? List.from(data['order_unique_ids'])
              : null;
          final uniqueId = (orderIdsList != null && orderIdsList.isNotEmpty)
              ? orderIdsList.join(',')
              : (widget.orderPaymentUniqueId ?? "");

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                return ReportScreen(
                  price: widget.price!,
                  orderPaymentUniqueId: uniqueId,
                );
              },
            ),
          );
        }
      } else {
        debugPrint(
          '[COMBO-DEBUG] ✗ Step 4: order creation failed\n'
          '  response: ${data?.toString() ?? "null"}\n'
          '  isCombo : ${widget.isCombo}',
        );
        // ── Combo telemetry: log API-level failure ─────────────────────────
        if (widget.isCombo) {
          await _logFailedComboOrder(
            reason:
                'combo_create_order API error: '
                '${ComboService.errorText(data, fallback: 'unknown')}',
            amount: widget.price ?? 0.0,
          );
          // Prompt user to contact support since payment may have been taken
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Service.showMessage(
                context: context,
                title:
                    'If payment was deducted, please contact support at 8707 '
                    'with reference: ${widget.orderPaymentUniqueId}',
                error: true,
                duration: 5,
              );
            }
          });
        }
        Service.showMessage(
          context: context,
          title: widget.isCombo
              ? ComboService.errorText(
                  data,
                  fallback: 'Order failed. Please try again.',
                )
              : (data != null
                    ? "${errorCodes['${data['error_code']}'] ?? 'Order failed. Please try again.'}"
                    : "Something went wrong. Please try again."),
          error: true,
        );
      }
    } catch (e) {
      // ── Combo telemetry: log exception-level failure ───────────────────────
      if (widget.isCombo) {
        await _logFailedComboOrder(
          reason: 'combo_create_order exception: $e',
          amount: widget.price ?? 0.0,
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Service.showMessage(
              context: context,
              title:
                  'If payment was deducted, please contact support at 8707 '
                  'with reference: ${widget.orderPaymentUniqueId}',
              error: true,
              duration: 5,
            );
          }
        });
      }
      Service.showMessage(
        context: context,
        title: "Something went wrong. Please try again.",
        error: true,
      );
    } finally {
      setState(() {
        _loading = false;
        _placeOrder = false;
      });
    }
  }

  // void _payOrderPayment({otp, paymentId = ""}) async {
  //   var pId = "";
  //   if (otp.toString().isNotEmpty) {
  //     pId = paymentId;
  //   } else {
  //     if (!widget.isCourier!) {
  //       pId = "0";
  //     }
  //   }
  //   if (kifiyaMethod != -1) {
  //     setState(() {
  //       _loading = true;
  //       _placeOrder = true;
  //     });
  //     var data = await payOrderPayment(
  //         otp, paymentResponse['payment_gateway'][kifiyaMethod]['_id']);
  //     if (data != null && data['success']) {
  //       widget.isCourier! ? _createCourierOrder() : _createOrder();
  //     } else {
  //       setState(() {
  //         _loading = false;
  //         _placeOrder = false;
  //       });
  //       Service.showMessage(  context: context,
  // title:
  //           "${errorCodes['${data['error_code']}']}!", true));
  //       await Future.delayed(Duration(seconds: 2));
  //       if (data['error_code'] == 999) {
  //         await Service.saveBool('logged', false);
  //         await Service.remove('user');
  //         Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  //       }
  //     }
  //   } else {
  //     Service.showMessage(  context: context,
  // title:
  //         "Please select a payment method for your order.", true,
  //         duration: 4));
  //   }
  // }
  void _payOrderPayment({otp, paymentId = ""}) async {
    // SECURITY FIX: Validate images exist BEFORE processing payment
    // This prevents payment deduction when image upload will fail
    bool imagesValid = await _validateCourierImagesBeforePayment();
    if (!mounted) return;
    if (!imagesValid) {
      setState(() {
        _loading = false;
        _placeOrder = false;
      });
      return; // Stop payment - images are invalid
    }

    var pId = "";
    if (otp.toString().isNotEmpty) {
      pId = paymentId;
    } else {
      if (widget.isCourier != null && widget.isCourier == false) {
        pId = "0";
      }
    }
    if (kifiyaMethod != -1) {
      setState(() {
        _loading = true;
        _placeOrder = true;
      });
      // ZOORYA-PAY: pass the ZOORYA gateway _id (not a method index).
      // Old: paymentResponse['payment_gateway'][kifiyaMethod]['_id']
      final dynamic _zooryaGw =
          (paymentResponse['payment_gateway'] as List<dynamic>).firstWhere(
            (g) => g['name'].toString().toUpperCase() == 'ZOORYA-PAY',
            orElse: () => null,
          );
      {
        final List<dynamic> zMethods = _visiblePaymentMethods(_zooryaGw);
        if (kifiyaMethod >= 0 && kifiyaMethod < zMethods.length) {
          final selMethod = zMethods[kifiyaMethod];
          final String selKey = selMethod['key'].toString().toLowerCase();
          final String selDisplayName = selMethod['name'].toString();
          final String selType = (selMethod['type'] ?? 'ussd').toString();
          final String? selImageUrl = selMethod['image_url']?.toString();
          if (selKey == _cyberSourceKey) {
            setState(() {
              _loading = false;
              _placeOrder = false;
            });
            _showProceedToPayDialog(
              displayName: selDisplayName,
              onProceed: () => _startCyberSource(displayName: selDisplayName),
            );
            return;
          }
          if (selKey == 'telebirr') {
            _showProceedToPayDialog(
              displayName: selDisplayName,
              type: selType,
              onProceed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TelebirrUssd(
                      userId: userData['user']['_id'],
                      serverToken: userData['user']['server_token'],
                      hisab: widget.price!,
                      traceNo: widget.orderPaymentUniqueId!,
                      uniqueId: widget.orderPaymentUniqueId!,
                      phone: userData['user']['phone'] ?? '',
                      orderPaymentId: widget.orderPaymentId!,
                      isZooryaPay: true,
                      imageUrl: selImageUrl,
                      type: selType,
                    ),
                  ),
                ).then((value) {
                  _onZooryaTelebirrResult(value);
                });
              },
            );
            return;
          } else if (selKey == 'zemen') {
            _showProceedToPayDialog(
              displayName: selDisplayName,
              type: selType,
              onProceed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ZooryaPayOtpScreen(
                      method: selKey,
                      displayName: selDisplayName,
                      imageUrl: selImageUrl,
                      amount: widget.price!,
                      userId: userData['user']['_id'],
                      serverToken: userData['user']['server_token'],
                      uniqueId: widget.orderPaymentUniqueId!,
                      orderPaymentId: widget.orderPaymentId!,
                    ),
                  ),
                ).then((value) {
                  if (value == true) {
                    _boaVerify();
                  }
                });
              },
            );
            return;
          } else if (selKey == 'dashen') {
            _showProceedToPayDialog(
              displayName: selDisplayName,
              type: selType,
              onProceed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ZooryaPayUssdScreen(
                      method: selKey,
                      displayName: selDisplayName,
                      type: selType,
                      imageUrl: selImageUrl,
                      amount: widget.price!,
                      userId: userData['user']['_id'],
                      serverToken: userData['user']['server_token'],
                      uniqueId: widget.orderPaymentUniqueId!,
                      orderPaymentId: widget.orderPaymentId!,
                      phoneNumber: userData['user']['phone'] ?? '',
                    ),
                  ),
                ).then((value) {
                  _boaVerify();
                });
              },
            );
            return;
          } else if (selKey == 'mpesa') {
            _showProceedToPayDialog(
              displayName: selDisplayName,
              type: selType,
              onProceed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ZooryaPayMpesaScreen(
                      displayName: selDisplayName,
                      imageUrl: selImageUrl,
                      amount: widget.price!,
                      userId: userData['user']['_id'],
                      serverToken: userData['user']['server_token'],
                      uniqueId: widget.orderPaymentUniqueId!,
                      orderPaymentId: widget.orderPaymentId!,
                      initialPhoneNumber: userData['user']['phone']?.toString(),
                    ),
                  ),
                ).then((value) {
                  // TEST: M-PESA order is created by the backend in /admin/check_paid_order,
                  // so the app does NOT call create_order. Uncomment to restore:
                  // if (value == true) {
                  //   _boaVerify();
                  // }
                  if (value is Map) {
                    _finishBackendCreatedOrder(value);
                  } else if (value == true) {
                    _boaVerify(skipCreateOrder: true);
                  }
                });
              },
            );
            return;
          } else if (selKey == 'nib' ||
              selKey == 'ethswitch') {
            _showProceedToPayDialog(
              displayName: selDisplayName,
              type: selType,
              onProceed: () {
                _startDirectZooryaPayUssd(
                  method: selKey,
                  displayName: selDisplayName,
                );
              },
            );
            return;
          } else if (selKey == 'telebirr_qr' || selKey == 'ethswitch_qr') {
            _showProceedToPayDialog(
              displayName: selDisplayName,
              type: selType,
              onProceed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ZooryaPayQrScreen(
                      method: selKey,
                      displayName: selDisplayName,
                      imageUrl: selImageUrl,
                      amount: widget.price!,
                      userId: userData['user']['_id'],
                      serverToken: userData['user']['server_token'],
                      uniqueId: widget.orderPaymentUniqueId!,
                      orderPaymentId: widget.orderPaymentId!,
                    ),
                  ),
                ).then((_) => _boaVerify());
              },
            );
            return;
          } else if (selKey == 'telebirr inapp' ||
              selKey == 'telebirr in app' ||
              selKey == 'telebirr in-app') {
            setState(() {
              _loading = false;
              _placeOrder = false;
            });
            _startTelebirrInApp();
            return;
          } else if (selKey == 'cash') {
            final List<dynamic> allGws = paymentResponse != null &&
                    paymentResponse['payment_gateway'] is List
                ? paymentResponse['payment_gateway'] as List<dynamic>
                : [];
            final dynamic cashGw = allGws.firstWhere(
              (g) => g['name'].toString().toLowerCase().contains('cash'),
              orElse: () => null,
            );
            final String cashGwId =
                cashGw != null ? cashGw['_id'].toString() : '0';
            var data = await payOrderPayment(
              otp,
              cashGwId,
              isPaymentModeCash: true,
            );
            if (!mounted) return;
            if (data != null && data['success']) {
              widget.isCombo
                  ? _createOrder()
                  : widget.isCourier!
                  ? _createCourierOrder()
                  : (aliexpressCart != null &&
                        aliexpressCart!.cart.storeId == cart.storeId)
                  ? _createAliexpressOrder()
                  : _createOrder();
            } else {
              setState(() {
                _loading = false;
                _placeOrder = false;
              });
              final errorText = widget.isCombo
                  ? ComboService.errorText(
                      data,
                      fallback: 'Payment failed. Please try again.',
                    )
                  : "${errorCodes['${data?['error_code']}'] ?? 'Payment failed.'}!";
              Service.showMessage(
                context: context,
                title: errorText,
                error: true,
              );
              await Future.delayed(Duration(seconds: 2));
              if (data != null && data['error_code'] == 999) {
                await Service.saveBool('logged', false);
                await Service.remove('user');
                Navigator.pushReplacementNamed(context, LoginScreen.routeName);
              }
            }
            return;
          }
        }
      }
      final String _zooryaGatewayId = _zooryaGw != null
          ? _zooryaGw['_id'].toString()
          : '';
      var data = await payOrderPayment(otp, _zooryaGatewayId);
      if (!mounted) return;
      if (data != null && data['success']) {
        widget.isCombo
            ? _createOrder()
            : widget.isCourier!
            ? _createCourierOrder()
            : (aliexpressCart != null &&
                  aliexpressCart!.cart.storeId == cart.storeId)
            ? _createAliexpressOrder()
            : _createOrder();
      } else {
        setState(() {
          _loading = false;
          _placeOrder = false;
        });
        final errorText = widget.isCombo
            ? ComboService.errorText(
                data,
                fallback: 'Payment failed. Please try again.',
              )
            : "${errorCodes['${data?['error_code']}'] ?? 'Payment failed.'}!";
        Service.showMessage(context: context, title: errorText, error: true);
        await Future.delayed(Duration(seconds: 2));
        if (data != null && data['error_code'] == 999) {
          await Service.saveBool('logged', false);
          await Service.remove('user');
          Navigator.pushReplacementNamed(context, LoginScreen.routeName);
        }
      }
    } else {
      Service.showMessage(
        context: context,
        title: "Please select a payment method for your order.",
        error: true,
        duration: 4,
      );
    }
  }

  // TEST: for ZOORYA-PAY Telebirr USSD the backend creates the order inside
  // /admin/check_paid_order, so the order comes from that response and the
  // app must NOT call /api/user/create_order. Set to false to restore the
  // old app-side create.
  static const bool _zooryaTelebirrBackendCreatesOrder = true;

  /// Handles the value popped by the ZOORYA-PAY TelebirrUssd screen.
  /// A Map is the check_paid_order response (paid → order created by backend).
  /// Anything else (user closed the screen) → ask check_paid_order once.
  void _onZooryaTelebirrResult(dynamic value) {
    if (!_zooryaTelebirrBackendCreatesOrder) {
      _boaVerify();
      return;
    }
    if (value is Map) {
      _finishBackendCreatedOrder(value);
    } else {
      _boaVerify(skipCreateOrder: true);
    }
  }

  // ───────────────────────── CyberSource card payment ─────────────────────────

  static const String _cyberSourceKey = 'cybersource';

  /// ZOORYA-PAY methods visible to the user, plus the CyberSource card tile
  /// when the backend's `payment_gateway` list contains an enabled
  /// CyberSource gateway (`is_payment_visible: true`). Nothing is hardcoded:
  /// the tile's name and image come from that gateway.
  List<dynamic> _visiblePaymentMethods(dynamic zooryaGateway) {
    final List<dynamic> methods =
        (zooryaGateway != null && zooryaGateway['methods'] is List)
        ? (zooryaGateway['methods'] as List)
              .where(
                (m) =>
                    m is Map &&
                    (m['is_visible'] == true || m['status'] == true),
              )
              .toList()
        : <dynamic>[];

    // The backend creates a plain ZMall order on PAID; it does not place the
    // AliExpress order, so card payment is hidden for AliExpress carts.
    final bool isAliexpressCart =
        aliexpressCart != null && aliexpressCart!.cart.storeId == cart.storeId;
    final dynamic cyberSourceGateway = _cyberSourceGateway();
    if (!isAliexpressCart && cyberSourceGateway != null) {
      methods.add({
        'key': _cyberSourceKey, // internal routing key only
        'name': cyberSourceGateway['name'].toString(),
        'image_url': cyberSourceGateway['image_url']?.toString(),
        'type': '',
        'is_visible': true,
      });
    }

    final gateways = paymentResponse?['payment_gateway'];
    if (gateways is List) {
      // 1. Telebirr InApp
      bool foundTelebirrInApp = false;
      for (final g in gateways) {
        if (g is! Map) continue;
        final name = g['name'].toString().toLowerCase();
        if ((name.contains('telebirr inapp') ||
                name.contains('telebirr in app') ||
                name.contains('telebirr in-app')) &&
            g['is_payment_visible'] != false) {
          methods.add({
            'key': 'telebirr inapp',
            'name': g['name'].toString(),
            'image_url': 'images/payment/telebirr.png',
            'type': 'inapp',
            'is_visible': true,
          });
          foundTelebirrInApp = true;
          break;
        }
      }
      if (!foundTelebirrInApp) {
        methods.add({
          'key': 'telebirr inapp',
          'name': 'Telebirr InApp',
          'image_url': 'images/payment/telebirr.png',
          'type': 'inapp',
          'is_visible': true,
        });
      }

      // 2. Cash payment (if not cashless only)
      if (widget.onlyCashless != true) {
        bool foundCash = false;
        for (final g in gateways) {
          if (g is! Map) continue;
          final name = g['name'].toString().toLowerCase();
          if (name.contains('cash') && g['is_payment_visible'] != false) {
            methods.add({
              'key': 'cash',
              'name': g['name'].toString(),
              'image_url': 'images/payment/cod.png',
              'type': 'cash',
              'is_visible': true,
            });
            foundCash = true;
            break;
          }
        }
        if (!foundCash) {
          methods.add({
            'key': 'cash',
            'name': 'Cash',
            'image_url': 'images/payment/cod.png',
            'type': 'cash',
            'is_visible': true,
          });
        }
      }
    } else {
      methods.add({
        'key': 'telebirr inapp',
        'name': 'Telebirr InApp',
        'image_url': 'images/payment/telebirr.png',
        'type': 'inapp',
        'is_visible': true,
      });
      if (widget.onlyCashless != true) {
        methods.add({
          'key': 'cash',
          'name': 'Cash',
          'image_url': 'images/payment/cod.png',
          'type': 'cash',
          'is_visible': true,
        });
      }
    }

    return methods;
  }

  /// The CyberSource gateway from `payment_gateway`, or null when the backend
  /// doesn't list it or has hidden it. Matched on the name containing "cyber"
  /// so spelling variants (e.g. "CyberSoruce") still match.
  dynamic _cyberSourceGateway() {
    final gateways = paymentResponse?['payment_gateway'];
    if (gateways is! List) return null;
    for (final g in gateways) {
      if (g is! Map) continue;
      final name = g['name'].toString().toLowerCase().replaceAll(
        RegExp(r'[^a-z]'),
        '',
      );
      if (name.contains('cyber') && g['is_payment_visible'] == true) return g;
    }
    return null;
  }

  /// CyberSource card payment: /pay → WebView → /status.
  /// The backend creates the order once the payment is PAID — create_order
  /// must NOT be called here.
  Future<void> _startCyberSource({required String displayName}) async {
    final bool imagesValid = await _validateCourierImagesBeforePayment();
    if (!mounted || !imagesValid) return;

    final String userId = userData['user']['_id'];
    final String serverToken = userData['user']['server_token'];

    setState(() {
      _loading = true;
      _placeOrder = true;
    });
    final pay = await CyberSourceService.pay(
      context: context,
      userId: userId,
      serverToken: serverToken,
      uniqueId: widget.orderPaymentUniqueId!,
    );
    if (!mounted) return;

    if (CyberSourceService.isInvalidToken(pay)) {
      _stopLoading();
      await _onCyberSourceResult(pay!);
      return;
    }
    final String? checkoutId = pay?['checkout_id']?.toString();
    final String? checkoutUrl = pay?['checkout_url']?.toString();
    if (pay == null || pay['success'] != true || checkoutId == null) {
      _stopLoading();
      setState(() => kifiyaMethod = -1);
      Service.showMessage(
        context: context,
        title: pay?['message']?.toString() ??
            'Couldn\'t open card payment. Check your internet connection and try again.',
        error: true,
      );
      return;
    }

    // Already paid on an earlier attempt (/pay is idempotent): skip the WebView.
    if (pay['status']?.toString() != CyberSourceService.paid &&
        checkoutUrl != null) {
      _stopLoading();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CyberSourceWebView(
            title: displayName,
            checkoutUrl: checkoutUrl,
            checkoutId: checkoutId,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _loading = true;
        _placeOrder = true;
      });
    }

    // Always confirm the real status, even if the user closed the WebView:
    // the payment may have gone through.
    final result = await CyberSourceService.waitForResult(
      context: context,
      userId: userId,
      serverToken: serverToken,
      checkoutId: checkoutId,
    );
    if (!mounted) return;
    _stopLoading();
    await _onCyberSourceResult(result);
  }

  void _stopLoading() {
    setState(() {
      _loading = false;
      _placeOrder = false;
    });
  }

  Future<void> _onCyberSourceResult(Map result) async {
    if (CyberSourceService.isInvalidToken(result)) {
      Service.showMessage(
        context: context,
        title: errorCodes['999'] ?? 'Your session has expired. Please log in again.',
        error: true,
      );
      await Service.saveBool('logged', false);
      await Service.remove('user');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      return;
    }

    final String status = result['status']?.toString() ?? '';
    if (result['is_paid'] == true || status == CyberSourceService.paid) {
      // Order already exists server-side; just show it.
      await _finishBackendCreatedOrder(result);
      return;
    }

    final String message;
    switch (status) {
      case CyberSourceService.review:
        message =
            'Your card payment is under review. We\'ll confirm your order shortly. '
            'For help, call 8707 with reference ${widget.orderPaymentUniqueId}.';
        break;
      case CyberSourceService.expired:
        message = 'The card payment session expired. Please try again.';
        break;
      case CyberSourceService.verifying:
        message =
            'We\'re still confirming your card payment. Check your orders in a moment. '
            'For help, call 8707 with reference ${widget.orderPaymentUniqueId}.';
        break;
      default: // CREATED → declined, cancelled or not paid yet
        message =
            'Card payment was not completed. You can try again or choose another method.';
    }
    setState(() => kifiyaMethod = -1);
    Service.showMessage(
      context: context,
      title: message,
      error: status != CyberSourceService.review &&
          status != CyberSourceService.verifying,
      duration: 5,
    );
  }

  void _startTelebirrInApp() async {
    var data = await useBorsa();
    if (!mounted) return;
    if (data != null && data['success']) {
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: kPrimaryColor,
            title: const Text("Pay using telebirr app"),
            content: Text(
              "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using telebirr in-app?",
            ),
            actions: [
              TextButton(
                child: Text(
                  Provider.of<ZLanguage>(context).cancel,
                  style: TextStyle(color: kSecondaryColor),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              TextButton(
                child: Text(
                  Provider.of<ZLanguage>(context).cont,
                  style: TextStyle(
                    color: kBlackColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  var uniqueId = RandomDigits.getString(6);
                  String uniqueIdString = uniqueId;
                  Navigator.of(dialogContext).pop();

                  setState(() {
                    inAppTraceNumber =
                        "${kTelebirrInAppTraceKey}${widget.orderPaymentUniqueId!}TELE$uniqueIdString";
                    _selectedPaymentMethod = "telebirr inapp";
                  });

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return TelebirrInApp(
                          context: context,
                          amount: widget.price!,
                          traceNo: inAppTraceNumber,
                          phone: userData['user']['phone'],
                        );
                      },
                    ),
                  ).then((value) async {
                    if (_orderPlaced) return;

                    final isPaid = await pollTelebirrStatus(
                      merchOrderId: inAppTraceNumber,
                    );

                    if (!mounted) return;
                    if (_orderPlaced) return;

                    if (isPaid) {
                      _orderPlaced = true;
                      Service.showMessage(
                        context: context,
                        error: false,
                        title: "Telebirr payment confirmed.",
                      );

                      // FOR TESTING TELEBIRR INAPP: commented out create order endpoint
                      // if (widget.isCourier!) {
                      //   _createCourierOrder();
                      // } else if (aliexpressCart != null &&
                      //     aliexpressCart!.cart.storeId == cart.storeId) {
                      //   _createAliexpressOrder();
                      // } else {
                      //   _createOrder();
                      // }
                    } else {
                      Service.showMessage(
                        context: context,
                        title:
                            "Payment was not completed. You can try again or choose another method.",
                        error: true,
                        duration: 4,
                      );
                    }
                  });
                },
              ),
            ],
          );
        },
      );
    }
  }

  /// Uses the /admin/check_paid_order response (the backend already created
  /// the order there): clear the cart and open the receipt.
  Future<void> _finishBackendCreatedOrder(Map response) async {
    debugPrint(
      '[ZOORYA-PAY] ✅ Order created by /admin/check_paid_order — '
      'NOT calling /api/user/create_order. Response: $response',
    );
    final dynamic d = response['data'] is Map ? response['data'] : null;
    final dynamic o = response['order'] is Map
        ? response['order']
        : (d is Map && d['order'] is Map ? d['order'] : null);
    final String uniqueId = (response['order_unique_id'] ??
            d?['order_unique_id'] ??
            o?['unique_id'] ??
            widget.orderPaymentUniqueId ??
            "")
        .toString();

    await Service.remove('cart');
    await Service.remove('aliexpressCart');
    if (widget.isCombo) await ComboCart.clear();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _placeOrder = false;
    });
    Service.showMessage(
      context: context,
      title: "Order successfully created",
      error: false,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReportScreen(
          price: widget.price!,
          orderPaymentUniqueId: uniqueId,
        ),
      ),
    );
  }

  Future<bool> _boaVerify({bool skipCreateOrder = false}) async {
    if (!mounted) return false;
    debugPrint(
      '╔══════════════════════════════════════════════════════════════════╗',
    );
    debugPrint(
      '║ 🔍 [_boaVerify] STARTING PAYMENT VERIFICATION CHECK            ║',
    );
    debugPrint(
      '╠══════════════════════════════════════════════════════════════════╣',
    );
    debugPrint('║ orderPaymentId:       ${widget.orderPaymentId}');
    debugPrint('║ orderPaymentUniqueId: ${widget.orderPaymentUniqueId}');
    debugPrint(
      '╚══════════════════════════════════════════════════════════════════╝',
    );
    setState(() {
      _loading = true;
      _placeOrder = true;
    });
    var data = await boaVerify();
    debugPrint('[_boaVerify] → Received response from boaVerify: $data');

    if (!mounted) return false;
    if (data != null && data['success'] && skipCreateOrder) {
      setState(() {
        _loading = false;
        _placeOrder = false;
      });
      await _finishBackendCreatedOrder(data);
      return true;
    }
    if (data != null && data['success']) {
      // SECURITY FIX: Validate images before creating order after payment verification
      bool imagesValid = await _validateCourierImagesBeforePayment();

      if (!mounted) return false;
      if (!imagesValid) {
        setState(() {
          _loading = false;
          _placeOrder = false;
        });
        // Payment was verified but images are invalid - log for potential refund
        Service.showMessage(
          context: context,
          title:
              "Payment verified but order could not be created due to missing images. Please contact support at 8707 for assistance.",
          error: true,
          duration: 5,
        );
        return false;
      }

      setState(() {
        _loading = false;
        _placeOrder = false;
      });
      Service.showMessage(
        context: context,
        title: "Payment verification Successful!",
        error: false,
        duration: 2,
      );
      widget.isCourier!
          ? _createCourierOrder()
          : (aliexpressCart != null &&
                aliexpressCart!.cart.storeId == cart.storeId)
          ? _createAliexpressOrder()
          : _createOrder();
      return true;
    } else {
      setState(() {
        _loading = false;
        _placeOrder = false;
        if (widget.onlyCashless!) {
          kifiyaMethod = -1;
        } else {
          kifiyaMethod = 1;
        }
      });
      await useBorsa();
      Service.showMessage(
        context: context,
        title:
            "${data != null ? data['error'] : 'Verification failed'}! Please complete your payment!",
        error: true,
      );
      await Future.delayed(Duration(seconds: 3));
      return false;
    }
  }

  void _showProceedToPayDialog({
    required String displayName,
    String? type,
    required VoidCallback onProceed,
  }) {
    final formattedName = Service.capitalizeFirstLetters(displayName);
    final String typeSuffix =
        (type != null && type.isNotEmpty) ? " (${type.toUpperCase()})" : "";
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kPrimaryColor,
          title: Text("Pay Using $formattedName$typeSuffix"),
          content: Text(
            "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using $formattedName$typeSuffix?",
          ),
          actions: [
            TextButton(
              child: Text(
                Provider.of<ZLanguage>(context).cancel,
                style: TextStyle(
                  color: kSecondaryColor,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  kifiyaMethod = -1;
                });
              },
            ),
            TextButton(
              child: Text(
                Provider.of<ZLanguage>(context).cont,
                style: TextStyle(
                  color: kBlackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onProceed();
              },
            ),
          ],
        );
      },
    );
  }

  int _zooryaPollAttempt = 0;
  // Direct NIB / EthSwitch checks stop after ZooryaPayService.pollWindow (2 min).
  DateTime? _zooryaPollStartedAt;
  String _zooryaDirectDisplayName = '';

  Future<void> _startDirectZooryaPayUssd({
    required String method,
    required String displayName,
  }) async {
    // Phone that receives the USSD / STK prompt (defaults to the account phone).
    String payPhone = userData['user']['phone']?.toString() ?? '';

    // M-PESA only works with Safaricom numbers (07...). If the account phone
    // isn't one, ask the user for an M-PESA number before continuing.
    if (method == 'mpesa') {
      if (isMpesaPhone(payPhone)) {
        payPhone = normalizeEthPhone(payPhone);
      } else {
        final entered = await showMpesaPhoneSheet(context);
        if (!mounted) return;
        if (entered == null) {
          setState(() {
            _loading = false;
            _placeOrder = false;
            kifiyaMethod = -1;
          });
          return;
        }
        payPhone = entered;
      }
    }

    // SECURITY FIX: Validate images before processing payment
    bool imagesValid = await _validateCourierImagesBeforePayment();
    if (!mounted) return;
    if (!imagesValid) {
      setState(() {
        _loading = false;
        _placeOrder = false;
      });
      return;
    }

    // For M-PESA: self-dismissing notification so user does not need to click anything
    if (method == 'mpesa') {
      Service.showMessage(
        context: context,
        title: "M-PESA: Approve the prompt sent to $payPhone.",
        error: false,
        duration: 4,
      );
    }

    setState(() {
      _loading = true;
      _placeOrder = true;
      _zooryaPollAttempt = 0;
      _zooryaPollStartedAt = DateTime.now();
      _zooryaDirectDisplayName = displayName;
    });

    debugPrint('╔══════════════════════════════════════════════════════════════════╗');
    debugPrint('║ 🚀 [ZOORYA-PAY] DIRECT USSD INITIATION: $method');
    debugPrint('╚══════════════════════════════════════════════════════════════════╝');

    final result = await ZooryaPayService.pay(
      context: context,
      userId: userData['user']['_id'],
      serverToken: userData['user']['server_token'],
      method: method,
      uniqueId: widget.orderPaymentUniqueId!,
      amount: widget.price!,
      phoneNumber: payPhone,
    );

    if (!mounted) return;

    if (result == null || result['success'] != true) {
      final msg = result?['message']?.toString() ??
          'Payment initiation failed. Please try again.';
      debugPrint('[ZOORYA-PAY] ❌ Direct USSD Initiation Failed: $msg');
      setState(() {
        _loading = false;
        _placeOrder = false;
        kifiyaMethod = -1;
      });
      Service.showMessage(
        context: context,
        title: msg,
        error: true,
        duration: 5,
      );
      return;
    }

    debugPrint('[ZOORYA-PAY] ✅ Direct USSD initiated successfully! Prompt sent to user device.');
    if (method != 'mpesa') {
      Service.showMessage(
        context: context,
        title: "Payment request sent. Please enter your PIN on your phone.",
        error: false,
        duration: 5,
      );
    }

    _pollDirectZooryaPayment(
      orderPaymentId: widget.orderPaymentId!,
      method: method,
    );
  }

  void _pollDirectZooryaPayment({
    required String orderPaymentId,
    required String method,
  }) async {
    if (!mounted) return;
    _zooryaPollAttempt++;
    debugPrint('[ZOORYA-PAY] 🔄 Poll attempt #$_zooryaPollAttempt for orderPaymentId=$orderPaymentId');

    final result = await ZooryaPayService.checkPaidOrder(
      context: context,
      userId: userData['user']['_id'],
      serverToken: userData['user']['server_token'],
      orderPaymentId: orderPaymentId,
    );

    if (!mounted) return;

    bool isPaid = false;
    if (result != null) {
      if (result['success'] == true || result['success'] == 'true') isPaid = true;
      if (result['is_paid'] == true || result['is_paid'] == 'true') isPaid = true;
      if (result['paid'] == true || result['paid'] == 'true') isPaid = true;
      if (result['data'] is Map) {
        final data = result['data'] as Map;
        if (data['is_paid'] == true || data['is_paid'] == 'true') isPaid = true;
        if (data['paid'] == true || data['paid'] == 'true') isPaid = true;
        if (data['status'] == 'PAID' || data['status'] == 'COMPLETED') isPaid = true;
      }
    }

    if (isPaid) {
      debugPrint('╔══════════════════════════════════════════════════════════════════╗');
      debugPrint('║ ✅ [ZOORYA-PAY] DIRECT PAYMENT CONFIRMED! VERIFYING ORDER        ║');
      debugPrint('╚══════════════════════════════════════════════════════════════════╝');
      _boaVerify();
    } else {
      final elapsed = DateTime.now().difference(
        _zooryaPollStartedAt ?? DateTime.now(),
      );
      if (elapsed < ZooryaPayService.pollWindow) {
        await Future.delayed(ZooryaPayService.pollInterval);
        if (mounted) {
          _pollDirectZooryaPayment(
            orderPaymentId: orderPaymentId,
            method: method,
          );
        }
      } else {
        debugPrint(
          '[ZOORYA-PAY] ⏱️ Stopped checking after 2 min ($_zooryaPollAttempt checks).',
        );
        setState(() {
          _loading = false;
          _placeOrder = false;
        });
        _showZooryaTimeoutDialog(method: method);
      }
    }
  }

  /// Shown when a direct NIB / EthSwitch payment isn't confirmed within 2 min.
  void _showZooryaTimeoutDialog({required String method}) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("We couldn't confirm your payment"),
        content: const Text(
          'The prompt may have expired. Resend it, or check again if you already paid.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _boaVerify(); // one single check
            },
            child: const Text("I've paid, check again"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _startDirectZooryaPayUssd(
                method: method,
                displayName: _zooryaDirectDisplayName,
              );
            },
            child: const Text(
              'Resend prompt',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _ethSwitchVerify(String traceNo) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _placeOrder = true;
    });
    var data = await ethSwitchVerify(traceNo: traceNo);
    if (!mounted) return;
    if (data != null && data['success']) {
      _boaVerify();
    } else {
      setState(() {
        _loading = false;
        _placeOrder = false;
        if (widget.onlyCashless!) {
          kifiyaMethod = -1;
        } else {
          kifiyaMethod = 1;
        }
      });
      await useBorsa();
      Service.showMessage(
        context: context,
        title:
            "Payment was not made or verified! If payment is completed please contact support on 8707!",
        error: true,
        duration: 6,
      );
      await Future.delayed(Duration(seconds: 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        // surfaceTintColor: kPrimaryColor,
        title: Text(
          Provider.of<ZLanguage>(context).payments,
          style: TextStyle(color: kBlackColor),
        ),
        // elevation: 1.0,
      ),
      body: SafeArea(
        child: ModalProgressHUD(
          inAsyncCall: _loading,
          progressIndicator: linearProgressIndicator,
          color: kPrimaryColor,
          child: paymentResponse != null
              ? Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: getProportionateScreenWidth(
                            kDefaultPadding,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            // mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: getProportionateScreenHeight(
                                    kDefaultPadding,
                                  ),
                                  horizontal: getProportionateScreenWidth(
                                    kDefaultPadding,
                                  ),
                                ),
                                margin: EdgeInsets.symmetric(
                                  vertical: getProportionateScreenHeight(
                                    kDefaultPadding / 2,
                                  ),
                                ),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: kPrimaryColor,
                                  border: Border.all(color: kWhiteColor),
                                  borderRadius: BorderRadius.circular(
                                    getProportionateScreenWidth(
                                      kDefaultPadding / 1.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: OrderStatusRow(
                                        title: "Total Price",
                                        icon: HeroiconsOutline.banknotes,
                                        fontSize: getProportionateScreenHeight(
                                          16,
                                        ),
                                        value:
                                            "${widget.price!.toStringAsFixed(2)} ${Provider.of<ZMetaData>(context, listen: false).currency}",
                                      ),
                                    ),
                                    Flexible(
                                      child: OrderStatusRow(
                                        icon: HeroiconsOutline.creditCard,
                                        title: Provider.of<ZLanguage>(
                                          context,
                                        ).balance,
                                        fontSize: getProportionateScreenHeight(
                                          16,
                                        ),
                                        value:
                                            "${paymentResponse['wallet'].toStringAsFixed(2)} ${Provider.of<ZMetaData>(context, listen: false).currency} ",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Text(

                              //   "${Provider.of<ZLanguage>(context).howWouldYouPay} ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)}?",
                              //   style: TextStyle(
                              //       fontSize: 20, fontWeight: FontWeight.w600),
                              //   // Theme.of(context)
                              //   //     .textTheme
                              //   //     .titleLarge
                              //   //     ?.copyWith(fontWeight: FontWeight.w600),
                              //   textAlign: TextAlign.center,
                              // ),
                              // // SizedBox(
                              // //     height: getProportionateScreenHeight(
                              // //         kDefaultPadding / 2)),
                              // // CategoryContainer(
                              // //     title: Provider.of<ZLanguage>(context).balance),
                              // // SizedBox(
                              // //     height: getProportionateScreenHeight(
                              // //         kDefaultPadding / 2)),
                              // Container(
                              //   // height:
                              //   //     getProportionateScreenHeight(kDefaultPadding * 4),
                              //   width: double.infinity,
                              //   padding: EdgeInsets.symmetric(
                              //       horizontal:
                              //           getProportionateScreenWidth(kDefaultPadding),
                              //       vertical: getProportionateScreenHeight(
                              //           kDefaultPadding / 2)),
                              //   margin: EdgeInsets.symmetric(
                              //       vertical: getProportionateScreenHeight(
                              //           kDefaultPadding / 2)),
                              //   decoration: BoxDecoration(
                              //     color: kPrimaryColor,
                              //     border: Border.all(
                              //         color: kBlackColor.withValues(alpha: 0.2)),
                              //     borderRadius: BorderRadius.circular(
                              //       getProportionateScreenWidth(kDefaultPadding / 2),
                              //     ),
                              //   ),
                              //   child: Center(
                              //     child: Column(
                              //       children: [
                              //         Text(
                              //           "${paymentResponse['wallet'].toStringAsFixed(2)} ${Provider.of<ZMetaData>(context, listen: false).currency} ",
                              //           style: Theme.of(context)
                              //               .textTheme
                              //               .titleLarge
                              //               ?.copyWith(fontWeight: FontWeight.w600),
                              //         ),
                              //         Text(
                              //           Provider.of<ZLanguage>(context).balance,
                              //           style: TextStyle(
                              //               fontWeight: FontWeight.w600,
                              //               color: kGreyColor),
                              //         ),
                              //       ],
                              //     ),
                              //   ),
                              // ),
                              // SizedBox(
                              //     height: getProportionateScreenHeight(
                              //         kDefaultPadding / 2)),
                              // Text(
                              //   Provider.of<ZLanguage>(context).addFundsInfo,
                              //   style:
                              //       Theme.of(context).textTheme.bodySmall?.copyWith(
                              //             color: Theme.of(context)
                              //                 .colorScheme
                              //                 .onSurface
                              //                 .withValues(alpha: 0.6),
                              //           ),
                              // ),
                              // SizedBox(
                              //   height: getProportionateScreenHeight(kDefaultPadding),
                              // ),

                              // Show attached images preview for courier orders
                              if (widget.isCourier == true &&
                                  imagePath != null &&
                                  imagePath.length > 0)
                                Container(
                                  margin: EdgeInsets.only(
                                    top: getProportionateScreenHeight(
                                      kDefaultPadding / 8,
                                    ),
                                    bottom: getProportionateScreenHeight(
                                      kDefaultPadding / 2,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: getProportionateScreenHeight(
                                      kDefaultPadding / 2,
                                    ),
                                    horizontal: getProportionateScreenWidth(
                                      kDefaultPadding,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      0xFF667EEA,
                                    ).withValues(alpha: 0.1),
                                    //  kSecondaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      getProportionateScreenWidth(
                                        kDefaultPadding / 1.5,
                                      ),
                                    ),
                                    border: Border.all(
                                      color: kWhiteColor,
                                      //  kSecondaryColor.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header with icon and count
                                      Row(
                                        spacing: getProportionateScreenWidth(
                                          kDefaultPadding / 2,
                                        ),
                                        children: [
                                          Icon(
                                            HeroiconsOutline.paperClip,
                                            color: kBlackColor,
                                            size: getProportionateScreenWidth(
                                              kDefaultPadding,
                                            ),
                                          ),

                                          Text(
                                            "${imagePath.length} image(s) attached",
                                            style: TextStyle(
                                              color: kBlackColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize:
                                                  getProportionateScreenWidth(
                                                    kDefaultPadding * 0.8,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: getProportionateScreenHeight(
                                          kDefaultPadding / 2,
                                        ),
                                      ),
                                      // Image thumbnails preview
                                      SizedBox(
                                        height: getProportionateScreenHeight(
                                          kDefaultPadding * 4,
                                        ),
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: imagePath.length,
                                          padding: EdgeInsets.only(
                                            right: getProportionateScreenWidth(
                                              kDefaultPadding / 2,
                                            ),
                                          ),
                                          separatorBuilder: (context, index) =>
                                              SizedBox(
                                                width:
                                                    getProportionateScreenWidth(
                                                      kDefaultPadding / 3,
                                                    ),
                                              ),
                                          itemBuilder: (context, index) {
                                            return Container(
                                              width:
                                                  getProportionateScreenWidth(
                                                    kDefaultPadding * 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      getProportionateScreenWidth(
                                                        kDefaultPadding / 3,
                                                      ),
                                                    ),
                                                // border: Border.all(
                                                //   color: kGreyColor.withValues(
                                                //     alpha: 0.5,
                                                //   ),
                                                //   width: 1.5,
                                                // ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      getProportionateScreenWidth(
                                                        kDefaultPadding / 3,
                                                      ),
                                                    ),
                                                child: Image.file(
                                                  File(imagePath[index]),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    // Show error icon if image can't be loaded
                                                    return Container(
                                                      color: Color(
                                                        0xFF667EEA,
                                                      ).withValues(alpha: 0.1),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            HeroiconsOutline
                                                                .exclamationTriangle,
                                                            color:
                                                                kSecondaryColor,
                                                            size: getProportionateScreenWidth(
                                                              kDefaultPadding *
                                                                  1.5,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            height:
                                                                getProportionateScreenHeight(
                                                                  kDefaultPadding /
                                                                      4,
                                                                ),
                                                          ),
                                                          Text(
                                                            "Missing",
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                              fontSize:
                                                                  getProportionateScreenWidth(
                                                                    kDefaultPadding *
                                                                        0.6,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                Provider.of<ZLanguage>(context).selectPayment,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (widget.onlyCashless!)
                                Text(
                                  Provider.of<ZLanguage>(
                                    context,
                                  ).onlyDigitalPayments,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                ),

                              ///list of payment methods///
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    // ZOORYA-PAY: expand methods from the gateway.
                                    // Old flat gateway list (commented out for ZOORYA-PAY test):
                                    // final List<dynamic> allGateways =
                                    //     paymentResponse['payment_gateway'] as List<dynamic>;
                                    // final List<dynamic> visibleGateways = widget.isCombo
                                    //     ? allGateways.where((g) => ['cash', 'wallet']
                                    //         .contains(g['name'].toString().toLowerCase())).toList()
                                    //     : allGateways;

                                    // Find ZOORYA-PAY gateway and show its methods instead.
                                    final List<dynamic> allGateways =
                                        paymentResponse['payment_gateway']
                                            as List<dynamic>;
                                    final dynamic zooryaGateway = allGateways
                                        .firstWhere(
                                          (g) =>
                                              g['name']
                                                  .toString()
                                                  .toUpperCase() ==
                                              'ZOORYA-PAY',
                                          orElse: () => null,
                                        );
                                    final List<dynamic> zooryaMethods =
                                        _visiblePaymentMethods(zooryaGateway);

                                    debugPrint(
                                      '[ZOORYA-PAY] building grid '
                                      'found=${zooryaGateway != null}  '
                                      'methods=${zooryaMethods.length}  '
                                      'keys=${zooryaMethods.map((m) => m["key"]).toList()}',
                                    );
                                    return GridView.builder(
                                      shrinkWrap: true,
                                      itemCount: zooryaMethods.length,
                                      padding: EdgeInsets.symmetric(
                                        vertical: getProportionateScreenHeight(
                                          kDefaultPadding / 2,
                                        ),
                                      ),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing:
                                                getProportionateScreenWidth(
                                                  kDefaultPadding,
                                                ),
                                            mainAxisSpacing:
                                                getProportionateScreenWidth(
                                                  kDefaultPadding / 2,
                                                ),
                                          ),
                                      itemBuilder: (BuildContext ctx, index) {
                                        // ZOORYA-PAY: iterate over methods, not gateways.
                                        final method = zooryaMethods[index];
                                        // paymentName uses the method KEY for routing logic
                                        final String paymentName = method['key']
                                            .toString()
                                            .toLowerCase();
                                        // displayName uses the method NAME for the card title
                                        final String displayName =
                                            method['name'].toString();
                                        final String methodType =
                                            (method['type'] ?? 'ussd').toString();
                                        final String? methodImageUrl =
                                            method['image_url']?.toString();

                                        debugPrint(
                                          '[ZOORYA-PAY] rendering method card '
                                          '[$index] key="$paymentName" name="$displayName" type="$methodType"',
                                        );

                                        // ZOORYA-PAY image map (from backend image_url or fallback to local assets)
                                        final String zooryaImagePath =
                                            (methodImageUrl != null &&
                                                    methodImageUrl.isNotEmpty)
                                            ? methodImageUrl
                                            : paymentName == 'cash'
                                            ? 'images/payment/cod.png'
                                            : (paymentName == 'telebirr' ||
                                                paymentName == 'telebirr_qr' ||
                                                paymentName == 'telebirr inapp' ||
                                                paymentName == 'telebirr in app' ||
                                                paymentName == 'telebirr in-app')
                                            ? 'images/payment/new_payment/telebirr.png'
                                            : paymentName == 'mpesa'
                                            ? 'images/payment/new_payment/mpesa.png'
                                            : paymentName == 'nib'
                                            ? 'images/payment/new_payment/nib_bank.png'
                                            : paymentName == 'zemen'
                                            ? 'images/payment/new_payment/zemen.png'
                                            : paymentName == 'ethswitch_qr'
                                            ? 'images/payment/new_payment/ethswitch.png'
                                            : paymentName == 'dashen'
                                            ? 'images/payment/dashen.png'
                                            : 'images/payment/default_payment.png';

                                        return KifiyaMethodContainer(
                                          selected: kifiyaMethod == index,
                                          isSoon: false,
                                          title: displayName,
                                          kifiyaMethod: kifiyaMethod,
                                          imagePath: zooryaImagePath,
                                          // CyberSource logo is wide (Visa/Mastercard):
                                          // let it fill the badge so it stays readable.
                                          fillImage:
                                              paymentName == _cyberSourceKey,
                                          press: () async {
                                            // Select this method card
                                            setState(() {
                                              kifiyaMethod = index;
                                            });

                                            // -- Telebirr InApp --
                                            if (paymentName == 'telebirr inapp' ||
                                                paymentName == 'telebirr in app' ||
                                                paymentName == 'telebirr in-app') {
                                              setState(() {
                                                _selectedPaymentMethod = paymentName;
                                              });
                                              _startTelebirrInApp();
                                              return;
                                            }

                                            // -- Cash on Delivery --
                                            if (paymentName == 'cash') {
                                              if (widget.onlyCashless!) {
                                                Service.showMessage(
                                                  context: context,
                                                  title: Provider.of<ZLanguage>(
                                                    context,
                                                    listen: false,
                                                  ).onlyDigitalPayments,
                                                  duration: 5,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              } else {
                                                setState(() {
                                                  _selectedPaymentMethod = "cash";
                                                });
                                                await useBorsa();
                                              }
                                              return;
                                            }

                                            // -- CyberSource card (Visa / Mastercard, 3-D Secure) via WebView --
                                            if (paymentName == _cyberSourceKey) {
                                              _showProceedToPayDialog(
                                                displayName: displayName,
                                                onProceed: () => _startCyberSource(
                                                  displayName: displayName,
                                                ),
                                              );
                                              return;
                                            }

                                            // -- ZOORYA-PAY: Telebirr USSD (Shows Telebirr USSD Screen matching design, then calls USSD) --
                                            if (paymentName == 'telebirr') {
                                              _showProceedToPayDialog(
                                                displayName: displayName,
                                                type: methodType,
                                                onProceed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => TelebirrUssd(
                                                        userId: userData['user']['_id'],
                                                        serverToken: userData['user']['server_token'],
                                                        hisab: widget.price!,
                                                        traceNo: widget.orderPaymentUniqueId!,
                                                        uniqueId: widget.orderPaymentUniqueId!,
                                                        phone: userData['user']['phone'] ?? '',
                                                        orderPaymentId: widget.orderPaymentId!,
                                                        isZooryaPay: true,
                                                        imageUrl: methodImageUrl,
                                                        type: methodType,
                                                      ),
                                                    ),
                                                  ).then((value) {
                                                    _onZooryaTelebirrResult(value);
                                                  });
                                                },
                                              );
                                              return;
                                            }

                                            // -- ZOORYA-PAY: OTP Bank methods (e.g. Zemen Bank) --
                                            if (paymentName == 'zemen') {
                                              _showProceedToPayDialog(
                                                displayName: displayName,
                                                type: methodType,
                                                onProceed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ZooryaPayOtpScreen(
                                                        method: paymentName,
                                                        displayName: displayName,
                                                        imageUrl: methodImageUrl,
                                                        amount: widget.price!,
                                                        userId: userData['user']['_id'],
                                                        serverToken: userData['user']['server_token'],
                                                        uniqueId: widget.orderPaymentUniqueId!,
                                                        orderPaymentId: widget.orderPaymentId!,
                                                      ),
                                                    ),
                                                  ).then((value) {
                                                    if (value == true) {
                                                      _boaVerify();
                                                    }
                                                  });
                                                },
                                              );
                                              return;
                                            }

                                            // -- ZOORYA-PAY: Dashen USSD (Clean White UI Screen, then polls) --
                                            if (paymentName == 'dashen') {
                                              _showProceedToPayDialog(
                                                displayName: displayName,
                                                type: methodType,
                                                onProceed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ZooryaPayUssdScreen(
                                                        method: paymentName,
                                                        displayName: displayName,
                                                        type: methodType,
                                                        imageUrl: methodImageUrl,
                                                        amount: widget.price!,
                                                        userId: userData['user']['_id'],
                                                        serverToken: userData['user']['server_token'],
                                                        uniqueId: widget.orderPaymentUniqueId!,
                                                        orderPaymentId: widget.orderPaymentId!,
                                                        phoneNumber: userData['user']['phone'] ?? '',
                                                      ),
                                                    ),
                                                  ).then((value) {
                                                    _boaVerify();
                                                  });
                                                },
                                              );
                                              return;
                                            }

                                            // -- ZOORYA-PAY: M-PESA (Dedicated clean checkout screen like Zemen) --
                                            if (paymentName == 'mpesa') {
                                              _showProceedToPayDialog(
                                                displayName: displayName,
                                                type: methodType,
                                                onProceed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ZooryaPayMpesaScreen(
                                                        displayName: displayName,
                                                        imageUrl: methodImageUrl,
                                                        amount: widget.price!,
                                                        userId: userData['user']['_id'],
                                                        serverToken: userData['user']['server_token'],
                                                        uniqueId: widget.orderPaymentUniqueId!,
                                                        orderPaymentId: widget.orderPaymentId!,
                                                        initialPhoneNumber: userData['user']['phone']?.toString(),
                                                      ),
                                                    ),
                                                  ).then((value) {
                                                    // TEST: M-PESA order is created by the backend in /admin/check_paid_order,
                                                    // so the app does NOT call create_order. Uncomment to restore:
                                                    // if (value == true) {
                                                    //   _boaVerify();
                                                    // }
                                                    if (value is Map) {
                                                      _finishBackendCreatedOrder(value);
                                                    } else if (value == true) {
                                                      _boaVerify(skipCreateOrder: true);
                                                    }
                                                  });
                                                },
                                              );
                                              return;
                                            }

                                            // -- ZOORYA-PAY: Other USSD methods (Direct to USSD, preceded by confirmation popup) --
                                            if (paymentName == 'nib' ||
                                                paymentName == 'ethswitch') {
                                              _showProceedToPayDialog(
                                                displayName: displayName,
                                                type: methodType,
                                                onProceed: () {
                                                  _startDirectZooryaPayUssd(
                                                    method: paymentName,
                                                    displayName: displayName,
                                                  );
                                                },
                                              );
                                              return;
                                            }

                                            // -- ZOORYA-PAY: QR methods (Preceded by confirmation popup) --
                                            if (paymentName == 'telebirr_qr' ||
                                                paymentName == 'ethswitch_qr') {
                                              _showProceedToPayDialog(
                                                displayName: displayName,
                                                type: methodType,
                                                onProceed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ZooryaPayQrScreen(
                                                        method: paymentName,
                                                        displayName: displayName,
                                                        imageUrl: methodImageUrl,
                                                        amount: widget.price!,
                                                        userId:
                                                            userData['user']['_id'],
                                                        serverToken:
                                                            userData['user']['server_token'],
                                                        uniqueId: widget
                                                            .orderPaymentUniqueId!,
                                                        orderPaymentId:
                                                            widget.orderPaymentId!,
                                                      ),
                                                    ),
                                                  ).then((_) => _boaVerify());
                                                },
                                              );
                                              return;
                                            }

                                            if (paymentName == "cash") {
                                              if (widget.onlyCashless!) {
                                                Service.showMessage(
                                                  context: context,
                                                  title: Provider.of<ZLanguage>(
                                                    context,
                                                    listen: false,
                                                  ).onlyDigitalPayments,
                                                  // error: false,
                                                  duration: 5,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              } else {
                                                await useBorsa();
                                              }
                                            } else if (paymentName ==
                                                "wallet") {
                                              if (widget.onlyCashless! &&
                                                  paymentResponse != null &&
                                                  paymentResponse['wallet'] <
                                                      widget.price) {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Only digital payment accepted and your balance is insufficient!",
                                                  // error: false,
                                                  duration: 5,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              } else {
                                                await useBorsa();
                                              }
                                            } else if (paymentName ==
                                                "telebirr reference") {
                                              var data = await useBorsa();
                                              if (data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay using telebirr app",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using telebirr app?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop();
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return KifiyaVerification(
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo: widget
                                                                        .orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((success) {
                                                              if (success !=
                                                                      null ||
                                                                  !success) {
                                                                if (mounted) {
                                                                  Service.showMessage(
                                                                    context:
                                                                        context,
                                                                    title:
                                                                        "Payment not completed. Please choose your payment method.",
                                                                    error: true,
                                                                  );
                                                                }
                                                              } else {
                                                                /////////old/////
                                                                // if (widget.isCourier!) {
                                                                //   _createCourierOrder();
                                                                // } else {
                                                                //   _createOrder();
                                                                // }
                                                                /////////old/////
                                                                if (widget
                                                                    .isCourier!) {
                                                                  _createCourierOrder();
                                                                } else if ((aliexpressCart !=
                                                                        null &&
                                                                    aliexpressCart!
                                                                            .cart
                                                                            .storeId ==
                                                                        cart.storeId)) {
                                                                  _createAliexpressOrder();
                                                                } else {
                                                                  _createOrder();
                                                                }
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              }
                                            } else if (paymentName == "boa") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                setState(() {
                                                  uuid = (int.parse(uuid) + 1)
                                                      .toString();
                                                });

                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        CyberSource(
                                                          url:
                                                              "https://pgw.shekla.app/cards/process?total=${widget.price}&stotal=${widget.price}&tax=0&shiping=0&order_id=${uuid}_${widget.orderPaymentUniqueId}&first=${userData['user']['first_name']}&last=${userData['user']['last_name']}&phone=251${userData['user']['phone']}&email=${userData['user']['email']}&appId=1234",
                                                        ),
                                                  ),
                                                ).then((value) {
                                                  _boaVerify();
                                                });
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                              }
                                            } else if (paymentName == "amole") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) {
                                                      return AmoleScreen(
                                                        hisab: widget.price!,
                                                        userData: userData,
                                                      );
                                                    },
                                                  ),
                                                ).then((value) {
                                                  if (value != null) {
                                                    _payOrderPayment(
                                                      otp: value,
                                                      // ZOORYA-PAY: gateway _id resolved in _payOrderPayment
                                                      paymentId: '',
                                                    );
                                                  }
                                                });
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            } else if (paymentName ==
                                                "ethswitch") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using EthSwitch",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using EthSwitch?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            setState(() {
                                                              uuid =
                                                                  (int.parse(
                                                                            uuid,
                                                                          ) +
                                                                          1)
                                                                      .toString();
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return EthSwitchScreen(
                                                                    title:
                                                                        "EthSwitch Payment Gateway",
                                                                    url:
                                                                        "https://pgw.shekla.app/ethioSwitch/initiate",
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        uuid +
                                                                        '_' +
                                                                        widget
                                                                            .orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _ethSwitchVerify(
                                                                uuid +
                                                                    '_' +
                                                                    widget
                                                                        .orderPaymentUniqueId!,
                                                              );
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            } else if (paymentName ==
                                                "etta card") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using Loyalty Card",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using ETTA Loyalty Card?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            setState(() {
                                                              uuid =
                                                                  (int.parse(
                                                                            uuid,
                                                                          ) +
                                                                          1)
                                                                      .toString();
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return EttaCardScreen(
                                                                    url:
                                                                        "$BASE_URL/admin/pay_payment_ettacard",
                                                                    amount: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        uuid +
                                                                        '_' +
                                                                        widget
                                                                            .orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            } else if (paymentName ==
                                                "santimpay") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using SantimPay",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using SantimPay?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            setState(() {
                                                              uuid =
                                                                  (int.parse(
                                                                            uuid,
                                                                          ) +
                                                                          1)
                                                                      .toString();
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return SantimPay(
                                                                    title:
                                                                        "SantimPay Payment",
                                                                    url:
                                                                        "$BASE_URL/api/santimpay/generatepaymenturl",
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        uuid +
                                                                        '_' +
                                                                        widget
                                                                            .orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            } else if (paymentName == "chapa") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using Chapa",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using Chapa?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            setState(() {
                                                              uuid =
                                                                  (int.parse(
                                                                            uuid,
                                                                          ) +
                                                                          1)
                                                                      .toString();
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return ChapaScreen(
                                                                    title:
                                                                        "Chapa Payment Gateway",
                                                                    url:
                                                                        "$BASE_URL/api/chapa/generatepaymenturl",
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        uuid +
                                                                        '_' +
                                                                        widget
                                                                            .orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            } else if (paymentName ==
                                                "cbe birr") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using CBE Birr",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using CBE Birr?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();

                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return CbeUssd(
                                                                    userId:
                                                                        userData['user']['_id'],
                                                                    serverToken:
                                                                        userData['user']['server_token'],
                                                                    url:
                                                                        "https://pgw.shekla.app/cbe/ussd/request",
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo: widget
                                                                        .orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            } else if (paymentName ==
                                                "tele birr") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay using telebirr ussd",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using telebirr?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            var uniqueId =
                                                                RandomDigits.getString(
                                                                  6,
                                                                );
                                                            String
                                                            uniqueIdString = '';
                                                            Navigator.of(
                                                              context,
                                                            ).pop();

                                                            setState(() {
                                                              uniqueIdString =
                                                                  uniqueId;
                                                            });

                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return TelebirrUssd(
                                                                    userId:
                                                                        userData['user']['_id'],
                                                                    serverToken:
                                                                        userData['user']['server_token'],
                                                                    url:
                                                                        "http://196.189.44.60:8069/telebirr/ussd/send_sms", // New configuration: odoo server ip,
                                                                    // "https://pgw.shekla.app/telebirr/ussd/send_sms",
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        "${uniqueIdString}_${widget.orderPaymentUniqueId!}",
                                                                    // widget.orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            }
                                            ///**************************Dashen mastercard***************************************
                                            else if (paymentName ==
                                                "dashen mastercard") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using Mastercard",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using Dashen Mastercard?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return DashenMasterCard(
                                                                    url:
                                                                        "https://pgw.shekla.app/dashenMpgs/mastercard/api/checkout",
                                                                    amount: widget
                                                                        .price!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    traceNo: widget
                                                                        .orderPaymentUniqueId!,
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                    currency: Provider.of<ZMetaData>(
                                                                      context,
                                                                      listen:
                                                                          false,
                                                                    ).currency,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            }
                                            ///*******************************Dashen mastercard*******************************
                                            ///////////***********************Star Pay*************************************///
                                            else if (paymentName == "starpay") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using StarPay",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using StarPay?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return StarPayScreen(
                                                                    url:
                                                                        "https://pgw.shekla.app/star_pay/pay/payment",
                                                                    amount: widget
                                                                        .price!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    email:
                                                                        userData['user']['email'],
                                                                    firstName:
                                                                        userData['user']['first_name'],
                                                                    lastName:
                                                                        userData['user']['last_name'],
                                                                    traceNo: widget
                                                                        .orderPaymentUniqueId!,
                                                                    items: cart
                                                                        .items!,
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            }
                                            //********************************Star Pay end******************************************///
                                            ///**************************Telebirr InApp***************************************
                                            else if (paymentName ==
                                                    "telebirr inapp" ||
                                                paymentName ==
                                                    "telebirr in app" ||
                                                paymentName ==
                                                    "telebirr in-app") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay using telebirr app",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using telebirr in-app?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            var uniqueId =
                                                                RandomDigits.getString(
                                                                  6,
                                                                );
                                                            String
                                                            uniqueIdString = '';
                                                            Navigator.of(
                                                              context,
                                                            ).pop();

                                                            setState(() {
                                                              uniqueIdString =
                                                                  uniqueId;
                                                              inAppTraceNumber =
                                                                  "${kTelebirrInAppTraceKey}${widget.orderPaymentUniqueId!}TELE$uniqueIdString";
                                                              _selectedPaymentMethod =
                                                                  paymentName;
                                                            });

                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return TelebirrInApp(
                                                                    context:
                                                                        context,
                                                                    amount: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        inAppTraceNumber,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                  );
                                                                },
                                                              ),
                                                            ).then((
                                                              value,
                                                            ) async {
                                                              // DISABLED: _boaVerify callback — using query/polling only

                                                              // Guard: if an order was already
                                                              // placed for this payment, never
                                                              // create a second one. Prevents the
                                                              // polling path from producing duplicate
                                                              // orders on re-entry / concurrent polls.
                                                              if (_orderPlaced)
                                                                return;

                                                              final isPaid =
                                                                  await pollTelebirrStatus(
                                                                    merchOrderId:
                                                                        inAppTraceNumber,
                                                                  );

                                                              // debugPrint('###[Telebirr] pollTelebirrStatus result: $isPaid', );

                                                              if (!mounted)
                                                                return;

                                                              // Re-check after the await: another
                                                              // poll/callback may have placed the
                                                              // order while we were waiting.
                                                              if (_orderPlaced)
                                                                return;

                                                              if (isPaid) {
                                                                // Claim the order before creating it
                                                                // so no other path can create again.
                                                                _orderPlaced =
                                                                    true;
                                                                Service.showMessage(
                                                                  context:
                                                                      context,
                                                                  error: false,
                                                                  title:
                                                                      "Telebirr payment confirmed.",
                                                                );

                                                                // FOR TESTING TELEBIRR INAPP: commented out create order endpoint
                                                                // if (widget
                                                                //     .isCourier!) {
                                                                //   _createCourierOrder();
                                                                // } else if (aliexpressCart !=
                                                                //         null &&
                                                                //     aliexpressCart!
                                                                //             .cart
                                                                //             .storeId ==
                                                                //         cart.storeId) {
                                                                //   _createAliexpressOrder();
                                                                // } else {
                                                                //   _createOrder();
                                                                // }
                                                              } else {
                                                                Service.showMessage(
                                                                  context:
                                                                      context,
                                                                  title:
                                                                      "Payment was not completed or timed out. Please try again or contact support.",
                                                                  error: true,
                                                                );
                                                                setState(() {
                                                                  kifiyaMethod =
                                                                      -1;
                                                                });
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            }
                                            ///*******************************Telebirr InApp*******************************
                                            ///
                                            ///
                                            ///*******************************Addis Pay*******************************
                                            else if (paymentName ==
                                                "addis pay") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using AddisPay",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using Addis Pay?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            var uniqueId =
                                                                RandomDigits.getString(
                                                                  6,
                                                                );
                                                            String
                                                            uniqueIdString = '';
                                                            Navigator.of(
                                                              context,
                                                            ).pop();

                                                            setState(() {
                                                              uniqueIdString =
                                                                  uniqueId;
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return AddisPay(
                                                                    url:
                                                                        "https://pgw.shekla.app/addispay/api/checkout",
                                                                    amount: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        "${widget.orderPaymentUniqueId!}_${uniqueIdString}",
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    firstName:
                                                                        userData['user']["first_name"],
                                                                    lastName:
                                                                        userData['user']["last_name"],
                                                                    email:
                                                                        userData['user']["email"],
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            }
                                            ///*******************************Addis Pay*******************************
                                            ///
                                            ///
                                            ///*******************************Yagout Pay*******************************
                                            else if (paymentName ==
                                                "yagoutpay") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using YagoutPay",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using YagoutPay?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            var uniqueId =
                                                                RandomDigits.getString(
                                                                  6,
                                                                );
                                                            String
                                                            uniqueIdString = '';
                                                            Navigator.of(
                                                              context,
                                                            ).pop();

                                                            setState(() {
                                                              uniqueIdString =
                                                                  uniqueId;
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return YagoutPay(
                                                                    url:
                                                                        "https://pgw.shekla.app/yagout/payment_link",
                                                                    amount: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        "${widget.orderPaymentUniqueId!}_${uniqueIdString}",
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    firstName:
                                                                        userData['user']["first_name"],
                                                                    lastName:
                                                                        userData['user']["last_name"],
                                                                    email:
                                                                        userData['user']["email"],
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            }
                                            //////////////////////////////// Yagout Pay ///////////////////////////////////////
                                            ///**************************MoMo***************************************
                                            //    else if (paymentResponse['payment_gateway']
                                            //               [index]['name']
                                            //           .toString()
                                            //           .toLowerCase() ==
                                            //       "momo") {
                                            //     var data = await useBorsa();
                                            //     if (data != null && data['success']) {
                                            //       showDialog(
                                            //           context: context,
                                            //           builder: (context) {
                                            //             return AlertDialog(  backgroundColor: kPrimaryColor,
                                            //               title: Text("Pay Using MoMo"),
                                            //               content: Text(
                                            //                   "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using MoMo?"),
                                            //               actions: [
                                            //                 TextButton(
                                            //                   child: Text(
                                            //                     Provider.of<ZLanguage>(
                                            //                             context)
                                            //                         .cancel,
                                            //                     style: TextStyle(
                                            //                         color: kSecondaryColor),
                                            //                   ),
                                            //                   onPressed: () {
                                            //                     Navigator.of(context).pop();
                                            //                   },
                                            //                 ),
                                            //                 TextButton(
                                            //                   child: Text(
                                            //                     Provider.of<ZLanguage>(
                                            //                             context)
                                            //                         .cont,
                                            //                     style: TextStyle(
                                            //                         color: kBlackColor),
                                            //                   ),
                                            //                   onPressed: () {
                                            //                     Navigator.of(context).pop();
                                            //                     Navigator.push(
                                            //                       context,
                                            //                       MaterialPageRoute(
                                            //                         builder: (context) {
                                            //                           return MoMoUssd(
                                            //                             userId:
                                            //                                 userData['user']
                                            //                                     ['_id'],
                                            //                             serverToken: userData[
                                            //                                     'user'][
                                            //                                 'server_token'],
                                            //                             url:
                                            //                                 'https://pgw.shekla.app/momo/makepayment',
                                            //                             hisab:
                                            //                                 widget.price!,
                                            //                             traceNo: widget
                                            //                                 .orderPaymentUniqueId!,
                                            //                             phone:
                                            //                                 userData['user']
                                            //                                     ['phone'],
                                            //                             orderPaymentId: widget
                                            //                                 .orderPaymentId!,
                                            //                           );
                                            //                         },
                                            //                       ),
                                            //                     ).then((value) {
                                            //                       _boaVerify();
                                            //                     });
                                            //                   },
                                            //                 )
                                            //               ],
                                            //             );
                                            //           });
                                            //     } else {
                                            //       ScaffoldMessenger.of(context)
                                            //           .showSnackBar(Service.showMessage1(
                                            //               "Something went wrong! Please try again!",
                                            //               true));
                                            //       setState(() {
                                            //         kifiyaMethod = -1;
                                            //       });
                                            //     }
                                            //   }
                                            ///*******************************MoMo end*******************************
                                            //////////////////////////////// Wegagen Bank ///////////////////////////////////////
                                            else if (paymentName.contains(
                                              "wegagen",
                                            )) {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using Wegagen Bank",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using Wegagen Bank?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            setState(() {
                                                              uuid =
                                                                  (int.parse(
                                                                            uuid,
                                                                          ) +
                                                                          1)
                                                                      .toString();
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return WegagenUssd(
                                                                    title:
                                                                        "Wegagen Bank Payment",
                                                                    url:
                                                                        "$BASE_URL/admin/pay_payment_wegagen_ussd_pay",
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo: widget
                                                                        .orderPaymentUniqueId!, //no uuid
                                                                    //  traceNo:  uuid +"_" +widget .orderPaymentUniqueId!, //to prevent trace number duplication
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                    orderPaymentUniqueId:
                                                                        widget
                                                                            .orderPaymentUniqueId!,
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              // Wegagen confirms payment
                                                              // synchronously, so on
                                                              // approval we create the
                                                              // order directly (no
                                                              // _boaVerify step).
                                                              if (value ==
                                                                  true) {
                                                                widget.isCourier!
                                                                    ? _createCourierOrder()
                                                                    : (aliexpressCart !=
                                                                              null &&
                                                                          aliexpressCart!.cart.storeId ==
                                                                              cart.storeId)
                                                                    ? _createAliexpressOrder()
                                                                    : _createOrder();
                                                              } else {
                                                                Service.showMessage(
                                                                  context:
                                                                      context,
                                                                  title:
                                                                      "Payment not completed. Please choose your payment method.",
                                                                  error: true,
                                                                );
                                                                setState(() {
                                                                  kifiyaMethod =
                                                                      -1;
                                                                });
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            }
                                            //////////////////////////////// Wegagen Bank end///////////////////////////////////////
                                            else if (paymentName == "zemen") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using International Card",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using International Card?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            setState(() {
                                                              uuid =
                                                                  (int.parse(
                                                                            uuid,
                                                                          ) +
                                                                          1)
                                                                      .toString();
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return Telebirr(
                                                                    url:
                                                                        "https://pgw.shekla.app/zemen/post_bill",
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        uuid +
                                                                        "_" +
                                                                        widget
                                                                            .orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                    title:
                                                                        "Master Card Payment Gateway",
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            } else if (paymentName ==
                                                "dashen") {
                                              var data = await useBorsa();
                                              if (data != null &&
                                                  data['success']) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      backgroundColor:
                                                          kPrimaryColor,
                                                      title: Text(
                                                        "Pay Using International Card",
                                                      ),
                                                      content: Text(
                                                        "Proceed to pay ${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.price!.toStringAsFixed(2)} using International Card?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cancel,
                                                            style: TextStyle(
                                                              color:
                                                                  kSecondaryColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        TextButton(
                                                          child: Text(
                                                            Provider.of<
                                                                  ZLanguage
                                                                >(context)
                                                                .cont,
                                                            style: TextStyle(
                                                              color:
                                                                  kBlackColor,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            setState(() {
                                                              uuid =
                                                                  (int.parse(
                                                                            uuid,
                                                                          ) +
                                                                          1)
                                                                      .toString();
                                                            });
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) {
                                                                  return Telebirr(
                                                                    url:
                                                                        "https://pgw.shekla.app/dashen/post_bill",
                                                                    hisab: widget
                                                                        .price!,
                                                                    traceNo:
                                                                        uuid +
                                                                        "_" +
                                                                        widget
                                                                            .orderPaymentUniqueId!,
                                                                    phone:
                                                                        userData['user']['phone'],
                                                                    orderPaymentId:
                                                                        widget
                                                                            .orderPaymentId!,
                                                                    title:
                                                                        "Dashen Payment Gateway",
                                                                  );
                                                                },
                                                              ),
                                                            ).then((value) {
                                                              _boaVerify();
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                Service.showMessage(
                                                  context: context,
                                                  title:
                                                      "Something went wrong! Please try again!",
                                                  error: true,
                                                );
                                                setState(() {
                                                  kifiyaMethod = -1;
                                                });
                                              }
                                            }
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              // SizedBox(
                              //   height: getProportionateScreenHeight(kDefaultPadding),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Place Order button moved inside the ModalProgressHUD so the
                    // loading barrier covers it and blocks taps while an order is
                    // being processed (it previously lived in bottomNavigationBar,
                    // outside the HUD, and stayed tappable).
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: getProportionateScreenHeight(
                          kDefaultPadding / 2,
                        ),
                        horizontal: getProportionateScreenHeight(
                          kDefaultPadding,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        border: Border(top: BorderSide(color: kWhiteColor)),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(kDefaultPadding),
                          topRight: Radius.circular(kDefaultPadding),
                        ),
                      ),
                      child: CustomButton(
                        isLoading: paymentResponse != null && _placeOrder,
                        title: Provider.of<ZLanguage>(context).placeOrder,
                        press: () {
                          _payOrderPayment(otp: "");
                        },
                        color: kSecondaryColor,
                      ),
                    ),
                  ],
                )
              : Container(),
        ),
      ),
    );
  }

  Future<dynamic> getPaymentGateway() async {
    final deviceType = Platform.isIOS ? "iOS" : "android";
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_payment_gateway";
    Map data = {
      "user_id": userData['user']['_id'],
      "city_id": Provider.of<ZMetaData>(context, listen: false).cityId,
      "server_token": userData['user']['server_token'],
      "store_delivery_id": widget.orderPaymentId,
      "is_user_pickup_with_schedule": widget.userpickupWithSchedule,
      "vehicleId": widget.vehicleId,
      "device_type": deviceType,
      "app_version": appVersion,
      // "device_type": "android",
      // "device_type": 'iOS',
    };
    var body = json.encode(data);
    debugPrint('┌─────────────────────────────────────────────────────');
    debugPrint('│ [PAYMENT GATEWAY] POST → $url');
    debugPrint('│ request body : $body');
    debugPrint('└─────────────────────────────────────────────────────');
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
            Duration(seconds: 20),
            onTimeout: () {
              if (mounted)
                setState(() {
                  this._loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );

      debugPrint('┌─────────────────────────────────────────────────────');
      debugPrint('│ [PAYMENT GATEWAY] HTTP ${response.statusCode}');
      debugPrint('│ raw response : ${response.body}');
      debugPrint('└─────────────────────────────────────────────────────');

      if (mounted)
        setState(() {
          this.paymentResponse = json.decode(response.body);
          this._loading = false;
        });

      return json.decode(response.body);
    } catch (e) {
      if (mounted)
        setState(() {
          this._loading = false;
        });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Something went wrong. Please check your internet connection!",
            ),
            backgroundColor: kSecondaryColor,
          ),
        );
      }
      return null;
    }
  }

  Future<dynamic> payOrderPayment(otp, paymentId, {bool isPaymentModeCash = false}) async {
    if (widget.isCombo) {
      debugPrint(
        '[COMBO-DEBUG] ▶ Step 3: combo_pay_order_payment\n'
        '  storeA_order_payment_id: ${widget.storeAOrderPaymentId ?? widget.orderPaymentId}\n'
        '  storeB_order_payment_id: ${widget.storeBOrderPaymentId}\n'
        '  otp: ${otp?.toString().isEmpty == true ? "(empty)" : "***"}',
      );
      final res = await ComboService.pay(
        context,
        userData: userData,
        originPaymentId: widget.storeAOrderPaymentId ?? widget.orderPaymentId!,
        waypointPaymentId: widget.storeBOrderPaymentId ?? "",
        otp: otp?.toString() ?? "",
      );
      debugPrint(
        '[COMBO-DEBUG] ◀ Step 3 response: ${res == null ? "NULL (timeout/network)" : res.toString()}',
      );
      if (mounted) {
        setState(() {
          this._loading = false;
        });
      }
      return res;
    }

    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/pay_order_payment";

    // if (widget.isCourier! &&
    //     services != null &&
    //     services['deliveries'] != null &&
    //     services['deliveries'].isNotEmpty) {
    //   debugPrint(
    //     "##### DEBUG: List of deliveries count: ${services['deliveries'].toString().length} \nlist of Delivery types: ${services['deliveries']} \n### Delivery at index 0: ${services['deliveries'][0]} \n### More Detail: ${services['deliveries'][0]['_id']} \nfor order_payment_id: ${widget.orderPaymentId}",
    //   );
    // }
    Map data = widget.isCourier!
        ? {
            "user_id": userData['user']['_id'],
            "otp": otp,
            "order_payment_id": widget.orderPaymentId,
            "payment_id": paymentId,
            "order_type": 7,
            "is_payment_mode_cash": isPaymentModeCash,
            "server_token": userData['user']['server_token'],
            "store_delivery_id": services['deliveries'][0]['_id'],
          }
        : {
            "user_id": userData['user']['_id'],
            "otp": otp,
            "order_payment_id": widget.orderPaymentId,
            "payment_id": paymentId,
            "is_payment_mode_cash": isPaymentModeCash,
            "server_token": userData['user']['server_token'],
          };

    var body = json.encode(data);
    debugPrint("[COMBO-DEBUG] pay_order_payment BODY: $body");
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
            Duration(seconds: 40),
            onTimeout: () {
              if (mounted)
                setState(() {
                  this._loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );
      debugPrint("[COMBO-DEBUG] pay_order_payment RESPONSE: ${response.body}");
      if (mounted)
        setState(() {
          this._loading = false;
        });

      return json.decode(response.body);
    } catch (e) {
      if (mounted)
        setState(() {
          this._loading = false;
        });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Something went wrong."),
            backgroundColor: kSecondaryColor,
          ),
        );
      }
      return null;
    }
  }

  Future<dynamic> useBorsa() async {
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/change_user_wallet_status";
    Map data = {
      "user_id": userData['user']['_id'],
      "is_use_wallet": _selectedPaymentMethod == "wallet",
      "server_token": userData['user']['server_token'],
    };

    var body = json.encode(data);
    debugPrint('[boaVerify] 🚀 Calling POST /admin/check_paid_order: $url');
    debugPrint('[boaVerify] 🚀 Request payload: $body');
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
            Duration(seconds: 20),
            onTimeout: () {
              if (mounted)
                setState(() {
                  this._loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );

      debugPrint('[boaVerify] 📥 Response status: ${response.statusCode}');
      debugPrint('[boaVerify] 📥 Response body:   ${response.body}');
      if (mounted)
        setState(() {
          this._loading = false;
        });
      return json.decode(response.body);
    } catch (e) {
      if (mounted)
        setState(() {
          this._loading = false;
        });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Something went wrong. Please check your internet connection!",
            ),
            backgroundColor: kSecondaryColor,
          ),
        );
      }
      return null;
    }
  }

  Future<dynamic> sendMaregagecha() async {
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/send_otp";

    Map data = {
      "user_id": userData['user']['_id'],
      "phone": userData['user']['phone'],
      "type": userData['user']['admin_type'],
      "token": userData['user']['server_token'],
      "country_phone_code": userData['user']['country_phone_code'],
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
            Duration(seconds: 20),
            onTimeout: () {
              if (mounted)
                setState(() {
                  this._loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );

      if (mounted)
        setState(() {
          this._loading = false;
        });

      return json.decode(response.body);
    } catch (e) {
      if (mounted)
        setState(() {
          this._loading = false;
        });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Something went wrong. Please check your internet connection!",
            ),
            backgroundColor: kSecondaryColor,
          ),
        );
      }
      return null;
    }
  }

  Future<dynamic> amoleAddToBorsa() async {
    setState(() {
      _loading = true;
      linearProgressIndicator = Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitWave(
              color: kSecondaryColor,
              size: getProportionateScreenWidth(kDefaultPadding),
            ),
            SizedBox(height: kDefaultPadding * 0.5),
            Text(
              "Adding fund to wallet...",
              style: TextStyle(color: kBlackColor),
            ),
          ],
        ),
      );
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/add_wallet_amount";

    Map data = {
      "user_id": userData['user']['_id'],
      "payment_id": paymentResponse['payment_gateway'][0]['_id'],
      "otp": otp,
      "type": userData['user']['admin_type'],
      "server_token": userData['user']['server_token'],
      "wallet": topUpAmount,
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
            Duration(seconds: 20),
            onTimeout: () {
              if (mounted)
                setState(() {
                  this._loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );

      if (mounted)
        setState(() {
          this._loading = false;
        });

      return json.decode(response.body);
    } catch (e) {
      if (mounted)
        setState(() {
          this._loading = false;
        });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Something went wrong. Please check your internet connection!",
            ),
            backgroundColor: kSecondaryColor,
          ),
        );
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Combo failed-order telemetry (§combo-telemetry)
  // Called when create_order fails for a combo AFTER payment has been taken.
  // Mirrors _logFailedOrderAfterPayment but carries combo-specific fields.
  // ---------------------------------------------------------------------------
  Future<void> _logFailedComboOrder({
    required String reason,
    required double amount,
  }) async {
    try {
      final Map<String, dynamic> record = {
        'timestamp': DateTime.now().toIso8601String(),
        'combo_id': widget.comboId ?? '',
        'store_a_order_payment_id': widget.storeAOrderPaymentId ?? '',
        'store_b_order_payment_id': widget.storeBOrderPaymentId ?? '',
        'order_payment_unique_id': widget.orderPaymentUniqueId ?? '',
        'amount': amount,
        'user_id': userData['user']['_id'],
        'user_phone': userData['user']['phone'],
        'reason': reason,
        'is_combo': true,
      };

      // Persist locally so the user can reference it when contacting support
      List<dynamic> failedOrders = await Service.read('failed_orders') ?? [];
      failedOrders.add(record);
      await Service.save('failed_orders', failedOrders);

      // Best-effort backend notification (same endpoint as single-store)
      try {
        final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
        await http
            .post(
              Uri.parse("$baseUrl/api/user/log_failed_order"),
              headers: {"Content-Type": "application/json"},
              body: json.encode(record),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Silent fail — local log is the primary record
      }
    } catch (_) {
      // Never crash the payment flow due to telemetry
    }
  }

  /// SECURITY: Log failed order after successful payment for support team to process refund
  Future<void> _logFailedOrderAfterPayment({
    required String reason,
    required String paymentId,
    required double amount,
  }) async {
    try {
      // Store failed order info locally for user reference
      Map<String, dynamic> failedOrder = {
        'timestamp': DateTime.now().toIso8601String(),
        'order_payment_id': widget.orderPaymentId,
        'order_payment_unique_id': widget.orderPaymentUniqueId,
        'amount': amount,
        'user_id': userData['user']['_id'],
        'user_phone': userData['user']['phone'],
        'reason': reason,
        'payment_id': paymentId,
        'is_courier': true,
      };

      // Store in local storage for user to reference when contacting support
      List<dynamic> failedOrders = await Service.read('failed_orders') ?? [];
      failedOrders.add(failedOrder);
      await Service.save('failed_orders', failedOrders);

      // Try to notify backend about the failed order (best effort)
      try {
        var url =
            "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/log_failed_order";
        await http
            .post(
              Uri.parse(url),
              headers: {"Content-Type": "application/json"},
              body: json.encode(failedOrder),
            )
            .timeout(Duration(seconds: 5));
      } catch (_) {
        // Silent fail - local log is primary
      }

      // debugPrint(
      //   "SECURITY: Logged failed order after payment - ID: ${widget.orderPaymentId}, Amount: $amount, Reason: $reason",
      // );
    } catch (e) {
      // debugPrint("Error logging failed order: $e");
    }
  }

  Future<dynamic> createCourierOrder() async {
    setState(() {
      linearProgressIndicator = Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitWave(
              color: kSecondaryColor,
              size: getProportionateScreenWidth(kDefaultPadding),
            ),
            SizedBox(height: kDefaultPadding * 0.5),
            Text(
              "Creating courier order...",
              style: TextStyle(color: kBlackColor),
            ),
          ],
        ),
      );
    });
    // var url ="${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/create_order";
    var url =
        _selectedPaymentMethod == "telebirr inapp" ||
            _selectedPaymentMethod == "telebirr in app" ||
            _selectedPaymentMethod == "telebirr in-app"
        ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/create_order_for_telebirr_inapp"
        : "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/create_order";
    var postUri = Uri.parse(url);
    try {
      http.MultipartRequest request = new http.MultipartRequest("POST", postUri)
        ..fields['user_id'] = userData['user']['_id']
        ..fields['server_token'] = userData['user']['server_token']
        ..fields['cart_id'] = courierCart['cart_id']
        ..fields['delivery_type'] = "2"
        ..fields['paid_by'] = paidBySender ? "1" : "2"
        ..fields['is_schedule_order'] = isCourierSchedule ? "true" : "false"
        ..fields['schedule_order_start_at'] = isCourierSchedule
            ? courierScheduleDate
            : ""
        ..fields['vehicle_id'] = widget.vehicleId!
        // Idempotency key: backend should return the existing order for a
        // repeated call with the same unique id instead of creating a duplicate.
        ..fields['order_payment_unique_id'] = widget.orderPaymentUniqueId!;
      if (imagePath != null && imagePath.length > 0) {
        // Validate all image paths using the shared service
        final batch = await ImageUploadService.validateBatch(imagePath);

        // If every image failed validation, stop the order
        if (batch.allFailed) {
          if (mounted)
            setState(() {
              _loading = false;
              _placeOrder = false;
            });

          if (!mounted) return null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "All images failed validation (${batch.issues.map((i) => i.label).join('; ')}). "
                "Please go back and select images again.",
                style: TextStyle(color: kPrimaryColor),
              ),
              backgroundColor: kSecondaryColor,
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: "OK",
                textColor: kPrimaryColor,
                onPressed: () {},
              ),
            ),
          );

          return null;
        }

        // If some (but not all) images had issues, warn but continue with valid ones
        if (batch.hasIssues) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${batch.issues.length} image(s) skipped (${batch.issues.map((i) => i.label).join('; ')}). "
                "Continuing with ${batch.validPaths.length} valid image(s).",
                style: TextStyle(color: kPrimaryColor),
              ),
              backgroundColor: kSecondaryColor,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Upload valid images
        if (batch.hasValid) {
          setState(() {
            linearProgressIndicator = Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitWave(
                    color: kSecondaryColor,
                    size: getProportionateScreenWidth(kDefaultPadding),
                  ),
                  SizedBox(height: kDefaultPadding * 0.5),
                  Text(
                    "Uploading ${batch.validPaths.length} image(s)...",
                    style: TextStyle(color: kBlackColor),
                  ),
                ],
              ),
            );
          });

          for (var i = 0; i < batch.validPaths.length; i++) {
            try {
              http.MultipartFile multipartFile = await http
                  .MultipartFile.fromPath('file', batch.validPaths[i]);
              request.files.add(multipartFile);
            } catch (e) {
              // Skip files that fail to attach (e.g., deleted between validation and attach)
              //debugPrint('Failed to attach image: ${batch.validPaths[i]} - $e');
            }
          }
        }
      }
      await request
          .send()
          .then((response) async {
            http.Response.fromStream(response).then((value) async {
              var data = json.decode(value.body);
              // debugPrint( "courier order data>> $data\n_selectedPaymentMethod $_selectedPaymentMethod",);
              if (data != null && data['success']) {
                if (data['duplicate'] != null && data['duplicate'] == true) {
                  // debugPrint("order duplicated>> ${data['duplicate']}}");
                  // duplicate logic
                  Service.showMessage(
                    context: context,
                    title:
                        "This order has already been placed. Please check your order history.",
                    // error: true,
                  );
                } else {
                  // debugPrint("order duplicated>> ${data['duplicate']}}");
                  // normal success logic
                  if (mounted)
                    Service.showMessage(
                      context: context,
                      title: "Order successfully created",
                      error: false,
                    );
                  await Service.remove("images");
                  if (mounted)
                    setState(() {
                      _loading = false;
                      _placeOrder = false;
                    });
                  // Navigate to report screen with isCourier flag for proper back navigation
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportScreen(
                        price: widget.price,
                        orderPaymentUniqueId: widget.orderPaymentUniqueId,
                        isCourier: true,
                      ),
                    ),
                  );
                }
              } else {
                if (mounted)
                  setState(() {
                    _loading = false;
                    _placeOrder = false;
                  });
                if (mounted)
                  Service.showMessage(
                    context: context,
                    title:
                        "${errorCodes['${data['error_code']}'] ?? 'Something went wrong'}!",
                    error: true,
                  );
                // print("else error>>> ${data['error_code']}");

                // SECURITY: Log failed order when API returns error
                await _logFailedOrderAfterPayment(
                  reason:
                      "API error: ${data['error_code']} - ${errorCodes['${data['error_code']}']}",
                  paymentId: kifiyaMethod != -1
                      ? paymentResponse['payment_gateway'][kifiyaMethod]['_id'] ??
                            ''
                      : '',
                  amount: widget.price ?? 0.0,
                );

                await Future.delayed(Duration(seconds: 2));
                if (data['error_code'] == 999) {
                  await Service.saveBool('logged', false);
                  await Service.remove('user');
                  Navigator.pushReplacementNamed(
                    context,
                    LoginScreen.routeName,
                  );
                } else {
                  // Show support message for non-auth errors
                  Service.showMessage(
                    context: context,
                    title:
                        "If payment was deducted, contact support at 8707. Ref: ${widget.orderPaymentUniqueId}",
                    error: true,
                    duration: 8,
                  );
                }
              }
              return json.decode(value.body);
            });
          })
          .timeout(
            Duration(seconds: 40),
            onTimeout: () {
              if (mounted)
                setState(() {
                  _loading = false;
                  this._placeOrder = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );
    } catch (e) {
      // print("catch error>>> $e");

      String errorMessage =
          "Something went wrong. Please check your internet connection!";
      bool clearImages = false;

      // Detect file-related errors
      if (e.toString().contains('FileSystemException') ||
          e.toString().contains('No such file') ||
          e.toString().contains('Cannot open file')) {
        errorMessage =
            "Image upload failed. Some images may be missing. "
            "Please go back and re-select your images, then try again.";
        clearImages = true;
      } else if (e is TimeoutException) {
        errorMessage =
            "Request timed out. Please check your internet connection and try again.";
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException')) {
        errorMessage =
            "Network error. Please check your internet connection and try again.";
      }

      if (mounted)
        setState(() {
          this._loading = false;
          this._placeOrder = false;
        });

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: kSecondaryColor,
            duration: Duration(seconds: 5),
          ),
        );

      // Only clear images if they're actually invalid (not network errors)
      if (clearImages) {
        await Service.remove("images");
      }

      // SECURITY: Log failed order after payment was already processed
      // This helps support team track orders that need refunds
      await _logFailedOrderAfterPayment(
        reason: "Order creation failed after payment: $e",
        paymentId: kifiyaMethod != -1
            ? paymentResponse['payment_gateway'][kifiyaMethod]['_id'] ?? ''
            : '',
        amount: widget.price ?? 0.0,
      );

      // Show additional message about contacting support
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          Service.showMessage(
            context: context,
            title:
                "If payment was deducted, please contact support at 8707 with reference: ${widget.orderPaymentUniqueId}",
            error: true,
            duration: 5,
          );
        }
      });

      return null;
    }
  }

  Future<dynamic> createAliexpressOrder() async {
    // debugPrint("in createAliexpressOrder>>>");
    var aliOrderResponse;
    var mobile_no = cart.phone.isNotEmpty
        ? cart.phone
        : "${userData['user']['phone']}";
    var full_name = cart.userName.isNotEmpty
        ? cart.userName
        : "${userData['user']['first_name']} ${userData['user']['last_name']}";

    // Extract cart and product details from AliExpressCart
    Cart alicart = aliexpressCart!.cart;
    List<String>? itemIds = aliexpressCart!.itemIds;
    List<int>? productIds = aliexpressCart!.productIds;
    // debugPrint("alicart.items: ${alicart.items!.map((item) => item.toJson()).toList()}");
    // debugPrint("alicart.items length: ${alicart.items!.length}");
    // debugPrint("productIds:${productIds!} length: ${productIds.length}");
    // debugPrint("itemIds: ${itemIds} length: ${itemIds!.length}");

    List<Map<String, dynamic>> productItems = [];
    alicart.items!.asMap().forEach((index, item) {
      if (index < productIds!.length && index < itemIds!.length) {
        productItems.add({
          "product_count": item.quantity,
          "product_id": productIds[index],
          "sku_attr": itemIds[index],
          "product_price": {
            // "currency_code": "ETB",
            "price": item.price,
          },
        });
      }
      // else {debugPrint("Index $index out of range for productIds or itemIds");}
    });
    // debugPrint("productItems>>> $productItems");
    setState(() {
      linearProgressIndicator = Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitWave(
              color: kSecondaryColor,
              size: getProportionateScreenWidth(kDefaultPadding),
            ),
            SizedBox(height: kDefaultPadding * 0.5),
            Text("Creating order...", style: TextStyle(color: kBlackColor)),
          ],
        ),
      );
    });
    // debugPrint('Cart items: ${aliexpressCart!.cart.items}');
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/admin/aliexpress_creat_order";
    if (productItems.isNotEmpty) {
      try {
        Map data = {
          "access_token": aliExpressAccessToken,
          "full_name": full_name,
          "mobile_no": mobile_no,
          "product_items": productItems,
          // Idempotency key: backend should return the existing order for a
          // repeated call with the same unique id instead of creating a duplicate.
          "order_payment_unique_id": widget.orderPaymentUniqueId,
        };
        var body = json.encode(data);
        // debugPrint("body $body");
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
              Duration(seconds: 50),
              onTimeout: () {
                if (mounted)
                  setState(() {
                    this._loading = false;
                  });
                throw TimeoutException("The connection has timed out!");
              },
            );
        if (mounted)
          setState(() {
            aliOrderResponse = json.decode(response.body);
          });
        return aliOrderResponse;
      } catch (e) {
        if (mounted)
          setState(() {
            this._loading = false;
          });

        if (mounted)
          Service.showMessage(
            context: context,
            title:
                "Failed to create aliexpress order, please check your internet and try again",
            error: true,
          );
        return null;
      }
    }
  }

  Future<dynamic> createOrder({List<dynamic>? orderIds}) async {
    setState(() {
      linearProgressIndicator = Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitWave(
              color: kSecondaryColor,
              size: getProportionateScreenWidth(kDefaultPadding),
            ),
            SizedBox(height: kDefaultPadding * 0.5),
            Text("Creating order...", style: TextStyle(color: kBlackColor)),
          ],
        ),
      );
    });

    if (widget.isCombo) {
      // ── Retry loop with exponential back-off (§combo-retry) ──────────────
      // Attempts: 1, 2, 3.  Delays between attempts: 1 s, 2 s.
      // A null response means network/timeout — safe to retry.
      // A non-null response (success OR a known API error) stops immediately
      // so we never double-charge.
      Map<String, dynamic>? res;
      const int _maxAttempts = 3;
      for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
        debugPrint(
          '[COMBO-DEBUG] ▶ Step 4: combo_create_order attempt $attempt/$_maxAttempts\n'
          '  combo_id       : ${widget.comboId}\n'
          '  storeA_cart_id : ${widget.storeACartId}\n'
          '  storeB_cart_id : ${widget.storeBCartId}',
        );
        res = await ComboService.createOrder(
          context,
          userData: userData,
          comboId: widget.comboId ?? "",
          originCartId: widget.storeACartId ?? "",
          waypointCartId: widget.storeBCartId ?? "",
        );
        debugPrint(
          '[COMBO-DEBUG] ◀ Step 4 attempt $attempt response: '
          '${res == null ? "NULL (timeout/network) — will retry" : res.toString()}',
        );
        // Stop on any non-null body: the server replied, so retrying could
        // duplicate the order even if success == false.
        if (res != null) break;
        // null == network error / timeout — wait before next attempt
        if (attempt < _maxAttempts) {
          await Future.delayed(Duration(seconds: attempt)); // 1 s, then 2 s
        }
      }
      if (mounted) {
        setState(() {
          orderResponse = res;
          this._loading = false;
        });
      }
      return res;
    }

    // var url ="${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/create_order";
    var url =
        _selectedPaymentMethod == "telebirr inapp" ||
            _selectedPaymentMethod == "telebirr in app" ||
            _selectedPaymentMethod == "telebirr in-app"
        ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/create_order_for_telebirr_inapp"
        : "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/create_order";
    ;
    try {
      List<dynamic>? filteredOrderIds;
      if (aliexpressCart != null &&
          aliexpressCart!.cart.storeId == cart.storeId) {
        filteredOrderIds = orderIds; // Pass the orderIds
      }
      Map data = {
        "user_id": userData['user']['_id'],
        "cart_id": userData['user']['cart_id'],
        "is_schedule_order": cart.isSchedule,
        "schedule_order_start_at": cart.scheduleStart != null && cart.isSchedule
            ? cart.scheduleStart?.toUtc().toString()
            : "",
        "server_token": userData['user']['server_token'],
        // Idempotency key: backend should return the existing order for a
        // repeated call with the same unique id instead of creating a duplicate.
        "order_payment_unique_id": widget.orderPaymentUniqueId,
        if (filteredOrderIds != null) "aliexpress_order_ids": filteredOrderIds,
      };
      var body = json.encode(data);
      debugPrint("[COMBO-DEBUG] create_order URL: $url");
      debugPrint("[COMBO-DEBUG] create_order BODY: $body");
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
            Duration(seconds: 50),
            onTimeout: () {
              if (mounted)
                setState(() {
                  this._loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );
      debugPrint("[COMBO-DEBUG] create_order RESPONSE: ${response.body}");
      if (mounted)
        setState(() {
          orderResponse = json.decode(response.body);
        });
      return orderResponse;
    } catch (e) {
      if (mounted)
        setState(() {
          this._loading = false;
          this._placeOrder = false;
        });

      if (mounted)
        Service.showMessage(
          context: context,
          title:
              "Failed to create order, please check your internet and try again",
          error: true,
        );
      return null;
    }
  }
  ////old createOrder(): which is before aliexpress integration
  // Future<dynamic> createOrder() async {
  //   setState(() {
  //     linearProgressIndicator = Container(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           SpinKitWave(
  //             color: kSecondaryColor,
  //             size: getProportionateScreenWidth(kDefaultPadding),
  //           ),
  //           SizedBox(height: kDefaultPadding * 0.5),
  //           Text(
  //             "Creating order...",
  //             style: TextStyle(color: kBlackColor),
  //           ),
  //         ],
  //       ),
  //     );
  //   });
  //   var url =
  //       "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/create_order";
  //   try {
  //     Map data = {
  //       "user_id": userData['user']['_id'],
  //       "cart_id": userData['user']['cart_id'],
  //       "is_schedule_order": cart.isSchedule != null ? cart.isSchedule : false,
  //       "schedule_order_start_at": cart.scheduleStart != null &&
  //               cart.isSchedule != null &&
  //               cart.isSchedule
  //           ? cart.scheduleStart?.toUtc().toString()
  //           : "",
  //       "server_token": userData['user']['server_token'],
  //     };
  //     var body = json.encode(data);
  //     http.Response response;
  //     response = await http
  //         .post(
  //       Uri.parse(url),
  //       headers: <String, String>{
  //         "Content-Type": "application/json",
  //         "Accept": "application/json"
  //       },
  //       body: body,
  //     )
  //         .timeout(
  //       Duration(seconds: 50),
  //       onTimeout: () {
  //         setState(() {
  //           this._loading = false;
  //         });
  //         throw TimeoutException("The connection has timed out!");
  //       },
  //     );
  //     setState(() {
  //       orderResponse = json.decode(response.body);
  //     });

  //     return orderResponse;
  //   } catch (e) {
  //     setState(() {
  //       this._loading = false;
  //       this._placeOrder = false;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       Service.showMessage(
  //         "Failed to create order, please check your internet and try again",
  //         true,
  //       ),
  //     );
  //     return null;
  //   }
  // }
  //////////////
  Future<dynamic> userDetails() async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_detail";
    Map data = {
      "user_id": userData['user']['_id'],
      "server_token": userData['user']['server_token'],
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
            Duration(seconds: 30),
            onTimeout: () {
              if (mounted)
                Service.showMessage(
                  context: context,
                  title: "Network error",
                  error: true,
                );
              if (mounted)
                setState(() {
                  _loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );
      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      return null;
    }
  }

  Future<dynamic> boaVerify({String title = "Verifying payment..."}) async {
    setState(() {
      linearProgressIndicator = Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitWave(
              color: kSecondaryColor,
              size: getProportionateScreenWidth(kDefaultPadding),
            ),
            SizedBox(height: kDefaultPadding * 0.5),
            Text(title, style: TextStyle(color: kBlackColor)),
          ],
        ),
      );
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/admin/check_paid_order";
    Map data = {
      "user_id": userData['user']['_id'],
      "server_token": userData['user']['server_token'],
      "order_payment_id": widget.orderPaymentId,
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
            Duration(seconds: 30),
            onTimeout: () {
              if (mounted)
                setState(() {
                  this._loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );

      if (mounted)
        setState(() {
          this._loading = false;
        });
      return json.decode(response.body);
    } catch (e) {
      if (mounted)
        setState(() {
          this._loading = false;
        });
      if (mounted)
        Service.showMessage(
          context: context,
          title: "Failed to verify payment. Check you internet and try again",
          error: true,
          duration: 4,
        );
      return null;
    }
  }

  Future<dynamic> ethSwitchVerify({
    String title = "Verifying payment...",
    required String traceNo,
  }) async {
    setState(() {
      linearProgressIndicator = Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitWave(
              color: kSecondaryColor,
              size: getProportionateScreenWidth(kDefaultPadding),
            ),
            SizedBox(height: kDefaultPadding * 0.5),
            Text(title, style: TextStyle(color: kBlackColor)),
          ],
        ),
      );
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/admin/pay_payment_etswitch";
    Map data = {
      "user_id": userData['user']['_id'],
      "server_token": userData['user']['server_token'],
      "trace_no": traceNo,
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
            Duration(seconds: 30),
            onTimeout: () {
              if (mounted)
                setState(() {
                  this._loading = false;
                });
              throw TimeoutException("The connection has timed out!");
            },
          );

      if (mounted)
        setState(() {
          this._loading = false;
        });
      return json.decode(response.body);
    } catch (e) {
      if (mounted)
        setState(() {
          this._loading = false;
        });
      if (mounted)
        Service.showMessage(
          context: context,
          title: "Failed to verify payment. Check you internet and try again",
          error: true,
          duration: 4,
        );
      return null;
    }
  }
}
