import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/combo/combo_route.dart';
import 'package:zmall/combo/models/combo_cart.dart';
import 'package:zmall/combo/services/combo_service.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/kifiya/kifiya_screen.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/combo_invoice.dart';
import 'package:zmall/models/combo_payment_context.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:zmall/checkout/checkout_screen.dart' show DetailsRow;
import 'package:zmall/widgets/order_status_row.dart';

/// Checkout summary for a two-store order: route -> invoice -> continue to Kifiya payment.
class ComboCheckoutScreen extends StatefulWidget {
  const ComboCheckoutScreen({super.key});

  @override
  State<ComboCheckoutScreen> createState() => _ComboCheckoutScreenState();
}

class _ComboCheckoutScreenState extends State<ComboCheckoutScreen> {
  var userData;
  Cart? cart;
  ComboCart? combo;
  ComboRoute? route;

  /// Typed, parsed invoice. Replaces the raw Map once successfully fetched.
  ComboInvoice? _invoice;

  bool _loading = true;
  String? _invoiceError;

  Widget linearProgressIndicator = Container(
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    userData = await Service.read('user');
    final cartData = await Service.read('cart');
    combo = await ComboCart.load();
    if (!mounted) return;
    if (userData == null || cartData == null || combo == null) {
      Service.showMessage(
        context: context,
        title: "Your cart has changed. Please try again.",
        error: true,
      );
      Navigator.of(context).pop();
      return;
    }
    cart = Cart.fromJson(cartData);
    await _getInvoice();
  }

