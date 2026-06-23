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
    bridgeCart();
  }

  Future<void> bridgeCart() async {
    try {
      final userRaw = await Service.read('user');

      if (userRaw == null) {
        await Service.save('pending_ai_cart', {
          'cart_id': widget.cartId,
          'saved_at': DateTime.now().millisecondsSinceEpoch,
        });

        if (!mounted) return;

        _replaceRoute(LoginScreen.routeName);
        return;
      }

      final user = userRaw is Map ? userRaw : jsonDecode(userRaw.toString());

      if (mounted) {
        setState(() {
          statusText = 'Fetching your cart...';
        });
      }

      final uri = Uri.parse('$BASE_URL/api/ai/cart/${widget.cartId}');

      // DEBUG: print credentials + cartId so you can test deeplinks manually
      // print('\n');
      // print('╔═══════════════════════════════════════════════════════════');
      // print('║  DEEPLINK DEBUG — McpCartScreen.bridgeCart()');
      // print('║  cartId (from deeplink) : ${widget.cartId}');
      // print('║  user_id                : ${user['user']['_id']}');
      // print('║  server_token           : ${user['user']['server_token']}');
      // print('║  request URL            : $uri');
      // print('║');
      // print('║  Test deeplink via adb:');
      // print(
      //   '║  adb shell am start -a android.intent.action.VIEW -d "zmall://cart/${widget.cartId}"',
      // );
      // print('╚═══════════════════════════════════════════════════════════\n');

      final response = await http
          .get(
            uri,
            headers: {
              'server_token': user['user']['server_token']?.toString() ?? '',
              'user_id': user['user']['_id']?.toString() ?? '',
            },
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      // DEBUG: print full API response
      // print('\n');
      // print('╔═══════════════════════════════════════════════════════════');
      // print('║  DEEPLINK API RESPONSE — /api/ai/cart/${widget.cartId}');
      // print('║  status_code : ${response.statusCode}');
      // print('║  success     : ${data['success']}');
      // print('║  store_id    : ${data['store_id']}');
      // print('║  store_name  : ${data['store_name']}');
      // print('║  items count : ${(data['items'] as List?)?.length ?? 0}');
      // print('║  error       : ${data['error']}');
      // print('║  raw body    : ${response.body}');
      // print('╚═══════════════════════════════════════════════════════════\n');

      if (response.statusCode == 404 || data['success'] != true) {
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

      final items = (data['items'] as List)
          .map(
            (i) => {
              '_id': i['item_id'],
              'item_name': i['name'],
              'price': (i['price'] as num).toDouble(),
              'quantity': i['quantity'],
              'specification': [],
              'note_for_item': '',
              // image_url from the AI cart API can be [] — normalise to String.
              'image_url': (i['image_url'] is List || i['image_url'] == null)
                  ? ''
                  : i['image_url'].toString(),
            },
          )
          .toList();

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
          if (!mounted) return;

          final replace = await showConflictDialog(
            existingStoreName:
                existingCart['store_name']?.toString() ?? 'another store',
            newStoreName: storeName,
          );

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
      );
    } catch (_) {
      isProcessingDeepLinkCart = false;
      if (mounted) {
        setState(() {
          error = 'Could not load cart. Please check your connection.';
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
      storeLocationMap = {'lat': 0.0, 'long': 0.0};
    }

    final cartData = {
      'user_id': user['user']['_id'] ?? user['_id'] ?? '',
      'server_token':
          user['user']['server_token'] ?? user['server_token'] ?? '',
      'store_id': storeId,
      'store_name': storeName,
      'items': items,
      'destination_address': {'name': '', 'lat': 0.0, 'long': 0.0, 'note': ''},
      'store_location': storeLocationMap,
      'is_schedule': false,
      'schedule_start': null,
      'delivery_for_other': false,
      'username': '',
      'phone': '',
      'is_laundry_service': false,
    };

    await Service.save('cart', cartData);

    final savedCartRaw = await Service.read('cart');
    final savedCart = savedCartRaw is Map
        ? savedCartRaw
        : (savedCartRaw != null ? jsonDecode(savedCartRaw.toString()) : null);

    final hasStoreId =
        savedCart is Map &&
        (savedCart['store_id']?.toString().isNotEmpty ?? false);
    final hasOrderDetails = savedCart is Map && savedCart['items'] is List;

    if (!hasStoreId || !hasOrderDetails) {
      if (mounted) {
        setState(() {
          error = 'Cart verification failed. Please try again.';
        });
      }
      return;
    }

    if (!mounted) return;

    _replaceRoute(CartScreen.routeName);
  }

  void _replaceRoute(String routeName) {
    if (_didNavigate) return;
    _didNavigate = true;
    isProcessingDeepLinkCart = false;

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
