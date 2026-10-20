import 'dart:convert';
import 'dart:io';

import 'package:fl_location/fl_location.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../cart/cart_screen.dart';
import '../kifiya/kifiya_screen.dart';
import '../login/login_screen.dart';
import '../models/metadata.dart';
import '../services/address_validation_service.dart';
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
    debugPrint(
      '[MCP CART] McpCartScreen initialized for cartId: ${widget.cartId}',
    );
    bridgeCart();
  }

  Future<void> bridgeCart() async {
    try {
      debugPrint(
        '[MCP CART] bridgeCart() starting for cartId: ${widget.cartId}',
      );
      final userRaw = await Service.read('user');

      if (userRaw == null) {
        debugPrint(
          '[MCP CART] No user session found. Storing pending_ai_cart and redirecting to login.',
        );
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

      debugPrint(
        '\n╔═══════════════════════════════════════════════════════════',
      );
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
      debugPrint(
        '╚═══════════════════════════════════════════════════════════\n',
      );

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

      // ─── MCP CART API RESPONSE: FULL STRUCTURED DEBUG ─────────────────────
      debugPrint(
        '\n╔══════════════════════════════════════════════════════════════════',
      );
      debugPrint('║  [MCP CART RESPONSE] GET /api/ai/cart/${widget.cartId}');
      debugPrint('║  HTTP Status Code  : ${response.statusCode}');
      debugPrint(
        '║  Success           : ${data is Map ? data['success'] : 'N/A'}',
      );
      debugPrint(
        '║  Error             : ${data is Map ? (data['error'] ?? 'none') : 'N/A'}',
      );
      debugPrint(
        '║  Error Code        : ${data is Map ? (data['error_code'] ?? 'none') : 'N/A'}',
      );
      debugPrint(
        '║  Message           : ${data is Map ? (data['message'] ?? 'none') : 'N/A'}',
      );
      debugPrint(
        '║──────────────────── STORE INFO ──────────────────────────────────',
      );
      debugPrint(
        '║  store_id          : ${data is Map ? (data['store_id'] ?? data['cart']?['store_id'] ?? data['data']?['store_id'] ?? 'not found') : 'N/A'}',
      );
      debugPrint(
        '║  store_name        : ${data is Map ? (data['store_name'] ?? data['cart']?['store_name'] ?? data['data']?['store_name'] ?? 'not found') : 'N/A'}',
      );
      final _dbgLocation = data is Map
          ? (data['store_location'] ??
                data['cart']?['store_location'] ??
                data['data']?['store_location'])
          : null;
      if (_dbgLocation is List && _dbgLocation.length >= 2) {
        debugPrint(
          '║  store_location     : [lng=${_dbgLocation[0]}, lat=${_dbgLocation[1]}] (GeoJSON: [lng, lat])',
        );
      } else {
        debugPrint('║  store_location     : $_dbgLocation');
      }
      debugPrint(
        '║  currency          : ${data is Map ? (data['currency'] ?? 'not set') : 'N/A'}',
      );
      debugPrint(
        '║──────────────────── DESTINATION ─────────────────────────────────',
      );
      final _dbgDest = data is Map
          ? (data['destination_address'] ??
                data['destination'] ??
                data['cart']?['destination_address'])
          : null;
      if (_dbgDest is Map) {
        debugPrint(
          '║  dest.address      : ${_dbgDest['address'] ?? _dbgDest['name'] ?? 'not set'}',
        );
        debugPrint('║  dest.lat          : ${_dbgDest['lat']}');
        debugPrint(
          '║  dest.lng          : ${_dbgDest['lng'] ?? _dbgDest['long']}',
        );
        debugPrint('║  dest.note         : ${_dbgDest['note'] ?? 'none'}');
      } else {
        debugPrint(
          '║  destination       : $_dbgDest  ← (⚠ no destination_address in response!)',
        );
      }
      debugPrint(
        '║──────────────────── ITEMS LIST ──────────────────────────────────',
      );
      final _dbgItems = data is Map
          ? (data['items'] ??
                data['cart']?['items'] ??
                data['data']?['items'] ??
                data['order_details'] ??
                [])
          : [];
      if (_dbgItems is List && (_dbgItems).isNotEmpty) {
        debugPrint('║  items_count       : ${_dbgItems.length}');
        for (int _i = 0; _i < (_dbgItems).length; _i++) {
          final _it = _dbgItems[_i];
          if (_it is Map) {
            debugPrint('║  Item[$_i]');
            debugPrint(
              '║    item_id         : ${_it['item_id'] ?? _it['_id'] ?? 'no id'}',
            );
            debugPrint(
              '║    name            : ${_it['name'] ?? _it['item_name'] ?? 'unnamed'}',
            );
            debugPrint('║    price           : ${_it['price']} ETB');
            debugPrint('║    quantity        : ${_it['quantity']}');
            debugPrint('║    image_url       : ${_it['image_url']}');
            debugPrint(
              '║    specifications  : ${(_it['specifications'] ?? _it['specification'] is List) ? 'present (${(_it['specifications'] ?? _it['specification'] as List?)?.length ?? 0} groups)' : 'none'}',
            );
            debugPrint(
              '║    note_for_item   : ${_it['note_for_item'] ?? 'none'}',
            );
          } else {
            debugPrint('║  Item[$_i]         : $_it (non-Map)');
          }
        }
      } else {
        debugPrint(
          '║  items             : ⚠ EMPTY or not present in response!',
        );
      }
      debugPrint(
        '║──────────────────── INVOICE (pre-created) ───────────────────────',
      );
      final _dbgInvoice = data is Map
          ? (data['invoice'] ??
                data['cart']?['invoice'] ??
                data['data']?['invoice'])
          : null;
      if (_dbgInvoice is Map) {
        debugPrint('║  invoice found!    : YES');
        debugPrint('║  order_payment_id  : ${_dbgInvoice['order_payment_id']}');
        debugPrint(
          '║  order_payment_uid : ${_dbgInvoice['order_payment_unique_id']}',
        );
        debugPrint(
          '║  user_pay_payment  : ${_dbgInvoice['user_pay_payment'] ?? _dbgInvoice['total']} ETB',
        );
      } else {
        debugPrint(
          '║  invoice           : none (will auto-generate in _tryAutoCheckout)',
        );
      }
      debugPrint(
        '║──────────────────── RAW BODY ─────────────────────────────────────',
      );
      debugPrint('║  ${response.body}');
      debugPrint(
        '╚══════════════════════════════════════════════════════════════════\n',
      );

      if (response.statusCode == 404 ||
          (data is Map && data['success'] == false)) {
        debugPrint(
          '[MCP CART] Cart retrieval failed: status=${response.statusCode}, error=${data is Map ? data['error'] : 'Unknown error'}',
        );
        if (mounted) {
          setState(() {
            error =
                (data is Map ? data['error'] : null) ??
                'Cart not found or expired.';
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

      final storeId =
          (data['store_id'] ??
                  data['cart']?['store_id'] ??
                  data['data']?['store_id'])
              ?.toString() ??
          '';
      final storeName =
          (data['store_name'] ??
                  data['cart']?['store_name'] ??
                  data['data']?['store_name'])
              ?.toString() ??
          '';
      final storeLocation =
          data['store_location'] ??
          data['cart']?['store_location'] ??
          data['data']?['store_location'];

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

      final invoice =
          data['invoice'] ??
          (data['cart'] is Map ? data['cart']['invoice'] : null) ??
          (data['data'] is Map ? data['data']['invoice'] : null);

      if (rawItems.isEmpty && invoice == null) {
        debugPrint('[MCP CART] No items found in cart: $data');
        if (mounted) {
          setState(() {
            error =
                data['error']?.toString() ??
                data['message']?.toString() ??
                'Cart has no items or has expired.';
          });
        }
        return;
      }

      final items = rawItems
          .map((i) {
            if (i is! Map) return <String, dynamic>{};
            List<dynamic> specs = [];
            if (i['specifications'] != null && i['specifications'] is List) {
              specs = List.from(i['specifications']);
            } else if (i['specification'] != null &&
                i['specification'] is List) {
              specs = List.from(i['specification']);
            }

            // Auto-select one default size/specification if available
            for (var specGroup in specs) {
              if (specGroup is Map &&
                  specGroup['list'] != null &&
                  specGroup['list'] is List &&
                  specGroup['list'].isNotEmpty) {
                bool hasDefault = specGroup['list'].any(
                  (option) =>
                      option is Map && option['is_default_selected'] == true,
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
          })
          .where((element) => element.isNotEmpty)
          .toList();

      debugPrint(
        '\n╔══════════════════════════════════════════════════════════════════',
      );
      debugPrint(
        '║  [MCP CART] Items after normalization for store: "$storeName"',
      );
      debugPrint('║  store_id          : $storeId');
      debugPrint('║  storeLocation raw : $storeLocation');
      debugPrint('║  total items mapped: ${items.length}');
      for (int _mi = 0; _mi < items.length; _mi++) {
        final _m = items[_mi];
        debugPrint('║  Normalized[$_mi]');
        debugPrint('║    _id             : ${_m['_id']}');
        debugPrint('║    item_name       : ${_m['item_name']}');
        debugPrint('║    price           : ${_m['price']} ETB');
        debugPrint('║    quantity        : ${_m['quantity']}');
        debugPrint(
          '║    specifications  : ${(_m['specification'] as List?)?.length ?? 0} spec groups',
        );
        debugPrint(
          '║    image_url       : ${_m['image_url'].toString().isEmpty ? "(empty)" : _m['image_url']}',
        );
      }
      debugPrint(
        '╚══════════════════════════════════════════════════════════════════\n',
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

          debugPrint(
            '[MCP CART] User conflict dialog choice: replace=$replace',
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
      // Backend stores store_location as [lat, lng] (confirmed from pickup_addresses in log)
      storeLocationMap = {
        'lat':
            (num.tryParse(storeLocation[0]?.toString() ?? '9.010498') ??
                    9.010498)
                .toDouble(),
        'long':
            (num.tryParse(storeLocation[1]?.toString() ?? '38.761886') ??
                    38.761886)
                .toDouble(),
      };
    } else if (storeLocation is Map) {
      storeLocationMap = Map<String, dynamic>.from(storeLocation);
    } else {
      storeLocationMap = {'lat': 9.010498, 'long': 38.761886};
    }

    // Ensure destination_address is mandatory and has valid coordinates
    Map<String, dynamic> destAddress;

    // Priority 1: explicit destination / destination_address in the API response
    final rawDest =
        data?['destination'] ??
        data?['destination_address'] ??
        (data != null && data['cart'] is Map
            ? (data['cart']['destination'] ??
                data['cart']['destination_address'])
            : null);
    final rawDestLat =
        num.tryParse(
          rawDest is Map ? (rawDest['lat']?.toString() ?? '0') : '0',
        ) ??
        0.0;
    final rawDestLong =
        num.tryParse(
          rawDest is Map
              ? (rawDest['long']?.toString() ??
                  rawDest['lng']?.toString() ??
                  '0')
              : '0',
        ) ??
        0.0;
    final rawDestName =
        rawDest is Map
            ? (rawDest['address']?.toString() ??
                rawDest['name']?.toString() ??
                'Delivery Address')
            : 'Delivery Address';

    // Priority 2: destination_addresses array from the cart response
    // Format: [{"location": [lat, lng], "address": "..."}]
    // We skip entries whose coords match the store (placeholder "Store Delivery Zone")
    Map<String, dynamic>? destFromCart;
    final rawDestAddresses =
        data?['destination_addresses'] ??
        (data?['cart'] is Map ? data!['cart']['destination_addresses'] : null);
    if (rawDestAddresses is List && rawDestAddresses.isNotEmpty) {
      for (final d in rawDestAddresses) {
        if (d is! Map) continue;
        final loc = d['location'];
        double dLat = 0, dLng = 0;
        if (loc is List && loc.length >= 2) {
          // destination_addresses location is [lng, lat] (GeoJSON order) per the log
          dLng = (num.tryParse(loc[0]?.toString() ?? '0') ?? 0).toDouble();
          dLat = (num.tryParse(loc[1]?.toString() ?? '0') ?? 0).toDouble();
        } else if (loc is Map) {
          dLat = (num.tryParse(loc['lat']?.toString() ?? '0') ?? 0).toDouble();
          dLng =
              (num.tryParse(
                    loc['long']?.toString() ?? loc['lng']?.toString() ?? '0',
                  ) ??
                  0)
              .toDouble();
        }
        // Skip if coords are zero or identical to the store (placeholder)
        if (dLat == 0.0 || dLng == 0.0) continue;
        if (dLat == storeLocationMap['lat'] && dLng == storeLocationMap['long'])
          continue;
        destFromCart = {
          'name': d['address']?.toString() ?? 'Delivery Address',
          'lat': dLat,
          'long': dLng,
          'note': '',
        };
        break;
      }
    }
    debugPrint('[MCP DEST] rawDest=$rawDest | destFromCart=$destFromCart');

    if (rawDest != null && rawDest is Map && rawDestLat != 0.0) {
      // Priority 1: explicit destination field from backend
      destAddress = {
        'name': rawDestName,
        'lat': rawDestLat.toDouble(),
        'long': rawDestLong.toDouble(),
        'note': rawDest['note']?.toString() ?? '',
      };
      debugPrint('[MCP DEST] Using Priority 1: explicit destination = $destAddress');
    } else if (destFromCart != null) {
      // Priority 2: destination_addresses array from cart (non-placeholder entry)
      destAddress = destFromCart;
      debugPrint(
        '[MCP DEST] Using Priority 2: destination_addresses from cart = $destAddress',
      );
    } else {
      // Priority 3: PRIMARY FALLBACK — live phone location via FlLocation
      Map<String, dynamic>? gpsDest;
      try {
        LocationPermission perm = await FlLocation.checkLocationPermission();
        if (perm == LocationPermission.denied) {
          perm = await FlLocation.requestLocationPermission();
        }
        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          final isEnabled = await FlLocation.isLocationServicesEnabled;
          if (isEnabled) {
            final currentLoc = await FlLocation.getLocation(
              timeLimit: const Duration(seconds: 4),
            );
            if (currentLoc.latitude != 0.0 &&
                currentLoc.longitude != 0.0 &&
                currentLoc.latitude != storeLocationMap['lat']) {
              gpsDest = {
                'name': 'Current Location',
                'lat': currentLoc.latitude,
                'long': currentLoc.longitude,
                'note': '',
              };
            }
          }
        }
      } catch (e) {
        debugPrint('[MCP DEST] Live phone GPS lookup error: $e');
      }
      debugPrint('[MCP DEST] Priority 3 live phone GPS dest = $gpsDest');

      // Priority 4: user's saved addresses in the app (Service.read('delivery'))
      Map<String, dynamic>? deliveryDest;
      if (gpsDest == null) {
        try {
          final deliveryData = await Service.read('delivery');
          if (deliveryData is Map && deliveryData['list'] is List) {
            for (final a in deliveryData['list']) {
              if (a is! Map) continue;
              final aLat = num.tryParse(a['lat']?.toString() ?? '0') ?? 0.0;
              final aLng = num.tryParse(a['long']?.toString() ?? '0') ?? 0.0;
              if (aLat != 0.0 && aLng != 0.0 && aLat != storeLocationMap['lat']) {
                deliveryDest = {
                  'name': a['name']?.toString() ?? 'Saved Address',
                  'lat': aLat.toDouble(),
                  'long': aLng.toDouble(),
                  'note': a['note']?.toString() ?? '',
                };
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('[MCP DEST] Priority 4 read error: $e');
        }
        debugPrint('[MCP DEST] Priority 4 saved delivery dest = $deliveryDest');
      }

      // Priority 5: read user's delivery address from previous saved cart
      Map<String, dynamic>? cartDest;
      if (gpsDest == null && deliveryDest == null) {
        try {
          final savedCart = await Service.read('cart');
          if (savedCart is Map) {
            final cd = savedCart['destination_address'];
            if (cd is Map) {
              final cdLat = num.tryParse(cd['lat']?.toString() ?? '0') ?? 0.0;
              final cdLng = num.tryParse(cd['long']?.toString() ?? '0') ?? 0.0;
              if (cdLat != 0.0 &&
                  cdLng != 0.0 &&
                  cdLat != storeLocationMap['lat']) {
                cartDest = {
                  'name': cd['name']?.toString() ?? 'My Location',
                  'lat': cdLat.toDouble(),
                  'long': cdLng.toDouble(),
                  'note': cd['note']?.toString() ?? '',
                };
              }
            }
          }
        } catch (e) {
          debugPrint('[MCP DEST] Priority 5 read error: $e');
        }
        debugPrint('[MCP DEST] Priority 5 saved cart dest = $cartDest');
      }

      // Priority 6: saved latitude & longitude in SharedPreferences
      Map<String, dynamic>? savedCoordsDest;
      if (gpsDest == null && deliveryDest == null && cartDest == null) {
        try {
          final sLat =
              num.tryParse((await Service.read('latitude'))?.toString() ?? '0') ??
                  0.0;
          final sLng =
              num.tryParse((await Service.read('longitude'))?.toString() ?? '0') ??
                  0.0;
          if (sLat != 0.0 && sLng != 0.0 && sLat != storeLocationMap['lat']) {
            savedCoordsDest = {
              'name': 'Saved Coordinates',
              'lat': sLat.toDouble(),
              'long': sLng.toDouble(),
              'note': '',
            };
          }
        } catch (_) {}
        debugPrint('[MCP DEST] Priority 6 saved coords dest = $savedCoordsDest');
      }

      // Priority 7: app metadata default (ZMetaData - Bole: 9.004188, 38.768154)
      Map<String, dynamic>? metaDest;
      if (gpsDest == null &&
          deliveryDest == null &&
          cartDest == null &&
          savedCoordsDest == null) {
        try {
          if (mounted) {
            final meta = Provider.of<ZMetaData>(context, listen: false);
            if (meta.latitude != 0.0 &&
                meta.longitude != 0.0 &&
                meta.latitude != storeLocationMap['lat']) {
              metaDest = {
                'name': 'Bole (Default Location)',
                'lat': meta.latitude,
                'long': meta.longitude,
                'note': '',
              };
            }
          }
        } catch (_) {}
        debugPrint('[MCP DEST] Priority 7 metadata dest = $metaDest');
      }

      if (gpsDest != null) {
        destAddress = gpsDest;
        debugPrint(
          '[MCP DEST] Using Priority 3 (Live Phone Location): $destAddress',
        );
      } else if (deliveryDest != null) {
        destAddress = deliveryDest;
        debugPrint(
          '[MCP DEST] Using Priority 4 (Saved Delivery Address): $destAddress',
        );
      } else if (cartDest != null) {
        destAddress = cartDest;
        debugPrint(
          '[MCP DEST] Using Priority 5 (Saved Cart Address): $destAddress',
        );
      } else if (savedCoordsDest != null) {
        destAddress = savedCoordsDest;
        debugPrint(
          '[MCP DEST] Using Priority 6 (Saved Coordinates): $destAddress',
        );
      } else if (metaDest != null) {
        destAddress = metaDest;
        debugPrint(
          '[MCP DEST] Using Priority 7 (App Default Bole): $destAddress',
        );
      } else {
        // Priority 8: absolute fallback — default to Bole (never collapse to store coords)
        destAddress = {
          'name': 'Bole (Default Location)',
          'lat': 9.004188,
          'long': 38.768154,
          'note': '',
        };
        debugPrint(
          '[MCP DEST] ⚠ Priority 8 fallback: using Bole default coords (9.004188, 38.768154)',
        );
      }
    }

    // Sync resolved destination coordinates to app state (ZMetaData & storage)
    final finalDestLat =
        (num.tryParse(destAddress['lat']?.toString() ?? '0') ?? 0.0)
            .toDouble();
    final finalDestLng =
        (num.tryParse(destAddress['long']?.toString() ?? '0') ?? 0.0)
            .toDouble();
    if (finalDestLat != 0.0 && finalDestLng != 0.0) {
      if (mounted) {
        try {
          Provider.of<ZMetaData>(
            context,
            listen: false,
          ).setLocation(finalDestLat, finalDestLng);
        } catch (_) {}
      }
      Service.save('latitude', finalDestLat);
      Service.save('longitude', finalDestLng);
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

    final invoice =
        data?['invoice'] ??
        (data?['cart'] is Map ? data!['cart']['invoice'] : null);
    final bool canFastTrackToKifiya =
        (widget.target == 'kifiya' || invoice != null) &&
        invoice != null &&
        invoice is Map &&
        invoice['order_payment_id'] != null &&
        invoice['order_payment_unique_id'] != null;

    if (canFastTrackToKifiya) {
      final double price =
          (num.tryParse(
                    invoice['user_pay_payment']?.toString() ??
                        invoice['total']?.toString() ??
                        '0',
                  ) ??
                  0.0)
              .toDouble();
      final String paymentId = invoice['order_payment_id'].toString();
      final String uniqueId = invoice['order_payment_unique_id'].toString();
      final String vehicleId =
          (data?['default_vehicle'] is Map
                  ? data!['default_vehicle']['_id']
                  : null)
              ?.toString() ??
          data?['vehicle_id']?.toString() ??
          '';

      debugPrint(
        '[MCP CART] Pre-created invoice found. Navigating directly to KifiyaScreen (price: $price, paymentId: $paymentId, uniqueId: $uniqueId)',
      );
      _navigateToKifiya(
        price: price,
        orderPaymentId: paymentId,
        orderPaymentUniqueId: uniqueId,
        vehicleId: vehicleId,
      );
      return;
    }

    // Backend did not provide an invoice: auto-generate the order invoice from the app
    final userId = (user['user']?['_id'] ?? user['_id'] ?? '').toString();
    final serverToken =
        (user['user']?['server_token'] ?? user['server_token'] ?? '')
            .toString();

    final bool autoInvoiced = await _tryAutoCheckout(
      user: user,
      userId: userId,
      serverToken: serverToken,
      storeId: storeId,
      cartData: cartData,
      storeLocationMap: storeLocationMap,
      destAddress: destAddress,
      items: items,
    );

    if (autoInvoiced) {
      return;
    }

    debugPrint('[MCP CART] Falling back to CartScreen.');
    _replaceRoute(CartScreen.routeName);
  }

  Future<bool> _tryAutoCheckout({
    required Map user,
    required String userId,
    required String serverToken,
    required String storeId,
    required Map<String, dynamic> cartData,
    required Map<String, dynamic> storeLocationMap,
    required Map<String, dynamic> destAddress,
    required List items,
  }) async {
    try {
      if (mounted) {
        setState(() {
          statusText = 'Preparing your order invoice...';
        });
      }

      // Step 1: Sync cart to backend database (/api/user/add_item_in_cart_new)
      debugPrint(
        '\n╔══════════════════════════════════════════════════════════════════',
      );
      debugPrint('║  [MCP CART AUTO-INVOICE] Step 1: Sync Cart to Backend DB');
      debugPrint('║  POST /api/user/add_item_in_cart_new');
      debugPrint('║  user_id    : ${cartData['user_id']}');
      debugPrint('║  store_id   : ${cartData['store_id']}');
      debugPrint('║  store_name : ${cartData['store_name']}');
      debugPrint(
        '║  item_count : ${(cartData['items'] as List?)?.length ?? 0}',
      );
      debugPrint(
        '║  dest_name  : ${(cartData['destination_address'] as Map?)?['name']}',
      );
      debugPrint(
        '║  dest_lat   : ${(cartData['destination_address'] as Map?)?['lat']}',
      );
      debugPrint(
        '║  dest_lng   : ${(cartData['destination_address'] as Map?)?['long']}',
      );
      debugPrint('║  is_mcp     : ${cartData['is_mcp']}');
      debugPrint(
        '╚══════════════════════════════════════════════════════════════════\n',
      );

      final addCartUri = Uri.parse('$BASE_URL/api/user/add_item_in_cart_new');
      final addCartResponse = await http
          .post(
            addCartUri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(cartData),
          )
          .timeout(const Duration(seconds: 15));

      final addCartData = jsonDecode(addCartResponse.body);

      debugPrint(
        '\n╔══════════════════════════════════════════════════════════════════',
      );
      debugPrint(
        '║  [MCP CART AUTO-INVOICE] Step 1 RESPONSE: add_item_in_cart_new',
      );
      debugPrint('║  HTTP Status Code : ${addCartResponse.statusCode}');
      debugPrint(
        '║  Success          : ${addCartData is Map ? addCartData['success'] : 'N/A'}',
      );
      debugPrint(
        '║  cart_id returned : ${addCartData is Map ? (addCartData['cart_id'] ?? 'not in response') : 'N/A'}',
      );
      debugPrint(
        '║  Error Code       : ${addCartData is Map ? (addCartData['error_code'] ?? 'none') : 'N/A'}',
      );
      debugPrint(
        '║  Message          : ${addCartData is Map ? (addCartData['message'] ?? 'none') : 'N/A'}',
      );
      debugPrint('║  Raw Body         : ${addCartResponse.body}');
      debugPrint(
        '╚══════════════════════════════════════════════════════════════════\n',
      );

      if (addCartData is! Map || addCartData['success'] != true) {
        debugPrint(
          '[MCP CART AUTO-INVOICE] ⚠ Step 1 FAILED — cart not synced. Falling back to CartScreen.',
        );
        return false;
      }

      final newCartId = addCartData['cart_id']?.toString();
      if (newCartId != null && newCartId.isNotEmpty) {
        debugPrint(
          '[MCP CART AUTO-INVOICE] Step 1 ✓ Updating user cart_id → $newCartId',
        );
        if (user['user'] is Map) {
          user['user']['cart_id'] = newCartId;
        } else {
          user['cart_id'] = newCartId;
        }
        await Service.save('user', user);
      }

      // Step 2: Fetch available vehicles
      debugPrint(
        '\n╔═══════════════════════════════════════════════════════════',
      );
      debugPrint(
        '║  [MCP CART AUTO-INVOICE] Step 2: Fetching Delivery Vehicles',
      );
      debugPrint(
        '║  Store Coords: lat=${storeLocationMap['lat']}, lng=${storeLocationMap['long']}',
      );
      String cityId = '';
      try {
        if (mounted) {
          cityId = Provider.of<ZMetaData>(
            context,
            listen: false,
          ).cityId.toString();
        }
      } catch (_) {}

      final vehicleUri = Uri.parse('$BASE_URL/api/store/get_vehicle_list');
      final vehicleResponse = await http
          .post(
            vehicleUri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              "store_id": "",
              "type": 7,
              "delivery_type": 1,
              "user_id": userId,
              "server_token": serverToken,
              "city_id": cityId,
              "user_latitude": storeLocationMap['lat'],
              "user_longitude": storeLocationMap['long'],
            }),
          )
          .timeout(const Duration(seconds: 10));

      String vehicleId = '';
      String selectedVehicleName = '';
      bool isMotorbike = false;
      try {
        final vData = jsonDecode(vehicleResponse.body);
        if (vData is Map &&
            vData['vehicles'] is List &&
            (vData['vehicles'] as List).isNotEmpty) {
          final vList = vData['vehicles'] as List;
          debugPrint('║  Found ${vList.length} vehicles for this location:');
          for (var v in vList) {
            final vName = (v['name'] ?? '').toString();
            final vId = v['_id']?.toString() ?? '';
            debugPrint('║   - Vehicle: "$vName" (ID: $vId)');
            if (!isMotorbike &&
                (vName.toLowerCase().contains('motor') ||
                    vName.toLowerCase().contains('bike'))) {
              vehicleId = vId;
              selectedVehicleName = vName;
              isMotorbike = true;
            }
          }
          if (vehicleId.isEmpty) {
            vehicleId = vList[0]['_id'].toString();
            selectedVehicleName = (vList[0]['name'] ?? '').toString();
          }
        }
      } catch (e) {
        debugPrint('║  Vehicle parse note: $e');
      }
      debugPrint(
        '║  Selected Vehicle: "$selectedVehicleName" (ID: $vehicleId)',
      );
      debugPrint('║  Is Motorbike?     : $isMotorbike');
      debugPrint(
        '╚═══════════════════════════════════════════════════════════\n',
      );

      // Step 3: Calculate distance & time between store and delivery destination
      debugPrint(
        '\n╔═══════════════════════════════════════════════════════════',
      );
      debugPrint(
        '║  [MCP CART AUTO-INVOICE] Step 3: Distance & Time Calculation',
      );
      final storeLat =
          (num.tryParse(storeLocationMap['lat']?.toString() ?? '0') ?? 0.0)
              .toDouble();
      final storeLng =
          (num.tryParse(storeLocationMap['long']?.toString() ?? '0') ?? 0.0)
              .toDouble();
      final destLat =
          (num.tryParse(destAddress['lat']?.toString() ?? '0') ?? 0.0)
              .toDouble();
      final destLng =
          (num.tryParse(destAddress['long']?.toString() ?? '0') ?? 0.0)
              .toDouble();
      debugPrint('║  Store Coords (Origin)     : $storeLat, $storeLng');
      debugPrint('║  Delivery Coords (Dest)    : $destLat, $destLng');
      debugPrint(
        '[MCP COORDS] store=$storeLat,$storeLng  dest=$destLat,$destLng',
      );
      debugPrint('║  Destination Address Name  : "${destAddress['name']}"');

      double distance = 1000.0;
      double time = 600.0;
      bool usedGoogleDistance = false;

      if (storeLat != 0.0 &&
          storeLng != 0.0 &&
          destLat != 0.0 &&
          destLng != 0.0) {
        // Query Google Distance Matrix API
        final googleMatrix = await _fetchGoogleDistanceMatrix(
          originLat: storeLat,
          originLng: storeLng,
          destLat: destLat,
          destLng: destLng,
        );

        if (googleMatrix != null) {
          distance = googleMatrix['distance']!;
          time = googleMatrix['time']!;
          usedGoogleDistance = true;
          debugPrint('║  ✓ METHOD USED: GOOGLE DISTANCE MATRIX API');
        } else {
          debugPrint('║  ⚠ Falling back to Haversine geodesic calculation...');
          final distanceMeters =
              AddressValidationService.calculateDistanceInMeters(
                storeLat,
                storeLng,
                destLat,
                destLng,
              );
          distance = distanceMeters;
          time = (distanceMeters / 1000) * 120; // estimate ~2 min per km
          debugPrint('║  ✓ METHOD USED: HAVERSINE GEODESIC FALLBACK');
        }
      } else {
        debugPrint(
          '║  ⚠ Missing store or delivery coordinates! Using fallback defaults.',
        );
      }

      debugPrint(
        '║  FINAL DISTANCE APPLIED: ${distance.toStringAsFixed(1)} m (${(distance / 1000).toStringAsFixed(2)} km)',
      );
      debugPrint(
        '║  FINAL TIME (ETA)      : ${time.toStringAsFixed(1)} s (${(time / 60).toStringAsFixed(1)} min)',
      );
      debugPrint('║  GOOGLE MATRIX ACTIVE  : $usedGoogleDistance');
      debugPrint(
        '╚═══════════════════════════════════════════════════════════\n',
      );

      // Step 4: Request Order Invoice from /api/user/get_order_cart_invoice
      debugPrint(
        '\n╔═══════════════════════════════════════════════════════════',
      );
      debugPrint('║  [MCP CART AUTO-INVOICE] Step 4: Requesting Order Invoice');
      debugPrint('║  store_id           : $storeId');
      debugPrint('║  total_distance (m) : $distance');
      debugPrint('║  total_time (s)     : $time');
      debugPrint('║  vehicle_id         : $vehicleId');
      debugPrint('║  item_count         : ${items.length}');
      debugPrint(
        '╚═══════════════════════════════════════════════════════════\n',
      );

      if (mounted) {
        setState(() {
          statusText = 'Generating payment invoice...';
        });
      }

      final invoiceUri = Uri.parse('$BASE_URL/api/user/get_order_cart_invoice');
      final invoiceResponse = await http
          .post(
            invoiceUri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              "user_id": userId,
              "store_id": storeId,
              "total_time": time,
              "total_distance": distance,
              "order_type": 7,
              "is_user_pick_up_order": false,
              "total_item_count": items.length,
              "is_user_drop_order": true,
              "express_option": 0,
              "server_token": serverToken,
              "vehicle_id": vehicleId,
              "tip": 0,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final invoiceData = jsonDecode(invoiceResponse.body);
      debugPrint(
        '\n╔═══════════════════════════════════════════════════════════',
      );
      debugPrint('║  [MCP CART AUTO-INVOICE] Invoice API Response');
      debugPrint('║  HTTP Status Code : ${invoiceResponse.statusCode}');
      debugPrint(
        '║  Success          : ${invoiceData is Map ? invoiceData['success'] : false}',
      );
      debugPrint(
        '║  Error Code       : ${invoiceData is Map ? invoiceData['error_code'] : null}',
      );
      debugPrint(
        '║  Distance Alarm   : ${invoiceData is Map ? invoiceData['is_distance_alarm'] : null}',
      );
      debugPrint('║  Raw Body         : ${invoiceResponse.body}');
      debugPrint(
        '╚═══════════════════════════════════════════════════════════\n',
      );

      if (invoiceData is Map &&
          invoiceData['success'] == true &&
          invoiceData['order_payment'] != null &&
          invoiceData['is_distance_alarm'] != true) {
        final orderPayment = invoiceData['order_payment'];
        final double price =
            (num.tryParse(
                      orderPayment['user_pay_payment']?.toString() ??
                          orderPayment['total']?.toString() ??
                          '0',
                    ) ??
                    0.0)
                .toDouble();
        final String paymentId = orderPayment['_id']?.toString() ?? '';
        final String uniqueId = orderPayment['unique_id']?.toString() ?? '';

        if (paymentId.isNotEmpty && uniqueId.isNotEmpty) {
          debugPrint(
            '\n╔═══════════════════════════════════════════════════════════',
          );
          debugPrint('║  [MCP CART AUTO-INVOICE] SUCCESS! Ready for Payment');
          debugPrint('║  Order Payment ID : $paymentId');
          debugPrint('║  Unique ID        : $uniqueId');
          debugPrint('║  Total Price      : $price ETB');
          debugPrint('║  Selected Vehicle : $vehicleId');
          debugPrint('║  Navigating to Kifiya Payment Screen...');
          debugPrint(
            '╚═══════════════════════════════════════════════════════════\n',
          );

          _navigateToKifiya(
            price: price,
            orderPaymentId: paymentId,
            orderPaymentUniqueId: uniqueId,
            vehicleId: vehicleId,
          );
          return true;
        }
      } else {
        debugPrint(
          '[MCP CART AUTO-INVOICE] Order invoice not generated (distance alarm, store hours, or API restriction). Falling back to CartScreen.',
        );
      }
    } catch (e, st) {
      debugPrint(
        '[MCP CART AUTO-INVOICE] Exception during auto-invoice: $e\n$st',
      );
    }
    return false;
  }

  Future<Map<String, double>?> _fetchGoogleDistanceMatrix({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final apiKey = Platform.isAndroid
        ? 'AIzaSyBzMHLnXLbtLMi9rVFOR0eo5pbouBtxyjg'
        : 'AIzaSyDAgZScAJfUHxahi_n4OpuI8HrTHVlirJk';

    final url =
        'https://maps.googleapis.com/maps/api/distancematrix/json?origins=${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}&destinations=${destLat.toStringAsFixed(6)},${destLng.toStringAsFixed(6)}&key=$apiKey';

    debugPrint(
      '\n╔═══════════════════════════════════════════════════════════',
    );
    debugPrint('║  [GOOGLE DISTANCE MATRIX REQUEST]');
    debugPrint('║  Origin (Store)      : $originLat, $originLng');
    debugPrint('║  Destination (User)  : $destLat, $destLng');
    debugPrint('║  Platform            : ${Platform.operatingSystem}');
    debugPrint(
      '║  URL                 : https://maps.googleapis.com/maps/api/distancematrix/json?origins=${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}&destinations=${destLat.toStringAsFixed(6)},${destLng.toStringAsFixed(6)}&key=***',
    );
    debugPrint('╚═══════════════════════════════════════════════════════════');

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '\n╔═══════════════════════════════════════════════════════════',
      );
      debugPrint('║  [GOOGLE DISTANCE MATRIX RESPONSE]');
      debugPrint('║  HTTP Status Code : ${response.statusCode}');
      debugPrint(
        '╚═══════════════════════════════════════════════════════════',
      );
      // Print raw body as plain line so logcat does NOT truncate it
      debugPrint('[GOOGLE RAW BODY] ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status']?.toString();
        debugPrint('[GOOGLE STATUS] Overall=$status');

        if (status == 'OK' &&
            data['rows'] is List &&
            (data['rows'] as List).isNotEmpty) {
          final row = data['rows'][0];
          if (row['elements'] is List && (row['elements'] as List).isNotEmpty) {
            final element = row['elements'][0];
            final elementStatus = element['status']?.toString();
            debugPrint('[GOOGLE STATUS] Element=$elementStatus');

            if (elementStatus == 'OK') {
              final distanceMeters = (element['distance']?['value'] as num?)
                  ?.toDouble();
              final distanceText =
                  element['distance']?['text']?.toString() ?? '';
              final durationSeconds = (element['duration']?['value'] as num?)
                  ?.toDouble();
              final durationText =
                  element['duration']?['text']?.toString() ?? '';

              debugPrint(
                '[GOOGLE RESULT] distance=$distanceText ($distanceMeters m)  duration=$durationText ($durationSeconds s)',
              );
              debugPrint(
                '\n╔═══════════════════════════════════════════════════════════',
              );
              debugPrint('║  ✓ Distance Text  : $distanceText');
              debugPrint(
                '║  ✓ Distance Value : $distanceMeters meters (${((distanceMeters ?? 0) / 1000).toStringAsFixed(2)} km)',
              );
              debugPrint('║  ✓ Duration Text  : $durationText');
              debugPrint(
                '║  ✓ Duration Value : $durationSeconds seconds (${((durationSeconds ?? 0) / 60).toStringAsFixed(1)} mins)',
              );
              debugPrint(
                '╚═══════════════════════════════════════════════════════════\n',
              );

              if (distanceMeters != null && durationSeconds != null) {
                return {'distance': distanceMeters, 'time': durationSeconds};
              }
            } else {
              debugPrint(
                '[GOOGLE STATUS] ⚠ Element status not OK: $elementStatus',
              );
            }
          }
        } else {
          debugPrint('[GOOGLE STATUS] ⚠ status was not OK: $status');
        }
      } else {
        debugPrint('[GOOGLE STATUS] ⚠ HTTP error: ${response.statusCode}');
      }
      debugPrint(
        '[GOOGLE STATUS] ⚠ Did not return valid result → falling back to Haversine',
      );
    } catch (e) {
      debugPrint(
        '\n╔═══════════════════════════════════════════════════════════',
      );
      debugPrint('║  [GOOGLE DISTANCE MATRIX ERROR]: $e');
      debugPrint(
        '╚═══════════════════════════════════════════════════════════\n',
      );
    }
    return null;
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
      final isExpired =
          error!.toLowerCase().contains('expire') ||
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
