import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';

// ---------------------------------------------------------------------------
// OrderEntry (§13.1)
// ---------------------------------------------------------------------------
// Represents an entry in the orders list or order history.
// Can be either a single-store order or a grouped two-store combo order.
// ---------------------------------------------------------------------------

class OrderEntry {
  final bool isCombo;
  final String? comboId;
  final Map<String, dynamic>? singleOrder;
  final List<Map<String, dynamic>> comboOrders;

  OrderEntry._({
    required this.isCombo,
    this.comboId,
    this.singleOrder,
    this.comboOrders = const [],
  });

  factory OrderEntry.single(Map<String, dynamic> order) {
    return OrderEntry._(
      isCombo: false,
      singleOrder: order,
    );
  }

  factory OrderEntry.combo(String comboId, List<Map<String, dynamic>> orders) {
    return OrderEntry._(
      isCombo: true,
      comboId: comboId,
      comboOrders: orders,
    );
  }

  /// All child orders in this entry
  List<Map<String, dynamic>> get allOrders =>
      isCombo ? comboOrders : (singleOrder != null ? [singleOrder!] : []);

  /// Order creation timestamp used for sorting descending
  DateTime get createdAt {
    if (allOrders.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final raw = allOrders.first['created_at']?.toString();
    if (raw == null || raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Formatted date for active orders (MM/DD HH:MM:SS)
  String get formattedDate {
    if (allOrders.isEmpty) return "";
    final raw = allOrders.first['created_at']?.toString() ?? "";
    if (!raw.contains('T')) return raw;
    try {
      final parts = raw.split('T');
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split('.')[0].split(':');
      final hour = (int.tryParse(timeParts[0]) ?? 0) + 3; // UTC+3
      return "${dateParts[1]}/${dateParts[2]} $hour:${timeParts[1]}:${timeParts[2]}";
    } catch (_) {
      return raw;
    }
  }

  /// Formatted date for order history (DD/MM/YYYY HH:MM:SS)
  String get formattedHistoryDate {
    if (allOrders.isEmpty) return "";
    final raw = allOrders.first['created_at']?.toString() ?? "";
    if (!raw.contains('T')) return raw;
    try {
      final parts = raw.split('T');
      final dateParts = parts[0].split('-');
      final time = parts[1].split('.')[0];
      return "${dateParts[2]}/${dateParts[1]}/${dateParts[0]} $time";
    } catch (_) {
      return raw;
    }
  }

  /// Combined total price across all child orders.
  /// Handles both active orders (`total_order_price`) and history (`total`).
  double get totalPrice {
    double sum = 0.0;
    for (final o in allOrders) {
      final p = o['total_order_price'] ?? o['total'] ?? 0;
      if (p is num) {
        sum += p.toDouble();
      }
    }
    return sum;
  }

  /// List of store names
  List<String> get storeNames {
    return allOrders.map((o) {
      final name = o['store_name'] ?? o['store_detail']?['name'] ?? "";
      return name.toString();
    }).where((n) => n.isNotEmpty).toList();
  }

  /// Combined store name title: "Burger House + Fresh Mart"
  String get combinedStoreName {
    final names = storeNames;
    if (names.isEmpty) return "Store";
    return names.join(' + ');
  }

  /// List of store image URLs
  List<String> get storeImages {
    return allOrders.map((o) {
      final img = o['store_image'] ?? o['store_detail']?['image_url'] ?? "";
      return img.toString();
    }).where((i) => i.isNotEmpty).toList();
  }

  /// List of unique IDs
  List<String> get uniqueIds {
    return allOrders.map((o) {
      return (o['unique_id'] ?? "").toString();
    }).where((id) => id.isNotEmpty).toList();
  }

  /// Display string for order unique IDs: "Order No. #470721, #470722"
  String get orderNumbersLabel {
    final ids = uniqueIds;
    if (ids.isEmpty) return "";
    return "Order No. #${ids.join(', #')}";
  }
}

// ---------------------------------------------------------------------------
// groupOrders (§13.1)
// ---------------------------------------------------------------------------
// Groups a flat list of orders into OrderEntry objects.
// Looks for combo_id in:
// 1. order['combo_id']
// 2. order['order_payment_detail']?['combo_id']
// 3. Local stored 'combo_orders' {combo_id, order_ids}
// ---------------------------------------------------------------------------

List<OrderEntry> groupOrders(List rawOrders, dynamic localCombos) {
  final comboOfOrder = <String, String>{};
  if (localCombos != null && localCombos is List) {
    for (final c in localCombos) {
      if (c is Map) {
        final cId = c['combo_id']?.toString() ?? "";
        final orderIds = c['order_ids'];
        if (cId.isNotEmpty && orderIds is List) {
          for (final id in orderIds) {
            if (id != null) {
              comboOfOrder[id.toString()] = cId;
            }
          }
        }
      }
    }
  }

  final byCombo = <String, List<Map<String, dynamic>>>{};
  final out = <OrderEntry>[];

  for (final raw in rawOrders) {
    if (raw is! Map) continue;
    final o = raw.cast<String, dynamic>();
    final id = o['combo_id'] ??
        o['order_payment_detail']?['combo_id'] ??
        comboOfOrder[o['_id']?.toString()];

    if (id == null || id.toString().isEmpty) {
      out.add(OrderEntry.single(o));
      continue;
    }

    final comboIdStr = id.toString();
    (byCombo[comboIdStr] ??= []).add(o);
  }

  byCombo.forEach((id, list) {
    out.add(OrderEntry.combo(id, list));
  });

  out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return out;
}

// ---------------------------------------------------------------------------
// Derived combo status (§13.3)
// ---------------------------------------------------------------------------

class ComboStatusInfo {
  final String label;
  final Color color;

  const ComboStatusInfo(this.label, this.color);
}

ComboStatusInfo getComboStatus(List<Map<String, dynamic>> orders) {
  if (orders.isEmpty) {
    return const ComboStatusInfo("", Colors.grey);
  }

  if (orders.length == 1) {
    final o = orders.first;
    final oStatus = (o['order_status'] as num?)?.toInt() ?? 0;
    final dStatus = (o['delivery_status'] as num?)?.toInt();
    // Odoo/POS stores: no driver, always order_status.
    final isOdoo = isOdooStoreByName(o['store_name']?.toString());
    if (!isOdoo && oStatus == 7 && dStatus != null) {
      return ComboStatusInfo(
        order_status['$dStatus'] ?? "Waiting to accept order",
        dStatus == 25 ? Colors.green : const Color(0xFFFF8A00),
      );
    }
    return ComboStatusInfo(
      order_status['$oStatus'] ?? "Status $oStatus",
      oStatus == 25
          ? Colors.green
          : (oStatus >= 100 ? Colors.red : const Color(0xFFFF8A00)),
    );
  }

  // Both >= 100: Cancelled
  final bool allFailed = orders.every((o) {
    final s = (o['order_status'] as num?)?.toInt() ?? 0;
    return s >= 100;
  });
  if (allFailed) {
    return const ComboStatusInfo("Cancelled", Colors.red);
  }

  // One >= 100, the other active
  final failedOrders = orders.where((o) {
    final s = (o['order_status'] as num?)?.toInt() ?? 0;
    return s >= 100;
  }).toList();
  final activeOrders = orders.where((o) {
    final s = (o['order_status'] as num?)?.toInt() ?? 0;
    return s < 100;
  }).toList();

  if (failedOrders.isNotEmpty && activeOrders.isNotEmpty) {
    final failedName = failedOrders.first['store_name'] ??
        failedOrders.first['store_detail']?['name'] ??
        "Store";
    final activeName = activeOrders.first['store_name'] ??
        activeOrders.first['store_detail']?['name'] ??
        "Other";
    return ComboStatusInfo(
      "$failedName cancelled · $activeName in progress",
      const Color(0xFFFF8A00),
    );
  }

  // Both 25: Completed
  final bool allCompleted = orders.every((o) {
    final s = (o['order_status'] as num?)?.toInt() ?? 0;
    return s == 25;
  });
  if (allCompleted) {
    return const ComboStatusInfo("Completed", Colors.green);
  }

  // Once a driver is assigned (delivery_status >= 9 or provider assigned)
  final orderWithProvider = orders.firstWhere(
    (o) {
      final ds = (o['delivery_status'] as num?)?.toInt() ?? 0;
      return ds >= 9 || o['provider_id'] != null;
    },
    orElse: () => {},
  );

  if (orderWithProvider.isNotEmpty) {
    final dStatus = (orderWithProvider['delivery_status'] as num?)?.toInt() ?? 9;
    return ComboStatusInfo(
      order_status['$dStatus'] ?? "Delivery in progress",
      dStatus == 25 ? Colors.green : const Color(0xFFFF8A00),
    );
  }

  // Store-side steps (1–7): Status of the less advanced child
  int minStatus = 999;
  Map<String, dynamic> minOrder = orders.first;
  for (final o in orders) {
    final s = (o['order_status'] as num?)?.toInt() ?? 0;
    if (s < minStatus) {
      minStatus = s;
      minOrder = o;
    }
  }

  final minStoreName = minOrder['store_name'] ??
      minOrder['store_detail']?['name'] ??
      "Store";
  if (minStatus == 1) {
    return ComboStatusInfo(
      "Waiting for $minStoreName to accept",
      const Color(0xFFFF8A00),
    );
  } else if (minStatus == 3) {
    return ComboStatusInfo(
      "Waiting for $minStoreName to prepare order",
      const Color(0xFFFF8A00),
    );
  } else if (minStatus == 5 || minStatus == 7) {
    return ComboStatusInfo(
      "$minStoreName preparing order",
      const Color(0xFFFF8A00),
    );
  }

  final text = order_status['$minStatus'] ?? "Order in progress";
  return ComboStatusInfo(text, const Color(0xFFFF8A00));
}
