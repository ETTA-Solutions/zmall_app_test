/// Demo data used by the support chat when the backend is unreachable,
/// so users can still "find" products and get a View Cart action.
class MockProduct {
  final String name;
  final double price;
  final String category;

  const MockProduct({
    required this.name,
    required this.price,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'category': category,
      };
}

/// Demo catalog (burger focused) used for offline product searches.
const List<MockProduct> mockProducts = [
  MockProduct(name: 'Classic ZMall Burger', price: 180.0, category: 'Burger'),
  MockProduct(name: 'Double Cheeseburger', price: 250.0, category: 'Burger'),
  MockProduct(name: 'Chicken Crispy Burger', price: 220.0, category: 'Burger'),
  MockProduct(name: 'Zinger Burger', price: 210.0, category: 'Burger'),
  MockProduct(name: 'Veggie Burger', price: 160.0, category: 'Burger'),
  MockProduct(name: 'Pepperoni Pizza (Large)', price: 350.0, category: 'Pizza'),
  MockProduct(name: 'Margherita Pizza (Medium)', price: 260.0, category: 'Pizza'),
  MockProduct(name: 'Cappuccino', price: 60.0, category: 'Coffee'),
  MockProduct(name: 'Americano', price: 50.0, category: 'Coffee'),
  MockProduct(name: 'French Fries', price: 80.0, category: 'Sides'),
  MockProduct(name: 'Chicken Wings (8pc)', price: 200.0, category: 'Sides'),
  MockProduct(name: 'Soft Drink (Coke 500ml)', price: 40.0, category: 'Drinks'),
];

/// Returns demo products matching the user's message, or an empty list.
List<MockProduct> searchMockProducts(String message) {
  final lower = message.toLowerCase();

  final keywordCategories = {
    'burger': 'Burger',
    'pizza': 'Pizza',
    'coffee': 'Coffee',
    'drink': 'Drinks',
    'soda': 'Drinks',
    'coke': 'Drinks',
    'fries': 'Sides',
    'chicken': 'Sides',
    'wings': 'Sides',
  };

  String? category;
  for (final entry in keywordCategories.entries) {
    if (lower.contains(entry.key)) {
      category = entry.value;
      break;
    }
  }

  if (category != null) {
    return mockProducts
        .where((product) => product.category == category)
        .toList();
  }

  final isProductSearch = lower.contains('find') ||
      lower.contains('search') ||
      lower.contains('show me') ||
      lower.contains('menu') ||
      lower.contains('food') ||
      lower.contains('order ') ||
      lower.contains('buy') ||
      lower.contains('item');

  if (isProductSearch) {
    return mockProducts;
  }

  return [];
}

/// Formats a list of demo products into a chat-friendly reply.
String formatMockProducts(List<MockProduct> products) {
  final lines = products
      .map(
        (product) => '• ${product.name} — ${product.price.toStringAsFixed(0)} ETB',
      )
      .toList();
  return 'Here is what I found:\n\n${lines.join('\n')}\n\n'
      'Tap the green "View Cart" button to add them to your cart. 🛒';
}