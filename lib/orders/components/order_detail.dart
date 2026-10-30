import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:zmall/orders/components/address_timeline.dart';
import 'package:zmall/orders/components/order_info_row.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/location/components/provider_location.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/orders/components/order_history_detail.dart';
import 'package:zmall/widgets/order_status_row.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/orders/components/category_container.dart';
//
import 'package:zmall/borsa/refund/refund_confirmation_dialog.dart';
import 'package:zmall/borsa/refund/refund_otp_sheet.dart';
import 'package:zmall/borsa/refund/refund_service.dart';

class OrderDetail extends StatefulWidget {
  const OrderDetail({
    super.key,
    required this.order,
    required this.userId,
    required this.serverToken,
    //
    required this.userPhone,
  });

  final order;
  final String userId, serverToken;
  //
  final String userPhone;

  @override
  _OrderDetailState createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetail> {
  bool _loading = false;
  var responseData;
  var orderStatus;
  late String providerId;
  String reason = "Changed my mind";

  @override
  void initState() {
    super.initState();
    orderStatus = widget.order;
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
  //     'unique_id': widget.order['unique_id'] ?? widget.order['_id'],
  //     'from_amount': (widget.order['total_order_price'] as num).toDouble(),
  //     'can_refund': true,
  //     'is_refunded': false,
  //     'wallet_description': 'Order Refund #${widget.order['unique_id']}',
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

  // ---------------------------------------------------------------------------
  // Combo cross-reference banner (§order-detail-combo-banner)
  //
  // Shown at the top of the Order Status tab when this order is part of a
  // two-store combo.  Detects combo membership via:
  //   1. order['combo_id']
  //   2. order['order_payment_detail']?['combo_id']
  //
  // Tapping the banner pops back to the store-picker bottom sheet or the
  // orders list — no extra route plumbing needed.
  // ---------------------------------------------------------------------------
  String? _resolveComboId() {
    final raw = widget.order;
    final id = raw['combo_id'] ?? raw['order_payment_detail']?['combo_id'];
    if (id == null) return null;
    final s = id.toString();
    return s.isNotEmpty ? s : null;
  }

  Widget _buildComboCrossRefBanner() {
    final comboId = _resolveComboId();
    if (comboId == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(kDefaultPadding),
          vertical: getProportionateScreenHeight(kDefaultPadding / 3),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(kDefaultPadding / 1.5),
          vertical: getProportionateScreenHeight(kDefaultPadding / 2),
        ),
        decoration: BoxDecoration(
          color: kSecondaryColor.withValues(alpha: 0.08),
          border: Border.all(color: kSecondaryColor.withValues(alpha: 0.30)),
          borderRadius: BorderRadius.circular(kDefaultPadding / 1.2),
        ),
        child: Row(
          children: [
            Icon(
              HeroiconsOutline.shoppingBag,
              size: getProportionateScreenHeight(16),
              color: kSecondaryColor,
            ),
            SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Part of a combo order (2 stores · 1 driver)',
                    style: TextStyle(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: getProportionateScreenHeight(12.5),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to view the other store\'s order',
                    style: TextStyle(
                      color: kSecondaryColor.withValues(alpha: 0.75),
                      fontSize: getProportionateScreenHeight(11),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              HeroiconsOutline.chevronRight,
              size: getProportionateScreenHeight(16),
              color: kSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  //
  void _getOrderStatus() async {
    var data = await getOrderStatus();
    if (data != null && data['success']) {
      if (mounted)
        setState(() {
          orderStatus = data;
          providerId = orderStatus['provider_id'] != null
              ? orderStatus['provider_id']
              : "";
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
    await Future.delayed(Duration(seconds: 10), () {
      if (mounted) _getOrderStatus();
    });
  }

  void _showInvoice() async {
    setState(() {
      _loading = true;
    });
    var data = await showInvoice();
    if (data != null && data['success']) {
      setState(() {
        _loading = false;
        responseData = data;
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
              orderId: widget.order['_id'],
              userId: widget.userId,
              serverToken: widget.serverToken,
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

  void _userCancelOrder() async {
    // debugPrint("Cancel order");
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

  // Add _buildTimelineNode widget
  Widget _buildTimelineNode({
    required bool isCompleted,
    required String title,
    String? date,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Container(
                    margin: EdgeInsets.only(
                      top: getProportionateScreenHeight(20),
                    ),
                    height: 24,
                    width: 2,
                    color: isCompleted ? kSecondaryColor : kWhiteColor,
                  ),
                Container(
                  width: getProportionateScreenWidth(18),
                  height: getProportionateScreenHeight(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? kSecondaryColor : kWhiteColor,
                    border: Border.all(color: kWhiteColor, width: 1),
                  ),

                  child: Icon(
                    isCompleted
                        ? HeroiconsSolid.check
                        : HeroiconsSolid.minusCircle,
                    color: kPrimaryColor,
                    size: getProportionateScreenHeight(kDefaultPadding),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(width: getProportionateScreenWidth(kDefaultPadding)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: getProportionateScreenHeight(12),
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.black : Colors.grey,
                ),
              ),
              if (date != null)
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? Colors.black54 : Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Order Detail", style: TextStyle(color: kBlackColor)),
          elevation: 1.0,
          bottom: TabBar(
            indicatorColor: kSecondaryColor,
            tabs: [
              Column(
                children: [
                  Tab(
                    icon: Icon(HeroiconsOutline.truck, color: kSecondaryColor),
                  ),
                  Text("Order Status", style: TextStyle(color: kBlackColor)),
                ],
              ),
              Column(
                children: [
                  Tab(
                    icon: Icon(
                      HeroiconsOutline.shoppingBag,
                      color: kSecondaryColor,
                    ),
                  ),
                  Text("Cart", style: TextStyle(color: kBlackColor)),
                ],
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            //////Order status Tab section/////
            SingleChildScrollView(
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Combo cross-reference banner ───────────────────
                        // Visible only when this order is part of a combo.
                        _buildComboCrossRefBanner(),
                        ////order price section///
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
                            horizontal: getProportionateScreenWidth(
                              kDefaultPadding,
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
                            spacing: getProportionateScreenHeight(
                              kDefaultPadding,
                            ),
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
                                padding: EdgeInsets.symmetric(
                                  // vertical: getProportionateScreenHeight(
                                  //   kDefaultPadding,
                                  // ),
                                  horizontal: getProportionateScreenWidth(
                                    kDefaultPadding / 2,
                                  ),
                                ),
                                child: Column(
                                  spacing: getProportionateScreenWidth(
                                    kDefaultPadding / 2,
                                  ),
                                  children: [
                                    OrderInfoRow(
                                      label: "Order ID",
                                      value: "${widget.order['unique_id']}",
                                    ),
                                    OrderInfoRow(
                                      label: Provider.of<ZLanguage>(
                                        context,
                                        listen: false,
                                      ).totalOrderPrice,

                                      value:
                                          "${widget.order['total_order_price'].toStringAsFixed(2)} ${Provider.of<ZMetaData>(context, listen: false).currency}",
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: kWhiteColor.withValues(
                                          alpha: 0.8,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          kDefaultPadding,
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
                                                "${Service.capitalizeFirstLetters(widget.order['store_name'])}",
                                          ),

                                          AddressTimelineNode(
                                            isLast: true,
                                            isPickup: false,
                                            address:
                                                "${widget.order['destination_addresses'][0]['address']}",

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
                              //   Provider.of<ZLanguage>(
                              //     context,
                              //     listen: false,
                              //   ).orderDetails,
                              //   style: Theme.of(context).textTheme.titleLarge!
                              //       .copyWith(
                              //         color: kBlackColor,
                              //         fontWeight: FontWeight.bold,
                              //         fontSize: getProportionateScreenHeight(17),
                              //       ),
                              // ),
                              // Row(
                              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              //   children: [
                              //     Flexible(
                              //       child: OrderStatusRow(
                              //         icon: HeroiconsOutline.banknotes,
                              //         value:
                              //             "${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.order['total_order_price'].toStringAsFixed(2)}",
                              // title: Provider.of<ZLanguage>(
                              //   context,
                              //   listen: false,
                              // ).totalOrderPrice,
                              //       ),
                              //     ),
                              //     Flexible(
                              //       child: OrderStatusRow(
                              //         icon: HeroiconsOutline.hashtag,
                              //         value: "${widget.order['unique_id']}",
                              //         title: "Order ID",
                              //       ),
                              //     ),
                              //   ],
                              // ),

                              // OrderStatusRow(
                              //   icon: HeroiconsOutline.mapPin,
                              //   value:
                              //       "${widget.order['destination_addresses'][0]['address']}",
                              //   title: Provider.of<ZLanguage>(
                              //     context,
                              //     listen: false,
                              //   ).deliveryAddress,
                              // ),
                              // OrderStatusRow(
                              //   icon: HeroiconsOutline.buildingStorefront,
                              //   value:
                              //       "${Service.capitalizeFirstLetters(widget.order['store_name'])}",
                              //   title: "Store",
                              // ),
                            ],
                          ),
                        ),

                        orderStatus['order_status'] != 25 &&
                                orderStatus['delivery_status'] != null &&
                                orderStatus['delivery_status'] < 100
                            ? Container(
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
                                  horizontal: getProportionateScreenWidth(
                                    kDefaultPadding,
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    OrderStatusRow(
                                      icon: HeroiconsOutline.clock,
                                      value: "Order Status",
                                      title:
                                          "Track the current status of your order",
                                    ),
                                    // Text(
                                    //   "Order Status",
                                    //   style: Theme.of(context)
                                    //       .textTheme
                                    //       .titleLarge!
                                    //       .copyWith(
                                    //         color: kBlackColor,
                                    //         fontWeight: FontWeight.bold,
                                    //         fontSize:
                                    //             getProportionateScreenHeight(17),
                                    //       ),
                                    // ),
                                    SizedBox(
                                      height: getProportionateScreenHeight(
                                        kDefaultPadding * 1.2,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: getProportionateScreenWidth(
                                          kDefaultPadding / 2,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          // Order status timeline nodes
                                          _buildTimelineNode(
                                            isCompleted:
                                                orderStatus['order_status'] >=
                                                1,
                                            title: "${order_status['1']}",
                                            isLast: false,
                                          ),

                                          _buildTimelineNode(
                                            isCompleted:
                                                orderStatus['order_status'] >=
                                                3,
                                            title: "${order_status['3']}",
                                            isLast: false,
                                          ),

                                          _buildTimelineNode(
                                            isCompleted:
                                                orderStatus['order_status'] >=
                                                5,
                                            title: "${order_status['5']}",
                                            isLast: false,
                                          ),

                                          _buildTimelineNode(
                                            isCompleted:
                                                orderStatus['order_status'] >=
                                                7,
                                            title: "${order_status['7']}",
                                            isLast:
                                                widget
                                                    .order['destination_addresses'][0]['address']
                                                    .toString()
                                                    .toLowerCase() ==
                                                "user pickup",
                                          ),
                                          // Delivery status timeline nodes
                                          if (widget
                                                  .order['destination_addresses'][0]['address']
                                                  .toString()
                                                  .toLowerCase() !=
                                              "user pickup")
                                            Column(
                                              children: [
                                                _buildTimelineNode(
                                                  isCompleted:
                                                      orderStatus['delivery_status'] >=
                                                      19,
                                                  title:
                                                      "${order_status['19']}",
                                                  isLast: false,
                                                ),
                                                _buildTimelineNode(
                                                  isCompleted:
                                                      orderStatus['delivery_status'] >=
                                                      23,
                                                  title:
                                                      "${order_status['23']}",
                                                  isLast: true,
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: getProportionateScreenHeight(
                                    kDefaultPadding,
                                  ),
                                  horizontal: getProportionateScreenWidth(
                                    kDefaultPadding,
                                  ),
                                ),
                                width: double.infinity,
                                decoration: BoxDecoration(color: kPrimaryColor),
                                child: _buildTimelineNode(
                                  isCompleted: true,
                                  title:
                                      "${order_status['${orderStatus['order_status']}']}",
                                  isLast: true,
                                ),
                              ),
                        orderStatus['order_status'] != 25 &&
                                orderStatus['delivery_status'] != null &&
                                orderStatus['delivery_status'] > 100
                            ? Container(
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
                                  horizontal: getProportionateScreenWidth(
                                    kDefaultPadding,
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
                                child: _buildTimelineNode(
                                  isCompleted: true,
                                  title:
                                      "${order_status['${orderStatus['delivery_status']}']}",
                                  isLast: true,
                                ),
                              )
                            : Container(),
                      ],
                    ),
                    Container(
                      margin: EdgeInsets.only(
                        top: getProportionateScreenHeight(kDefaultPadding),
                      ),
                      child: Column(
                        children: [
                          orderStatus['order_status'] == 3
                              ? TextButton(
                                  onPressed: () {
                                    _showDialog();
                                  },
                                  child: Text(
                                    "Cancel Order",
                                    style: TextStyle(color: kBlackColor),
                                  ),
                                )
                              : Container(),
                          orderStatus != null &&
                                  orderStatus['provider_id'] != null &&
                                  orderStatus['order_status'] != 25 &&
                                  orderStatus['delivery_status'] != null &&
                                  orderStatus['delivery_status'] >= 17 &&
                                  orderStatus['delivery_status'] < 25
                              ? Padding(
                                  padding: EdgeInsets.only(
                                    bottom: getProportionateScreenHeight(
                                      kDefaultPadding,
                                    ),
                                    left: getProportionateScreenWidth(
                                      kDefaultPadding,
                                    ),
                                    right: getProportionateScreenWidth(
                                      kDefaultPadding,
                                    ),
                                  ),
                                  child: CustomButton(
                                    title: "Track My Order",
                                    press: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) {
                                            return ProviderLocation(
                                              providerId:
                                                  orderStatus['provider_id'],
                                              providerImage:
                                                  orderStatus['provider_image'],
                                              providerName:
                                                  orderStatus['provider_first_name'],
                                              providerPhone:
                                                  orderStatus['provider_phone'],
                                              destLat:
                                                  orderStatus['destination_addresses'][0]['location'][0],
                                              destLong:
                                                  orderStatus['destination_addresses'][0]['location'][1],
                                              userId: widget.userId,
                                              serverToken: widget.serverToken,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                    color: kSecondaryColor,
                                  ),
                                )
                              : Container(),
                          orderStatus['order_status'] == 25
                              ? Padding(
                                  padding: EdgeInsets.only(
                                    bottom: getProportionateScreenHeight(
                                      kDefaultPadding,
                                    ),
                                    left: getProportionateScreenWidth(
                                      kDefaultPadding,
                                    ),
                                    right: getProportionateScreenWidth(
                                      kDefaultPadding,
                                    ),
                                  ),
                                  child: _loading
                                      ? Container()
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
                    ),
                  ],
                ),
              ),
            ),

            //////Order cart Tab section/////
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.order['order_details'].length,
                      separatorBuilder: (context, index) => SizedBox(
                        height: getProportionateScreenWidth(
                          kDefaultPadding / 2,
                        ),
                      ),
                      itemBuilder: (context, index) {
                        String extractProductName(String? noteForItem) {
                          if (noteForItem == null || noteForItem.isEmpty)
                            return '';
                          return noteForItem.split(': ').first;
                        }

                        return Container(
                          width: double.infinity,
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
                            horizontal: getProportionateScreenWidth(
                              kDefaultPadding,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            border: Border.all(color: kWhiteColor),
                            borderRadius: BorderRadius.circular(
                              getProportionateScreenWidth(
                                kDefaultPadding / 1.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CategoryContainer(
                                title:
                                    widget.order['order_details'][index]['product_name']
                                            .toString()
                                            .toLowerCase() ==
                                        "aliexpress"
                                    ? "${Service.capitalizeFirstLetters(extractProductName(widget.order['order_details'][index]['items'][0]['note_for_item']))}"
                                    : widget.order['order_details'][index]['product_name'] !=
                                          null
                                    ? Service.capitalizeFirstLetters(
                                        widget
                                            .order['order_details'][index]['product_name'],
                                      )
                                    : "Item",
                              ),
                              SizedBox(
                                height: getProportionateScreenHeight(
                                  kDefaultPadding / 4,
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(color: kPrimaryColor),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: getProportionateScreenWidth(
                                      kDefaultPadding / 2,
                                    ),
                                    vertical: getProportionateScreenHeight(
                                      kDefaultPadding / 2,
                                    ),
                                  ),
                                  child: ListView.separated(
                                    physics: ClampingScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: widget
                                        .order['order_details'][index]['items']
                                        .length,
                                    separatorBuilder: (context, index) =>
                                        Divider(color: kWhiteColor),
                                    itemBuilder: (context, idx) {
                                      String extractItemName(
                                        String? noteForItem,
                                      ) {
                                        if (noteForItem == null ||
                                            noteForItem.isEmpty)
                                          return '';
                                        var parts = noteForItem.split(': ');
                                        return parts.length >= 3
                                            ? "${parts[2]}:\n${parts[1]}"
                                            : parts.length >= 2
                                            ? "${parts[1]}"
                                            : '';
                                      }

                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  widget.order['order_details'][index]['product_name']
                                                              .toString()
                                                              .toLowerCase() ==
                                                          "aliexpress"
                                                      ? "${extractItemName(widget.order['order_details'][index]['items'][idx]['note_for_item'])}"
                                                      : "${Service.capitalizeFirstLetters(widget.order['order_details'][index]['items'][idx]['item_name'])}",
                                                  softWrap: true,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                Text(
                                                  "Quantity: ${widget.order['order_details'][index]['items'][idx]['quantity']}",
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            "${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.order['order_details'][index]['items'][idx]['total_price'].toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: getProportionateScreenHeight(
                        kDefaultPadding / 2,
                      ),
                      horizontal: getProportionateScreenWidth(
                        kDefaultPadding / 2,
                      ),
                    ),
                    margin: EdgeInsets.symmetric(
                      vertical: getProportionateScreenHeight(
                        kDefaultPadding / 2,
                      ),
                      horizontal: getProportionateScreenWidth(kDefaultPadding),
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      border: Border.all(color: kWhiteColor),
                      borderRadius: BorderRadius.circular(
                        getProportionateScreenWidth(kDefaultPadding / 1.5),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            "${Provider.of<ZMetaData>(context, listen: false).currency} ${widget.order['total_order_price'].toStringAsFixed(2)}",
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            "Total Price",
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: kGreyColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 0.1,
                    color: kSecondaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<dynamic> userCancelOrder() async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/user_cancel_order";
    Map data = {
      "user_id": widget.userId,
      "server_token": widget.serverToken,
      "cancel_reason": reason,
      "order_id": widget.order['_id'],
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
      responseData = json.decode(response.body);
      return json.decode(response.body);
    } catch (e) {
      return null;
    }
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
      "order_id": widget.order['_id'],
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
                error: true,
                context: context,
                title: "Something went wrong!",
              );
              throw TimeoutException("The connection has timed out!");
            },
          );
      setState(() {
        this._loading = false;
        orderStatus = json.decode(response.body);
      });

      return json.decode(response.body);
    } catch (e) {
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

  Future<dynamic> showInvoice() async {
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/show_invoice";
    Map data = {
      "user_id": widget.userId,
      "server_token": widget.serverToken,
      "order_id": widget.order['_id'],
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
                error: true,
                context: context,
                title: "Something went wrong!",
              );
              throw TimeoutException("The connection has timed out!");
            },
          );
      setState(() {
        this._loading = false;
      });

      return json.decode(response.body);
    } catch (e) {
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
}

class InfoContainer extends StatelessWidget {
  const InfoContainer({
    Key? key,
    required this.title,
    required this.header,
    this.status = false,
  }) : super(key: key);

  final String title;
  final String header;
  final bool status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: getProportionateScreenHeight(kDefaultPadding / 3),
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: status ? kPrimaryColor : kSecondaryColor,
        borderRadius: BorderRadius.circular(
          getProportionateScreenWidth(kDefaultPadding / 2),
        ),
      ),
      child: Column(
        children: [
          CategoryContainer(title: header),
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: status ? kSecondaryColor : kBlackColor),
            ),
          ),
        ],
      ),
    );
  }
}

// void _showDialog() {
//   showModalBottomSheet(
//     context: context,
//     backgroundColor: kPrimaryColor,
//     builder: (BuildContext context) {
//       return Padding(
//         padding: EdgeInsets.only(
//           bottom:
//               MediaQuery.of(context).viewInsets.bottom +
//               kDefaultPadding, // Adjust for keyboard
//         ),
//         child: SafeArea(
//           child: Container(
//             width: double.infinity,
//             decoration: BoxDecoration(
//               color: kPrimaryColor,
//               borderRadius: BorderRadius.circular(kDefaultPadding),
//             ),
//             padding: EdgeInsets.symmetric(
//               horizontal: getProportionateScreenWidth(kDefaultPadding),
//               vertical: getProportionateScreenHeight(kDefaultPadding),
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               spacing: getProportionateScreenHeight(kDefaultPadding / 2),
//               children: <Widget>[
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Row(
//                       spacing: getProportionateScreenWidth(
//                         kDefaultPadding / 2,
//                       ),
//                       children: [
//                         Text(
//                           "Cancel Order?",
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: kBlackColor,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Icon(
//                           color: kBlackColor,
//                           HeroiconsOutline.faceFrown,
//                           size: getProportionateScreenHeight(24),
//                         ),
//                       ],
//                     ),
//                     IconButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       icon: Icon(
//                         color: kBlackColor,
//                         HeroiconsOutline.xCircle,
//                         size: getProportionateScreenHeight(24),
//                       ),
//                     ),
//                   ],
//                 ),
//                 Text("Are you sure you want to cancel the order?"),
//                 Container(
//                   constraints: BoxConstraints(minHeight: 120),
//                   padding: EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                       color: kGreyColor.withValues(alpha: 0.2),
//                     ),
//                   ),
//                   child: TextField(
//                     style: TextStyle(color: kBlackColor),
//                     maxLines: null,
//                     keyboardType: TextInputType.multiline,
//                     onChanged: (val) {
//                       reason = val;
//                     },
//                     decoration: InputDecoration.collapsed(
//                       hintText: "$reason",
//                       hintStyle: TextStyle(color: kGreyColor),
//                     ),
//                   ),
//                 ),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     TextButton(
//                       child: Row(
//                         spacing: getProportionateScreenWidth(
//                           kDefaultPadding / 2,
//                         ),
//                         children: [
//                           Text(
//                             "Sure",
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: kBlackColor,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Icon(
//                             color: kGreyColor,
//                             HeroiconsOutline.faceFrown,
//                             size: getProportionateScreenHeight(24),
//                           ),
//                         ],
//                       ),
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                         _userCancelOrder();
//                       },
//                     ),
//                     TextButton(
//                       child: Row(
//                         spacing: getProportionateScreenWidth(
//                           kDefaultPadding / 2,
//                         ),
//                         children: [
//                           Text(
//                             "Keep It",
//                             style: TextStyle(
//                               fontSize: 16,
//                               color: kSecondaryColor,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Icon(
//                             color: kSecondaryColor,
//                             HeroiconsOutline.faceSmile,
//                             size: getProportionateScreenHeight(24),
//                           ),
//                         ],
//                       ),
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     },
//   );
// }
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kSecondaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashHeight = 5.0;
    const gap = 5.0;

    double y = 0;

    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashHeight),
        paint,
      );

      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
