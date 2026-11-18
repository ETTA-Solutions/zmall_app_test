import 'package:flutter/material.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/services/service.dart';

const String kMenuChatFallbackImage = 'images/meanu_chat.jpeg';

/// Demo product model used by the support chat for product recommendations,
/// mock search results, and direct-to-cart integration.
class MockProduct {
  final String id;
  final String storeId;
  final String name;
  final double price;
  final double? originalPrice;
  final String unit;
  final String currencySymbol;
  final String category;
  final String description;
  final String imageUrl;

  /// Local Flutter asset path to the meal image shown in the chat food card
  final String localImageAsset;

  /// True when the backend sent price 0 because the real price lives in the
  /// item's specifications (e.g. Size: Small / Large). Such items are priced
  /// from their options by [ChatSpecPricing] before they are shown, and
  /// checked out with the same options. Items with a normal price keep false.
  final bool priceFromSpecs;

  const MockProduct({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.category,
    this.originalPrice,
    this.unit = '1 ct',
    this.currencySymbol = 'ETB',
    this.description = '',
    this.imageUrl = '',
    this.localImageAsset = '',
    this.priceFromSpecs = false,
  });

  /// Copy of this product priced from its specification options.
  MockProduct withSpecPrice({required double price, String? optionsNote}) {
    final note = optionsNote?.trim() ?? '';
    return MockProduct(
      id: id,
      storeId: storeId,
      name: name,
      price: price,
      category: category,
      originalPrice: originalPrice,
      unit: unit,
      currencySymbol: currencySymbol,
      description: note.isEmpty
          ? description
          : description.trim().isEmpty
          ? note
          : '$note\n$description',
      imageUrl: imageUrl,
      localImageAsset: localImageAsset,
      priceFromSpecs: true,
    );
  }

  /// Factory constructor for creating MockProduct from backend data
  /// when only basic fields (name, amount, price) are available
  factory MockProduct.fromBackendData({
    required String name,
    required double price,
    String? amount,
    String? id,
    String? storeId,
    bool priceFromSpecs = false,
  }) {
    final productId = id ?? 'backend_${name.hashCode}';
    final productStoreId = storeId ?? 'backend';

    // Simple category guessing based on name
    String categoryName = 'Food';
    final lower = name.toLowerCase();
    if (lower.contains('burger') || lower.contains('sandwich'))
      categoryName = 'Burger';
    else if (lower.contains('pizza'))
      categoryName = 'Pizza';
    else if (lower.contains('coffee') || lower.contains('cappuccino'))
      categoryName = 'Coffee';
    else if (lower.contains('fries') || lower.contains('wings'))
      categoryName = 'Sides';
    else if (lower.contains('salad'))
      categoryName = 'Salad';
    else if (lower.contains('juice') || lower.contains('drink'))
      categoryName = 'Drinks';
    else if (lower.contains('cake') || lower.contains('dessert'))
      categoryName = 'Dessert';
    else if (lower.contains('steak') || lower.contains('filet'))
      categoryName = 'Steak';

    // Always use the fallback image (menu_chat.jpeg) for backend menu items
    // as per user requirement
    String imageAsset = kMenuChatFallbackImage;

    // Use provided amount or default based on category
    final unitText =
        amount ??
        (categoryName == 'Burger' ||
                categoryName == 'Pizza' ||
                categoryName == 'Steak'
            ? '1 portion'
            : '1 kg');

    return MockProduct(
      id: productId,
      storeId: productStoreId,
      name: name,
      price: price,
      category: categoryName,
      unit: unitText,
      currencySymbol: 'ETB',
      description: '',
      imageUrl: '',
      localImageAsset: imageAsset,
      priceFromSpecs: priceFromSpecs,
    );
  }

  String get formattedPrice {
    if (currencySymbol == '\$') {
      return '\$${price.toStringAsFixed(2)}';
    }
    return '${price.toStringAsFixed(0)} $currencySymbol';
  }

  String? get formattedOriginalPrice {
    if (originalPrice == null) return null;
    if (currencySymbol == '\$') {
      return '\$${originalPrice!.toStringAsFixed(2)}';
    }
    return '${originalPrice!.toStringAsFixed(0)} $currencySymbol';
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'store_id': storeId,
    'name': name,
    'price': price,
    'original_price': originalPrice,
    'unit': unit,
    'category': category,
    'description': description,
    'image_url': imageUrl,
  };
}

/// Demo store model used for mock store discovery and recommendations.
class MockStore {
  final String id;
  final String name;
  final String category;
  final String location;
  final double rating;
  final bool hasRating; // Flag to indicate if rating is available from backend
  final String deliveryTime;
  final double deliveryFee;
  final String logoText;
  final Color themeColor;
  final String imageUrl;

