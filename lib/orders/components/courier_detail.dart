import 'dart:async';
import 'dart:convert';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zmall/orders/components/address_timeline.dart';
import 'package:zmall/orders/components/order_info_row.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/location/components/provider_location.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/order_status_row.dart';
import 'order_history_detail.dart';
//
import 'package:zmall/borsa/refund/refund_confirmation_dialog.dart';
import 'package:zmall/borsa/refund/refund_otp_sheet.dart';
import 'package:zmall/borsa/refund/refund_service.dart';

class CourierDetail extends StatefulWidget {
  const CourierDetail({
    super.key,
    this.courierData,
    required this.userId,
    this.serverToken,
    //
    required this.userPhone,
  });
  final courierData;
  final String userId;
  final String? serverToken;
  //
  final String userPhone;

  @override
  _CourierDetailState createState() => _CourierDetailState();
}

class _CourierDetailState extends State<CourierDetail> {
  String reason = "Changed my mind";
  bool _loading = false;
  var orderStatus;
  late String providerId;

  @override
  void initState() {
    super.initState();
    _getOrderStatus();
  }

  //
  // Future<void> _forceLogout() async {
  //   await Service.saveBool('logged', false);
  //   await Service.remove('user');
  //   if (!mounted) return;
  //   Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  // }

  // void _onRefundTap() {
  //   final meta = Provider.of<ZMetaData>(context, listen: false);

  //   // Build a transaction-like object from the order
  //   // so the existing RefundService / OTP sheet can work with it.
  //   final transaction = {
  //     'unique_id': widget.courierData['unique_id'] ?? widget.courierData['_id'],
  //     'from_amount': (widget.courierData['total_order_price'] as num)
  //         .toDouble(),
  //     'can_refund': true,
  //     'is_refunded': false,
  //     'wallet_description': 'Order Refund #${widget.courierData['unique_id']}',
  //     // add any extra fields your RefundService expects
  //   };

  //   final service = RefundService(
  //     userId: widget.userId,
  //     phone: widget.userPhone,
  //     context: context,
  //   );

  //   RefundOtpSheet.show(
  //     context: context,
  //     transaction: transaction,
  //     service: service,
  //     currency: meta.currency,
  //     onVerified: (result) {
  //       if (!mounted) return;

  //       RefundConfirmationDialog.show(
  //         context: this.context,
  //         verifyResult: result,
  //         transaction: transaction,
  //         service: service,
  //         currency: meta.currency,
  //         onSuccess: () {
  //           Service.showMessage(
  //             context: context,
  //             title: "Refund processed successfully!",
  //             error: false,
  //             duration: 5,
  //           );
  //           // Optionally refresh order status or pop the screen
  //           if (mounted) {
  //             _getOrderStatus(); // refresh
  //             // or Navigator.of(context).pop();
  //           }
  //         },
  //         onForceLogout: _forceLogout,
  //       );
  //     },
  //     onForceLogout: _forceLogout,
  //   );
  // }
  //

