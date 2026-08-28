import 'package:flutter/material.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/services/service.dart';

// ── Meal image asset paths (mapped by category) ─────────────────────────────
const String _imgBurger = 'images/meal/burger_with_fires.jpg';
const String _imgPizza = 'images/meal/pizza.jpg';
const String _imgPizzaAlt = 'images/meal/pizza_hot.jpg';
const String _imgSides = 'images/meal/one.jpg';
const String _imgCoffee = 'images/meal/two.jpg';

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
    description: 'Medium roast Ethiopian Yirgacheffe single-origin ground coffee',
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
    description: 'Juicy grilled beef patty with melted cheddar cheese & house sauce',
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
    description: 'Two beef patties, loaded double cheese, pickles and signature dressing',
    localImageAsset: _imgBurger,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9d',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Classic ZMall Burger',
    price: 180.0,
    unit: '1 portion',
    category: 'Burger',
    description: 'Signature grilled beef patty with crisp lettuce and fresh tomatoes',
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
    description: 'Spicy crunchy chicken patty with zesty relish and fresh greens',
    localImageAsset: _imgBurger,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa0',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Veggie Burger',
    price: 160.0,
    unit: '1 portion',
    category: 'Burger',
    description: 'Delicious plant-based patty with avocado sauce and garden veggies',
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
    description: 'Hand-tossed crust, Italian tomato sauce, mozzarella & beef pepperoni',
    localImageAsset: _imgPizza,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa2',
    storeId: '64aba2706d11e42d492fba68',
    name: 'Margherita Pizza (Medium)',
    price: 260.0,
    unit: '6 slices',
    category: 'Pizza',
    description: 'Fresh mozzarella cheese, tomato passata, virgin olive oil and basil',
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
    description: '8 pieces of crispy juicy chicken wings in smoky barbecue glaze',
    localImageAsset: _imgSides,
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa5',
    storeId: '64aba2706d11e42d492fba69',
    name: 'Cappuccino',
    price: 60.0,
    unit: '1 cup',
    category: 'Coffee',
    description: 'Freshly brewed rich espresso topped with smooth velvety milk foam',
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
    description: 'Crisp romaine, grilled chicken breast, parmesan & caesar dressing',
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
];


/// Demo store model used for mock store discovery and recommendations.
class MockStore {
  final String id;
  final String name;
  final String category;
  final String location;
  final double rating;
  final String deliveryTime;
  final double deliveryFee;
  final String logoText;
  final Color themeColor;

