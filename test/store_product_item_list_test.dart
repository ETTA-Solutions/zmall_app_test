// Tests the user_get_store_product_item_list endpoint without an emulator.
//
// Run:
//   flutter test test/store_product_item_list_test.dart
//   flutter test test/store_product_item_list_test.dart --dart-define=STORE_ID=<id>
//   flutter test test/store_product_item_list_test.dart --dart-define=BASE_URL=https://app.zmall.et
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://testbackend.zmall.et',
);
const storeId = String.fromEnvironment(
  'STORE_ID',
  defaultValue: '6a6b069856bef41124383c9e', // ayat
);

Future<(int, Map<String, dynamic>)> fetchStoreProducts(String id) async {
  final response = await http
      .post(
        Uri.parse('$baseUrl/api/user/user_get_store_product_item_list'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'store_id': id}),
      )
      .timeout(const Duration(seconds: 60));
  return (
    response.statusCode,
    Map<String, dynamic>.from(json.decode(response.body)),
  );
}

void main() {
  test('returns products for a valid store', () async {
    final (status, data) = await fetchStoreProducts(storeId);

    print('POST $baseUrl/api/user/user_get_store_product_item_list');
    print('store_id: $storeId -> HTTP $status, success: ${data['success']}');
    print('top-level keys: ${data.keys.toList()}');

    expect(status, 200);
    expect(data['success'], true, reason: 'response: $data');

    final store = data['store'];
    if (store is Map) {
      print('store: ${store['name']} (open: ${store['is_store_busy'] == false})');
    }

    final products = data['products'];
    expect(products, isA<List>(), reason: "'products' should be a list");
    print('products (categories): ${(products as List).length}');
    for (final p in products.take(5)) {
      final name = p['_id']?['name'] ?? p['name'];
      final items = (p['items'] as List?) ?? const [];
      print('  - $name: ${items.length} items');
      for (final item in items.take(3)) {
        print('      • ${item['name']}  price=${item['price']}');
      }
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('fails for an unknown store id', () async {
    final (status, data) = await fetchStoreProducts('000000000000000000000000');
    print('unknown store -> HTTP $status, $data');
    expect(data['success'], isNot(true));
  }, timeout: const Timeout(Duration(seconds: 90)));
}
