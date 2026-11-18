import 'package:zmall/models/combo_invoice.dart';

// ---------------------------------------------------------------------------
// ComboLeg
// ---------------------------------------------------------------------------
// Holds payment and cart identifiers for one store in a two-store combo order.
//
// Convention (§11.2):
// - storeA is ORIGIN (farther store from customer).
// - storeB is WAYPOINT (nearer store to customer).
// ---------------------------------------------------------------------------

class ComboLeg {
  const ComboLeg({
    required this.storeId,
    required this.storeName,
    required this.cartId,
    required this.orderPaymentId,
    required this.orderPaymentUniqueId,
    required this.userPay,
    this.orderPrice = 0.0,
    this.deliveryPrice = 0.0,
    this.promo = 0.0,
  });

  /// order_payment.store_id
  final String storeId;

  /// store.name
  final String storeName;

  /// order_payment.cart_id
  final String cartId;

  /// order_payment._id (used in combo_pay_order_payment and combo_create_order)
  final String orderPaymentId;

  /// order_payment.unique_id as String
  final String orderPaymentUniqueId;

  /// order_payment.user_pay_payment
  final double userPay;

  /// order_payment.total_order_price
  final double orderPrice;

  /// order_payment.total_delivery_price
  final double deliveryPrice;

  /// order_payment.promo_payment
  final double promo;

  factory ComboLeg.fromStoreInvoice(StoreInvoice inv) {
    return ComboLeg(
      storeId: inv.storeId,
      storeName: inv.store.storeName,
      cartId: inv.cartId,
      orderPaymentId: inv.orderPaymentId,
      orderPaymentUniqueId: inv.orderPaymentUniqueId,
      userPay: inv.userPay,
      orderPrice: inv.orderPrice,
      deliveryPrice: inv.deliveryPrice,
      promo: inv.promo,
    );
  }
}

// ---------------------------------------------------------------------------
// ComboPaymentContext
// ---------------------------------------------------------------------------
// Typed context passed to KifiyaScreen when paying for a combo order.
// Holds origin (storeA) and waypoint (storeB) legs, as well as combined totals.
// ---------------------------------------------------------------------------

class ComboPaymentContext {
  const ComboPaymentContext({
    required this.comboId,
    required this.storeA,
    required this.storeB,
    this.combinedDeliveryPrice = 0.0,
    this.combinedUserPay = 0.0,
    this.vehicleId,
  });

  /// combo_id from server
  final String comboId;

  /// Origin store leg (farther store from customer)
  final ComboLeg storeA;

  /// Waypoint store leg (nearer store to customer)
  final ComboLeg storeB;

  /// combined_delivery_price from invoice
  final double combinedDeliveryPrice;

  /// combined_user_pay_payment from invoice
  final double combinedUserPay;

  /// origin store's vehicleId (used for get_payment_gateway)
  final String? vehicleId;

  factory ComboPaymentContext.fromInvoice(ComboInvoice invoice) {
    return ComboPaymentContext(
      comboId: invoice.comboId,
      storeA: ComboLeg.fromStoreInvoice(invoice.origin),
      storeB: ComboLeg.fromStoreInvoice(invoice.secondary),
      combinedDeliveryPrice: invoice.combinedDelivery,
      combinedUserPay: invoice.combinedUserPay,
      vehicleId: invoice.vehicleId,
    );
  }
}
