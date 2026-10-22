import 'package:flutter/material.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/services/service.dart';

// ── Meal image asset paths (mapped by category) ─────────────────────────────
const String _imgBurger = 'images/meal/burger_with_fires.jpg';
const String _imgPizza = 'images/meal/pizza.jpg';
const String _imgPizzaAlt = 'images/meal/pizza_hot.jpg';
const String _imgSides = 'images/meal/one.jpg';
const String _imgCoffee = 'images/meal/two.jpg';

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
  });

  /// Factory constructor for creating MockProduct from backend data
  /// when only basic fields (name, amount, price) are available
  factory MockProduct.fromBackendData({
    required String name,
    required double price,
    String? amount,
    String? id,
    String? storeId,
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

/// Catalog used for offline/mock chatbot product recommendations and cart testing.
const List<MockProduct> mockProducts = [
  // ── Fresh Grocery Products ──────────────────────────────────────────
  MockProduct(
    id: '64aba5286d11e42d492fba81',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Premium Pure Cane Brown Sugar',
    price: 4.99,
    originalPrice: 5.99,
    unit: '2 lbs',
    currencySymbol: '\$',
    category: 'Pantry',
    description: 'Rich moisture-sealed brown sugar for baking and coffee',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba82',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Grass-Fed Unsalted Butter Sticks',
    price: 5.49,
    originalPrice: 6.99,
    unit: '1 ct',
    currencySymbol: '\$',
    category: 'Dairy',
    description: 'Creamy artisanal butter churned from pure grass-fed milk',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba83',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Organic Sugar Bee Apple',
    price: 4.95,
    unit: '5 ct',
    currencySymbol: '\$',
    category: 'Produce',
    description: 'Sweet, extra-crisp organic red honeybee orchard apples',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba84',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Organic Whole Milk (1 Gallon)',
    price: 4.29,
    originalPrice: 4.99,
    unit: '1 gal',
    currencySymbol: '\$',
    category: 'Dairy',
    description: 'Fresh farm-pasteurized whole milk fortified with vitamin D',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba85',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Cage-Free Grade A Brown Eggs',
    price: 3.99,
    originalPrice: 4.49,
    unit: '12 ct',
    currencySymbol: '\$',
    category: 'Dairy',
    description: 'Dozen farm-fresh large brown eggs rich in omega-3',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba86',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Fresh Sourdough Artisanal Bread',
    price: 3.49,
    originalPrice: 3.99,
    unit: '1 loaf',
    currencySymbol: '\$',
    category: 'Bakery',
    description: 'Hand-crafted naturally leavened crispy golden sourdough loaf',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba87',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Extra Virgin Cold-Pressed Olive Oil',
    price: 8.99,
    originalPrice: 10.99,
    unit: '500 ml',
    currencySymbol: '\$',
    category: 'Pantry',
    description: 'First cold-pressed Mediterranean extra virgin olive oil',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba88',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Organic Fresh Hass Avocados',
    price: 3.99,
    originalPrice: 4.99,
    unit: '4 ct',
    currencySymbol: '\$',
    category: 'Produce',
    description: 'Ripe and creamy pesticide-free organic Hass avocados',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba89',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Fair Trade Ground Arabica Coffee',
    price: 7.99,
    originalPrice: 9.49,
    unit: '12 oz',
    currencySymbol: '\$',
    category: 'Coffee',
    description:
        'Medium roast Ethiopian Yirgacheffe single-origin ground coffee',
    localImageAsset: _imgCoffee,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba90',
    storeId: '64aba2706d11e42d492fba71',
    name: 'Greek Plain Whole Milk Yogurt',
    price: 4.49,
    originalPrice: 5.29,
    unit: '32 oz',
    currencySymbol: '\$',
    category: 'Dairy',
    description: 'High-protein authentic strained thick Greek yogurt',
    localImageAsset: _imgSides,
  ),

  // ── ZMall Burger & Grill Products ─────────────────────────────────
  MockProduct(
    id: '64aba5286d11e42d492fba9b',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Cheese Burger',
    price: 250.0,
    originalPrice: 280.0,
    unit: '1 portion',
    category: 'Burger',
    description:
        'Juicy grilled beef patty with melted cheddar cheese & house sauce',
    localImageAsset: _imgBurger,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9c',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Double Cheese Burger',
    price: 320.0,
    originalPrice: 360.0,
    unit: '1 portion',
    category: 'Burger',
    description:
        'Two beef patties, loaded double cheese, pickles and signature dressing',
    localImageAsset: _imgBurger,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9d',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Classic ZMall Burger',
    price: 180.0,
    unit: '1 portion',
    category: 'Burger',
    description:
        'Signature grilled beef patty with crisp lettuce and fresh tomatoes',
    localImageAsset: _imgBurger,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9e',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Chicken Crispy Burger',
    price: 220.0,
    unit: '1 portion',
    category: 'Burger',
    description: 'Crispy fried chicken breast fillet with garlic herb mayo',
    localImageAsset: _imgBurger,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9f',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Zinger Burger',
    price: 210.0,
    unit: '1 portion',
    category: 'Burger',
    description:
        'Spicy crunchy chicken patty with zesty relish and fresh greens',
    localImageAsset: _imgBurger,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa0',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Veggie Burger',
    price: 160.0,
    unit: '1 portion',
    category: 'Burger',
    description:
        'Delicious plant-based patty with avocado sauce and garden veggies',
    localImageAsset: _imgBurger,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa1',
    storeId: '64aba2706d11e42d492fba68',
    name: 'Pepperoni Pizza (Large)',
    price: 350.0,
    originalPrice: 390.0,
    unit: '8 slices',
    category: 'Pizza',
    description:
        'Hand-tossed crust, Italian tomato sauce, mozzarella & beef pepperoni',
    localImageAsset: _imgPizza,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa2',
    storeId: '64aba2706d11e42d492fba68',
    name: 'Margherita Pizza (Medium)',
    price: 260.0,
    unit: '6 slices',
    category: 'Pizza',
    description:
        'Fresh mozzarella cheese, tomato passata, virgin olive oil and basil',
    localImageAsset: _imgPizzaAlt,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa3',
    storeId: '64aba2706d11e42d492fba67',
    name: 'French Fries',
    price: 80.0,
    unit: '1 pack',
    category: 'Sides',
    description: 'Golden crispy potato fries lightly sprinkled with sea salt',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa4',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Chicken Wings (8pc)',
    price: 200.0,
    unit: '8 pc',
    category: 'Sides',
    description:
        '8 pieces of crispy juicy chicken wings in smoky barbecue glaze',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa5',
    storeId: '64aba2706d11e42d492fba69',
    name: 'Cappuccino',
    price: 60.0,
    unit: '1 cup',
    category: 'Coffee',
    description:
        'Freshly brewed rich espresso topped with smooth velvety milk foam',
    localImageAsset: _imgCoffee,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa6',
    storeId: '64aba2706d11e42d492fba69',
    name: 'Americano',
    price: 50.0,
    unit: '1 cup',
    category: 'Coffee',
    description: 'Fresh single-origin Ethiopian espresso with hot water',
    localImageAsset: _imgCoffee,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa7',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Soft Drink (Coke 500ml)',
    price: 40.0,
    unit: '500 ml',
    category: 'Drinks',
    description: 'Chilled refreshing Coca-Cola bottle (500ml)',
    localImageAsset: _imgCoffee,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa8',
    storeId: '64aba2706d11e42d492fba70',
    name: 'Chicken Caesar Salad',
    price: 240.0,
    unit: '1 bowl',
    category: 'Salad',
    description:
        'Crisp romaine, grilled chicken breast, parmesan & caesar dressing',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa9',
    storeId: '64aba2706d11e42d492fba69',
    name: 'Chocolate Lava Cake',
    price: 150.0,
    unit: '1 pc',
    category: 'Dessert',
    description: 'Warm chocolate fudge cake with molten chocolate core',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbab0',
    storeId: '64aba2706d11e42d492fba72',
    name: 'Butter Croissant',
    price: 85.0,
    unit: '1 piece',
    category: 'Pastry',
    description: 'Golden flaky croissant baked fresh each morning',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbab1',
    storeId: '64aba2706d11e42d492fba73',
    name: 'Spiced Tibs Bowl',
    price: 280.0,
    unit: '1 bowl',
    category: 'Ethiopian Cuisine',
    description: 'Tender beef tibs with onions, peppers and traditional spices',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbab2',
    storeId: '64aba2706d11e42d492fba74',
    name: 'Fresh Fruit Juice',
    price: 75.0,
    unit: '500 ml',
    category: 'Drinks',
    description: 'Refreshing mixed fruit juice prepared to order',
    localImageAsset: _imgCoffee,
  ),
];

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

/// Returns the delivery-time label for a mock product's store.
String getMockStoreDeliveryTime(String storeId) {
  for (final store in mockStores) {
    if (store.id == storeId) return store.deliveryTime;
  }
  return mockStores.first.deliveryTime;
}

const List<MockStore> mockStores = [
  MockStore(
    id: '64aba2706d11e42d492fba71',
    name: 'Fresh Grocery',
    category: 'Supermarket & Fresh Produce',
    location: 'Bole Road, Addis Ababa',
    rating: 4.9,
    deliveryTime: 'Delivery by 12:30pm',
    deliveryFee: 45.0,
    logoText: 'Fresh\nGrocery',
    themeColor: Color(0xFF237249),
  ),
  MockStore(
    id: '64aba2706d11e42d492fba67',
    name: 'ZMall Burger & Grill',
    category: 'Fast Food / Burgers',
    location: 'Bole Medhanialem, Addis Ababa',
    rating: 4.8,
    deliveryTime: 'Delivery in 20–35 min',
    deliveryFee: 50.0,
    logoText: 'ZMall\nBurger',
    themeColor: Color(0xFFE11D48),
  ),
  MockStore(
    id: '64aba2706d11e42d492fba68',
    name: 'Pizza Bella Italia',
    category: 'Pizza & Italian',
    location: 'Atlas, Addis Ababa',
    rating: 4.9,
    deliveryTime: 'Delivery in 25–40 min',
    deliveryFee: 60.0,
    logoText: 'Bella\nPizza',
    themeColor: Color(0xFFEA580C),
  ),
  MockStore(
    id: '64aba2706d11e42d492fba69',
    name: 'Addis Coffee Roasters',
    category: 'Cafe & Bakery',
    location: 'Sarbet, Addis Ababa',
    rating: 4.7,
    deliveryTime: 'Delivery in 15–25 min',
    deliveryFee: 40.0,
    logoText: 'Addis\nCoffee',
    themeColor: Color(0xFF78350F),
  ),
  MockStore(
    id: '64aba2706d11e42d492fba70',
    name: 'Green Garden Healthy Bowls',
    category: 'Healthy / Salads',
    location: 'Kazanchis, Addis Ababa',
    rating: 4.6,
    deliveryTime: 'Delivery in 30–45 min',
    deliveryFee: 55.0,
    logoText: 'Green\nGarden',
    themeColor: Color(0xFF15803D),
  ),
  MockStore(
    id: '64aba2706d11e42d492fba72',
    name: 'Bole Bakery House',
    category: 'Bakery & Pastries',
    location: 'Bole, Addis Ababa',
    rating: 4.5,
    deliveryTime: 'Delivery in 20-30 min',
    deliveryFee: 35.0,
    logoText: 'Bole\nBakery',
    themeColor: Color(0xFFB45309),
  ),
  MockStore(
    id: '64aba2706d11e42d492fba73',
    name: 'Addis Spice Kitchen',
    category: 'Ethiopian Cuisine',
    location: 'Mexico, Addis Ababa',
    rating: 4.8,
    deliveryTime: 'Delivery in 25-40 min',
    deliveryFee: 45.0,
    logoText: 'Addis\nSpice',
    themeColor: Color(0xFF9F1239),
  ),
  MockStore(
    id: '64aba2706d11e42d492fba74',
    name: 'Quick Basket Market',
    category: 'Grocery & Convenience',
    location: 'CMC, Addis Ababa',
    rating: 4.4,
    deliveryTime: 'Delivery in 15-25 min',
    deliveryFee: 30.0,
    logoText: 'Quick\nBasket',
    themeColor: Color(0xFF0369A1),
  ),
];

/// Mock active order details for order tracking and inquiries
class MockOrderInfo {
  final String orderId;
  final String storeName;
  final String status;
  final List<String> items;
  final double totalAmount;
  final String driverName;
  final String driverPhone;
  final String estimatedArrival;
  final String deliveryAddress;
  final String paymentMethod;

  const MockOrderInfo({
    required this.orderId,
    required this.storeName,
    required this.status,
    required this.items,
    required this.totalAmount,
    required this.driverName,
    required this.driverPhone,
    required this.estimatedArrival,
    required this.deliveryAddress,
    required this.paymentMethod,
  });
}

const MockOrderInfo mockActiveOrder = MockOrderInfo(
  orderId: 'ZM-98421',
  storeName: 'ZMall Burger & Grill',
  status: 'Out for Delivery 🛵',
  items: [
    '1x Double Cheese Burger (320 ETB)',
    '1x French Fries (80 ETB)',
    '1x Soft Drink Coke 500ml (40 ETB)',
  ],
  totalAmount: 440.0,
  driverName: 'Dawit T.',
  driverPhone: '+251 91 122 3344',
  estimatedArrival: '10–15 minutes',
  deliveryAddress: 'Bole Medhanialem, Addis Ababa',
  paymentMethod: 'Telebirr (Paid)',
);

const MockOrderInfo mockPastOrder = MockOrderInfo(
  orderId: 'ZM-77215',
  storeName: 'Pizza Bella Italia',
  status: 'Delivered ✅',
  items: ['1x Pepperoni Pizza Large (350 ETB)'],
  totalAmount: 350.0,
  driverName: 'Abebe K.',
  driverPhone: '+251 92 334 5566',
  estimatedArrival: 'Delivered yesterday',
  deliveryAddress: 'Bole Medhanialem, Addis Ababa',
  paymentMethod: 'Telebirr (Paid)',
);

/// Returns the comprehensive system prompt instructing Gemini to act as ZMall's AI assistant
/// equipped with all mock data (products, stores, orders, policies).
String getMockChatbotSystemPrompt({
  String? userName,
  String? userOrderId,
  String? userOrderStatus,
}) {
  final productsList = mockProducts
      .map(
        (p) =>
            '- ${p.name} [Category: ${p.category}] — ${p.price.toStringAsFixed(0)} ETB: ${p.description}',
      )
      .join('\n');

  final storesList = mockStores
      .map(
        (s) =>
            '- ${s.name} (${s.category}) at ${s.location} | Est. Delivery: ${s.deliveryTime} | Fee: ${s.deliveryFee.toStringAsFixed(0)} ETB',
      )
      .join('\n');

  final activeOrderId = userOrderId ?? mockActiveOrder.orderId;
  final activeOrderStatus = userOrderStatus ?? mockActiveOrder.status;

  return '''
You are the official, friendly AI Support Assistant for ZMall (Ethiopia's premier food & grocery delivery app).
Your mission is to help users browse food items, track orders, understand delivery & payments, and resolve support queries with polite, helpful, and concise responses.

### 📋 MOCK DATABASE & CATALOG:

#### 🍔 AVAILABLE PRODUCTS (Current Menu & Prices in ETB):
$productsList

#### 🏬 PARTNER STORES:
$storesList

#### 📦 USER'S CURRENT ACTIVE ORDER:
- Order ID: #$activeOrderId
- Store: ${mockActiveOrder.storeName}
- Status: $activeOrderStatus
- Items in Order: ${mockActiveOrder.items.join(', ')}
- Total: ${mockActiveOrder.totalAmount.toStringAsFixed(0)} ETB
- Delivery Driver: ${mockActiveOrder.driverName} (${mockActiveOrder.driverPhone})
- ETA: ${mockActiveOrder.estimatedArrival}
- Delivery Address: ${mockActiveOrder.deliveryAddress}
- Payment: ${mockActiveOrder.paymentMethod}

#### 🕒 PAST ORDER:
- Order ID: #${mockPastOrder.orderId} (${mockPastOrder.storeName}) — Status: ${mockPastOrder.status} (${mockPastOrder.totalAmount.toStringAsFixed(0)} ETB)

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
2. If the user asks about order tracking, status, or "where is my order", reference Order #$activeOrderId with its current status and driver details.
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
- Include up to 6 relevant items from the catalog above.
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
      }
    }

    await Service.save('cart', cart.toJson());
  } catch (_) {}
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

      if (name.isEmpty || price <= 0) continue;

      results.add(
        MockProduct.fromBackendData(
          name: name,
          price: price,
          amount: amount,
          id: id,
          storeId: storeId,
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
      final storeId = item['store_id']?.toString() ??
          browseResults['store_id']?.toString() ??
          browseResults['store_name']?.toString() ??
          'backend';

      if (name.isEmpty || price <= 0) continue;

      // Use the fallback image (menu_chat.jpeg) for all backend menu items
      results.add(
        MockProduct(
          id: id,
          storeId: storeId,
          name: name,
          price: price,
          category: 'Food', // Default category since not provided
          unit: '1 portion', // Default unit
          currencySymbol: 'ETB',
          description: '',
          imageUrl: '',
          localImageAsset: kMenuChatFallbackImage, // Use the fallback image
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
      final name = item['store_name']?.toString() ??
          item['name']?.toString() ??
          item['company_name']?.toString() ??
          '';
      if (name.trim().isEmpty) continue;

      final id = item['store_id']?.toString() ??
          item['id']?.toString() ??
          item['_id']?.toString() ??
          'backend_${name.hashCode}';

      final imageUrl = item['image_url']?.toString() ??
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
