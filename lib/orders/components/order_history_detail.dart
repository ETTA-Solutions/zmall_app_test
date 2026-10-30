import 'dart:async';
import 'dart:convert';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/orders/components/order_rating.dart';
import 'package:zmall/widgets/order_status_row.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/store/components/image_container.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/orders/components/category_container.dart';

class OrderHistoryDetail extends StatefulWidget {
  static String routeName = '/order_history_detail';

  @override
  _OrderHistoryDetailState createState() => _OrderHistoryDetailState();

  const OrderHistoryDetail({
    super.key,
    this.orderId,
    this.userId,
    this.serverToken,
  });

  final String? orderId, userId, serverToken;
}

class _OrderHistoryDetailState extends State<OrderHistoryDetail> {
  bool _loading = false;
  var responseData;
  var userData;

  String? get effectiveOrderId =>
      widget.orderId ??
      (ModalRoute.of(context)?.settings.arguments is Map
          ? ((ModalRoute.of(context)!.settings.arguments as Map)['orderId'] ??
              (ModalRoute.of(context)!.settings.arguments as Map)['order_id'])
          : (ModalRoute.of(context)?.settings.arguments is String
              ? ModalRoute.of(context)!.settings.arguments as String
              : null));

  String? get effectiveUserId =>
      widget.userId ??
      userData?['user']?['_id'] ??
      (ModalRoute.of(context)?.settings.arguments is Map
          ? ((ModalRoute.of(context)!.settings.arguments as Map)['userId'] ??
              (ModalRoute.of(context)!.settings.arguments as Map)['user_id'])
          : null);

  String? get effectiveServerToken =>
      widget.serverToken ??
      userData?['user']?['server_token'] ??
      (ModalRoute.of(context)?.settings.arguments is Map
          ? ((ModalRoute.of(context)!.settings.arguments as Map)['serverToken'] ??
              (ModalRoute.of(context)!.settings.arguments as Map)['server_token'])
          : null);

  bool get _isCombo =>
      responseData != null &&
      responseData['combo'] != null &&
      responseData['combo'] is Map &&
      responseData['combo']['stores'] != null &&
      responseData['combo']['stores'] is List &&
      (responseData['combo']['stores'] as List).isNotEmpty;

  Map<String, dynamic>? get _comboData =>
      _isCombo ? (responseData['combo'] as Map<String, dynamic>) : null;

  List<dynamic> get _comboStores =>
      _isCombo ? (_comboData?['stores'] as List<dynamic>? ?? []) : [];

  Map<String, dynamic>? get _comboTotals =>
      _isCombo ? (_comboData?['totals'] as Map<String, dynamic>?) : null;

  RateMyApp _rateMyApp = RateMyApp(
    preferencesPrefix: 'rateMyApp_',
    minLaunches: 3, //5
    minDays: 0, //7
    remindLaunches: 3, //5
    remindDays: 2, //3
    appStoreIdentifier: 'com.enigma.zmall',
    googlePlayIdentifier: 'com.enigma.zmall',
  );
  @override
  void initState() {
    super.initState();
    getUser();
    _rateMyApp.init().then(
      (_) => {
        if (_rateMyApp.shouldOpenDialog)
          {
            _rateMyApp.showStarRateDialog(
              context,
              title: "Enjoying ZMall?",
              message: "Please leave a rating!",
              dialogStyle: DialogStyle(
                titleAlign: TextAlign.center,
                messageAlign: TextAlign.center,
                messagePadding: EdgeInsets.only(bottom: 20.0),
              ),
              starRatingOptions: StarRatingOptions(initialRating: 5),
              actionsBuilder: actionsBuilder,
            ),
          },
      },
    );
  }

  List<Widget> actionsBuilder(BuildContext context, double? stars) =>
      stars == null
      ? [buildCancelButton()]
      : [buildOkButton(stars), buildCancelButton()];

  Widget buildOkButton(double stars) => TextButton(
    child: Text('OK'),
    onPressed: () async {
      final launchAppStore = stars >= 4;

      Service.showMessage(
        context: context,
        title: "Thanks for your feedback!",
        error: true,
      );
      final event = RateMyAppEventType.rateButtonPressed;
      await _rateMyApp.callEvent(event);

      if (launchAppStore) {
        _rateMyApp.launchStore();
      }

      Navigator.of(context).pop();
    },
  );
  Widget buildCancelButton() => RateMyAppNoButton(_rateMyApp, text: "Cancel");

  void getUser() async {
    var data = await Service.read('user');
    if (data != null) {
      setState(() {
        userData = data;
      });
      _getDetails();
    }
  }