  Future<void> _getInvoice() async {
    setState(() {
      _loading = true;
      _invoiceError = null;
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
              "Calculating distance...",
              style: TextStyle(color: kBlackColor),
            ),
          ],
        ),
      );
    });

    final destination = cart!.destinationAddress!;
    final first = cart!.storeLocation!;
    final second = combo!.second.storeLocation!;

    debugPrint(
      '[COMBO-DEBUG] ▶ Step 2a: computeComboRoute\n'
      '  store_1 id : ${cart!.storeId}  lat=${first.lat} lng=${first.long}\n'
      '  store_2 id : ${combo!.second.storeId}  lat=${second.lat} lng=${second.long}\n'
      '  customer    : lat=${destination.lat} lng=${destination.long}',
    );

    route = await computeComboRoute(
      storeIdX: cart!.storeId!,
      xLat: first.lat!,
      xLng: first.long!,
      storeIdY: combo!.second.storeId!,
      yLat: second.lat!,
      yLng: second.long!,
      custLat: destination.lat!,
      custLng: destination.long!,
      apiKey: apiKey,
    );
    if (!mounted) return;

    debugPrint(
      '[COMBO-DEBUG] ✓ Step 2a: route computed (fallback=${route!.fromFallback})\n'
      '  origin_store_id  : ${route!.originStoreId}\n'
      '  waypoint_store_id: ${route!.waypointStoreId}\n'
      '  totalDistance    : ${route!.totalDistance.toStringAsFixed(0)} m\n'
      '  totalTime        : ${route!.totalTime.toStringAsFixed(0)} s',
    );

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

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
              "Generating Order Invoice...",
              style: TextStyle(color: kBlackColor),
            ),
          ],
        ),
      );
    });

    debugPrint(
      '[COMBO-DEBUG] ▶ Step 2b: getInvoice\n'
      '  combo_id    : ${combo!.comboId}\n'
      '  store_a (origin)  : ${route!.originStoreId}  cart=${combo!.cartIdByStore[route!.originStoreId]}\n'
      '  store_b (waypoint): ${route!.waypointStoreId} cart=${combo!.cartIdByStore[route!.waypointStoreId]}',
    );

    final data = await ComboService.getInvoice(
      context,
      userData: userData,
      combo: combo!,
      route: route!,
    );
    if (!mounted) return;

    debugPrint(
      '[COMBO-DEBUG] ◀ Step 2b response: ${data == null ? "NULL (timeout/network)" : data.toString()}',
    );

    if (data != null && data['success'] == true) {
      // Parse into the typed model. Never keep the raw response in state
      // because the store object contains private data. (§11.3)
      final parsed = ComboInvoice.fromJson(Map<String, dynamic>.from(data));

      // Structural validation (§11.5)
      final validationError = parsed.validate();
      if (validationError != null) {
        setState(() {
          _invoice = null;
          _invoiceError = validationError;
          _loading = false;
        });
        return;
      }

      // Persist order payment ids keyed by store_id into ComboCart.
      combo!.orderPaymentIdByStore
        ..[parsed.origin.storeId] = parsed.origin.orderPaymentId
        ..[parsed.secondary.storeId] = parsed.secondary.orderPaymentId;
      combo!.originStoreId = route!.originStoreId;
      await combo!.save();
      if (!mounted) return;

      debugPrint(
        '[COMBO-DEBUG] ✓ Step 2b invoice parsed:\n'
        '  combo_id          : ${parsed.comboId}\n'
        '  origin  store_id  : ${parsed.origin.storeId}  name="${parsed.origin.store.storeName}"\n'
        '    orderPaymentId  : ${parsed.origin.orderPaymentId}\n'
        '    orderPrice      : ${parsed.origin.orderPrice}\n'
        '    deliveryPrice   : ${parsed.origin.deliveryPrice}\n'
        '    userPay         : ${parsed.origin.userPay}\n'
        '    vehicleId       : ${parsed.origin.vehicleId ?? "(none)"}\n'
        '  waypoint store_id : ${parsed.secondary.storeId}  name="${parsed.secondary.store.storeName}"\n'
        '    orderPaymentId  : ${parsed.secondary.orderPaymentId}\n'
        '    orderPrice      : ${parsed.secondary.orderPrice}\n'
        '    deliveryPrice   : ${parsed.secondary.deliveryPrice}\n'
        '    userPay         : ${parsed.secondary.userPay}\n'
        '  combinedDelivery  : ${parsed.combinedDelivery}\n'
        '  combinedUserPay   : ${parsed.combinedUserPay}\n'
        '  etaLabel          : ${parsed.etaLabel}\n'
        '  onlyCashless      : ${parsed.onlyCashless}\n'
        '  anyStoreBusy      : ${parsed.anyStoreBusy}',
      );

      setState(() {
        _invoice = parsed;
        _loading = false;
      });
    } else if (ComboService.isSessionExpired(data)) {
      await _logout();
    } else {
      setState(() {
        _invoice = null;
        _invoiceError = ComboService.errorText(data);
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    Service.showMessage(
      context: context,
      title: "${errorCodes['999']}!",
      error: true,
    );
    await CoreServices.clearCache();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  }

  List<String> get _pickupOrder => [
    route!.originStoreId,
    route!.waypointStoreId,
  ];

  /// Use combinedUserPay from the typed model — the canonical total. (§3.2)
  double get _total => _invoice?.combinedUserPay ?? 0;

  void _proceedToPayment() {
    if (_invoice == null || route == null || combo == null) return;

    // Block: busy store
    if (_invoice!.anyStoreBusy) {
      Service.showMessage(
        context: context,
        title:
            '${_invoice!.busyStoreName ?? 'A store'} is currently busy. Please try again later.',
        error: true,
        duration: 4,
      );
      return;
    }

    // Block: scheduled-only store (Phase 1 has no schedule toggle)
    if (_invoice!.onlyScheduled) {
      Service.showMessage(
        context: context,
        title:
            'One of the stores only accepts scheduled orders. Combo orders cannot be scheduled yet.',
        error: true,
        duration: 4,
      );
      return;
    }

    // Block: pickup-only store
    if (_invoice!.onlyPickup) {
      Service.showMessage(
        context: context,
        title:
            'One of the stores only accepts self-pickup, which is not supported for combo orders.',
        error: true,
        duration: 4,
      );
      return;
    }

    final inv = _invoice!;

    debugPrint(
      '[COMBO-DEBUG] ▶ Step 3 — pushing KifiyaScreen\n'
      '  price (combinedUserPay)        : ${inv.combinedUserPay}\n'
      '  orderPaymentId (origin)        : ${inv.origin.orderPaymentId}\n'
      '  orderPaymentUniqueId (origin)  : ${inv.origin.orderPaymentUniqueId}\n'
      '  storeA orderPaymentId (origin) : ${inv.origin.orderPaymentId}\n'
      '  storeB orderPaymentId (waypoint): ${inv.secondary.orderPaymentId}\n'
      '  storeA cartId                  : ${inv.origin.cartId}\n'
      '  storeB cartId                  : ${inv.secondary.cartId}\n'
      '  vehicleId                      : ${inv.vehicleId ?? "(none)"}\n'
      '  onlyCashless                   : ${inv.onlyCashless}',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KifiyaScreen(
          price: inv.combinedUserPay,
          // orderPaymentId: used by get_payment_gateway (origin's payment id).
          orderPaymentId: inv.origin.orderPaymentId,
          // orderPaymentUniqueId: origin's unique_id integer (not the combo _id). (§11.7)
          orderPaymentUniqueId: inv.origin.orderPaymentUniqueId,
          vehicleId: inv.vehicleId,
          onlyCashless: inv.onlyCashless,
          combo: ComboPaymentContext.fromInvoice(inv),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<ZLanguage>(context);
    final currency = Provider.of<ZMetaData>(context, listen: false).currency;

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        title: Text(lang.checkout, style: TextStyle(color: kBlackColor)),
      ),
      bottomNavigationBar: _invoice == null
          ? null
          : SafeArea(
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: getProportionateScreenHeight(kDefaultPadding / 4),
                  horizontal: getProportionateScreenHeight(kDefaultPadding),
                ),
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
                  spacing: getProportionateScreenHeight(kDefaultPadding / 2),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("${lang.total} :"),
                        SizedBox(width: kDefaultPadding / 2),
                        Text(
                          "$currency ${_total.toStringAsFixed(2)}",
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    CustomButton(
                      isLoading: false,
                      title: lang.placeOrder,
                      press: _proceedToPayment,
                      color: kSecondaryColor,
                    ),
                  ],
                ),
              ),
            ),
      body: ModalProgressHUD(
        inAsyncCall: _loading,
        color: kPrimaryColor,
        progressIndicator: linearProgressIndicator,
        child: _invoiceError != null
            ? _errorView()
            : _invoice == null
            ? SizedBox.shrink()
            : SingleChildScrollView(
                padding: EdgeInsets.all(
                  getProportionateScreenWidth(kDefaultPadding),
                ),
                child: Column(
                  children: [
                    _deliveryDetailsCard(lang),
                    for (int i = 0; i < _pickupOrder.length; i++)
                      _storeCard(i + 1, _pickupOrder[i], currency),
                    _summaryCard(lang, currency),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: kDefaultPadding,
        children: [
          Icon(Icons.error_outline, color: kSecondaryColor, size: 48),
          Text(_invoiceError!, textAlign: TextAlign.center),
          CustomButton(
            title: "Try again",
            press: _getInvoice,
            color: kSecondaryColor,
          ),
        ],
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: getProportionateScreenHeight(12)),
    padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding * .75)),
    decoration: BoxDecoration(
      color: kWhiteColor,
      borderRadius: BorderRadius.circular(kDefaultPadding),
    ),
    child: child,
  );

  Widget _deliveryDetailsCard(ZLanguage lang) {
    final String fullName = userData != null && userData['user'] != null
        ? "${userData['user']['first_name'] ?? ''} ${userData['user']['last_name'] ?? ''}".trim()
        : "";
    final String phone = userData != null && userData['user'] != null
        ? "${Provider.of<ZMetaData>(context, listen: false).areaCode} ${userData['user']['phone'] ?? ''}".trim()
        : "";
    final String address =
        cart?.destinationAddress?.name?.split(',')[0] ?? "Current location";

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderStatusRow(
            value: lang.deliveryDetails,
            title: "Your Delivery Summary",
            icon: HeroiconsOutline.informationCircle,
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
          DetailsRow(
            title: lang.name,
            subtitle: fullName,
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 3)),
          DetailsRow(
            title: lang.phone,
            subtitle: phone,
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 3)),
          DetailsRow(
            title: lang.deliveryAddress,
            subtitle: address,
          ),
        ],
      ),
    );
  }

  Widget _storeCard(int pickup, String storeId, String? currency) {
    // Resolve the StoreInvoice leg from the typed model by store_id.
    final leg = (storeId == route?.originStoreId ||
            _invoice!.origin.storeId == storeId)
        ? _invoice!.origin
        : _invoice!.secondary;

    // Item rows: use local cart for item names/quantities (server doesn't
    // return per-item breakdown in the invoice). Subtotal comes from the
    // server's total_order_price — not from local prices. (§11.6)
    final items = storeId == cart!.storeId
        ? cart!.items ?? []
        : combo!.second.items ?? [];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderStatusRow(
            title: "Pickup $pickup",
            icon: HeroiconsOutline.buildingStorefront,
            iconBackgroundColor: kPrimaryColor,
            value: Service.capitalizeFirstLetters(
              leg.store.storeName.isNotEmpty
                  ? leg.store.storeName
                  : 'Store $pickup',
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
          Divider(color: kPrimaryColor),
          for (final item in items)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: getProportionateScreenHeight(3),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      "${item.quantity} × ${Service.capitalizeFirstLetters(item.itemName ?? '')}",
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: kBlackColor,
                      ),
                    ),
                  ),
                  SizedBox(width: kDefaultPadding / 2),
                  Text(
                    "$currency ${(item.price ?? 0).toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: kBlackColor,
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: kPrimaryColor),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
          DetailsRow(
            title: "Items",
            subtitle: "$currency ${leg.orderPrice.toStringAsFixed(2)}",
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(ZLanguage lang, String? currency) {
    final inv = _invoice!;
    final itemsTotal = inv.origin.orderPrice + inv.secondary.orderPrice;
    final eta = inv.etaLabel;
    final vehicleName = inv.vehicleName ?? '';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderStatusRow(
            value: lang.orderDetail,
            title: "Summary of your order",
            icon: HeroiconsOutline.banknotes,
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
          DetailsRow(
            title: lang.servicePrice,
            subtitle: "$currency ${inv.combinedDelivery.toStringAsFixed(2)}",
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 3)),
          DetailsRow(
            title: lang.totalOrderPrice,
            subtitle: "$currency ${itemsTotal.toStringAsFixed(2)}",
          ),
          if (vehicleName.isNotEmpty) ...[
            SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 3)),
            DetailsRow(
              title: "Vehicle",
              subtitle: Service.capitalizeFirstLetters(vehicleName),
            ),
          ],
          if (eta.isNotEmpty) ...[
            SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 3)),
            DetailsRow(
              title: "Estimated Time",
              subtitle: eta,
            ),
          ],
        ],
      ),
    );
  }
}
