// ignore_for_file: deprecated_member_use, unnecessary_null_comparison

import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_location/fl_location.dart';
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/aliexpress/ali_product_screen.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/delivery/delivery_screen.dart';
import 'package:zmall/lunch_home/lunch_home_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/notifications/notification_store.dart';
import 'package:zmall/widgets/order_status_row.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/services/zmall_availability_service.dart';
import 'package:zmall/utils/backend_logger.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/store/components/image_container.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/widgets/stock_availability_dialog.dart';
import 'package:zmall/widgets/stock_left_notification.dart';

/// Pair of the checkout-lock decision and the raw availability result used
/// by the "You have X left" popup.
class _CartAvailability {
  const _CartAvailability(this.available, this.result);

  final bool? available;
  final ZmallAvailabilityResult? result;
}

class Body extends StatefulWidget {
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> with TickerProviderStateMixin {
  bool isLocationServicesEnabled = false;
  Cart? cart;
  AliExpressCart? aliexpressCart;
  bool _loading = true;
  bool _checkingAvailability = false;
  bool _checkoutBlocked = false;
  String _lastStockLeftSignature = '';
  double price = 0;
  var appClose;
  var appOpen;
  var storeDetail;
  double? latitude, longitude;
  LocationPermission _permissionStatus = LocationPermission.denied;
  //////////////////newly added
  var storeLocations;
  var storeID;
  String storeName = '';
  var userData;
  var extraItems;
  //double walletBalance = 0.0;
  //String payeePhone = "964345364";
  //String payerPassword = "";
  //bool transferLoading = false;
  //bool isDonation = false;
  //bool isCheckout = false;
  //
  @override
  void initState() {
    super.initState();
    _doLocationTask();
    getCart();
    _getStoreExtraItemList();
    getAppKeys();
    _loading = false;
    // _getTransactions();
  }

  void calculatePrice() {
    double tempPrice = 0;
    cart?.items?.forEach((item) {
      tempPrice += item.price!;
    });
    setState(() {
      price = tempPrice;
    });
  }

  void getCart() async {
    setState(() {
      _loading = true;
    });
    try {
      userData = await Service.read('user');
      var data = await Service.read('cart');
      var aliCart = await Service.read('aliexpressCart');

      if (data != null) {
        setState(() {
          cart = Cart.fromJson(data);
          cart!.serverToken = userData['user']['server_token'];
          //walletBalance = double.parse(userData['user']['wallet'].toString());
          storeID = cart!.storeId!;
          Service.save('cart', cart!.toJson());
        });

        // debugPrint("ALI CART>>> ${aliCart != null}");
        if (aliCart != null) {
          setState(() {
            aliexpressCart = AliExpressCart.fromJson(aliCart);
            Service.save('aliexpressCart', aliexpressCart);
          });
        }
        // else {
        //   debugPrint("ALI CART NOT FOUND>>>");
        // }
        _getStoreExtraItemList();

        calculatePrice();
        _refreshAvailability();
        if (cart != null && cart!.items!.isNotEmpty) {
          _getStoreDetail();
        } else {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (e) {
      // debugPrint('CART_FROMJSON_ERROR: $e\n$st');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _getStoreDetail() async {
    setState(() {
      _loading = true;
    });
    var data = await getStoreDetail();
    if (data != null && data['success']) {
      setState(() {
        storeDetail = data;
        cart!.isLaundryService =
            storeDetail['store']['is_provide_laundry_service'];
        storeLocations = storeDetail['store']['location'];
        storeName = storeDetail['store']['name'];
        if (aliexpressCart?.cart != null &&
            cart!.storeId == aliexpressCart!.cart.storeId) {
          cart!.storeLocation = aliexpressCart!.cart.storeLocation =
              StoreLocation(long: storeLocations[1], lat: storeLocations[0]);
        }
      });
      Service.save('cart', cart!.toJson());
      Service.save('aliexpressCart', aliexpressCart?.toJson());
    } else {
      Service.showMessage(
        context: context,
        title: "${errorCodes['${data['error_code']}']}!",
        error: true,
      );
    }
    setState(() {
      _loading = false;
    });
  }

  void _requestLocationPermission() async {
    // First, check if location services are enabled
    bool isLocationServicesEnabled = await FlLocation.isLocationServicesEnabled;
    // debugPrint( ">>>>\n is location on in permition $isLocationServicesEnabled");

    if (isLocationServicesEnabled == true) {
      // Then check permissions
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
    } else {
      // Location services are disabled
      Service.showMessage(
        context: context,
        title:
            "Location services are turned off. Please enable them in your device settings.",
        error: true,
      );
      return;
    }
  }

  void getLocation() async {
    try {
      var currentLocation = await FlLocation.getLocation(
        timeLimit: const Duration(seconds: 10), // Add a timeout
      );
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
    } catch (e) {
      // Handle location retrieval errors
      if (mounted) {
        Service.showMessage(
          context: context,
          title: "Could not get your location. Using default location instead.",
          error: true,
        );
        // Here you could explicitly set to use default location
        // Or provide UI for the user to manually enter location
      }
    }
  }

  void _doLocationTask() async {
    LocationPermission _permissionStatus =
        await FlLocation.checkLocationPermission();
    if (_permissionStatus == LocationPermission.whileInUse ||
        _permissionStatus == LocationPermission.always) {
      isLocationServicesEnabled = await FlLocation.isLocationServicesEnabled;
      if (isLocationServicesEnabled == true) {
        // debugPrint(">>>>>>\n is location on in permition $isLocationServicesEnabled");
        getLocation();
      } else {
        Service.showMessage(
          context: context,
          title:
              "Location services are turned off. Please enable them in your device settings.",
          error: true,
        );
        _requestLocationPermission();
      }
    } else {
      _requestLocationPermission();
    }
  }

  Future<bool> storeOpen() async {
    bool isStoreOpen = false;
    DateFormat dateFormat = new DateFormat.Hm();
    DateTime now = DateTime.now().toUtc().add(Duration(hours: 3));
    var appClose = await Service.read('app_close');
    var appOpen = await Service.read('app_open');
    DateTime zmallClose = dateFormat.parse(appClose);
    DateTime zmallOpen = dateFormat.parse(appOpen);

    now = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    zmallOpen = new DateTime(
      now.year,
      now.month,
      now.day,
      zmallOpen.hour,
      zmallOpen.minute,
    );
    zmallClose = new DateTime(
      now.year,
      now.month,
      now.day,
      zmallClose.hour,
      zmallOpen.minute,
    );
    if (now.isAfter(zmallOpen) && now.isBefore(zmallClose)) {
      isStoreOpen = true;
    } else {
      isStoreOpen = false;
    }
    return isStoreOpen;
  }

  void getAppKeys() async {
    var appKeys = await CoreServices.appKeys(context);
    if (appKeys != null && appKeys['success']) {
      if (mounted)
        setState(() {
          appClose = appKeys['app_close'];
          appOpen = appKeys['app_open'];
          Service.save("app_close", appClose);
          Service.save("app_open", appOpen);
        });
    } else {
      appClose = await Service.read('app_close');
      appOpen = await Service.read('app_open');
    }
  }

  //////////////////////////////////////////////////////////////////newly added
  void _getStoreExtraItemList() async {
    setState(() {
      _loading = true;
    });
    var data = await getStoreExtraItemList();

    if (data != null && data['success']) {
      extraItems = data['items'];
      // debugPrint(storeID);
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  String _getPrice(item) {
    if (item['price'] == null || item['price'] == 0) {
      for (var i = 0; i < item['specifications'].length; i++) {
        for (var j = 0; j < item['specifications'][i]['list'].length; j++) {
          if (item['specifications'][i]['list'][j]['is_default_selected']) {
            return item['specifications'][i]['list'][j]['price']
                .toStringAsFixed(2);
          }
        }
      }
    } else {
      return item['price'].toStringAsFixed(2);
    }
    return "0.00";
  }

  Future<bool> _checkAvailability() async {
    if (cart == null || cart!.items == null || cart!.items!.isEmpty) {
      return true;
    }

    final String? branchSlug = zmallBranchSlugForStore(cart!.storeId);
    if (branchSlug == null) {
      // Non-POS store — Odoo availability does not apply.
      return true;
    }

    final List<Map<String, dynamic>> products = [];
    final List<Item> itemsMissingOdooId = [];

    for (final item in cart!.items!) {
      final int? odooProductId = item.odooProductId;
      if (odooProductId == null) {
        itemsMissingOdooId.add(item);
        continue;
      }
      products.add({
        "product_id": odooProductId,
        "quantity": item.quantity ?? 1,
      });
    }

    if (itemsMissingOdooId.isNotEmpty) {
      BackendLogger.error(
        method: 'POST',
        url: '$kZmallOdooBaseUrl/zmall_order/$branchSlug',
        error:
            'Missing odoo_product_id for: ${itemsMissingOdooId.map((i) => i.itemName ?? i.id).join(", ")}',
      );
      Service.showMessage(
        context: context,
        title:
            "Some items are missing store inventory IDs. Remove them and add again from the product list.",
        error: true,
        duration: 4,
      );
      return false;
    }

    if (products.isEmpty) {
      return true;
    }

    BackendLogger.request(
      method: 'POST',
      url: '$kZmallOdooBaseUrl/zmall_order/$branchSlug',
      body: 'branch=$branchSlug storeId=${cart!.storeId} products=$products',
    );

    final result = await ZmallAvailabilityService.check(
      branchSlug: branchSlug,
      products: products,
    );

    if (result == null) {
      Service.showMessage(
        context: context,
        title:
            "Could not verify item availability. Please check your connection and try again.",
        error: true,
      );
      return false;
    }

    if (!result.success) {
      Service.showMessage(
        context: context,
        title: result.error ?? "Availability check failed.",
        error: true,
      );
      return false;
    }

    if (!result.canCheckout ||
        result.products.any((p) => !p.isAvailableForRequestedQuantity)) {
      await StockAvailabilityDialog.show(
        context: context,
        cartItems: cart!.items!,
        availabilityResult: result,
        onAdjustItem: _applyStockAdjustment,
        onAdjustAll: () => _applyAllStockAdjustments(result),
      );
      return false;
    }

    return true;
  }

  /// Silent availability check that updates [_checkoutBlocked] so the
  /// Checkout button can be locked while items are out of stock. When
  /// [showStockLeftNotification] is true (only when the user increases an
  /// item quantity) it also surfaces the "Limited Stock" popup based on the
  /// Odoo `forecasted_quantity`.
  Future<void> _refreshAvailability({
    bool showStockLeftNotification = false,
  }) async {
    if (!mounted) return;

    final _CartAvailability availability = await _fetchCartAvailability();
    final bool? available = availability.available;
    final bool block = available != null && !available;
    if (!mounted) return;
    if (_checkoutBlocked != block) {
      setState(() => _checkoutBlocked = block);
    }
    _debugDumpCart(available);
    if (showStockLeftNotification) {
      _maybeShowStockLeftNotification(availability.result);
    }
  }

  /// Debug-only dump of everything the availability/lock logic depends on.
  /// Run with `flutter run` (debug build) and read the [CART DEBUG] lines.
  void _debugDumpCart(bool? available) {
    if (!kDebugMode) return;
    final StringBuffer sb = StringBuffer('\n===== CART DEBUG =====\n');
    sb.writeln(
      'storeId: ${cart?.storeId ?? 'null'} (trimmed: "${cart?.storeId?.trim() ?? ''}")',
    );
    final String? slug = zmallBranchSlugForStore(cart?.storeId);
    sb.writeln(
      'branchSlug: ${slug ?? 'null  <-- NOT MAPPED: availability check is SKIPPED, checkout stays open'}',
    );
    if (cart?.items != null && cart!.items!.isNotEmpty) {
      sb.writeln('items:');
      for (final item in cart!.items!) {
        sb.writeln(
          '  - ${item.itemName ?? '(no name)'} | qty=${item.quantity ?? 1} | odoo_product_id=${item.odooProductId ?? 'null  <-- cannot be checked'}',
        );
      }
    } else {
      sb.writeln('items: (empty)');
    }
    sb.writeln(
      'availability: ${available == null
          ? 'UNKNOWN (network/server error -> not blocking)'
          : available
          ? 'available -> checkout UNLOCKED'
          : 'NOT available -> checkout LOCKED'}',
    );
    sb.writeln('_checkoutBlocked: $_checkoutBlocked');
    sb.writeln('===== /CART DEBUG =====');
    debugPrintSynchronously(sb.toString());
  }

  /// Core availability logic shared by the tap-time and auto checks.
  /// Returns:
  ///  - `available == true`   → all items available, checkout allowed
  ///  - `available == false`  → checkout must be blocked (out of stock / missing IDs)
  ///  - `available == null`   → could not verify (network/server error) — do not hard-block
  Future<_CartAvailability> _fetchCartAvailability() async {
    if (cart == null || cart!.items == null || cart!.items!.isEmpty) {
      return _CartAvailability(true, null);
    }

    final String? branchSlug = zmallBranchSlugForStore(cart!.storeId);
    if (branchSlug == null) {
      // Non-POS store — Odoo availability does not apply.
      return _CartAvailability(true, null);
    }

    final List<Map<String, dynamic>> products = [];
    final List<Item> itemsMissingOdooId = [];

    for (final item in cart!.items!) {
      final int? odooProductId = item.odooProductId;
      if (odooProductId == null) {
        itemsMissingOdooId.add(item);
        continue;
      }
      products.add({
        "product_id": odooProductId,
        "quantity": item.quantity ?? 1,
      });
    }

    if (itemsMissingOdooId.isNotEmpty) {
      return _CartAvailability(false, null);
    }

    if (products.isEmpty) {
      return _CartAvailability(true, null);
    }

    final result = await ZmallAvailabilityService.check(
      branchSlug: branchSlug,
      products: products,
    );

    if (result == null || !result.success) {
      // Could not verify — leave the button unlocked so the tap-time
      // check can surface the connection/server error.
      return _CartAvailability(null, null);
    }

    return _CartAvailability(
      result.canCheckout &&
          result.products.every((p) => p.isAvailableForRequestedQuantity),
      result,
    );
  }

  /// Shows the "Limited Stock" popup for every cart item whose quantity in
  /// the cart is greater than the Odoo `forecasted_quantity`, e.g. cart has
  /// 21 and the forecast is 20 → "Only 20 available".
  /// Only called when the user increases an item quantity.
  void _maybeShowStockLeftNotification(ZmallAvailabilityResult? result) {
    if (!mounted || result == null || cart == null) return;

    final List<StockLeftItem> stockLeftItems = [];
    for (final item in cart!.items!) {
      final int? odooId = item.odooProductId;
      if (odooId == null) continue;

      for (final product in result.products) {
        if (product.productId == odooId) {
          final double forecasted = product.forecastedQuantity ?? 0;
          final int cartQty = item.quantity ?? 1;
          if (cartQty > forecasted && forecasted >= 0) {
            stockLeftItems.add(
              StockLeftItem(
                item: item,
                forecastedQty: forecasted.toInt(),
                cartQty: cartQty,
              ),
            );
          }
          break;
        }
      }
    }

    if (stockLeftItems.isEmpty) return;

    final String signature = stockLeftItems
        .map((s) => '${s.item.id}:${s.forecastedQty}:${s.cartQty}')
        .join('|');
    if (signature == _lastStockLeftSignature) return;
    _lastStockLeftSignature = signature;

    StockLeftNotification.show(context: context, items: stockLeftItems);
  }

  void _applyStockAdjustment(Item item, int maxAvailable) {
    final int index = cart!.items!.indexOf(item);
    if (index < 0 || maxAvailable <= 0) return;

    final int currentQty = cart!.items![index].quantity ?? 1;
    if (currentQty <= 0) return;

    final double unitPrice = (cart!.items![index].price ?? 0) / currentQty;
    setState(() {
      cart!.items![index].quantity = maxAvailable;
      cart!.items![index].price = unitPrice * maxAvailable;
    });
    Service.save('cart', cart!.toJson());
    calculatePrice();
    _refreshAvailability();
  }

  void _applyAllStockAdjustments(ZmallAvailabilityResult result) {
    for (final item in cart!.items!) {
      final int? odooId = item.odooProductId;
      if (odooId == null) continue;

      for (final product in result.products) {
        if (product.productId == odooId &&
            !product.isAvailableForRequestedQuantity) {
          final double forecasted = product.forecastedQuantity ?? 0;
          if (forecasted > 0) {
            _applyStockAdjustment(item, forecasted.toInt());
          }
          break;
        }
      }
    }
    _refreshAvailability();
  }

  void addToCart(item, destination, storeLocation, storeId) {
    cart = Cart(
      userId: userData['user']['_id'],
      items: [item],
      serverToken: userData['user']['server_token'],
      destinationAddress: destination,
      storeId: storeId,
      storeLocation: storeLocation,
    );

    Service.save('cart', cart!.toJson());
    // Service.showMessage(
    //   context: context,
    //   title: "Item added to cart!",
    //   error: false,
    // );
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:
          userData != null && (cart != null && cart!.items!.length > 0)
          ? SafeArea(
              child: Container(
                width: double.infinity,
                // height: kDefaultPadding * 4,
                padding: EdgeInsets.symmetric(
                  vertical: getProportionateScreenHeight(kDefaultPadding / 2),
                  // horizontal: getProportionateScreenHeight(kDefaultPadding / 2),
                ).copyWith(bottom: getProportionateScreenHeight(kDefaultPadding)),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  border: Border(top: BorderSide(color: kWhiteColor)),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kDefaultPadding),
                    topRight: Radius.circular(kDefaultPadding),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: getProportionateScreenHeight(kDefaultPadding),
                  // crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //
                    if (extraItems != null) showExtraItems(),
                    // Spacer(),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(
                          kDefaultPadding,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: getProportionateScreenWidth(
                          kDefaultPadding * 1.2,
                        ),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            // crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${Provider.of<ZMetaData>(context, listen: false).currency} ${price.toStringAsFixed(2)}",
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      // fontSize: 18,
                                      color: kBlackColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                "${Provider.of<ZLanguage>(context).cartTotal}",
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: kGreyColor),
                              ),
                            ],
                          ),
                          Expanded(
                            child: CustomButton(
                              title: _checkoutBlocked
                                  ? "Out of stock"
                                  : _checkingAvailability
                                  ? "Checking stock..."
                                  : Provider.of<ZLanguage>(context).checkout,
                              enabled: !_checkoutBlocked,
                              press: (_checkingAvailability || _checkoutBlocked)
                                  ? () {}
                                  : () async {
                                      //   if (isDonation && !isCheckout) {
                                      //   setState(() {
                                      //     isCheckout = !isCheckout;
                                      //   });
                                      // } else {

                                      if (!isLocationServicesEnabled) {
                                        Service.showMessage(
                                          context: context,
                                          title:
                                              "Location services are turned off. Please enable them in your device settings.",
                                          error: true,
                                        );
                                        _doLocationTask();
                                      } else {
                                        setState(
                                          () => _checkingAvailability = true,
                                        );
                                        try {
                                          if (!await _checkAvailability()) {
                                            return;
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () =>
                                                  _checkingAvailability = false,
                                            );
                                          }
                                        }
                                        DateFormat dateFormat =
                                            new DateFormat.Hm();
                                        DateTime now = DateTime.now()
                                            .toUtc()
                                            .add(Duration(hours: 3));
                                        var appClose = await Service.read(
                                          'app_close',
                                        );
                                        var appOpen = await Service.read(
                                          'app_open',
                                        );
                                        DateTime zmallClose = dateFormat.parse(
                                          appClose,
                                        );
                                        DateTime zmallOpen = dateFormat.parse(
                                          appOpen,
                                        );

                                        now = DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                          now.hour,
                                          now.minute,
                                        );
                                        zmallOpen = new DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                          zmallOpen.hour,
                                          zmallOpen.minute,
                                        );
                                        zmallClose = new DateTime(
                                          now.year,
                                          now.month,
                                          now.day,
                                          zmallClose.hour,
                                          zmallClose.minute,
                                        );

                                        if (now.isAfter(zmallOpen) &&
                                            now.isBefore(zmallClose)) {
                                          Navigator.pushNamed(
                                            context,
                                            DeliveryScreen.routeName,
                                          );
                                          //   if (isDonation) {
                                          //   debugPrint('***This is Donation***');
                                          //   //showDonation();
                                          // } else {
                                          //   Navigator.pushNamed(
                                          //       context, DeliveryScreen.routeName);
                                          // }
                                        } else {
                                          Service.showMessage(
                                            context: context,
                                            title:
                                                "Sorry, we are currently closed. Please comeback soon.",
                                            error: false,
                                            duration: 3,
                                          );
                                        }
                                      }
                                    },
                              // },
                              color: kSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SizedBox.shrink(),
      body: ModalProgressHUD(
        color: kPrimaryColor,
        progressIndicator: LinearLoadingIndicator(title: "Checking..."),
        // progressIndicator: Column(
        //   mainAxisAlignment: MainAxisAlignment.center,
        //   children: [
        //     SpinKitWave(
        //       color: kSecondaryColor,
        //       size: getProportionateScreenHeight(kDefaultPadding),
        //     ),
        //     Text("Checking if items are available..."),
        //   ],
        // ),
        inAsyncCall: _loading,
        child: cart != null && cart!.items!.length > 0
            ? Column(
                children: [
                  Container(
                    padding: EdgeInsets.only(
                      left: getProportionateScreenWidth(kDefaultPadding / 2),
                      right: getProportionateScreenWidth(kDefaultPadding / 2),
                      bottom: getProportionateScreenHeight(kDefaultPadding / 2),
                    ),
                    decoration: BoxDecoration(
                      color: kWhiteColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(kDefaultPadding * 1.2),
                        bottomRight: Radius.circular(kDefaultPadding * 1.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (storeName.isNotEmpty)
                          Expanded(
                            child: OrderStatusRow(
                              title: "Store",
                              iconBackgroundColor: kPrimaryColor,
                              icon: HeroiconsOutline.buildingStorefront,
                              fontSize: getProportionateScreenHeight(14),
                              value: Service.capitalizeFirstLetters(storeName),
                            ),
                          ),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadiusGeometry.circular(
                                kDefaultPadding / 1.5,
                              ),
                            ),
                          ),
                          onPressed:
                              storeName.toString().toLowerCase() == "aliexpress"
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        return AliProductListScreen();
                                      },
                                    ),
                                  );
                                }
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        return NotificationStore(
                                          storeId: cart!.storeId!,
                                        );
                                      },
                                    ),
                                  );
                                },
                          child: Text(
                            "Add more?",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              // decoration: TextDecoration.underline
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divider(
                  //   color: kWhiteColor,
                  //   thickness: 1,
                  // ),
                  // SizedBox(
                  //     height: getProportionateScreenHeight(kDefaultPadding / 3)),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: cart!.toJson()['items'].length ?? 0,
                      padding: EdgeInsets.only(
                        left: getProportionateScreenWidth(kDefaultPadding / 2),
                        right: getProportionateScreenWidth(kDefaultPadding / 2),
                        top: getProportionateScreenHeight(kDefaultPadding / 2),
                      ),
                      separatorBuilder: (BuildContext context, int index) =>
                          Container(
                            height: getProportionateScreenHeight(
                              kDefaultPadding / 3,
                            ),
                          ),
                      itemBuilder: (context, index) {
                        final item = cart!.items?[index];
                        final isLunchBox =
                            item?.itemName?.contains('ምሳቃ') ?? false;
                        return item != null
                            ? GestureDetector(
                                onTap: isLunchBox
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                LunchHomeScreen(
                                                  curLat: latitude ?? 0,
                                                  curLon: longitude ?? 0,
                                                ),
                                          ),
                                        );
                                      }
                                    : null,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: getProportionateScreenWidth(
                                      kDefaultPadding / 2,
                                    ),
                                    vertical: getProportionateScreenHeight(
                                      kDefaultPadding / 4,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor,
                                    border: Border.all(
                                      color: isLunchBox
                                          ? kSecondaryColor
                                          : kWhiteColor,
                                      width: isLunchBox ? 3 : 2,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      kDefaultPadding,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ImageContainer(url: item.imageURL!),
                                      SizedBox(
                                        width: getProportionateScreenWidth(
                                          kDefaultPadding / 2,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          spacing: getProportionateScreenHeight(
                                            kDefaultPadding / 5,
                                          ),
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    isLunchBox
                                                        ? 'LUNCH ምሳቃ BOX'
                                                        : Service.capitalizeFirstLetters(
                                                            item.itemName!,
                                                          ),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isLunchBox
                                                          ? kSecondaryColor
                                                          : kBlackColor,
                                                    ),
                                                    softWrap: true,
                                                  ),
                                                ),
                                                if (isLunchBox)
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                      left:
                                                          getProportionateScreenWidth(
                                                            kDefaultPadding / 4,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.lunch_dining,
                                                      color: kSecondaryColor,
                                                      size: 20,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            Text(
                                              "${Provider.of<ZMetaData>(context, listen: false).currency} ${item.price!.toStringAsFixed(2)}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    color: kGreyColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            Text(item.noteForItem),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.remove_circle_outline,
                                                  color: item.quantity != 1
                                                      ? kSecondaryColor
                                                      : kGreyColor,
                                                ),
                                                onPressed: item.quantity == 1
                                                    ? () {
                                                        Service.showMessage(
                                                          context: context,
                                                          title:
                                                              "Minimum order quantity is 1!",
                                                          error: true,
                                                        );
                                                      }
                                                    : () {
                                                        int? currQty =
                                                            item.quantity;
                                                        double? unitPrice =
                                                            item.price! /
                                                            currQty!;
                                                        setState(() {
                                                          item.quantity =
                                                              currQty - 1;
                                                          item.price =
                                                              unitPrice *
                                                              (currQty - 1);
                                                          Service.save(
                                                            'cart',
                                                            cart!.toJson(),
                                                          );
                                                          if (aliexpressCart !=
                                                                  null &&
                                                              aliexpressCart!
                                                                      .cart
                                                                      .storeId ==
                                                                  cart!
                                                                      .storeId) {
                                                            aliexpressCart!
                                                                    .cart
                                                                    .items![index]
                                                                    .quantity =
                                                                currQty - 1;
                                                            aliexpressCart!
                                                                    .cart
                                                                    .items![index]
                                                                    .price =
                                                                unitPrice *
                                                                (currQty - 1);
                                                            Service.save(
                                                              'aliexpressCart',
                                                              aliexpressCart,
                                                            );
                                                          }
                                                        });
                                                        calculatePrice();
                                                        _refreshAvailability();
                                                      },
                                              ),
                                              Text(
                                                "${item.quantity}",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: kBlackColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.add_circle,
                                                  color: kSecondaryColor,
                                                ),
                                                onPressed: () {
                                                  int? currQty = item.quantity;
                                                  double? unitPrice =
                                                      item.price! / currQty!;
                                                  setState(() {
                                                    item.quantity = currQty + 1;
                                                    item.price =
                                                        unitPrice *
                                                        (currQty + 1);
                                                    Service.save(
                                                      'cart',
                                                      cart!.toJson(),
                                                    );
                                                    if (aliexpressCart !=
                                                            null &&
                                                        aliexpressCart!
                                                                .cart
                                                                .storeId ==
                                                            cart!.storeId) {
                                                      aliexpressCart!
                                                              .cart
                                                              .items![index]
                                                              .quantity =
                                                          currQty + 1;
                                                      aliexpressCart!
                                                              .cart
                                                              .items![index]
                                                              .price =
                                                          unitPrice *
                                                          (currQty + 1);
                                                      Service.save(
                                                        'aliexpressCart',
                                                        aliexpressCart,
                                                      );
                                                    }
                                                  });
                                                  calculatePrice();
                                                  _refreshAvailability(
                                                    showStockLeftNotification:
                                                        true,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                cart?.items?.removeAt(index);
                                                Service.save(
                                                  'cart',
                                                  cart!.toJson(),
                                                );
                                                if (aliexpressCart != null &&
                                                    aliexpressCart!
                                                            .cart
                                                            .storeId ==
                                                        cart!.storeId) {
                                                  aliexpressCart!.cart.items!
                                                      .removeAt(index);
                                                  aliexpressCart!.itemIds!
                                                      .removeAt(index);
                                                  aliexpressCart!.productIds!
                                                      .removeAt(index);
                                                  Service.save(
                                                    'aliexpressCart',
                                                    aliexpressCart,
                                                  );
                                                }
                                              });
                                              calculatePrice();
                                              _refreshAvailability();
                                            },
                                            child: Text(
                                              Provider.of<ZLanguage>(
                                                context,
                                              ).remove,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    fontSize: 12,
                                                    color: kSecondaryColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SizedBox.shrink();
                      },
                    ),
                  ),

                  ///////////////////////////New customization
                  // Align(
                  //   alignment: Alignment.bottomCenter,
                  //   child: Container(
                  //     decoration: BoxDecoration(
                  //         border: Border(top: BorderSide(color: kWhiteColor)),
                  //         borderRadius: BorderRadius.only(
                  //             topLeft: Radius.circular(kDefaultPadding),
                  //             topRight: Radius.circular(kDefaultPadding))),
                  //     padding: EdgeInsets.symmetric(
                  //         vertical:
                  //             getProportionateScreenHeight(kDefaultPadding / 2)),
                  //     child: Column(
                  //       mainAxisSize: MainAxisSize.min,
                  //       spacing:
                  //           getProportionateScreenHeight(kDefaultPadding / 4),
                  //       // crossAxisAlignment: CrossAxisAlignment.start,
                  //       children: [
                  //         //

                  //         if (extraItems != null) showExtraItems(),
                  //         // Spacer(),
                  //         Padding(
                  //           padding: EdgeInsets.symmetric(
                  //             horizontal:
                  //                 getProportionateScreenWidth(kDefaultPadding),
                  //           ).copyWith(
                  //               top: getProportionateScreenHeight(
                  //                   kDefaultPadding / 2)),
                  //           child: Row(
                  //             mainAxisSize: MainAxisSize.min,
                  //             spacing:
                  //                 getProportionateScreenWidth(kDefaultPadding),
                  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //             children: [
                  //               Column(
                  //                 mainAxisSize: MainAxisSize.min,
                  //                 mainAxisAlignment:
                  //                     MainAxisAlignment.spaceBetween,
                  //                 // crossAxisAlignment: CrossAxisAlignment.start,
                  //                 children: [
                  //                   Text(
                  //                     "${Provider.of<ZMetaData>(context, listen: false).currency} ${price.toStringAsFixed(2)}",
                  //                     style: Theme.of(context)
                  //                         .textTheme
                  //                         .titleLarge
                  //                         ?.copyWith(
                  //                           fontSize: 18,
                  //                           color: kBlackColor,
                  //                           fontWeight: FontWeight.bold,
                  //                         ),
                  //                   ),
                  //                   Text(
                  //                     "${Provider.of<ZLanguage>(context).cartTotal}",
                  //                     style: Theme.of(context)
                  //                         .textTheme
                  //                         .bodySmall
                  //                         ?.copyWith(
                  //                           color: kGreyColor,
                  //                         ),
                  //                   ),
                  //                 ],
                  //               ),
                  //               Expanded(
                  //                 child: CustomButton(
                  //                   title:
                  //                       Provider.of<ZLanguage>(context).checkout,
                  //                   press: () async {
                  //                     //   if (isDonation && !isCheckout) {
                  //                     //   setState(() {
                  //                     //     isCheckout = !isCheckout;
                  //                     //   });
                  //                     // } else {
                  //                     DateFormat dateFormat = new DateFormat.Hm();
                  //                     DateTime now = DateTime.now()
                  //                         .toUtc();
                  //                       .add(Duration(hours: 3));
                  //                     var appClose =
                  //                         await Service.read('app_close');
                  //                     var appOpen =
                  //                         await Service.read('app_open');
                  //                     DateTime zmallClose =
                  //                         dateFormat.parse(appClose);
                  //                     DateTime zmallOpen =
                  //                         dateFormat.parse(appOpen);

                  //                     now = DateTime(now.year, now.month, now.day,
                  //                         now.hour, now.minute);
                  //                     zmallOpen = new DateTime(
                  //                         now.year,
                  //                         now.month,
                  //                         now.day,
                  //                         zmallOpen.hour,
                  //                         zmallOpen.minute);
                  //                     zmallClose = new DateTime(
                  //                         now.year,
                  //                         now.month,
                  //                         now.day,
                  //                         zmallClose.hour,
                  //                         zmallClose.minute);

                  //                     if (now.isAfter(zmallOpen) &&
                  //                         now.isBefore(zmallClose)) {
                  //                       Navigator.pushNamed(
                  //                           context, DeliveryScreen.routeName);
                  //                       //   if (isDonation) {
                  //                       //   debugPrint('***This is Donation***');
                  //                       //   //showDonation();
                  //                       // } else {
                  //                       //   Navigator.pushNamed(
                  //                       //       context, DeliveryScreen.routeName);
                  //                       // }
                  //                     } else {
                  //                       Service.showMessage(
                  //                           context: context,
                  //                           title:
                  //                               "Sorry, we are currently closed. Please comeback soon.",
                  //                           error: false,
                  //                           duration: 3);
                  //                     }
                  //                   },
                  //                   // },
                  //                   color: kSecondaryColor,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  //////////////////////////////////////////////////
                ],
              )
            : Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(kDefaultPadding),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        HeroiconsOutline.shoppingCart,
                        size: getProportionateScreenHeight(kDefaultPadding * 5),
                        color: kSecondaryColor.withOpacity(0.8),
                      ),
                      SizedBox(
                        height: getProportionateScreenHeight(
                          kDefaultPadding * 1.5,
                        ),
                      ),
                      Text(
                        "Your Basket is Empty!",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800, // Very bold
                          color: kBlackColor,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                        height: getProportionateScreenHeight(
                          kDefaultPadding / 2,
                        ),
                      ),
                      Text(
                        "Start adding products to your cart to begin your order.",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: kGreyColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Optional: Add a button to navigate to products/home
                      // SizedBox(
                      //     height: getProportionateScreenHeight(
                      //         kDefaultPadding * 2)),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              "/start",
                              (Route<dynamic> route) => false,
                            );
                          },
                          child: Text(
                            "Start Shopping",
                            style: Theme.of(context).textTheme.titleMedium!
                                .copyWith(
                                  color: kSecondaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      //  Padding(
                      // padding: EdgeInsets.symmetric(
                      //     horizontal: getProportionateScreenWidth(
                      //         kDefaultPadding / 2)),
                      // child: CustomButton(
                      //   title: "Start Shopping",
                      //   press: () {
                      //     Navigator.pushNamedAndRemoveUntil(context, "/start",
                      //         (Route<dynamic> route) => false);
                      //   },
                      //   color: kSecondaryColor,
                      // ),
                      // ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<dynamic> getStoreDetail() async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/user_get_store_product_item_list";
    Map data = {"store_id": cart!.storeId!};
    var body = json.encode(data);
    try {
      BackendLogger.request(
        method: 'POST',
        url: url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: body,
      );
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
              setState(() {
                this._loading = false;
              });
              throw TimeoutException("The connection has timed out!");
            },
          );
      BackendLogger.response(
        method: 'POST',
        url: url,
        statusCode: response.statusCode,
        body: response.body,
      );
      setState(() {
        this.storeDetail = json.decode(response.body);
      });
      return json.decode(response.body);
    } catch (e) {
      BackendLogger.error(method: 'POST', url: url, error: e);
      if (mounted) {
        Service.showMessage(
          context: context,
          title:
              "Couldn't get store detail, check your internet and try again.",
          error: true,
          duration: 3,
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
  ///////////////////////////////////////////////////////////newly added

  Future<dynamic> getStoreExtraItemList() async {
    // debugPrint('Store ID ***${storeID}***');
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/user_get_store_product_item_available";

    Map data = {"store_id": storeID};
    var body = json.encode(data);

    try {
      BackendLogger.request(
        method: 'POST',
        url: url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: body,
      );
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
              setState(() {
                this._loading = false;
              });

              Service.showMessage(
                context: context,
                title: "Something went wrong!",
                error: true,
                duration: 3,
              );
              throw TimeoutException("The connection has timed out!");
            },
          );
      BackendLogger.response(
        method: 'POST',
        url: url,
        statusCode: response.statusCode,
        body: response.body,
      );
      setState(() {
        this._loading = false;
      });

      return json.decode(response.body);
    } catch (e) {
      BackendLogger.error(method: 'POST', url: url, error: e);
      // debugPrint(e);
      if (mounted) {
        setState(() {
          this._loading = false;
        });
      }

      return null;
    }
  }

  void _showDialog(item, destination, storeLocation, storeId) {
    showDialog(
      context: context,
      builder: (BuildContext alertContext) {
        return AlertDialog(
          backgroundColor: kPrimaryColor,
          title: Text(Provider.of<ZLanguage>(context).warning),
          content: Text(Provider.of<ZLanguage>(context).itemsFound),
          actions: [
            TextButton(
              child: Text(
                Provider.of<ZLanguage>(context).cancel,
                style: TextStyle(
                  color: kBlackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(alertContext).pop();
              },
            ),
            TextButton(
              child: Text(
                Provider.of<ZLanguage>(context).clear,
                style: TextStyle(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                setState(() {
                  cart!.toJson();
                  Service.remove('cart');
                  Service.remove('aliexpressCart'); ////NEW
                  cart = Cart();
                  addToCart(item, destination, storeLocation, storeId);
                });

                Navigator.of(alertContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget showExtraItems() {
    bool isNull = extraItems.every(
      (extraItem) => cart!.items!.any(
        (cartItem) => cartItem.toJson()['_id'] == extraItem['_id'],
      ),
    );
    return isNull
        ? SizedBox.shrink()
        : Column(
            mainAxisSize: MainAxisSize.min,
            spacing: getProportionateScreenHeight(kDefaultPadding / 2),
            children: [
              if (extraItems != null)
                Text(
                  'Perfect Paring for Your Order!',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: kBlackColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Container(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * 0.12,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: extraItems.length,
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(
                      kDefaultPadding / 2,
                    ),
                    vertical: getProportionateScreenHeight(kDefaultPadding / 2),
                  ),
                  separatorBuilder: (BuildContext context, int index) =>
                      SizedBox(
                        width: getProportionateScreenWidth(kDefaultPadding / 2),
                      ),
                  itemBuilder: (context, index) {
                    bool isAppear = cart!.items!.any(
                      (element) =>
                          element.toJson()['_id'] == extraItems[index]['_id'],
                    );
                    if (isAppear) {
                      return SizedBox.shrink();
                    }
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: kWhiteColor),
                        borderRadius: BorderRadius.circular(kDefaultPadding),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(
                          kDefaultPadding / 2,
                        ),
                        vertical: getProportionateScreenHeight(
                          kDefaultPadding / 3,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        spacing: getProportionateScreenHeight(
                          kDefaultPadding / 3,
                        ),
                        children: [
                          /////item image section///
                          CachedNetworkImage(
                            imageUrl:
                                "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${extraItems[index]['image_url']}",
                            imageBuilder: (context, imageProvider) => Container(
                              width: getProportionateScreenWidth(
                                kDefaultPadding * 3,
                              ),
                              height: getProportionateScreenHeight(
                                kDefaultPadding * 3,
                              ),
                              decoration: BoxDecoration(
                                color: kWhiteColor,
                                borderRadius: BorderRadius.circular(
                                  getProportionateScreenHeight(kDefaultPadding),
                                ),
                                image: DecorationImage(
                                  fit: BoxFit.contain,
                                  image: imageProvider,
                                ),
                              ),
                            ),
                            placeholder: (context, url) => Center(
                              child: Container(
                                width: getProportionateScreenWidth(
                                  kDefaultPadding * 3,
                                ),
                                height: getProportionateScreenHeight(
                                  kDefaultPadding * 3,
                                ),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    kWhiteColor,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: getProportionateScreenWidth(
                                kDefaultPadding * 3,
                              ),
                              height: getProportionateScreenHeight(
                                kDefaultPadding * 3,
                              ),
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  fit: BoxFit.contain,
                                  image: AssetImage(zmallLogo),
                                ),
                              ),
                            ),
                          ),

                          //////item name and price section////
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                extraItems[index]['name'],
                                style: TextStyle(
                                  fontSize: getProportionateScreenWidth(
                                    kDefaultPadding * 0.9,
                                  ),
                                  color: kBlackColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                softWrap: true,
                              ),
                              Text(
                                "${_getPrice(extraItems[index])} ${Provider.of<ZMetaData>(context, listen: false).currency}",
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: kGreyColor),
                              ),
                              ///// add to cart button section///
                              GestureDetector(
                                onTap: () async {
                                  // Add to cart.....

                                  // debugPrint('id... ${extraItems[index]['_id']}');
                                  Item item = Item(
                                    id: extraItems[index]['_id'],
                                    quantity: 1,
                                    specification: [],
                                    noteForItem: "",
                                    price: double.parse(
                                      _getPrice(extraItems[index]),
                                    ),
                                    itemName: extraItems[index]['name'],
                                    imageURL:
                                        extraItems[index]['image_url'].length >
                                            0
                                        ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${extraItems[index]['image_url']}"
                                        : "https://ibb.co/vkhzjd6",
                                    odooProductId: extractOdooProductId(
                                      extraItems[index],
                                    ),
                                  );
                                  // debugPrint('item... $item');
                                  StoreLocation storeLocation = StoreLocation(
                                    long: storeLocations[1],
                                    lat: storeLocations[0],
                                  );
                                  // debugPrint('sLocation... $storeLocation');
                                  DestinationAddress destination =
                                      DestinationAddress(
                                        long: Provider.of<ZMetaData>(
                                          context,
                                          listen: false,
                                        ).longitude,
                                        lat: Provider.of<ZMetaData>(
                                          context,
                                          listen: false,
                                        ).latitude,
                                        name: "Current Location",
                                        note: "User current location",
                                      );
                                  // debugPrint('DestinationAddress... $destination');
                                  if (cart != null && userData != null) {
                                    if (cart!.storeId! ==
                                        extraItems[index]['store_id']) {
                                      setState(() {
                                        Service.addOrMergeCartItem(cart!, item);
                                        Service.save('cart', cart!.toJson())
                                            .then((value) => calculatePrice())
                                            .then((value) => setState(() {}));
                                      });
                                      _refreshAvailability();
                                    } else {
                                      _showDialog(
                                        item,
                                        destination,
                                        storeLocation,
                                        extraItems[index]['store_id'],
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    // color: kSecondaryColor.withValues(alpha: 0.1),
                                    // borderRadius: BorderRadius.circular(
                                    //   kDefaultPadding / 2,
                                    // ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      // horizontal: getProportionateScreenWidth(
                                      //   kDefaultPadding / 2,
                                      // ),
                                      vertical: getProportionateScreenWidth(
                                        kDefaultPadding / 4,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      spacing: getProportionateScreenWidth(
                                        kDefaultPadding / 3,
                                      ),
                                      children: [
                                        Icon(
                                          size: 20,
                                          color: kSecondaryColor,
                                          HeroiconsOutline.plus,
                                        ),
                                        Text(
                                          "Add",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontSize: 14,
                                                color: kSecondaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }
}
