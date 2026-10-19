import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../cart/cart_screen.dart';
import '../kifiya/kifiya_screen.dart';
import '../login/login_screen.dart';
import '../services/service.dart';
import '../utils/constants.dart';
import '../utils/navigator_key.dart';

class McpCartScreen extends StatefulWidget {
  static const String routeName = '/mcp-cart';

  final String cartId;
  final String? target;

  const McpCartScreen({super.key, required this.cartId, this.target});

  @override
  State<McpCartScreen> createState() => _McpCartScreenState();
}

class _McpCartScreenState extends State<McpCartScreen> {
  String statusText = 'Preparing your order...';
  String? error;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[MCP CART] McpCartScreen initialized for cartId: ${widget.cartId}');
    bridgeCart();
  }

  Future<void> bridgeCart() async {
    try {
      debugPrint('[MCP CART] bridgeCart() starting for cartId: ${widget.cartId}');
      final userRaw = await Service.read('user');

      if (userRaw == null) {
        debugPrint('[MCP CART] No user session found. Storing pending_ai_cart and redirecting to login.');
        await Service.save('pending_ai_cart', {
          'cart_id': widget.cartId,
          'saved_at': DateTime.now().millisecondsSinceEpoch,
        });

        if (!mounted) return;

        _replaceRoute(LoginScreen.routeName);
        return;
      }

      final user = userRaw is Map ? userRaw : jsonDecode(userRaw.toString());
      final userId = user['user']?['_id'] ?? user['_id'] ?? '';
      final serverToken =
          user['user']?['server_token'] ?? user['server_token'] ?? '';

      debugPrint('[MCP CART] User authenticated: userId=$userId');

      if (mounted) {
        setState(() {
          statusText = 'Fetching your cart...';
        });
      }

      final uri = Uri.parse('$BASE_URL/api/ai/cart/${widget.cartId}');

      debugPrint('\n╔═══════════════════════════════════════════════════════════');
      debugPrint('║  [MCP CART REQUEST] McpCartScreen.bridgeCart()');
      debugPrint('║  cartId (from deeplink) : ${widget.cartId}');
      debugPrint('║  user_id                : $userId');
      debugPrint(
        '║  server_token           : ${serverToken.isNotEmpty ? (serverToken.toString().length > 8 ? "${serverToken.toString().substring(0, 8)}..." : "present") : "EMPTY"}',
      );
      debugPrint('║  request URL            : $uri');
      debugPrint('║');
      debugPrint('║  Test deeplink via adb:');
      debugPrint(
        '║  adb shell am start -a android.intent.action.VIEW -d "zmall://cart/${widget.cartId}"',
      );
      debugPrint('╚═══════════════════════════════════════════════════════════\n');

      final response = await http
          .get(
            uri,
            headers: {
              'server_token': serverToken.toString(),
              'user_id': userId.toString(),
            },
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      debugPrint('\n╔═══════════════════════════════════════════════════════════');
      debugPrint('║  [MCP CART RESPONSE] /api/ai/cart/${widget.cartId}');
      debugPrint('║  [MCP CART] status_code : ${response.statusCode}');
      debugPrint('║  [MCP CART] success     : ${data is Map ? data['success'] : null}');
      debugPrint('║  [MCP CART] store_id    : ${data is Map ? (data['store_id'] ?? data['cart']?['store_id']) : null}');
      debugPrint('║  [MCP CART] store_name  : ${data is Map ? (data['store_name'] ?? data['cart']?['store_name']) : null}');
      debugPrint('║  [MCP CART] error       : ${data is Map ? data['error'] : null}');
      debugPrint('║  [MCP CART] raw body    : ${response.body}');
      debugPrint('╚═══════════════════════════════════════════════════════════\n');

      if (response.statusCode == 404 || (data is Map && data['success'] == false)) {
        debugPrint(
          '[MCP CART] Cart retrieval failed: status=${response.statusCode}, error=${data is Map ? data['error'] : 'Unknown error'}',
        );
        if (mounted) {
          setState(() {
            error = (data is Map ? data['error'] : null) ?? 'Cart not found or expired.';
          });
        }
        return;
      }

      if (data is! Map) {
        debugPrint('[MCP CART] Invalid response structure: $data');
        if (mounted) {
          setState(() {
            error = 'Invalid cart response received.';
          });
        }
        return;
      }

      final storeId = (data['store_id'] ?? data['cart']?['store_id'] ?? data['data']?['store_id'])?.toString() ?? '';
      final storeName = (data['store_name'] ?? data['cart']?['store_name'] ?? data['data']?['store_name'])?.toString() ?? '';
      final storeLocation = data['store_location'] ?? data['cart']?['store_location'] ?? data['data']?['store_location'];

      dynamic rawItemsList = data['items'];
      if (rawItemsList == null && data['cart'] is Map) {
        rawItemsList = data['cart']['items'] ?? data['cart']['order_details'];
      }
      if (rawItemsList == null && data['data'] is Map) {
        rawItemsList = data['data']['items'] ?? data['data']['order_details'];
      }
      if (rawItemsList == null) {
        rawItemsList = data['order_details'];
      }

      final List rawItems = (rawItemsList is List) ? rawItemsList : [];

      final invoice = data['invoice'] ??
          (data['cart'] is Map ? data['cart']['invoice'] : null) ??
          (data['data'] is Map ? data['data']['invoice'] : null);

      if (rawItems.isEmpty && invoice == null) {
        debugPrint('[MCP CART] No items found in cart: $data');
        if (mounted) {
          setState(() {
            error = data['error']?.toString() ??
                data['message']?.toString() ??
                'Cart has no items or has expired.';
          });
        }
        return;
      }

      final items = rawItems.map((i) {
        if (i is! Map) return <String, dynamic>{};
        List<dynamic> specs = [];
        if (i['specifications'] != null && i['specifications'] is List) {
          specs = List.from(i['specifications']);
        } else if (i['specification'] != null && i['specification'] is List) {
          specs = List.from(i['specification']);
        }

        // Auto-select one default size/specification if available
        for (var specGroup in specs) {
          if (specGroup is Map &&
              specGroup['list'] != null &&
              specGroup['list'] is List &&
              specGroup['list'].isNotEmpty) {
            bool hasDefault = specGroup['list'].any(
              (option) => option is Map && option['is_default_selected'] == true,
            );
            if (!hasDefault && specGroup['list'][0] is Map) {
              specGroup['list'][0]['is_default_selected'] = true;
            }
          }
        }

        final rawPrice = i['price'];
        final double itemPrice = (rawPrice is num)
            ? rawPrice.toDouble()
            : (double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0);

        final rawQty = i['quantity'];
        final int quantity = (rawQty is num)
            ? rawQty.toInt()
            : (int.tryParse(rawQty?.toString() ?? '1') ?? 1);

        return {
          '_id': (i['item_id'] ?? i['_id'] ?? '').toString(),
          'item_name': (i['name'] ?? i['item_name'] ?? '').toString(),
          'price': itemPrice,
          'quantity': quantity,
          'specification': specs,
          'note_for_item': (i['note_for_item'] ?? '').toString(),
          // image_url from the AI cart API can be [] — normalise to String.
          'image_url': (i['image_url'] is List || i['image_url'] == null)
              ? ''
              : i['image_url'].toString(),
        };
      }).where((element) => element.isNotEmpty).toList();

      debugPrint(
        '[MCP CART] Mapped ${items.length} items for store: "$storeName" ($storeId)',
      );

      final existingCartRaw = await Service.read('cart');

      if (existingCartRaw != null) {
        final existingCart = existingCartRaw is Map
            ? existingCartRaw
            : jsonDecode(existingCartRaw.toString());

        final existingStoreId = existingCart['store_id'];
        final existingItems =
            (existingCart['items'] ?? existingCart['order_details']) as List? ??
            [];

        if (existingItems.isNotEmpty &&
            existingStoreId != null &&
            existingStoreId != storeId) {
          debugPrint(
            '[MCP CART] Store conflict detected: existingStoreId=$existingStoreId vs newStoreId=$storeId',
          );
          if (!mounted) return;

          final replace = await showConflictDialog(
            existingStoreName:
                existingCart['store_name']?.toString() ?? 'another store',
            newStoreName: storeName,
          );

          debugPrint('[MCP CART] User conflict dialog choice: replace=$replace');

          if (!mounted) return;

          if (!replace) {
            _replaceRoute(CartScreen.routeName);
            return;
          }
        }
      }

      await commitCart(
        user: user,
        storeId: storeId,
        storeName: storeName,
        items: items,
        storeLocation: storeLocation,
        data: data,
      );
    } catch (e, stack) {
      debugPrint('[MCP CART ERROR] Exception in bridgeCart: $e\n$stack');
      isProcessingDeepLinkCart = false;
      if (mounted) {
        setState(() {
          error = 'Could not load cart: $e';
        });
      }
    }
  }

  Future<void> commitCart({
    required Map user,
    required String storeId,
    required String storeName,
    required List items,
    required dynamic storeLocation,
    Map? data,
  }) async {
    if (mounted) {
      setState(() {
        statusText = 'Setting up your cart...';
      });
    }

    // Convert store_location from [lat, lng] array to {lat, long} map
    Map<String, dynamic> storeLocationMap;
    if (storeLocation is List && storeLocation.length >= 2) {
      // MongoDB GeoJSON is [longitude, latitude], so index 1 is lat, 0 is long
      storeLocationMap = {
        'lat': (storeLocation[1] as num).toDouble(),
        'long': (storeLocation[0] as num).toDouble(),
      };
    } else if (storeLocation is Map) {
      storeLocationMap = Map<String, dynamic>.from(storeLocation);
    } else {
      storeLocationMap = {'lat': 9.010498, 'long': 38.761886};
    }

    // Ensure destination_address is mandatory and has valid coordinates
    Map<String, dynamic> destAddress;
    final rawDest = data?['destination_address'];
    if (rawDest != null &&
        rawDest is Map &&
        rawDest['lat'] != null &&
        (rawDest['lat'] as num) != 0) {
      destAddress = {
        'name': rawDest['name'] ?? 'Delivery Address',
        'lat': (rawDest['lat'] as num).toDouble(),
        'long': (rawDest['long'] as num).toDouble(),
        'note': rawDest['note'] ?? '',
      };
    } else {
      final userLocation = await Service.read('location');
      if (userLocation != null &&
          userLocation is Map &&
          userLocation['latitude'] != null) {
        destAddress = {
          'name': userLocation['address'] ?? 'My Location',
          'lat': (userLocation['latitude'] as num).toDouble(),
          'long': (userLocation['longitude'] as num).toDouble(),
          'note': '',
        };
      } else {
        destAddress = {
          'name': 'Store Delivery Zone',
          'lat': storeLocationMap['lat'] != 0.0
              ? storeLocationMap['lat']
              : 9.010498,
          'long': storeLocationMap['long'] != 0.0
              ? storeLocationMap['long']
              : 38.761886,
          'note': '',
        };
      }
    }

    final cartData = {
      'user_id': user['user']?['_id'] ?? user['_id'] ?? '',
      'server_token':
          user['user']?['server_token'] ?? user['server_token'] ?? '',
      'store_id': storeId,
      'store_name': storeName,
      'items': items,
      'destination_address': destAddress,
      'store_location': storeLocationMap,
      'is_schedule': false,
      'schedule_start': null,
      'delivery_for_other': false,
      'username': '',
      'phone': '',
      'is_laundry_service': false,
      'is_mcp': true,
    };

    debugPrint(
      '[MCP CART] Saving cart to local storage with ${items.length} items for "$storeName"...',
    );
    await Service.save('cart', cartData);

    final savedCartRaw = await Service.read('cart');
    final savedCart = savedCartRaw is Map
        ? savedCartRaw
        : (savedCartRaw != null ? jsonDecode(savedCartRaw.toString()) : null);

    final hasStoreId =
        savedCart is Map &&
        (savedCart['store_id']?.toString().isNotEmpty ?? false);
    final hasOrderDetails = savedCart is Map && savedCart['items'] is List;

    debugPrint(
      '[MCP CART] Verification: hasStoreId=$hasStoreId, hasOrderDetails=$hasOrderDetails',
    );

    if (!hasStoreId || !hasOrderDetails) {
      debugPrint(
        '[MCP CART ERROR] Cart verification failed! Saved cart data: $savedCart',
      );
      if (mounted) {
        setState(() {
          error = 'Cart verification failed. Please try again.';
        });
      }
      return;
    }

    if (!mounted) return;

    final invoice = data?['invoice'] ?? (data?['cart'] is Map ? data!['cart']['invoice'] : null);
    final bool canFastTrackToKifiya = (widget.target == 'kifiya' || invoice != null) &&
        invoice != null &&
        invoice is Map &&
        invoice['order_payment_id'] != null &&
        invoice['order_payment_unique_id'] != null;

    if (canFastTrackToKifiya) {
      final double price = (num.tryParse(invoice['user_pay_payment']?.toString() ?? invoice['total']?.toString() ?? '0') ?? 0.0).toDouble();
      final String paymentId = invoice['order_payment_id'].toString();
      final String uniqueId = invoice['order_payment_unique_id'].toString();
      final String vehicleId = (data?['default_vehicle'] is Map ? data!['default_vehicle']['_id'] : null)?.toString() ??
          data?['vehicle_id']?.toString() ??
          '';

      debugPrint(
        '[MCP CART] Fast-track enabled: Navigating directly to KifiyaScreen in 1 second (price: $price, paymentId: $paymentId, uniqueId: $uniqueId)',
      );
      _navigateToKifiya(
        price: price,
        orderPaymentId: paymentId,
        orderPaymentUniqueId: uniqueId,
        vehicleId: vehicleId,
      );
      return;
    }

    debugPrint(
      '[MCP CART] Cart successfully verified and saved. Navigating to CartScreen.',
    );
    _replaceRoute(CartScreen.routeName);
  }

  void _navigateToKifiya({
    required double price,
    required String orderPaymentId,
    required String orderPaymentUniqueId,
    required String vehicleId,
  }) {
    if (_didNavigate) {
      debugPrint(
        '[MCP CART] Already navigated. Ignoring duplicate call to _navigateToKifiya()',
      );
      return;
    }
    _didNavigate = true;
    isProcessingDeepLinkCart = false;

    debugPrint('[MCP CART] Navigating directly to KifiyaScreen');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        KifiyaScreen.routeName,
        (route) => false,
        arguments: {
          'price': price,
          'orderPaymentId': orderPaymentId,
          'orderPaymentUniqueId': orderPaymentUniqueId,
          'vehicleId': vehicleId.isNotEmpty ? vehicleId : null,
          'onlyCashless': false,
          'userpickupWithSchedule': false,
        },
      );
    });
  }

  void _replaceRoute(String routeName) {
    if (_didNavigate) {
      debugPrint(
        '[MCP CART] Already navigated. Ignoring duplicate call to _replaceRoute($routeName)',
      );
      return;
    }
    _didNavigate = true;
    isProcessingDeepLinkCart = false;

    debugPrint('[MCP CART] Replacing route with: $routeName');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        routeName,
        (route) => false,
      );
    });
  }

  Future<bool> showConflictDialog({
    required String existingStoreName,
    required String newStoreName,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Replace your cart?',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Text(
                'You already have items from $existingStoreName.\n\n'
                'Replace with new order from $newStoreName?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx, false);
                  },
                  child: const Text('Keep Existing'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Replace Cart'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildBrandMark({required Color accentColor, required Widget child}) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3.5,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            backgroundColor: accentColor.withValues(alpha: 0.12),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: child),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusShell({
    required Color accentColor,
    required Widget icon,
    required String title,
    required String message,
    required List<Widget> actions,
    Color? backgroundTint,
  }) {
    return Scaffold(
      backgroundColor: backgroundTint ?? Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBrandMark(accentColor: accentColor, child: icon),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      final isExpired = error!.toLowerCase().contains('expire') ||
          error!.toLowerCase().contains('not found');
      return _buildStatusShell(
        accentColor: kSecondaryColor,
        backgroundTint: Colors.white,
        icon: Image.asset(
          'images/zmall_sm.png',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
        title: isExpired ? 'Order Link Expired' : 'Cart Unavailable',
        message: isExpired
            ? 'This order link has expired or is no longer available. Please start a fresh order.'
            : error!,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kSecondaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                isProcessingDeepLinkCart = false;
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text(
                'Start Fresh Order',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: kBlackColor,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                isProcessingDeepLinkCart = false;
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text(
                'Go to Home',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    return _buildStatusShell(
      accentColor: kSecondaryColor,
      icon: Image.asset(
        'images/zmall_sm.png',
        width: 36,
        height: 36,
        fit: BoxFit.cover,
      ),
      title: statusText,
      message: 'AI Cart Bridge',
      actions: [
        Text(
          'Connecting your cart securely',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