  void _getDetails() async {
    // debugPrint("Fetching order detail");
    var data = await getDetail();
    if (data != null) {
      setState(() {
        responseData = data;
      });
      // debugPrint(
      //     "fdsa??? ${responseData['order_list']['cart_detail']['destination_addresses'][0]['user_details']}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            Provider.of<ZLanguage>(context, listen: false).orderDetails,
            style: TextStyle(color: kBlackColor),
          ),
          elevation: 1.0,
          bottom: TabBar(
            indicatorColor: kSecondaryColor,
            tabs: [
              Tab(
                icon: Column(
                  children: [
                    Icon(
                      HeroiconsOutline.bars3BottomLeft,
                      color: kSecondaryColor,
                    ),
                    Text(
                      Provider.of<ZLanguage>(context, listen: false).details,
                      style: TextStyle(color: kBlackColor),
                    ),
                  ],
                ),
              ),
              Tab(
                icon: Column(
                  children: [
                    Icon(HeroiconsOutline.documentText, color: kSecondaryColor),
                    Text(
                      Provider.of<ZLanguage>(context, listen: false).invoice,
                      style: TextStyle(color: kBlackColor),
                    ),
                  ],
                ),
              ),
              Tab(
                icon: Column(
                  children: [
                    Icon(HeroiconsOutline.shoppingBag, color: kSecondaryColor),
                    Text(
                      Provider.of<ZLanguage>(context, listen: false).cart,
                      style: TextStyle(color: kBlackColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: ModalProgressHUD(
            inAsyncCall: _loading,

            progressIndicator: LinearLoadingIndicator(),
            // progressIndicator: userData != null && responseData != null
            //     ? LinearLoadingIndicator()
            //     : ProductListShimmer(),
            color: kPrimaryColor,
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Padding(
                padding: EdgeInsets.all(
                  getProportionateScreenWidth(kDefaultPadding / 2),
                ),
                child: TabBarView(
                  children: [
                    /////order histry detail
                    responseData != null
                        ? SingleChildScrollView(
                            child: Column(
                              spacing: getProportionateScreenHeight(
                                kDefaultPadding / 2,
                              ),
                              children: [
                                // ── Combo cross-reference banner ─────────────────────
                                if (_isCombo)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: getProportionateScreenHeight(
                                        kDefaultPadding / 2,
                                      ),
                                      horizontal: getProportionateScreenWidth(
                                        kDefaultPadding,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      color: kSecondaryColor.withValues(
                                        alpha: 0.08,
                                      ),
                                      border: Border.all(
                                        color: kSecondaryColor.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        getProportionateScreenWidth(
                                          kDefaultPadding / 1.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          HeroiconsOutline.shoppingBag,
                                          color: kSecondaryColor,
                                          size: getProportionateScreenHeight(20),
                                        ),
                                        SizedBox(
                                          width: getProportionateScreenWidth(
                                            kDefaultPadding / 2,
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Combo Order (${_comboStores.length} Stores · 1 Driver)",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: kSecondaryColor,
                                                  fontSize:
                                                      getProportionateScreenHeight(
                                                        13,
                                                      ),
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                "Order #${_comboStores.map((s) => s['order_unique_id'] ?? '').where((id) => id.toString().isNotEmpty).join(', #')}",
                                                style: TextStyle(
                                                  fontSize:
                                                      getProportionateScreenHeight(
                                                        11.5,
                                                      ),
                                                  color: kBlackColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                ///////Order Details section/////
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: getProportionateScreenHeight(
                                      kDefaultPadding / 1.5,
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
                                        kDefaultPadding,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: getProportionateScreenHeight(
                                      kDefaultPadding,
                                    ),
                                    children: [
                                      Row(
                                        spacing: getProportionateScreenWidth(
                                          kDefaultPadding / 2,
                                        ),
                                        children: [
                                          Icon(
                                            HeroiconsOutline
                                                .clipboardDocumentCheck,
                                            color: kBlackColor,
                                          ),
                                          Text(
                                            Provider.of<ZLanguage>(
                                              context,
                                              listen: false,
                                            ).orderDetails,
                                            style: TextStyle(
                                              fontSize:
                                                  getProportionateScreenHeight(
                                                    kDefaultPadding,
                                                  ),
                                              color: kBlackColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          if ((responseData['store_detail'] == null ||
                                                  responseData['store_detail']['name'] ==
                                                      null) &&
                                              !_isCombo)
                                            Flexible(
                                              child: OrderStatusRow(
                                                icon: HeroiconsOutline.user,
                                                value:
                                                    "${Service.capitalizeFirstLetters(responseData['order_list']?['cart_detail']?['pickup_addresses']?[0]?['user_details']?['name'] ?? '')}",
                                                title: "From",
                                              ),
                                            ),
                                          Flexible(
                                            child: OrderStatusRow(
                                              icon: HeroiconsOutline.user,
                                              value: Service.capitalizeFirstLetters(
                                                responseData['order_list']?['cart_detail']?['destination_addresses']?[0]?['user_details']?['name'] ?? '',
                                              ),
                                              title: Provider.of<ZLanguage>(
                                                context,
                                                listen: false,
                                              ).receivedBy,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_isCombo)
                                        ..._comboStores.map((store) {
                                          final storeDetail =
                                              store['store_detail'] ?? {};
                                          final String storeName =
                                              storeDetail['name'] ?? 'Store';
                                          final String storeImg =
                                              storeDetail['image_url'] ?? '';
                                          final int storeStatus =
                                              store['order_status'] ??
                                                  responseData['order_list']?['order_status'] ??
                                                  0;
                                          final bool isCompleted =
                                              storeStatus == 25;
                                          final bool isRated =
                                              store['is_user_rated_to_store'] ??
                                                  responseData['order_list']?['is_user_rated_to_store'] ??
                                                  false;
                                          final String storeOrderId =
                                              store['order_id'] ??
                                                  (effectiveOrderId ?? '');
                                          final int seq =
                                              store['pickup_sequence'] ?? 1;
                                          final uniqueId =
                                              store['order_unique_id'] ?? '';

                                          return orderDetailRow(
                                            isStore: true,
                                            isRated: isRated,
                                            isCompleted: isCompleted,
                                            value: Service.capitalizeFirstLetters(
                                              storeName,
                                            ),
                                            subtitle:
                                                "Stop #$seq · #$uniqueId",
                                            imageUrl:
                                                "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/$storeImg",
                                            onRatePressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) {
                                                    return OrderRating(
                                                      userId: effectiveUserId,
                                                      orderId: storeOrderId,
                                                      serverToken:
                                                          effectiveServerToken,
                                                      imageUrl:
                                                          "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/$storeImg",
                                                      name: storeName,
                                                      isStore: true,
                                                    );
                                                  },
                                                ),
                                              ).then((value) => getUser());
                                            },
                                          );
                                        })
                                      else if (responseData['store_detail'] !=
                                              null &&
                                          responseData['store_detail']['name'] !=
                                              null)
                                        orderDetailRow(
                                          isStore: true,
                                          isRated:
                                              responseData['order_list']?['is_user_rated_to_store'] ??
                                              false,
                                          isCompleted:
                                              responseData['order_list']?['order_status'] ==
                                              25,
                                          value:
                                              "${Service.capitalizeFirstLetters(responseData['store_detail']['name'])}",
                                          imageUrl:
                                              "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${responseData['store_detail']['image_url']}",
                                          onRatePressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) {
                                                  return OrderRating(
                                                    userId: effectiveUserId,
                                                    orderId: effectiveOrderId,
                                                    serverToken:
                                                        effectiveServerToken,
                                                    imageUrl:
                                                        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${responseData['store_detail']['image_url']}",
                                                    name:
                                                        "${responseData['store_detail']['name']}",
                                                    isStore: true,
                                                  );
                                                },
                                              ),
                                            ).then((value) => getUser());
                                          },
                                        ),
                                    ],
                                  ),
                                ),

                                ///////Delivery Details section/////
                                Container(
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor,
                                    border: Border.all(color: kWhiteColor),
                                    borderRadius: BorderRadius.circular(
                                      getProportionateScreenWidth(
                                        kDefaultPadding,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: getProportionateScreenHeight(
                                        kDefaultPadding / 1.5,
                                      ),
                                      horizontal: getProportionateScreenWidth(
                                        kDefaultPadding,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: getProportionateScreenHeight(
                                        kDefaultPadding,
                                      ),
                                      children: [
                                        Row(
                                          spacing: getProportionateScreenWidth(
                                            kDefaultPadding / 2,
                                          ),
                                          children: [
                                            Icon(
                                              HeroiconsOutline.truck,
                                              color: kBlackColor,
                                            ),
                                            Text(
                                              Provider.of<ZLanguage>(
                                                context,
                                                listen: false,
                                              ).deliveryDetails,
                                              style: TextStyle(
                                                fontSize:
                                                    getProportionateScreenHeight(
                                                      kDefaultPadding,
                                                    ),
                                                color: kBlackColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),

                                        if (responseData['provider_detail'] !=
                                                null &&
                                            (responseData['order_list']?['order_status'] ==
                                                    25 ||
                                                _isCombo))
                                          orderDetailRow(
                                            isStore: false,
                                            isCompleted: true,
                                            value:
                                                "${responseData['provider_detail']['first_name'] ?? ''} ${responseData['provider_detail']['last_name'] ?? ''}".trim(),
                                            isRated:
                                                responseData['order_list']?['is_user_rated_to_provider'] ??
                                                false,
                                            imageUrl:
                                                "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${responseData['provider_detail']['image_url'] ?? ''}",
                                            onRatePressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) {
                                                    return OrderRating(
                                                      userId: effectiveUserId,
                                                      orderId: effectiveOrderId,
                                                      serverToken:
                                                          effectiveServerToken,
                                                      imageUrl:
                                                          "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${responseData['provider_detail']['image_url'] ?? ''}",
                                                      name:
                                                          "${responseData['provider_detail']['first_name'] ?? ''} ${responseData['provider_detail']['last_name'] ?? ''}".trim(),
                                                      isStore: false,
                                                    );
                                                  },
                                                ),
                                              ).then((value) => getUser());
                                            },
                                          ),

                                        ////////Address Section
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          spacing: getProportionateScreenHeight(
                                            kDefaultPadding,
                                          ),
                                          children: [
                                            if (responseData['order_list']?['order_status'] !=
                                                25)
                                              OrderStatusRow(
                                                icon: HeroiconsOutline.xCircle,
                                                value:
                                                    "${order_status['${responseData['order_list']['order_status']}'] ?? 'Pending'}",
                                                title: "Order Status",
                                              ),
                                            if (responseData['order_list']?['cart_detail']?['destination_addresses'] !=
                                                    null &&
                                                (responseData['order_list']['cart_detail']['destination_addresses']
                                                        as List)
                                                    .isNotEmpty)
                                              OrderStatusRow(
                                                icon: HeroiconsOutline.mapPin,
                                                value:
                                                    responseData['order_list']['cart_detail']['destination_addresses'][0]['address'] ??
                                                    '',
                                                title: "Delivery Address",
                                              ),
                                            if (_isCombo)
                                              ..._comboStores.map((store) {
                                                final storeDetail =
                                                    store['store_detail'] ?? {};
                                                final storeName =
                                                    storeDetail['name'] ??
                                                    'Store';
                                                final address =
                                                    storeDetail['address'] ?? '';
                                                return OrderStatusRow(
                                                  icon:
                                                      HeroiconsOutline
                                                          .buildingStorefront,
                                                  value: address,
                                                  title:
                                                      "Pickup (${Service.capitalizeFirstLetters(storeName)})",
                                                );
                                              })
                                            else if (responseData['order_list']?['cart_detail']?['pickup_addresses'] !=
                                                    null &&
                                                (responseData['order_list']['cart_detail']['pickup_addresses']
                                                        as List)
                                                    .isNotEmpty)
                                              OrderStatusRow(
                                                icon: HeroiconsOutline.mapPin,
                                                value:
                                                    responseData['order_list']['cart_detail']['pickup_addresses'][0]['address'] ??
                                                    '',
                                                title: "Pickup address",
                                              ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: OrderStatusRow(
                                                    icon:
                                                        HeroiconsOutline.clock,
                                                    value:
                                                        "${((responseData['order_list']?['order_payment_detail']?['total_time'] ?? 0) as num).toStringAsFixed(2)} mins",
                                                    title: "Time",
                                                  ),
                                                ),
                                                Flexible(
                                                  child: OrderStatusRow(
                                                    icon:
                                                        HeroiconsOutline.truck,
                                                    value:
                                                        "${((responseData['order_list']?['order_payment_detail']?['total_distance'] ?? 0) as num).toStringAsFixed(2)} KM",
                                                    title: "Distance",
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                ////Rate ZMall App section/////
                                Container(
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor,
                                    border: Border.all(color: kWhiteColor),
                                    borderRadius: BorderRadius.circular(
                                      getProportionateScreenWidth(
                                        kDefaultPadding,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: getProportionateScreenHeight(
                                        kDefaultPadding / 1.5,
                                      ),
                                      horizontal: getProportionateScreenWidth(
                                        kDefaultPadding,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: getProportionateScreenHeight(
                                        kDefaultPadding / 2,
                                      ),
                                      children: [
                                        Text(
                                          Provider.of<ZLanguage>(
                                            context,
                                            listen: false,
                                          ).enjoyingZmall,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          Provider.of<ZLanguage>(
                                            context,
                                            listen: false,
                                          ).rateReviewBlock,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelLarge,
                                          textAlign: TextAlign.justify,
                                        ),
                                        CustomButton(
                                          title: Provider.of<ZLanguage>(
                                            context,
                                            listen: false,
                                          ).rateUs,
                                          press: () {
                                            _rateMyApp.showStarRateDialog(
                                              context,
                                              title: "Enjoying ZMall?",
                                              message: "Please leave a rating!",
                                              dialogStyle: DialogStyle(
                                                titleAlign: TextAlign.center,
                                                messageAlign: TextAlign.center,
                                                messagePadding: EdgeInsets.only(
                                                  bottom: 20.0,
                                                ),
                                              ),
                                              starRatingOptions:
                                                  StarRatingOptions(
                                                    initialRating: 5,
                                                  ),
                                              actionsBuilder: actionsBuilder,
                                            );
                                          },
                                          color: kSecondaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(),
                    ////////////////Invoice Tab section/////////////////
                    if (responseData != null)
                      SingleChildScrollView(
                        child: Column(
                          spacing: getProportionateScreenHeight(
                            kDefaultPadding / 2,
                          ),
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                vertical: getProportionateScreenHeight(
                                  kDefaultPadding,
                                ),
                                horizontal: getProportionateScreenWidth(
                                  kDefaultPadding / 2,
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
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                spacing: getProportionateScreenWidth(
                                  kDefaultPadding / 2,
                                ),
                                children: [
                                  Flexible(
                                    child: OrderStatusRow(
                                      icon: HeroiconsOutline.clock,
                                      value:
                                          "${((responseData['order_list']?['order_payment_detail']?['total_time'] ?? 0) as num).toStringAsFixed(2)}min",
                                      title: "Time",
                                    ),
                                  ),
                                  Flexible(
                                    child: OrderStatusRow(
                                      icon: HeroiconsOutline.truck,
                                      value:
                                          "${((responseData['order_list']?['order_payment_detail']?['total_distance'] ?? 0) as num).toStringAsFixed(2)} KM",
                                      title: "Distance",
                                    ),
                                  ),
                                  Flexible(
                                    child: OrderStatusRow(
                                      icon: HeroiconsOutline.creditCard,
                                      value: Service.capitalizeFirstLetters(
                                        responseData['payment_gateway_name']
                                                ?.toString() ??
                                            Provider.of<ZLanguage>(
                                              context,
                                              listen: false,
                                            ).cash,
                                      ),
                                      title: Provider.of<ZLanguage>(
                                        context,
                                        listen: false,
                                      ).payments,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            ///total prices///
                            Container(
                              padding: EdgeInsets.symmetric(
                                vertical: getProportionateScreenHeight(
                                  kDefaultPadding,
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
                              child: Builder(
                                builder: (context) {
                                  final currency =
                                      Provider.of<ZMetaData>(
                                        context,
                                        listen: false,
                                      ).currency;
                                  final paymentDetail =
                                      responseData['order_list']?['order_payment_detail'] ??
                                      {};
                                  final totals =
                                      _isCombo
                                          ? (_comboTotals ?? {})
                                          : paymentDetail;
                                  final num servicePrice =
                                      totals['total_service_price'] ??
                                      totals['total_delivery_price'] ??
                                      paymentDetail['total_service_price'] ??
                                      0;
                                  final num cartPrice =
                                      totals['total_cart_price'] ??
                                      paymentDetail['total_cart_price'] ??
                                      0;
                                  final num promoPrice =
                                      totals['promo_payment'] ??
                                      paymentDetail['promo_payment'] ??
                                      0;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            Provider.of<ZLanguage>(
                                              context,
                                              listen: false,
                                            ).servicePrice,
                                          ),
                                          Text(
                                            "$currency  ${servicePrice.toStringAsFixed(2)}",
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: getProportionateScreenHeight(
                                          kDefaultPadding / 4,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            Provider.of<ZLanguage>(
                                              context,
                                              listen: false,
                                            ).totalServicePrive,
                                            style: TextStyle(
                                              color: kSecondaryColor,
                                            ),
                                          ),
                                          Text(
                                            "$currency  ${servicePrice.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: kSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (promoPrice != 0) ...[
                                        SizedBox(
                                          height:
                                              getProportionateScreenHeight(
                                                kDefaultPadding / 4,
                                              ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              Provider.of<ZLanguage>(
                                                context,
                                                listen: false,
                                              ).promo,
                                            ),
                                            Text(
                                              "$currency  ${promoPrice.toStringAsFixed(2)}",
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height:
                                              getProportionateScreenHeight(
                                                kDefaultPadding / 4,
                                              ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              Provider.of<ZLanguage>(
                                                context,
                                                listen: false,
                                              ).totalPromo,
                                              style: TextStyle(
                                                color: kSecondaryColor,
                                              ),
                                            ),
                                            Text(
                                              "$currency  ${promoPrice.toStringAsFixed(2)}",
                                              style: TextStyle(
                                                color: kSecondaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      SizedBox(
                                        height: getProportionateScreenHeight(
                                          kDefaultPadding / 4,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            Provider.of<ZLanguage>(
                                              context,
                                              listen: false,
                                            ).cartPrice,
                                          ),
                                          Text(
                                            "$currency  ${cartPrice.toStringAsFixed(2)}",
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: getProportionateScreenHeight(
                                          kDefaultPadding / 4,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            Provider.of<ZLanguage>(
                                              context,
                                              listen: false,
                                            ).totalCartPrice,
                                            style: TextStyle(
                                              color: kSecondaryColor,
                                            ),
                                          ),
                                          Text(
                                            "$currency  ${cartPrice.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: kSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Per-store breakdown if combo
                                      if (_isCombo) ...[
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Divider(
                                            color: kGreyColor.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "Store Breakdown",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize:
                                                getProportionateScreenHeight(
                                                  12.5,
                                                ),
                                            color: kBlackColor,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        ..._comboStores.map((s) {
                                          final sName =
                                              s['store_detail']?['name'] ??
                                              'Store';
                                          final sPay =
                                              s['order_payment'] ?? {};
                                          final num sCart =
                                              sPay['total_cart_price'] ??
                                              sPay['total_order_price'] ??
                                              0;
                                          final num sDelivery =
                                              sPay['total_delivery_price'] ??
                                              sPay['total_service_price'] ??
                                              0;
                                          final num sTotal =
                                              sPay['total'] ??
                                              sPay['user_pay_payment'] ??
                                              (sCart + sDelivery);

                                          return Padding(
                                            padding: EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    Service.capitalizeFirstLetters(
                                                      sName,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: kGreyColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  "$currency ${sTotal.toStringAsFixed(2)}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: kBlackColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),

                            ///////payments and total price////
                            Container(
                              padding: EdgeInsets.symmetric(
                                vertical: getProportionateScreenHeight(
                                  kDefaultPadding,
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
                              child: Builder(
                                builder: (context) {
                                  final currency =
                                      Provider.of<ZMetaData>(
                                        context,
                                        listen: false,
                                      ).currency;
                                  final paymentDetail =
                                      responseData['order_list']?['order_payment_detail'] ??
                                      {};
                                  final totals =
                                      _isCombo
                                          ? (_comboTotals ?? {})
                                          : paymentDetail;
                                  final num totalAmount =
                                      totals['total'] ??
                                      totals['user_pay_payment'] ??
                                      paymentDetail['total'] ??
                                      0;
                                  final num walletPayment =
                                      totals['wallet_payment'] ??
                                      paymentDetail['wallet_payment'] ??
                                      0;
                                  final num cashPayment =
                                      totals['cash_payment'] ??
                                      paymentDetail['cash_payment'] ??
                                      0;
                                  final num cardPayment =
                                      totals['card_payment'] ??
                                      paymentDetail['card_payment'] ??
                                      0;
                                  final num promoPrice =
                                      totals['promo_payment'] ??
                                      paymentDetail['promo_payment'] ??
                                      0;
                                  final bool isWalletPaid =
                                      walletPayment > 0 ||
                                      (paymentDetail['is_paid_from_wallet'] ==
                                          true);

                                  return Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            promoPrice != 0
                                                ? MainAxisAlignment.spaceBetween
                                                : MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ////digital payment section
                                          Row(
                                            children: [
                                              isWalletPaid
                                                  ? Icon(
                                                      Icons
                                                          .account_balance_wallet_outlined,
                                                      size:
                                                          getProportionateScreenHeight(
                                                            kDefaultPadding,
                                                          ),
                                                    )
                                                  : Icon(
                                                      HeroiconsOutline
                                                          .devicePhoneMobile,
                                                      size:
                                                          getProportionateScreenHeight(
                                                            kDefaultPadding,
                                                          ),
                                                    ),
                                              SizedBox(
                                                width:
                                                    getProportionateScreenWidth(
                                                      kDefaultPadding / 2,
                                                    ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    isWalletPaid
                                                        ? Provider.of<ZLanguage>(
                                                          context,
                                                          listen: false,
                                                        ).wallet
                                                        : Provider.of<ZLanguage>(
                                                          context,
                                                          listen: false,
                                                        ).online,
                                                  ),
                                                  Text(
                                                    isWalletPaid
                                                        ? "$currency ${walletPayment.toStringAsFixed(2)}"
                                                        : "$currency ${cardPayment.toStringAsFixed(2)}",
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          /////Promo payment section
                                          if (promoPrice != 0)
                                            Row(
                                              children: [
                                                Icon(
                                                  HeroiconsOutline.gift,
                                                  size:
                                                      getProportionateScreenHeight(
                                                        kDefaultPadding,
                                                      ),
                                                ),
                                                SizedBox(
                                                  width:
                                                      getProportionateScreenWidth(
                                                        kDefaultPadding / 2,
                                                      ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      Provider.of<ZLanguage>(
                                                        context,
                                                        listen: false,
                                                      ).promo,
                                                    ),
                                                    Text(
                                                      "$currency ${promoPrice.toStringAsFixed(2)}",
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),

                                          ////cash payment section
                                          Row(
                                            children: [
                                              Icon(
                                                HeroiconsOutline.banknotes,
                                                size:
                                                    getProportionateScreenHeight(
                                                      kDefaultPadding,
                                                    ),
                                              ),
                                              SizedBox(
                                                width:
                                                    getProportionateScreenWidth(
                                                      kDefaultPadding / 2,
                                                    ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    Service.capitalizeFirstLetters(
                                                      Provider.of<ZLanguage>(
                                                        context,
                                                        listen: false,
                                                      ).cash,
                                                    ),
                                                  ),
                                                  Text(
                                                    "$currency ${cashPayment.toStringAsFixed(2)}",
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: getProportionateScreenWidth(
                                          kDefaultPadding / 2,
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Text(
                                            Service.capitalizeFirstLetters(
                                              responseData['payment_gateway_name']
                                                      ?.toString() ??
                                                  '',
                                            ),
                                          ),
                                          Text(
                                            "$currency ${totalAmount.toStringAsFixed(2)}",
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          Text(
                                            Provider.of<ZLanguage>(
                                              context,
                                              listen: false,
                                            ).total,
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: getProportionateScreenWidth(
                                          kDefaultPadding / 2,
                                        ),
                                      ),
                                      (responseData['order_list']?['is_user_show_invoice'] ==
                                                  true ||
                                              responseData['order_list']?['order_status'] !=
                                                  25)
                                          ? Container()
                                          : Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical:
                                                    getProportionateScreenWidth(
                                                      kDefaultPadding / 2,
                                                    ),
                                              ),
                                              child: CustomButton(
                                                title:
                                                    Provider.of<ZLanguage>(
                                                      context,
                                                      listen: false,
                                                    ).submit,
                                                press: () {},
                                                color: kBlackColor,
                                              ),
                                            ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    ////////////////Cart Tab section/////////////////
                    responseData != null
                        ? (_isCombo
                            ? _buildComboCartTab()
                            : _buildSingleCartTab())
                        : Container(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _extractProductName(String? noteForItem) {
    if (noteForItem == null || noteForItem.isEmpty) return '';
    return noteForItem.split(': ').first;
  }

  String _extractItemName(String? noteForItem) {
    if (noteForItem == null || noteForItem.isEmpty) return '';
    var parts = noteForItem.split(': ');
    return parts.length >= 3
        ? "${parts[2]}:\n${parts[1]}"
        : parts.length >= 2
            ? "${parts[1]}"
            : '';
  }

  Widget _buildSingleCartTab() {
    final cartList =
        (responseData['order_list']?['cart_detail']?['order_details'] as List? ??
            []);

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: cartList.length,
            separatorBuilder: (context, index) => SizedBox(
              height: getProportionateScreenHeight(kDefaultPadding / 2),
            ),
            itemBuilder: (context, index) {
              final cat = cartList[index];
              final String prodName = cat['product_name'] != null
                  ? cat['product_name'].toString()
                  : (cat['product_detail']?['name']?.toString() ?? '');
              final List items = (cat['items'] as List? ?? []);

              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: getProportionateScreenHeight(kDefaultPadding),
                  horizontal: getProportionateScreenWidth(kDefaultPadding),
                ),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  border: Border.all(color: kWhiteColor),
                  borderRadius: BorderRadius.circular(
                    getProportionateScreenWidth(kDefaultPadding),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: getProportionateScreenHeight(kDefaultPadding / 3),
                  children: [
                    CategoryContainer(
                      title: prodName.toLowerCase() == "aliexpress"
                          ? (items.isNotEmpty
                              ? Service.capitalizeFirstLetters(
                                  _extractProductName(
                                    items[0]['note_for_item'],
                                  ),
                                )
                              : prodName)
                          : Service.capitalizeFirstLetters(prodName),
                    ),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        borderRadius: BorderRadius.circular(
                          getProportionateScreenWidth(kDefaultPadding),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              getProportionateScreenWidth(kDefaultPadding / 2),
                          vertical:
                              getProportionateScreenHeight(kDefaultPadding),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: ClampingScrollPhysics(),
                          separatorBuilder: (context, index) =>
                              Divider(color: kWhiteColor),
                          itemCount: items.length,
                          itemBuilder: (context, idx) {
                            final item = items[idx];
                            final String itemName = item['item_name'] ?? '';
                            final int quantity = item['quantity'] ?? 1;
                            final num totalPrice = item['total_price'] ?? 0;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prodName.toLowerCase() == "aliexpress"
                                            ? _extractItemName(
                                                item['note_for_item'],
                                              )
                                            : Service.capitalizeFirstLetters(
                                                itemName,
                                              ),
                                        softWrap: true,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        "${Provider.of<ZLanguage>(context, listen: false).quantity}: $quantity",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "${Provider.of<ZMetaData>(context, listen: false).currency} ${totalPrice.toStringAsFixed(2)}",
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
          width: double.infinity,
          height: 0.1,
          color: kSecondaryColor,
        ),
      ],
    );
  }

  Widget _buildComboCartTab() {
    final currency = Provider.of<ZMetaData>(context, listen: false).currency;
    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;

    return SingleChildScrollView(
      child: Column(
        spacing: getProportionateScreenHeight(kDefaultPadding / 2),
        children: [
          ..._comboStores.map((store) {
            final storeDetail = store['store_detail'] ?? {};
            final String storeName = storeDetail['name'] ?? 'Store';
            final String storeImg = storeDetail['image_url'] ?? '';
            final uniqueId = store['order_unique_id'] ?? '';
            final seq = store['pickup_sequence'] ?? 1;
            final num storeCartPrice =
                store['order_payment']?['total_cart_price'] ??
                    store['order_payment']?['total_order_price'] ??
                    0;
            final List orderDetails = (store['order_details'] as List? ?? []);

            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                getProportionateScreenWidth(kDefaultPadding / 1.2),
              ),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                border: Border.all(color: kWhiteColor),
                borderRadius: BorderRadius.circular(
                  getProportionateScreenWidth(kDefaultPadding),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store header
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: storeImg.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: storeImg.startsWith("http")
                                      ? storeImg
                                      : "$baseUrl/$storeImg",
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: kWhiteColor,
                                    child: Icon(
                                      HeroiconsOutline.buildingStorefront,
                                      color: kGreyColor,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: kWhiteColor,
                                  child: Icon(
                                    HeroiconsOutline.buildingStorefront,
                                    color: kGreyColor,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(
                        width: getProportionateScreenWidth(kDefaultPadding / 2),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Service.capitalizeFirstLetters(storeName),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: getProportionateScreenHeight(14),
                                color: kBlackColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Stop #$seq · Order #$uniqueId",
                              style: TextStyle(
                                fontSize: getProportionateScreenHeight(11.5),
                                color: kGreyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "$currency ${storeCartPrice.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Store product categories & items
                  ...orderDetails.map((cat) {
                    final String prodName = cat['product_name'] ??
                        cat['product_detail']?['name'] ??
                        '';
                    final List items = (cat['items'] as List? ?? []);

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(
                        getProportionateScreenWidth(kDefaultPadding / 1.5),
                      ),
                      decoration: BoxDecoration(
                        color: kWhiteColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(
                          getProportionateScreenWidth(kDefaultPadding / 1.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CategoryContainer(
                            title: prodName.toLowerCase() == "aliexpress"
                                ? (items.isNotEmpty
                                    ? Service.capitalizeFirstLetters(
                                        _extractProductName(
                                          items[0]['note_for_item'],
                                        ),
                                      )
                                    : prodName)
                                : Service.capitalizeFirstLetters(prodName),
                          ),
                          SizedBox(height: 8),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                Divider(color: kWhiteColor),
                            itemBuilder: (context, idx) {
                              final item = items[idx];
                              final String itemName = item['item_name'] ?? '';
                              final int qty = item['quantity'] ?? 1;
                              final num price = item['total_price'] ??
                                  item['item_price'] ??
                                  0;

                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prodName.toLowerCase() == "aliexpress"
                                              ? _extractItemName(
                                                  item['note_for_item'],
                                                )
                                              : Service.capitalizeFirstLetters(
                                                  itemName,
                                                ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize:
                                                    getProportionateScreenHeight(
                                                      13,
                                                    ),
                                              ),
                                        ),
                                        Text(
                                          "${Provider.of<ZLanguage>(context, listen: false).quantity}: $qty",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "$currency ${price.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize:
                                          getProportionateScreenHeight(13),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          // Combo Total Summary Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(
              getProportionateScreenWidth(kDefaultPadding),
            ),
            decoration: BoxDecoration(
              color: kPrimaryColor,
              border: Border.all(color: kWhiteColor),
              borderRadius: BorderRadius.circular(
                getProportionateScreenWidth(kDefaultPadding),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Combo Cart Items",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                Text(
                  "$currency ${((_comboTotals?['total_cart_price'] ?? 0) as num).toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<dynamic> getDetail() async {
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/order_history_detail";

    Map data = {
      "user_id": effectiveUserId,
      "server_token": effectiveServerToken,
      "order_id": effectiveOrderId,
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Something went wrong!"),
                  backgroundColor: kSecondaryColor,
                ),
              );
              throw TimeoutException("The connection has timed out!");
            },
          );
      if (json.decode(response.body) != null) {
        setState(() {
          responseData = json.decode(response.body);
        });
      }
      setState(() {
        this._loading = false;
      });
      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      setState(() {
        this._loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Your internet connection is bad!"),
          backgroundColor: kSecondaryColor,
        ),
      );
      return null;
    }
  }

  Widget addressDetailRow({
    required IconData icon,
    required String title,
    Color? iconColor,
  }) {
    return Row(
      spacing: getProportionateScreenWidth(kDefaultPadding / 2),
      children: [
        Icon(
          icon,
          size: getProportionateScreenHeight(kDefaultPadding / .75),
          color: iconColor ?? kBlackColor,
        ),
        Expanded(child: Text(title, softWrap: true)),
      ],
    );
  }

  Widget orderDetailRow({
    required bool isRated,
    required bool isStore,
    required String imageUrl,
    // required String userName,
    required String value,
    required bool isCompleted,
    required void Function() onRatePressed,
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: getProportionateScreenHeight(kDefaultPadding / 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: getProportionateScreenWidth(kDefaultPadding / 2),
        children: [
          ImageContainer(
            fit: BoxFit.fill,
            url: imageUrl,
            shape: BoxShape.rectangle,
            border: Border.all(color: kWhiteColor),
            borderRadius: BorderRadius.circular(
              getProportionateScreenWidth(kDefaultPadding / 1.2),
            ),
            width: getProportionateScreenWidth(kDefaultPadding * 3.5),
            height: getProportionateScreenHeight(kDefaultPadding * 3.5),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kBlackColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle ??
                      (isStore
                          ? "Store"
                          : Provider.of<ZLanguage>(
                              context,
                              listen: false,
                            ).deliveredBy),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: kGreyColor),
                ),
              ],
            ),
          ),
          if (isCompleted == true)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: isRated ? null : onRatePressed,
                  child: Icon(
                    isRated ? Icons.star : Icons.star_border,
                    color: isRated ? kSecondaryColor : null,
                    size: 24,
                  ),
                ),
                SizedBox(height: 4),
                Flexible(
                  child: Text(
                    isRated
                        ? Provider.of<ZLanguage>(
                            context,
                            listen: false,
                          ).thankYou
                        : Provider.of<ZLanguage>(context, listen: false).rateUs,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isRated ? kGreyColor : kBlackColor,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
