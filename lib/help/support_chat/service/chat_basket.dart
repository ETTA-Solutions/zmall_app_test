import 'package:flutter/foundation.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/services/service.dart';

/// One product + quantity inside the chat basket.
class ChatBasketLine {
  final MockProduct product;
  int quantity;

  ChatBasketLine({required this.product, required this.quantity});

  double get total => product.price * quantity;
}

/// Single-store basket shared by every chat surface (inline menu card, menu
/// sheet, basket bar) — mirrors the web ordering UI's basket.
class ChatBasket extends ChangeNotifier {
  MockStore? _store;
  final List<ChatBasketLine> _lines = [];

  MockStore? get store => _store;
  List<ChatBasketLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  bool get isNotEmpty => _lines.isNotEmpty;
  int get itemCount => _lines.fold(0, (sum, l) => sum + l.quantity);
  double get subtotal => _lines.fold(0.0, (sum, l) => sum + l.total);

  int quantityOf(MockProduct product) {
    for (final l in _lines) {
      if (l.product.id == product.id) return l.quantity;
    }
    return 0;
  }

  /// True when adding from [store] would replace a basket from another store.
  bool conflictsWith(MockStore store) =>
      _store != null && _lines.isNotEmpty && _store!.id != store.id;

  void add(MockStore store, MockProduct product) {
    if (conflictsWith(store)) _lines.clear();
    _store = store;
    final index = _lines.indexWhere((l) => l.product.id == product.id);
    if (index >= 0) {
      _lines[index].quantity++;
    } else {
      _lines.add(ChatBasketLine(product: product, quantity: 1));
    }
    debugPrint(
      "🧺 [CHAT BASKET] + ${product.name} → $itemCount item(s), ${subtotal.toStringAsFixed(0)} ETB",
    );
    notifyListeners();
  }

  void decrement(MockProduct product) {
    final index = _lines.indexWhere((l) => l.product.id == product.id);
    if (index < 0) return;
    if (_lines[index].quantity > 1) {
      _lines[index].quantity--;
    } else {
      _lines.removeAt(index);
    }
    if (_lines.isEmpty) _store = null;
    debugPrint(
      "🧺 [CHAT BASKET] − ${product.name} → $itemCount item(s), ${subtotal.toStringAsFixed(0)} ETB",
    );
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _store = null;
    notifyListeners();
  }
}

/// Snapshot of a checked-out basket, rendered as the "Complete Your Order"
/// card in the chat.
class ChatOrderReady {
  final String storeName;
  final List<ChatBasketLine> lines;
  final double itemsTotal;
  final double price;
  final String deliveryAddress;
  final String orderPaymentId;
  final String orderPaymentUniqueId;
  final String vehicleId;
  final bool onlyCashless;

  const ChatOrderReady({
    required this.storeName,
    required this.lines,
    required this.itemsTotal,
    required this.price,
    required this.deliveryAddress,
    required this.orderPaymentId,
    required this.orderPaymentUniqueId,
    required this.vehicleId,
    required this.onlyCashless,
  });
}

const _kChatAddressKey = 'chat_delivery_address';

/// Delivery address chosen in the chat. Every address field listens to it,
/// so changing it in one place updates the store list, basket and checkout.
final ValueNotifier<DestinationAddress?> chatDeliveryAddress = ValueNotifier(
  null,
);

/// Loads the chat address: the one picked in chat, else the saved cart's
/// named address. Stays null when the user hasn't chosen one.
Future<DestinationAddress?> loadChatDeliveryAddress() async {
  if (chatDeliveryAddress.value != null) return chatDeliveryAddress.value;
  try {
    final saved = await Service.read(_kChatAddressKey);
    if (saved != null) {
      return chatDeliveryAddress.value = DestinationAddress.fromJson(
        Map<String, dynamic>.from(saved),
      );
    }
    final cartData = await Service.read('cart');
    final dest = cartData?['destination_address'];
    final name = dest?['name']?.toString().trim();
    if (name != null && name.isNotEmpty && name != 'Current Location') {
      return chatDeliveryAddress.value = DestinationAddress.fromJson(
        Map<String, dynamic>.from(dest),
      );
    }
  } catch (_) {}
  return null;
}

Future<void> saveChatDeliveryAddress(DestinationAddress address) async {
  debugPrint(
    "📍 [CHAT ADDRESS] Selected: ${address.name} (${address.lat}, ${address.long})",
  );
  chatDeliveryAddress.value = address;
  await Service.save(_kChatAddressKey, address.toJson());
}

/// "1,250 ETB" for whole amounts, "53.45 ETB" otherwise — never rounds away
/// the cents the backend charges.
String formatEtb(double amount) {
  final whole = (amount.abs() * 100).round() % 100 == 0;
  final fixed = amount.abs().toStringAsFixed(whole ? 0 : 2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final sign = amount < 0 ? '−' : '';
  return '$sign$grouped${parts.length > 1 ? '.${parts[1]}' : ''} ETB';
}
