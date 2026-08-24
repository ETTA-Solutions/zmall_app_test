import 'package:zmall/models/cart.dart';
import 'package:zmall/services/service.dart';

/// Demo product model used by the support chat for product recommendations,
/// mock search results, and direct-to-cart integration.
class MockProduct {
  final String id;
  final String storeId;
  final String name;
  final double price;
  final String category;
  final String description;
  final String imageUrl;

  const MockProduct({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.category,
    this.description = '',
    this.imageUrl = '',
  });

  Map<String, dynamic> toJson() => {
        '_id': id,
        'store_id': storeId,
        'name': name,
        'price': price,
        'category': category,
        'description': description,
        'image_url': imageUrl,
      };
}

/// Catalog used for offline/mock chatbot product recommendations and cart testing.
const List<MockProduct> mockProducts = [
  MockProduct(
    id: '64aba5286d11e42d492fba9b',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Cheese Burger',
    price: 250.0,
    category: 'Burger',
    description:
        'Juicy grilled beef patty with melted cheddar cheese & house sauce',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9c',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Double Cheese Burger',
    price: 320.0,
    category: 'Burger',
    description:
        'Two beef patties, loaded double cheese, pickles and signature dressing',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9d',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Classic ZMall Burger',
    price: 180.0,
    category: 'Burger',
    description:
        'Signature grilled beef patty with crisp lettuce and fresh tomatoes',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9e',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Chicken Crispy Burger',
    price: 220.0,
    category: 'Burger',
    description: 'Crispy fried chicken breast fillet with garlic herb mayo',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fba9f',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Zinger Burger',
    price: 210.0,
    category: 'Burger',
    description:
        'Spicy crunchy chicken patty with zesty relish and fresh greens',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa0',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Veggie Burger',
    price: 160.0,
    category: 'Burger',
    description:
        'Delicious plant-based patty with avocado sauce and garden veggies',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa1',
    storeId: '64aba2706d11e42d492fba68',
    name: 'Pepperoni Pizza (Large)',
    price: 350.0,
    category: 'Pizza',
    description:
        'Hand-tossed crust, Italian tomato sauce, mozzarella & beef pepperoni',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa2',
    storeId: '64aba2706d11e42d492fba68',
    name: 'Margherita Pizza (Medium)',
    price: 260.0,
    category: 'Pizza',
    description:
        'Fresh mozzarella cheese, tomato passata, virgin olive oil and basil',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa3',
    storeId: '64aba2706d11e42d492fba67',
    name: 'French Fries',
    price: 80.0,
    category: 'Sides',
    description: 'Golden crispy potato fries lightly sprinkled with sea salt',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa4',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Chicken Wings (8pc)',
    price: 200.0,
    category: 'Sides',
    description:
        '8 pieces of crispy juicy chicken wings in smoky barbecue glaze',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa5',
    storeId: '64aba2706d11e42d492fba69',
    name: 'Cappuccino',
    price: 60.0,
    category: 'Coffee',
    description:
        'Freshly brewed rich espresso topped with smooth velvety milk foam',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa6',
    storeId: '64aba2706d11e42d492fba69',
    name: 'Americano',
    price: 50.0,
    category: 'Coffee',
    description: 'Fresh single-origin Ethiopian espresso with hot water',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa7',
    storeId: '64aba2706d11e42d492fba67',
    name: 'Soft Drink (Coke 500ml)',
    price: 40.0,
    category: 'Drinks',
    description: 'Chilled refreshing Coca-Cola bottle (500ml)',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa8',
    storeId: '64aba2706d11e42d492fba70',
    name: 'Chicken Caesar Salad',
    price: 240.0,
    category: 'Salad',
    description: 'Crisp romaine, grilled chicken breast, parmesan & caesar dressing',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa9',
    storeId: '64aba2706d11e42d492fba69',
    name: 'Chocolate Lava Cake',
    price: 150.0,
    category: 'Dessert',
    description: 'Warm chocolate fudge cake with molten chocolate core',
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

  const MockStore({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
  });
}

const List<MockStore> mockStores = [
  MockStore(
    id: '64aba2706d11e42d492fba67',
    name: 'ZMall Burger & Grill',
    category: 'Fast Food / Burgers',
    location: 'Bole Medhanialem, Addis Ababa',
    rating: 4.8,
    deliveryTime: '20–35 min',
    deliveryFee: 50.0,
  ),
  MockStore(
    id: '64aba2706d11e42d492fba68',
    name: 'Pizza Bella Italia',
    category: 'Pizza & Italian',
    location: 'Atlas, Addis Ababa',
    rating: 4.9,
    deliveryTime: '25–40 min',
    deliveryFee: 60.0,
  ),
  MockStore(
    id: '64aba2706d11e42d492fba69',
    name: 'Addis Coffee Roasters',
    category: 'Cafe & Bakery',
    location: 'Sarbet, Addis Ababa',
    rating: 4.7,
    deliveryTime: '15–25 min',
    deliveryFee: 40.0,
  ),
  MockStore(
    id: '64aba2706d11e42d492fba70',
    name: 'Green Garden Healthy Bowls',
    category: 'Healthy / Salads',
    location: 'Kazanchis, Addis Ababa',
    rating: 4.6,
    deliveryTime: '30–45 min',
    deliveryFee: 55.0,
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

  // Cheese burger specific match
  if (lower.contains('cheese') && lower.contains('burger')) {
    return mockProducts
        .where((p) => p.name.toLowerCase().contains('cheese'))
        .toList();
  }

  final keywordCategories = {
    'cheeseburger': 'Burger',
    'burger': 'Burger',
    'pizza': 'Pizza',
    'coffee': 'Coffee',
    'cappuccino': 'Coffee',
    'americano': 'Coffee',
    'drink': 'Drinks',
    'soda': 'Drinks',
    'coke': 'Drinks',
    'cola': 'Drinks',
    'fries': 'Sides',
    'wings': 'Sides',
    'salad': 'Salad',
    'dessert': 'Dessert',
    'cake': 'Dessert',
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

  return [];
}

/// Formats a list of demo products into a chat-friendly reply.
String formatMockProducts(List<MockProduct> products) {
  final lines = products
      .take(8)
      .map(
        (product) =>
            '• **${product.name}** — ${product.price.toStringAsFixed(0)} ETB'
            '${product.description.isNotEmpty ? '\n  ${product.description}' : ''}',
      )
      .toList()
      .join('\n');
  final extra = products.length > 8
      ? '\n\n…and ${products.length - 8} more items!'
      : '';
  return '😋 Here\'s what I found for you:\n\n$lines$extra\n\n'
      'Tap **View Cart** below to see them in your basket. 🛒';
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
  return '📍 Here are top stores available near you:\n\n$lines\n\n'
      'Tell me what you\'d like to order and I\'ll help you get started! 🍔';
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
        "1. 🍔 **Burger Fiesta Combo** (ZMall Burger & Grill)\n"
        "   • Double Cheese Burger + Large Fries + Coke — **399 ETB** *(Save 41 ETB)*\n\n"
        "2. 🍕 **Pizza Tuesday 2-for-1** (Pizza Bella Italia)\n"
        "   • Buy 1 Large Pepperoni, Get Margherita 50% OFF!\n\n"
        "3. 🛵 **Free Delivery on orders over 500 ETB**\n"
        "   • Use Promo Code: `ZMALLFREESHIP`\n\n"
        "4. 💳 **10% Cashback with Telebirr Pay**\n\n"
        "Tap **View Cart** or tell me what you'd like to order to apply discounts! 🛒";
  }

  // 2. Top Selling Stores this week (matches "Show me top selling stores this week")
  if (lower.contains('top selling') ||
      lower.contains('popular') ||
      lower.contains('trending') ||
      lower.contains('best selling') ||
      lower.contains('famous')) {
    return "🏆 **Top Selling Stores This Week**:\n\n"
        "🥇 **1. ZMall Burger & Grill** — ⭐4.8 (1,420+ orders)\n"
        "   • Signature: Double Cheese Burger (320 ETB)\n"
        "   • 🛵 20–35 min • Bole Medhanialem\n\n"
        "🥈 **2. Pizza Bella Italia** — ⭐4.9 (980+ orders)\n"
        "   • Signature: Pepperoni Pizza Large (350 ETB)\n"
        "   • 🛵 25–40 min • Atlas\n\n"
        "🥉 **3. Addis Coffee Roasters** — ⭐4.7 (750+ orders)\n"
        "   • Signature: Cappuccino & Chocolate Lava Cake\n"
        "   • 🛵 15–25 min • Sarbet\n\n"
        "Tell me what you feel like having! 😋";
  }

  // 3. Product searches (Burgers, Pizza, Coffee, Drinks, Fries, Wings, Salads)
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