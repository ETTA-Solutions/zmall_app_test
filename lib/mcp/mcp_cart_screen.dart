import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../cart/cart_screen.dart';
import '../login/login_screen.dart';
import '../services/service.dart';
import '../utils/constants.dart';
import '../utils/navigator_key.dart';

class McpCartScreen extends StatefulWidget {
  static const String routeName = '/mcp-cart';

  final String cartId;

  const McpCartScreen({super.key, required this.cartId});

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
      debugPrint('║  status_code : ${response.statusCode}');
      debugPrint('║  success     : ${data['success']}');
      debugPrint('║  store_id    : ${data['store_id']}');
      debugPrint('║  store_name  : ${data['store_name']}');
      debugPrint('║  items count : ${(data['items'] as List?)?.length ?? 0}');
      debugPrint('║  error       : ${data['error']}');
      debugPrint('║  raw body    : ${response.body}');
      debugPrint('╚═══════════════════════════════════════════════════════════\n');

      if (response.statusCode == 404 || data['success'] != true) {
        debugPrint(
          '[MCP CART] Cart retrieval failed: status=${response.statusCode}, error=${data['error']}',
        );
        if (mounted) {
          setState(() {
            error = data['error'] ?? 'Cart not found or expired.';
          });
        }
        return;
      }

      final storeId = data['store_id']?.toString() ?? '';
      final storeName = data['store_name']?.toString() ?? '';
      final storeLocation = data['store_location'];

      final items = (data['items'] as List).map((i) {
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
              (option) => option['is_default_selected'] == true,
            );
            if (!hasDefault) {
              specGroup['list'][0]['is_default_selected'] = true;
            }
          }
        }

        return {
          '_id': i['item_id'] ?? i['_id'] ?? '',
          'item_name': i['name'] ?? i['item_name'] ?? '',
          'price': (i['price'] as num).toDouble(),
          'quantity': i['quantity'] ?? 1,
          'specification': specs,
          'note_for_item': i['note_for_item'] ?? '',
          // image_url from the AI cart API can be [] — normalise to String.
          'image_url': (i['image_url'] is List || i['image_url'] == null)
              ? ''
              : i['image_url'].toString(),
        };
      }).toList();

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
    Map<String, dynamic>? data,
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

    debugPrint(
      '[MCP CART] Cart successfully verified and saved. Navigating to CartScreen.',
    );
    _replaceRoute(CartScreen.routeName);
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
      return _buildStatusShell(
        accentColor: kSecondaryColor,
        backgroundTint: Colors.white,
        icon: Image.asset(
          'images/zmall_sm.png',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
        title: 'Cart Unavailable',
        message: error!.contains('not found')
            ? 'Cart not found. Please try again.'
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
                setState(() => error = null);
                bridgeCart();
              },
              child: const Text('Try Again'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Browse Stores'),
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
