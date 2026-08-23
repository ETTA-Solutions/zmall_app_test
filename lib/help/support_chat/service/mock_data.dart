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
    storeId: '64aba2706d11e42d492fba67',
    name: 'Pepperoni Pizza (Large)',
    price: 350.0,
    category: 'Pizza',
    description:
        'Hand-tossed crust, Italian tomato sauce, mozzarella & beef pepperoni',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa2',
    storeId: '64aba2706d11e42d492fba67',
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
    storeId: '64aba2706d11e42d492fba67',
    name: 'Cappuccino',
    price: 60.0,
    category: 'Coffee',
    description:
        'Freshly brewed rich espresso topped with smooth velvety milk foam',
  ),
  MockProduct(
    id: '64aba5286d11e42d492fbaa6',
    storeId: '64aba2706d11e42d492fba67',
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
];

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
      .toList();
  final extra = products.length > 8
      ? '\n\n…and ${products.length - 8} more items!'
      : '';
  return '😋 Here\'s what I found for you:\n\n$lines$extra\n\n'
      'Tap **View Cart** below to see them in your basket. 🛒';
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