  const MockStore({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    this.hasRating = true, // Default to true for mock data
    required this.deliveryTime,
    required this.deliveryFee,
    this.logoText = '',
    this.themeColor = const Color(0xFF237249),
    this.imageUrl = '',
  });
}

/// Returns the comprehensive system prompt instructing Gemini to act as ZMall's AI assistant
/// with ZMall policies and the structured response format.
String getMockChatbotSystemPrompt({
  String? userName,
  String? userOrderId,
  String? userOrderStatus,
}) {
  final orderSection = (userOrderId != null && userOrderId.isNotEmpty)
      ? '''
#### 📦 USER'S CURRENT ORDER:
- Order ID: #$userOrderId${userOrderStatus != null ? '\n- Status: $userOrderStatus' : ''}
'''
      : '';

  return '''
You are the official, friendly AI Support Assistant for ZMall (Ethiopia's premier food & grocery delivery app).
Your mission is to help users browse food items, track orders, understand delivery & payments, and resolve support queries with polite, helpful, and concise responses.

$orderSection

#### 💳 PAYMENT METHODS ACCEPTED:
- Telebirr
- CBE Birr
- Amole
- ZMall Wallet (instant)
- Credit/Debit Cards
- Cash on Delivery

#### 🚚 DELIVERY & POLICIES:
- Standard Delivery: 30–45 mins (Citywide)
- Express Delivery: 15–30 mins
- Refund Policy: Processed in 3–5 business days to original method or instantly to ZMall Wallet.
- Order Cancellation: You can cancel free of charge before the store starts preparing the order.
- Support Phone: +251 96 757 5757 | Email: info@zmallshop.com

### 🎯 RESPONSE INSTRUCTIONS:
1. Be friendly, welcoming, and concise. Use clear bullet points and emojis where helpful.
2. If the user asks about order tracking, status, or "where is my order", use the user's current order above if provided; otherwise ask for their order ID.
3. If the user asks about refund or payment, explain clearly using the payment/refund policies above.
4. Keep responses directly relevant, crisp, and helpful.

### 📦 STRUCTURED RESPONSE FORMAT (CRITICAL — READ CAREFULLY):

Your JSON response MUST always include a top-level "message" field with a friendly text reply.

**Case A — Food / Menu / Product queries** (user asks about burgers, pizza, coffee, menu, food, etc.):
Return a JSON object like this:
{
  "message": "Here's the menu for <Store Name>:",
  "browse_results": {
    "type": "items",
    "store_name": "<Exact Store Name>",
    "results": [
      { "item_id": "<unique_id>", "name": "<Product Name>", "price": <number_in_ETB> },
      { "item_id": "<unique_id>", "name": "<Product Name>", "price": <number_in_ETB> }
    ]
  }
}
Rules:
- "price" must be a plain number (no currency symbol, no string quotes).
- Do NOT include a "rating" field anywhere in browse_results or its items.
- "store_name" must match the actual store that sells those items.
- Include up to 6 relevant items.
- Do NOT include markdown, asterisks, bullet points, or extra explanation inside "browse_results".

**Case B — Store / Restaurant discovery queries** (user asks about stores, restaurants, places near me, etc.):
Return a JSON object like this:
{
  "message": "Here are some open stores near you:",
  "stores": [
    { "name": "<Store Name>", "distance": "<X.X km>" },
    { "name": "<Store Name>", "distance": "<X.X km>" }
  ]
}
Rules:
- Do NOT include a "rating" field in the stores array.
- Include 3–6 relevant stores.
- "distance" is an approximate string like "1.2 km".

**Case C — All other queries** (order tracking, payment, refund, greetings, general support):
Return a plain JSON object with only a "message" field:
{
  "message": "Your friendly plain-text reply here with emojis and bullet points."
}

IMPORTANT: Always return valid JSON. Never return raw markdown or plain text outside of a JSON structure. Never include "rating" in any response field.
''';
}