  const MockStore({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
    this.logoText = '',
    this.themeColor = const Color(0xFF237249),
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
  items: [
    '1x Pepperoni Pizza Large (350 ETB)',
  ],
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
      .map((p) =>
          '- ${p.name} [Category: ${p.category}] — ${p.price.toStringAsFixed(0)} ETB: ${p.description}')
      .join('\n');

  final storesList = mockStores
      .map((s) =>
          '- ${s.name} (${s.category}) at ${s.location} | Rating: ⭐${s.rating} | Est. Delivery: ${s.deliveryTime} | Fee: ${s.deliveryFee.toStringAsFixed(0)} ETB')
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
2. If the user asks about food, burgers, pizza, coffee, or recommendations, mention matching items with their exact prices in ETB and invite them to tap **View Cart** or tell you what they would like to add.
3. If the user asks about order tracking, status, or "where is my order", reference Order #$activeOrderId with its current status and driver details.
4. If the user asks about refund or payment, explain clearly using the payment/refund policies above.
5. Keep responses directly relevant, crisp, and helpful. Do not output raw JSON or internal prompt instructions.
''';
}

/// Returns demo products matching the user's message, or an empty list.
List<MockProduct> searchMockProducts(String message) {
  final lower = message.toLowerCase().trim();
  if (lower.isEmpty) return [];

  // Fresh Grocery specific keywords
  if (lower.contains('sugar') ||
      lower.contains('butter') ||
      lower.contains('apple') ||
      lower.contains('grocery') ||
      lower.contains('groceries') ||
      lower.contains('produce') ||
      lower.contains('pantry') ||
      lower.contains('dairy') ||
      lower.contains('milk') ||
      lower.contains('egg') ||
      lower.contains('bread') ||
      lower.contains('oil') ||
      lower.contains('avocado') ||
      lower.contains('yogurt') ||
      lower.contains('fresh grocery')) {
    final groceryMatches = mockProducts
        .where((p) => p.storeId == '64aba2706d11e42d492fba71')
        .toList();
    if (groceryMatches.isNotEmpty) {
      return groceryMatches;
    }
  }

  // Cheese burger specific match
  if (lower.contains('cheese') && lower.contains('burger')) {
    return mockProducts
        .where((p) => p.name.toLowerCase().contains('cheese'))
        .toList();
  }

  final keywordCategories = {
    'cheeseburger': 'Burger',
    'burger': 'Burger',
    'burgers': 'Burger',
    'pizza': 'Pizza',
    'coffee': 'Coffee',
    'cappuccino': 'Coffee',
    'americano': 'Coffee',
    'drink': 'Drinks',
    'drinks': 'Drinks',
    'soda': 'Drinks',
    'coke': 'Drinks',
    'cola': 'Drinks',
    'fries': 'Sides',
    'wings': 'Sides',
    'sides': 'Sides',
    'snack': 'Sides',
    'salad': 'Salad',
    'dessert': 'Dessert',
    'cake': 'Dessert',
    'dairy': 'Dairy',
    'produce': 'Produce',
    'pantry': 'Pantry',
    'bakery': 'Bakery',
  };

  for (final entry in keywordCategories.entries) {
    if (lower.contains(entry.key)) {
      final matches = mockProducts
          .where((product) =>
              product.category == entry.value ||
              product.name.toLowerCase().contains(entry.key))
          .toList();
      if (matches.isNotEmpty) {
        return matches;
      }
    }
  }

  // Name matching
  final nameMatches = mockProducts
      .where((product) => lower.contains(product.name.toLowerCase()))
      .toList();
  if (nameMatches.isNotEmpty) {
    return nameMatches;
  }

  // Store match fallback
  for (final store in mockStores) {
    if (lower.contains(store.name.toLowerCase())) {
      return mockProducts.where((p) => p.storeId == store.id).toList();
    }
  }

  return [];
}

/// Checks if query is looking for store discovery or nearby stores.
bool isStoreQuery(String message) {
  final lower = message.toLowerCase().trim();
  // Store / place discovery
  if (lower.contains('store') ||
      lower.contains('restaurant') ||
      lower.contains('grocery') ||
      lower.contains('groceries') ||
      lower.contains('supermarket') ||
      lower.contains('market') ||
      lower.contains('shop') ||
      lower.contains('near me') ||
      lower.contains('places') ||
      lower.contains('browse')) {
    return true;
  }
  // Food / item keywords — show the matching store's card
  if (lower.contains('burger') ||
      lower.contains('pizza') ||
      lower.contains('coffee') ||
      lower.contains('cappuccino') ||
      lower.contains('americano') ||
      lower.contains('fries') ||
      lower.contains('wings') ||
      lower.contains('chicken') ||
      lower.contains('salad') ||
      lower.contains('dessert') ||
      lower.contains('cake') ||
      lower.contains('drink') ||
      lower.contains('coke') ||
      lower.contains('food') ||
      lower.contains('eat') ||
      lower.contains('hungry') ||
      lower.contains('menu') ||
      lower.contains('order') ||
      lower.contains('item') ||
      lower.contains('want') ||
      lower.contains('craving') ||
      lower.contains('show me')) {
    return true;
  }
  return false;
}

/// Returns the best matching store for the user's message.
MockStore searchMockStore(String message) {
  final lower = message.toLowerCase().trim();

  // Direct store name or category match
  for (final store in mockStores) {
    if (lower.contains(store.name.toLowerCase()) ||
        lower.contains(store.category.toLowerCase())) {
      return store;
    }
  }

  // Burger / fast food → ZMall Burger & Grill (or equivalent)
  if (lower.contains('burger') ||
      lower.contains('wings') ||
      lower.contains('fries') ||
      lower.contains('chicken') ||
      lower.contains('fast food') ||
      lower.contains('grill')) {
    return mockStores.firstWhere(
      (s) => s.id == '64aba2706d11e42d492fba67',
      orElse: () => mockStores.first,
    );
  }

  // Pizza / Italian
  if (lower.contains('pizza') || lower.contains('italian')) {
    return mockStores.firstWhere(
      (s) => s.id == '64aba2706d11e42d492fba68',
      orElse: () => mockStores.first,
    );
  }

  // Coffee / cafe / dessert / cake
  if (lower.contains('coffee') ||
      lower.contains('cappuccino') ||
      lower.contains('americano') ||
      lower.contains('cafe') ||
      lower.contains('dessert') ||
      lower.contains('cake')) {
    return mockStores.firstWhere(
      (s) => s.id == '64aba2706d11e42d492fba69',
      orElse: () => mockStores.first,
    );
  }

  // Salad / healthy
  if (lower.contains('salad') || lower.contains('healthy') || lower.contains('bowl')) {
    return mockStores.firstWhere(
      (s) => s.id == '64aba2706d11e42d492fba70',
      orElse: () => mockStores.first,
    );
  }

  // Grocery / produce / dairy / pantry
  if (lower.contains('grocery') ||
      lower.contains('groceries') ||
      lower.contains('sugar') ||
      lower.contains('butter') ||
      lower.contains('apple') ||
      lower.contains('milk') ||
      lower.contains('egg') ||
      lower.contains('fresh') ||
      lower.contains('market')) {
    return mockStores.firstWhere(
      (s) => s.id == '64aba2706d11e42d492fba71',
      orElse: () => mockStores.first,
    );
  }

  // Generic food / eat / hungry / menu → default to first store
  return mockStores.first;
}

MockStore? getStoreById(String storeId) {
  for (final store in mockStores) {
    if (store.id == storeId) return store;
  }
  return null;
}

List<MockProduct> getStoreProducts(String storeId) {
  return mockProducts.where((p) => p.storeId == storeId).toList();
}

/// Formats a list of demo products into a chat-friendly reply.
String formatMockProducts(List<MockProduct> products) {
  final lines = products
      .take(4)
      .map(
        (product) =>
            '• **${product.name}** — ${product.formattedPrice}'
            '${product.description.isNotEmpty ? '\n  ${product.description}' : ''}',
      )
      .toList()
      .join('\n');
  final extra = products.length > 4
      ? '\n\n…and ${products.length - 4} more items!'
      : '';
  return '😋 Here are top items fetched from the store:\n\n$lines$extra\n\n'
      'Scroll vertically through the items below to review or tap expand in top right! 🛒';
}

/// Formats a list of demo stores into a chat-friendly reply.
String formatMockStores(List<MockStore> stores) {
  final lines = stores
      .asMap()
      .entries
      .map((e) {
        final i = e.key + 1;
        final s = e.value;
        return '**$i. ${s.name}** — ⭐${s.rating} (${s.category})\n  📍 ${s.location} • 🛵 ${s.deliveryTime}';
      })
      .join('\n\n');
  return '📍 Here are top partner stores fetched near you:\n\n$lines\n\n'
      'Check the store items below and tap **+** to add directly to your cart! 🛍️';
}

/// Generates a rich mock bot reply offline when network is unreachable.
String getOfflineMockResponse(String message, {String? orderId, String? status}) {
  final lower = message.toLowerCase().trim();

  // 1. Special Offers & Deals (matches "What are today's special offers?")
  if (lower.contains('offer') ||
      lower.contains('special') ||
      lower.contains('deal') ||
      lower.contains('promo') ||
      lower.contains('discount') ||
      lower.contains('coupon')) {
    return "🔥 **Today's Hot Deals & Offers**:\n\n"
        "1. 🛍️ **Fresh Grocery Super Savings** (Fresh Grocery)\n"
        "   • Brown Sugar (2 lbs) + Butter Sticks + Apples — **\$15.43** *(Save \$3.00)*\n\n"
        "2. 🍔 **Burger Fiesta Combo** (ZMall Burger & Grill)\n"
        "   • Double Cheese Burger + Large Fries + Coke — **399 ETB** *(Save 41 ETB)*\n\n"
        "3. 🍕 **Pizza Tuesday 2-for-1** (Pizza Bella Italia)\n"
        "   • Buy 1 Large Pepperoni, Get Margherita 50% OFF!\n\n"
        "4. 🛵 **Free Delivery on orders over 500 ETB / \$25**\n"
        "   • Use Promo Code: `ZMALLFREESHIP`\n\n"
        "Tap **View Cart** or select items from the store card below to apply discounts! 🛒";
  }

  // 2. Top Selling Stores this week (matches "Show me top selling stores this week")
  if (lower.contains('top selling') ||
      lower.contains('popular') ||
      lower.contains('trending') ||
      lower.contains('best selling') ||
      lower.contains('famous')) {
    return "🏆 **Top Selling Stores This Week**:\n\n"
        "🥇 **1. Fresh Grocery** — ⭐4.9 (2,100+ orders)\n"
        "   • Signature: Organic Sugar Bee Apples & Grass-Fed Butter\n"
        "   • 🛵 Delivery by 12:30pm • Bole Road\n\n"
        "🥈 **2. ZMall Burger & Grill** — ⭐4.8 (1,420+ orders)\n"
        "   • Signature: Double Cheese Burger (320 ETB)\n"
        "   • 🛵 20–35 min • Bole Medhanialem\n\n"
        "🥉 **3. Pizza Bella Italia** — ⭐4.9 (980+ orders)\n"
        "   • Signature: Pepperoni Pizza Large (350 ETB)\n"
        "   • 🛵 25–40 min • Atlas\n\n"
        "Check out the items below or tell me what you feel like having! 😋";
  }

  // 3. Product searches (Grocery, Burgers, Pizza, Coffee, Drinks, Fries, Wings, Salads)
  final products = searchMockProducts(message);
  if (products.isNotEmpty) {
    return formatMockProducts(products);
  }

  // 4. Stores / Restaurants near me
  if (lower.contains('store') ||
      lower.contains('restaurant') ||
      lower.contains('shop') ||
      lower.contains('near me') ||
      lower.contains('place') ||
      lower.contains('cafe')) {
    return formatMockStores(mockStores);
  }

  final activeId = orderId ?? mockActiveOrder.orderId;
  final activeStatus = status ?? mockActiveOrder.status;

  // 5. Active Order Tracking & Status
  if ((lower.contains('where') && lower.contains('order')) ||
      lower.contains('track') ||
      lower.contains('status') ||
      lower.contains('eta') ||
      lower.contains('driver')) {
    return "📦 **Active Order Tracking** (#$activeId)\n\n"
        "• **Status**: $activeStatus\n"
        "• **Store**: ${mockActiveOrder.storeName}\n"
        "• **Items**: ${mockActiveOrder.items.join(', ')}\n"
        "• **Total**: ${mockActiveOrder.totalAmount.toStringAsFixed(0)} ETB (${mockActiveOrder.paymentMethod})\n"
        "• **Driver**: ${mockActiveOrder.driverName} (${mockActiveOrder.driverPhone})\n"
        "• **ETA**: ${mockActiveOrder.estimatedArrival}\n"
        "• **Destination**: ${mockActiveOrder.deliveryAddress}\n\n"
        "Need to call your driver or make updates? Just let me know! 😊";
  }

  // 6. Last / Recent Orders
  if (lower.contains('last order') ||
      lower.contains('previous order') ||
      lower.contains('past order') ||
      lower.contains('history') ||
      lower.contains('receipt')) {
    return "🛍️ **Your Recent Orders**:\n\n"
        "1. **Active**: #$activeId ($activeStatus) — ${mockActiveOrder.totalAmount.toStringAsFixed(0)} ETB\n"
        "   • ${mockActiveOrder.storeName}\n\n"
        "2. **Past**: #${mockPastOrder.orderId} (${mockPastOrder.storeName}) — ${mockPastOrder.status}\n"
        "   • Total: ${mockPastOrder.totalAmount.toStringAsFixed(0)} ETB\n\n"
        "You can re-order anytime from the **Orders** tab! 🧾";
  }

  // 7. General Food / Menu / Recommendation
  if (lower.contains('food') ||
      lower.contains('menu') ||
      lower.contains('eat') ||
      lower.contains('hungry') ||
      lower.contains('recommend') ||
      lower.contains('lunch') ||
      lower.contains('dinner') ||
      lower.contains('breakfast')) {
    return "🍔 **Here are our most popular menu favorites today**:\n\n"
        "• **Double Cheese Burger** — 320 ETB (Juicy beef patty & cheddar)\n"
        "• **Pepperoni Pizza (Large)** — 350 ETB (Italian crust & mozzarella)\n"
        "• **Chicken Wings (8pc)** — 200 ETB (Smoky BBQ glaze)\n"
        "• **Chicken Crispy Burger** — 220 ETB (Crispy fillet + mayo)\n"
        "• **Cappuccino** — 60 ETB (Freshly brewed espresso)\n\n"
        "Tap **View Cart** to start your order right now! 🛒";
  }

  // 8. Refunds
  if (lower.contains('refund') || lower.contains('money back')) {
    return "💸 **Refunds on ZMall**:\n\n"
        "• **ZMall Wallet**: Instant credit\n"
        "• **Telebirr / Bank Card**: 3–5 business days\n\n"
        "Refunds are guaranteed for missing or cancelled items. Share your order ID if you'd like me to check an issue! ✅";
  }

  // 9. Payment Methods
  if (lower.contains('payment') ||
      lower.contains('pay') ||
      lower.contains('telebirr') ||
      lower.contains('cbe') ||
      lower.contains('wallet')) {
    return "💳 **Accepted Payment Methods**:\n\n"
        "• **Telebirr** (Instant seamless checkout)\n"
        "• **CBE Birr**\n"
        "• **Amole**\n"
        "• **ZMall Wallet** (Instant 1-tap pay)\n"
        "• **Credit/Debit Cards**\n"
        "• **Cash on Delivery**\n\n"
        "All transactions are protected and 100% secure. 🔒";
  }

  // 10. Delivery Policies
  if (lower.contains('delivery') || lower.contains('deliver') || lower.contains('time') || lower.contains('fee')) {
    return "🚚 **Delivery Information**:\n\n"
        "• **Standard Delivery**: 30–45 mins (Citywide in Addis Ababa)\n"
        "• **Express Delivery**: 15–30 mins\n"
        "• **Delivery Fee**: 40–60 ETB (calculated by distance)\n\n"
        "Track your rider live after placing any order! ⏱️";
  }

  // 11. Cancellation
  if (lower.contains('cancel')) {
    return "❌ **Cancel Order Policy**:\n\n"
        "1. Open **Orders** tab\n"
        "2. Select active order **#$activeId**\n"
        "3. Tap **Cancel Order**\n\n"
        "⚠️ You can cancel free of charge before the restaurant starts cooking your food.";
  }

  // 12. Human Live Support
  if (lower.contains('agent') ||
      lower.contains('human') ||
      lower.contains('call') ||
      lower.contains('phone') ||
      lower.contains('support') ||
      lower.contains('contact')) {
    return "📞 **Contact Live Support**:\n\n"
        "• **Phone**: +251 96 757 5757\n"
        "• **Email**: info@zmallshop.com\n"
        "• **Hours**: 24/7 Everyday\n\n"
        "Our support team is ready to assist you anytime!";
  }

  // 13. Amharic Queries
  if (lower.contains('ሰላም') ||
      lower.contains('ምግብ') ||
      lower.contains('በርገር') ||
      lower.contains('ፒዛ') ||
      lower.contains('ትዕዛዝ') ||
      lower.contains('ቴሌብር') ||
      lower.contains('ስልክ')) {
    return "👋 ሰላም! እንኳን ወደ ZMall የድጋፍ መስመር በደህና መጡ።\n\n"
        "ምን ልርዳዎት?\n"
        "• 🍔 ምግብ እና በርገር ማዘዝ\n"
        "• 📦 የትዕዛዝ ሁኔታ መከታተል (#$activeId)\n"
        "• 💳 በቴሌብር ክፍያ መፈጸም\n"
        "• 📞 የቀጥታ ድጋፍ ማግኘት (+251 96 757 5757)";
  }

  // 14. Greetings & Small Talk
  if (lower.contains('hello') ||
      lower.contains('hi') ||
      lower.contains('hey') ||
      lower.contains('selam') ||
      lower.contains('good morning') ||
      lower.contains('good evening') ||
      lower.contains('good afternoon')) {
    return "👋 Hi there! Welcome to ZMall Support.\n\n"
        "How can I help you today? You can ask me about:\n"
        "• 🍔 Delicious burgers, pizzas, and drinks\n"
        "• 📦 Tracking order **#$activeId**\n"
        "• 🔥 Today's special offers & discount codes\n"
        "• 💳 Telebirr payments & refunds\n"
        "• 🛵 Delivery times & top restaurants";
  }

  // 15. Cart & Checkout
  if (lower.contains('cart') || lower.contains('basket') || lower.contains('checkout')) {
    return "🛒 **Your ZMall Cart**:\n\n"
        "Tap the green **View Cart** button below anytime to view your basket, adjust quantities, and checkout with Telebirr or cash! 🍔";
  }

  // 16. Appreciation & Politeness
  if (lower.contains('thank') ||
      lower.contains('cool') ||
      lower.contains('great') ||
      lower.contains('ok') ||
      lower.contains('okay') ||
      lower.contains('awesome') ||
      lower.contains('perfect')) {
    return "You're very welcome! 😊\n\n"
        "Feel free to ask if you need anything else. Enjoy your meal! 🍔🍟";
  }

  // 17. Help
  if (lower.contains('help') || lower.contains('what can you do') || lower.contains('who are you')) {
    return "💡 **Here is what I can help you with**:\n\n"
        "• 🍔 Browse popular burgers, pizza, sides & drinks\n"
        "• 📦 Live track your active order **#$activeId**\n"
        "• 🔥 Check today's special offers & promo codes\n"
        "• 💳 Telebirr & CBE Birr payment guidance\n"
        "• 💸 Instant refund policies\n"
        "• 🛵 Delivery times & partner stores\n"
        "• 📞 Connect with a 24/7 human agent";
  }

  return "I'm here to help with your ZMall orders, menu recommendations, deliveries, and payments. 😊\n\n"
      "Try asking:\n"
      "• *\"Show me burgers\"*\n"
      "• *\"What are today's special offers?\"*\n"
      "• *\"Where is my order?\"*\n"
      "• *\"How do I pay with Telebirr?\"*\n"
      "• *\"Show me top selling stores this week\"*";
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