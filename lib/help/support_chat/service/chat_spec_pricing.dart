import 'package:flutter/foundation.dart';
import 'package:zmall/help/support_chat/service/chat_checkout_service.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/models/cart.dart';

/// The options a chat order uses for an item whose price lives in its
/// specifications (base price 0, e.g. Size: Small 150 / Large 220).
///
/// Chat has no option picker, so it follows the store screen's rule
/// (`Service.getPrice`): the default-selected options, else the first option.
/// The same selection is used to show the price and to check out, so the
/// amount shown in chat is the amount charged.
class ChatSpecSelection {
  final List<Specification> specs;
  final double unitPrice;

  /// e.g. "Size: Small · Extra: Cheese" — shown under the item name.
  final String note;

  const ChatSpecSelection({
    required this.specs,
    required this.unitPrice,
    required this.note,
  });

  /// Builds the selection from a `get_item_information` item record, or null
  /// when no option gives the item a price.
  static ChatSpecSelection? fromItemInfo(Map info) {
    final rawSpecs = [
      for (final s in (info['specifications'] as List? ?? const []))
        if (s is Map && (s['list'] as List? ?? const []).isNotEmpty) s,
    ];

    final specs = <Specification>[];
    final labels = <String>[];
    var optionsPrice = 0.0;

    void choose(Map spec, List<Map> options) {
      specs.add(
        Specification(
          uniqueId: spec['unique_id'],
          list: [
            for (final o in options)
              ListElement(uniqueId: o['unique_id'], price: _price(o['price'])),
          ],
        ),
      );
      optionsPrice += options.fold(0.0, (sum, o) => sum + _price(o['price']));
      final names = options
          .map((o) => _text(o['name']))
          .where((n) => n.isNotEmpty);
      if (names.isNotEmpty) {
        final specName = _text(spec['name']);
        labels.add(
          specName.isEmpty
              ? names.join(', ')
              : '$specName: ${names.join(', ')}',
        );
      }
    }

    for (final spec in rawSpecs) {
      final options = [
        for (final o in spec['list'] as List)
          if (o is Map) o,
      ];
      final defaults = [
        for (final o in options)
          if (o['is_default_selected'] == true) o,
      ];
      if (defaults.isNotEmpty) {
        choose(spec, defaults);
      } else if (spec['is_required'] == true && options.isNotEmpty) {
        choose(spec, [options.first]);
      }
    }

    // Nothing priced yet: like Service.getPrice, fall back to the first
    // option of the first specification.
    if (optionsPrice <= 0 && rawSpecs.isNotEmpty) {
      final first = rawSpecs.first;
      final alreadyChosen = specs.any((s) => s.uniqueId == first['unique_id']);
      final firstOption = (first['list'] as List).first;
      if (!alreadyChosen && firstOption is Map) choose(first, [firstOption]);
    }

    final unitPrice = _price(info['price']) + optionsPrice;
    if (unitPrice <= 0) return null;
    return ChatSpecSelection(
      specs: specs,
      unitPrice: unitPrice,
      note: labels.join(' · '),
    );
  }

  static double _price(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  /// Option and spec names come back as a string or a list of translations.
  static String _text(dynamic v) {
    if (v is List) return v.isEmpty ? '' : v.first.toString().trim();
    return v?.toString().trim() ?? '';
  }
}

/// Prices the chat products the backend sent with price 0 (see
/// [MockProduct.priceFromSpecs]). Other products are returned untouched.
class ChatSpecPricing {
  static Future<List<MockProduct>> resolve(
    String baseUrl,
    List<MockProduct> products,
  ) async {
    if (!products.any((p) => p.priceFromSpecs)) return products;

    final priced = await Future.wait(
      products.map((p) async {
        if (!p.priceFromSpecs) return p;
        final info = await ChatCheckoutService.fetchItemInfo(baseUrl, p.id);
        final selection = info == null
            ? null
            : ChatSpecSelection.fromItemInfo(info);
        if (selection == null) {
          debugPrint(
            "⚠️ [CHAT SPEC PRICE] ${p.name}: no price found in specifications — hidden",
          );
          return null;
        }
        debugPrint(
          "✅ [CHAT SPEC PRICE] ${p.name}: ${selection.unitPrice} ETB (${selection.note})",
        );
        return p.withSpecPrice(
          price: selection.unitPrice,
          optionsNote: selection.note,
        );
      }),
    );
    return priced.whereType<MockProduct>().toList();
  }
}