/// Adds mock products to the persistent cart storage so opening CartScreen
/// shows the selected item instead of an empty basket.
Future<void> addMockProductsToCart(List<MockProduct> products) async {
  if (products.isEmpty) return;

  debugPrint(
    "🛒 [CHAT CART] Adding ${products.length} product(s) to local cart...",
  );
  for (final p in products) {
    debugPrint(
      "🛒 [CHAT CART] -> Product: ${p.name} (id: ${p.id}, storeId: ${p.storeId}, price: ${p.price})",
    );
  }

  try {
    final userData = await Service.read('user');
    final existingCartData = await Service.read('cart');
    final lat = await Service.read('latitude');
    final long = await Service.read('longitude');

    final primaryProduct = products.first;
    final storeId = primaryProduct.storeId;
    final userId = (userData != null && userData['user'] != null)
        ? (userData['user']['_id'] ?? '')
        : '';
    final serverToken = (userData != null && userData['user'] != null)
        ? (userData['user']['server_token'] ?? '')
        : '';
    final userName = (userData != null && userData['user'] != null)
        ? (userData['user']['name'] ?? '')
        : '';
    final phone = (userData != null && userData['user'] != null)
        ? (userData['user']['phone'] ?? '')
        : '';

    double parsedLat = 9.010498;
    double parsedLong = 38.761886;
    if (lat != null) {
      parsedLat = double.tryParse(lat.toString()) ?? 9.010498;
    }
    if (long != null) {
      parsedLong = double.tryParse(long.toString()) ?? 38.761886;
    }

    Cart cart;
    if (existingCartData != null) {
      try {
        cart = Cart.fromJson(existingCartData);
        debugPrint(
          "🛒 [CHAT CART] Existing cart found with ${cart.items?.length ?? 0} items for store: ${cart.storeId}",
        );
      } catch (_) {
        cart = Cart(
          userId: userId,
          serverToken: serverToken,
          storeId: storeId,
          storeLocation: StoreLocation(lat: 9.010498, long: 38.761886),
          destinationAddress: DestinationAddress(
            name: "Current Location",
            lat: parsedLat,
            long: parsedLong,
          ),
          userName: userName,
          phone: phone,
          items: [],
        );
      }
    } else {
      debugPrint(
        "🛒 [CHAT CART] No existing cart. Initializing fresh cart for store: $storeId",
      );
      cart = Cart(
        userId: userId,
        serverToken: serverToken,
        storeId: storeId,
        storeLocation: StoreLocation(lat: 9.010498, long: 38.761886),
        destinationAddress: DestinationAddress(
          name: "Current Location",
          lat: parsedLat,
          long: parsedLong,
        ),
        userName: userName,
        phone: phone,
        items: [],
      );
    }

    cart.storeId ??= storeId;
    cart.userId = (cart.userId != null && cart.userId!.isNotEmpty)
        ? cart.userId
        : userId;
    cart.serverToken =
        (cart.serverToken != null && cart.serverToken!.isNotEmpty)
        ? cart.serverToken
        : serverToken;
    cart.storeLocation ??= StoreLocation(lat: 9.010498, long: 38.761886);
    cart.destinationAddress ??= DestinationAddress(
      name: "Current Location",
      lat: parsedLat,
      long: parsedLong,
    );
    cart.items ??= [];

    // If cart was previously empty or from another store, point it to this store
    if (cart.items!.isEmpty) {
      cart.storeId = storeId;
    }

    for (final product in products.take(1)) {
      final existingIndex = cart.items!.indexWhere(
        (item) =>
            item.id == product.id ||
            item.itemName?.toLowerCase() == product.name.toLowerCase(),
      );

      if (existingIndex >= 0) {
        final existingItem = cart.items![existingIndex];
        final currentQty = existingItem.quantity ?? 1;
        existingItem.quantity = currentQty + 1;
        existingItem.price = product.price * (currentQty + 1);
        debugPrint(
          "🛒 [CHAT CART] Updated existing item '${product.name}' quantity to ${existingItem.quantity}",
        );
      } else {
        cart.items!.add(
          Item(
            id: product.id,
            itemName: product.name,
            price: product.price,
            quantity: 1,
            specification: [],
            noteForItem: product.description,
            imageURL: product.imageUrl,
          ),
        );
        debugPrint("🛒 [CHAT CART] Added new item '${product.name}' to cart");
      }
    }

    await Service.save('cart', cart.toJson());
    debugPrint(
      "✅ [CHAT CART] Cart successfully saved. Total items: ${cart.items?.length ?? 0}",
    );
  } catch (e, stack) {
    debugPrint("❌ [CHAT CART] Error saving cart: $e");
    debugPrint("❌ [CHAT CART] Stack trace: $stack");
  }
}