  void _getOrderStatus() async {
    var data = await getOrderStatus();
    if (data != null && data['success']) {
      setState(() {
        orderStatus = data;
        providerId = orderStatus['provider_id'];
      });
    } else {
      Service.showMessage(
        context: context,
        title: "${errorCodes['${data['error_code']}']}!",
        error: true,
      );
      if (data['error_code'] == 999) {
        await Service.saveBool('logged', false);
        await Service.remove('user');
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
  }

  void _userCancelOrder() async {
    setState(() {
      _loading = true;
    });
    var data = await userCancelOrder();
    if (data != null && data['success']) {
      Service.showMessage(
        context: context,
        title: "We're sad but you've successfully canceled your order.",
        error: false,
        duration: 5,
      );
      Navigator.of(context).pop();
    } else {
      if (data['error_code'] == 999) {
        await Service.saveBool('logged', false);
        await Service.remove('user');
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
      setState(() {
        _loading = false;
      });
      Service.showMessage(
        error: true,
        context: context,
        title: "${errorCodes['${data['error_code']}']}",
      );
    }
  }

  void _showInvoice() async {
    setState(() {
      _loading = true;
    });
    var data = await showInvoice();
    if (data != null && data['success']) {
      setState(() {
        _loading = false;
      });

      Service.showMessage(
        context: context,
        title: "Order Completed!",
        error: false,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return OrderHistoryDetail(
              orderId: widget.courierData['_id'],
              userId: widget.userId!,
              serverToken: widget.serverToken!,
            );
          },
        ),
      );
    } else {
      setState(() {
        _loading = false;
      });
      Service.showMessage(
        context: context,
        title: "${errorCodes['${data['error_code']}']}!",
        error: true,
      );
      if (data['error_code'] == 999) {
        await Service.saveBool('logged', false);
        await Service.remove('user');
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.courierData['destination_addresses'][0]['note'] ==
                  "Lunch from Home"
              ? "Lunch From Home"
              : "Courier Detail",
          style: TextStyle(color: kBlackColor),
        ),
        elevation: 1.0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(kDefaultPadding),
            vertical: getProportionateScreenHeight(kDefaultPadding),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: getProportionateScreenWidth(kDefaultPadding),
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: getProportionateScreenHeight(kDefaultPadding),
                  horizontal: getProportionateScreenWidth(kDefaultPadding),
                ),

                width: double.infinity,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  border: Border.all(color: kWhiteColor),
                  borderRadius: BorderRadius.circular(
                    getProportionateScreenWidth(kDefaultPadding / 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: getProportionateScreenWidth(kDefaultPadding / 2),
                  children: [
                    OrderStatusRow(
                      icon: HeroiconsOutline.documentText,
                      value: Provider.of<ZLanguage>(
                        context,
                        listen: false,
                      ).orderDetails,
                      title: "Pricing, and order information",
                    ),

                    Padding(
                      padding: EdgeInsets.only(
                        left: getProportionateScreenWidth(kDefaultPadding / 2),
                      ),
                      child: Column(
                        children: [
                          OrderInfoRow(
                            label: "Order ID",
                            value: "${widget.courierData['unique_id']}",
                          ),
                          OrderInfoRow(
                            label: Provider.of<ZLanguage>(
                              context,
                              listen: false,
                            ).totalOrderPrice,

                            value:
                                "${widget.courierData['total_order_price'].toStringAsFixed(2)} ${Provider.of<ZMetaData>(context, listen: false).currency}",
                          ),
                          OrderInfoRow(
                            label: "Confirmation Code",

                            value:
                                "${widget.courierData['confirmation_code_for_complete_delivery']}",
                          ),
                          OrderInfoRow(
                            label: "Order Status",

                            value:
                                widget.courierData['delivery_status'] != null &&
                                    widget.courierData['order_status'] == 7
                                ? "${order_status['${widget.courierData['delivery_status']}']}"
                                : "Pending...",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Delivery info
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: getProportionateScreenHeight(kDefaultPadding),
                  horizontal: getProportionateScreenWidth(kDefaultPadding),
                ),

                width: double.infinity,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  border: Border.all(color: kWhiteColor),
                  borderRadius: BorderRadius.circular(
                    getProportionateScreenWidth(kDefaultPadding / 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: getProportionateScreenWidth(kDefaultPadding / 2),
                  children: [
                    OrderStatusRow(
                      icon: HeroiconsOutline.truck,
                      value: "Delivery Information",
                      title: "View pickup, delivery, and address information",
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: getProportionateScreenWidth(kDefaultPadding / 2),
                      ),
                      child: Column(
                        children: [
                          OrderInfoRow(
                            label: "Reciver",
                            value:
                                "${widget.courierData['destination_addresses'][0]['user_details']['name']}",
                          ),
                          OrderInfoRow(
                            label: Provider.of<ZLanguage>(
                              context,
                              listen: false,
                            ).receiverPhone,

                            value:
                                "${Provider.of<ZMetaData>(context, listen: false).areaCode}  ${widget.courierData['destination_addresses'][0]['user_details']['phone']}",
                          ),
                          OrderInfoRow(
                            moreText: true,
                            label: "Item Description",
                            value:
                                widget.courierData['destination_addresses'][0]['note'] !=
                                    ''
                                ? widget
                                      .courierData['destination_addresses'][0]['note']
                                : "No descroption",
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: kWhiteColor.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(
                                kDefaultPadding,
                              ),
                            ),
                            margin: EdgeInsets.only(
                              top: getProportionateScreenHeight(
                                kDefaultPadding / 2,
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: getProportionateScreenHeight(
                                kDefaultPadding / 2,
                              ),
                              horizontal: getProportionateScreenWidth(
                                kDefaultPadding / 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                AddressTimelineNode(
                                  isLast: false,
                                  isPickup: true,
                                  title: "Pickup Address",
                                  address:
                                      "${widget.courierData['pickup_addresses'][0]['address']}",
                                ),

                                AddressTimelineNode(
                                  isLast: true,
                                  isPickup: false,
                                  address:
                                      "${widget.courierData['destination_addresses'][0]['address']}",

                                  title: Provider.of<ZLanguage>(
                                    context,
                                    listen: false,
                                  ).deliveryAddress,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Text(
                    //   // "Reciver Info",
                    //   Provider.of<ZLanguage>(
                    //     context,
                    //     listen: false,
                    //   ).deliveryDetails,
                    //   style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    //     color: kBlackColor,
                    //     fontWeight: FontWeight.bold,
                    //     fontSize: getProportionateScreenHeight(17),
                    //   ),
                    // ),
                    // SizedBox(
                    //   height: getProportionateScreenHeight(
                    //     kDefaultPadding * 1.5,
                    //   ),
                    // ),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Flexible(
                    //       child: OrderStatusRow(
                    //         icon: HeroiconsOutline.user,
                    //         value:
                    //             "${widget.courierData['destination_addresses'][0]['user_details']['name']}",
                    //         title: "Reciver",
                    //       ),
                    //     ),
                    //     Flexible(
                    //       child: OrderStatusRow(
                    //         icon: HeroiconsOutline.phone,
                    //         value:
                    //             "${Provider.of<ZMetaData>(context, listen: false).areaCode}  ${widget.courierData['destination_addresses'][0]['user_details']['phone']}",
                    //         title: Provider.of<ZLanguage>(
                    //           context,
                    //           listen: false,
                    //         ).receiverPhone,
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // SizedBox(
                    //   height: getProportionateScreenHeight(kDefaultPadding),
                    // ),

                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Flexible(
                    //       child: OrderStatusRow(
                    //         icon: HeroiconsOutline.mapPin,
                    //         value:
                    //             "${widget.courierData['pickup_addresses'][0]['address']}",
                    //         // "${Service.capitalizeFirstLetters(widget.courierData['store_name'])}",
                    //         title: "Pickup Address",
                    //       ),
                    //     ),
                    //     Flexible(
                    //       child: OrderStatusRow(
                    //         icon: HeroiconsOutline.mapPin,
                    //         value:
                    //             "${widget.courierData['destination_addresses'][0]['address']}",
                    //         title: Provider.of<ZLanguage>(
                    //           context,
                    //           listen: false,
                    //         ).deliveryAddress,
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // SizedBox(
                    //   height: getProportionateScreenHeight(kDefaultPadding),
                    // ),
                    // OrderStatusRow(
                    //   icon: HeroiconsOutline.bars3BottomLeft,
                    //   value:
                    //       widget.courierData['destination_addresses'][0]['note'] !=
                    //           ''
                    //       ? widget
                    //             .courierData['destination_addresses'][0]['note']
                    //       : "No descroption",
                    //   title: "Item Description",
                    // ),
                  ],
                ),
              ),

              Spacer(),
              orderStatus != null &&
                      orderStatus['provider_id'] != null &&
                      widget.courierData['order_status'] != 25 &&
                      widget.courierData['delivery_status'] != null &&
                      widget.courierData['delivery_status'] >= 9 &&
                      widget.courierData['delivery_status'] < 25
                  ? Padding(
                      padding: EdgeInsets.only(
                        bottom: getProportionateScreenHeight(kDefaultPadding),
                        left: getProportionateScreenWidth(kDefaultPadding),
                        right: getProportionateScreenWidth(kDefaultPadding),
                      ),
                      child: CustomButton(
                        title: "Track My Order",
                        press: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return ProviderLocation(
                                  providerId: orderStatus['provider_id'],
                                  providerImage: orderStatus['provider_image'],
                                  providerName:
                                      orderStatus['provider_first_name'],
                                  providerPhone: orderStatus['provider_phone'],
                                  destLat:
                                      orderStatus['destination_addresses'][0]['location'][0],
                                  destLong:
                                      orderStatus['destination_addresses'][0]['location'][1],
                                  userId: widget.userId!,
                                  serverToken: widget.serverToken!,
                                );
                              },
                            ),
                          );
                        },
                        color: kSecondaryColor,
                      ),
                    )
                  : Container(),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  widget.courierData['order_status'] == 25
                      ? Padding(
                          padding: EdgeInsets.only(
                            bottom: getProportionateScreenHeight(
                              kDefaultPadding,
                            ),
                            left: getProportionateScreenWidth(kDefaultPadding),
                            right: getProportionateScreenWidth(kDefaultPadding),
                          ),
                          child: _loading
                              ? SpinKitWave(
                                  size: getProportionateScreenWidth(
                                    kDefaultPadding,
                                  ),
                                  color: kBlackColor,
                                )
                              : CustomButton(
                                  title: "SUBMIT",
                                  press: () {
                                    _showInvoice();
                                  },
                                  color: kBlackColor,
                                ),
                        )
                      : Container(),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  widget.courierData['delivery_status'] != null &&
                          widget.courierData['delivery_status'] >= 109
                      ? Center(
                          child: TextButton(
                            onPressed: () {
                              _showDialog();
                            },
                            child: Text(
                              "Cancel",
                              style: TextStyle(color: kBlackColor),
                            ),
                          ),
                        )
                      : Container(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<dynamic> showInvoice() async {
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/show_invoice";
    Map data = {
      "user_id": widget.userId,
      "server_token": widget.serverToken,
      "order_id": widget.courierData['_id'],
      "is_user_show_invoice": true,
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
            Duration(seconds: 10),
            onTimeout: () {
              setState(() {
                this._loading = false;
              });
              Service.showMessage(
                context: context,
                title: "Something went wrong!",
                error: true,
              );
              throw TimeoutException("The connection has timed out!");
            },
          );
      setState(() {
        this._loading = false;
      });

      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      setState(() {
        this._loading = false;
      });
      Service.showMessage(
        error: true,
        context: context,
        title: "Your internet connection is bad!",
      );
      return null;
    }
  }

  void _showDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPrimaryColor,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height * 0.40,
        maxHeight: MediaQuery.sizeOf(context).height * 1.0,
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(context).viewInsets.bottom + kDefaultPadding / 2,
          ),
          child: SafeArea(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(kDefaultPadding),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(kDefaultPadding),
                vertical: getProportionateScreenHeight(kDefaultPadding),
              ).copyWith(top: 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: getProportionateScreenHeight(kDefaultPadding / 2),
                children: <Widget>[
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        spacing: getProportionateScreenWidth(
                          kDefaultPadding / 2,
                        ),
                        children: [
                          Text(
                            "Cancel Order?",
                            style: TextStyle(
                              fontSize: 18,
                              color: kBlackColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            color: kBlackColor,
                            HeroiconsOutline.faceFrown,
                            size: getProportionateScreenHeight(24),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          color: kBlackColor,
                          HeroiconsOutline.xCircle,
                          size: getProportionateScreenHeight(24),
                        ),
                      ),
                    ],
                  ),

                  Text("Are you sure you want to cancel the order?"),

                  // Reason field
                  Container(
                    constraints: BoxConstraints(minHeight: 120),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kGreyColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      style: TextStyle(color: kBlackColor),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      onChanged: (val) {
                        reason = val;
                      },
                      decoration: InputDecoration.collapsed(
                        hintText: "$reason",
                        hintStyle: TextStyle(color: kGreyColor),
                      ),
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      // Cancel → money goes to wallet
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _userCancelOrder();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kBlackColor,
                            backgroundColor: kWhiteColor,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      // SizedBox(width: getProportionateScreenWidth(12)),

                      // // Refund → OTP flow
                      // Expanded(
                      //   child: ElevatedButton(
                      //     onPressed: () {
                      //       Navigator.of(context).pop();
                      //       _onRefundTap();
                      //     },
                      //     style: ElevatedButton.styleFrom(
                      //       elevation: 0,
                      //       foregroundColor: kSecondaryColor,
                      //       backgroundColor: kPrimaryColor,
                      //       side: BorderSide(
                      //         color: kSecondaryColor.withValues(alpha: 0.4),
                      //       ),
                      //       padding: const EdgeInsets.symmetric(vertical: 14),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(12),
                      //       ),
                      //     ),
                      //     child: const Text(
                      //       "Refund",
                      //       style: TextStyle(
                      //         fontWeight: FontWeight.w600,
                      //         fontSize: 15,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      SizedBox(
                        width: getProportionateScreenHeight(kDefaultPadding),
                      ),

                      // Keep It
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            foregroundColor: Colors.white,
                            backgroundColor: kSecondaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Keep It",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<dynamic> getOrderStatus() async {
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_order_status";
    Map data = {
      "user_id": widget.userId,
      "server_token": widget.serverToken,
      "order_id": widget.courierData['_id'],
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
            Duration(seconds: 10),
            onTimeout: () {
              setState(() {
                this._loading = false;
              });
              Service.showMessage(
                context: context,
                title: "Something went wrong!",
                error: true,
              );
              throw TimeoutException("The connection has timed out!");
            },
          );
      setState(() {
        this._loading = false;
      });
      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      setState(() {
        this._loading = false;
      });
      Service.showMessage(
        context: context,
        title: "Your internet connection is bad!",
        error: true,
      );
      return null;
    }
  }

  Future<dynamic> userCancelOrder() async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/user_cancel_order";
    Map data = {
      "user_id": widget.userId,
      "server_token": widget.serverToken,
      "cancel_reason": reason,
      "order_id": widget.courierData['_id'],
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
            Duration(seconds: 10),
            onTimeout: () {
              Service.showMessage(
                context: context,
                title: "Network error",
                error: true,
              );
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
}


  // void _showDialogOld() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         backgroundColor: kPrimaryColor,
  //         title: Text("Keep Order"),
  //         content: Text("Are you sure you want to cancel?"),
  //         actions: <Widget>[
  //           TextButton(
  //             child: Text(
  //               "Think about it!",
  //               style: TextStyle(
  //                 color: kSecondaryColor,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //           TextButton(
  //             child: Text("Sure", style: TextStyle(color: kBlackColor)),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               _showCancelDialog();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // void _showCancelDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         backgroundColor: kPrimaryColor,
  //         title: Text("Reason ☹"),
  //         content: TextField(
  //           style: TextStyle(color: kBlackColor),
  //           keyboardType: TextInputType.text,
  //           onChanged: (val) {
  //             reason = val;
  //           },
  //           decoration: textFieldInputDecorator.copyWith(
  //             labelText: "Reason",
  //             hintText: "$reason",
  //           ),
  //         ),
  //         actions: <Widget>[
  //           TextButton(
  //             child: Text(
  //               "Think about it!",
  //               style: TextStyle(
  //                 color: kSecondaryColor,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //           TextButton(
  //             child: Text("Sure", style: TextStyle(color: kBlackColor)),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               _userCancelOrder();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