/// Simplified parser for backend responses that only contain basic product info
/// (name, amount, price) without complex formatting or additional metadata.
/// This is designed to work with the simple backend structure the user described.
List<MockProduct> parseSimpleBackendProducts(List<dynamic> backendItems) {
  final results = <MockProduct>[];

  for (final item in backendItems) {
    try {
      final name =
          item['name']?.toString() ??
          item['product_name']?.toString() ??
          item['item_name']?.toString() ??
          item['title']?.toString() ??
          '';

      final price =
          double.tryParse(
            item['price']?.toString() ??
                item['amount']?.toString() ??
                item['cost']?.toString() ??
                '0',
          ) ??
          0.0;

      final amount =
          item['amount']?.toString() ??
          item['quantity']?.toString() ??
          item['unit']?.toString();

      final id =
          item['id']?.toString() ??
          item['_id']?.toString() ??
          item['item_id']?.toString() ??
          item['product_id']?.toString();

      final storeId =
          item['store_id']?.toString() ??
          item['storeId']?.toString() ??
          item['store_name']?.toString();

      // Price 0 with a real item id: the price is in the specifications —
      // keep it, ChatSpecPricing prices it from its options.
      final priceFromSpecs = price <= 0 && isChatObjectId(id);
      if (name.isEmpty || (price <= 0 && !priceFromSpecs)) continue;

      results.add(
        MockProduct.fromBackendData(
          name: name,
          price: price,
          amount: amount,
          id: id,
          storeId: storeId,
          priceFromSpecs: priceFromSpecs,
        ),
      );
    } catch (_) {
      continue;
    }
  }

  return results;
}

List<MockProduct> parseBackendBrowseResults(
  Map<String, dynamic> browseResults,
) {
  final items = browseResults['results'];
  if (items is! List) return const [];

  final results = <MockProduct>[];

  for (final item in items) {
    try {
      final name = item['name']?.toString() ?? '';
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final id =
          item['item_id']?.toString() ??
          item['id']?.toString() ??
          'backend_${name.hashCode}';
      // Prefer the real store id so the item can be checked out from chat
      final storeId =
          item['store_id']?.toString() ??
          browseResults['store_id']?.toString() ??
          browseResults['store_name']?.toString() ??
          'backend';

      // Price 0 with a real item id: the price is in the specifications —
      // keep it, ChatSpecPricing prices it from its options.
      final priceFromSpecs = price <= 0 && isChatObjectId(id);
      if (name.isEmpty || (price <= 0 && !priceFromSpecs)) continue;

      // Optional fields — drive the menu's category chips, descriptions and
      // thumbnails when the backend sends them.
      final category =
          (item['category'] ?? item['category_name'] ?? item['product_name'])
              ?.toString()
              .trim();
      final description =
          (item['description'] ?? item['details'])?.toString().trim() ?? '';
      final imageUrl = item['image_url'] is List
          ? ((item['image_url'] as List).isNotEmpty
                ? (item['image_url'] as List).first.toString()
                : '')
          : (item['image_url'] ?? item['image'])?.toString() ?? '';

      results.add(
        MockProduct(
          id: id,
          storeId: storeId,
          name: name,
          price: price,
          category: (category == null || category.isEmpty) ? 'Food' : category,
          unit: '1 portion', // Default unit
          currencySymbol: 'ETB',
          description: description,
          imageUrl: imageUrl,
          localImageAsset: kMenuChatFallbackImage, // Use the fallback image
          priceFromSpecs: priceFromSpecs,
        ),
      );
    } catch (_) {
      continue;
    }
  }

  return results;
}

List<MockStore> parseBackendStoreResults(dynamic storesData) {
  if (storesData is! List) return const [];
  final results = <MockStore>[];

  for (final item in storesData) {
    if (item is! Map) continue;
    try {
      final name =
          item['store_name']?.toString() ??
          item['name']?.toString() ??
          item['company_name']?.toString() ??
          '';
      if (name.trim().isEmpty) continue;

      final id =
          item['store_id']?.toString() ??
          item['id']?.toString() ??
          item['_id']?.toString() ??
          'backend_${name.hashCode}';

      final imageUrl =
          item['image_url']?.toString() ??
          item['logo']?.toString() ??
          item['image']?.toString() ??
          '';

      final distance = item['distance']?.toString() ?? '';
      final category = item['category']?.toString() ?? 'Restaurant';
      final hasRating = item['rating'] != null;
      final rating = double.tryParse(item['rating']?.toString() ?? '0') ?? 0.0;
      final deliveryTime =
          item['delivery_time']?.toString() ?? 'Delivery available';
      final deliveryFee =
          double.tryParse(item['delivery_fee']?.toString() ?? '0') ?? 0.0;

      results.add(
        MockStore(
          id: id,
          name: name,
          category: category,
          location: distance.isNotEmpty ? '$distance away' : 'Available',
          rating: rating,
          hasRating: hasRating,
          deliveryTime: deliveryTime,
          deliveryFee: deliveryFee,
          logoText: name.substring(0, name.length.clamp(0, 8)),
          themeColor: const Color(0xFF237249),
          imageUrl: imageUrl,
        ),
      );
    } catch (_) {
      continue;
    }
  }

  return results;
}

/// True for a MongoDB ObjectId (24 hex chars) — i.e. a real ZMall item id,
/// not a chat placeholder like `backend_123`.
bool isChatObjectId(String? id) =>
    id != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id);
