import 'dart:convert';

/// Converts a raw /chat_test response into the structured JSON contract the
/// chat UI renders (the same shape the mock data uses):
///
///   { "message": "...", "browse_results": { "type": "items", "store_name": "...", "results": [ { "item_id", "name", "price" } ] } }
///   { "message": "...", "stores": [ { "name": "...", "distance": "1.2 km" } ] }
///   { "message": "..." }
///
/// The backend model often replies with markdown text (bullet menus, store
/// lists, or JSON wrapped in ```json fences) instead of real JSON. This
/// normalizer extracts that data so products and stores render as cards.
Map<String, dynamic> normalizeChatResponse(Map<String, dynamic> raw) {
  final result = Map<String, dynamic>.from(raw);

  String text = '';
  for (final key in const ['message', 'response', 'reply', 'answer', 'text']) {
    final value = raw[key];
    if (value is Map) {
      // Structured payload nested inside the reply field
      _mergeStructured(result, Map<String, dynamic>.from(value));
      text = result['message']?.toString() ?? '';
      break;
    }
    if (value != null && value.toString().trim().isNotEmpty) {
      text = value.toString();
      break;
    }
  }

  // JSON embedded in the reply text (raw or inside a ```json fence)
  final embedded = _extractEmbeddedJson(text);
  if (embedded != null) {
    _mergeStructured(result, embedded);
    text = embedded['message']?.toString() ?? _stripJsonBlock(text);
  }

  if (!_hasStructuredData(result) && text.isNotEmpty) {
    final items = _parseMarkdownItems(text);
    if (items.isNotEmpty) {
      final storeName = _parseMenuStoreName(text);
      if (storeName != null) {
        result['browse_results'] = {
          'type': 'items',
          'store_name': storeName,
          'results': items,
        };
      } else {
        result['items'] = items;
      }
      text = _introText(text) ?? '';
    } else {
      final stores = _parseMarkdownStores(text);
      if (stores.isNotEmpty) {
        result['stores'] = stores;
        text = _introText(text) ?? '';
      }
    }
  }

  result['message'] = text.trim();
  return result;
}

bool _hasStructuredData(Map<String, dynamic> r) {
  final browse = r['browse_results'];
  if (browse is Map &&
      browse['results'] is List &&
      (browse['results'] as List).isNotEmpty) {
    return true;
  }
  for (final key in const [
    'products',
    'items',
    'menu',
    'stores',
    'companies',
  ]) {
    final v = r[key];
    if (v is List && v.isNotEmpty) return true;
  }
  return false;
}

void _mergeStructured(
  Map<String, dynamic> target,
  Map<String, dynamic> source,
) {
  for (final key in const [
    'message',
    'browse_results',
    'products',
    'items',
    'menu',
    'stores',
    'companies',
  ]) {
    if (source[key] != null) target[key] = source[key];
  }
}

final _fenceRe = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);

Map<String, dynamic>? _extractEmbeddedJson(String text) {
  final candidates = <String>[
    for (final m in _fenceRe.allMatches(text)) m.group(1)!.trim(),
  ];
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start)
    candidates.add(text.substring(start, end + 1));

  for (final c in candidates) {
    try {
      final decoded = json.decode(c);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

String _stripJsonBlock(String text) => text.replaceAll(_fenceRe, '').trim();

final _listMarkerRe = RegExp(r'^\s*(?:[*\-•]|\d+[.)])\s+');
final _priceRe = RegExp(
  r'(?:(?:ETB|Birr|Br)\.?\s*([\d,]+(?:\.\d+)?))|(?:([\d,]+(?:\.\d+)?)\s*(?:ETB|Birr|Br)\b)',
  caseSensitive: false,
);
final _kmRe = RegExp(r'([\d.]+)\s*km\b', caseSensitive: false);

String _cleanInline(String s) =>
    s.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '').trim();

String _trimSeparators(String s) => s
    .replaceAll(RegExp(r'^[\s\-–—:|(]+'), '')
    .replaceAll(RegExp(r'[\s\-–—:|(,]+$'), '')
    .replaceAll(
      RegExp(r'\s*[-–—:]?\s*(?:price|distance)\s*$', caseSensitive: false),
      '',
    )
    .trim();

/// Parses menu lines such as `* **Burger** - 250 ETB`, `1. Pizza — ETB 320`
/// or table rows `| Burger | 250 ETB |` into browse_results items.
List<Map<String, dynamic>> _parseMarkdownItems(String text) {
  final items = <Map<String, dynamic>>[];

  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    String name = '';
    double price = 0;

    if (trimmed.startsWith('|')) {
      final cells = trimmed
          .split('|')
          .map(_cleanInline)
          .where((c) => c.isNotEmpty)
          .toList();
      if (cells.isEmpty ||
          cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c))) {
        continue;
      }
      for (final cell in cells) {
        final m =
            _priceRe.firstMatch(cell) ??
            RegExp(r'^([\d,]+(?:\.\d+)?)$').firstMatch(cell);
        if (m != null && price == 0) {
          price = _toPrice(m);
        } else if (name.isEmpty && !RegExp(r'^\d').hasMatch(cell)) {
          name = cell;
        }
      }
    } else if (_listMarkerRe.hasMatch(trimmed)) {
      final content = _cleanInline(trimmed.replaceFirst(_listMarkerRe, ''));
      final m = _priceRe.firstMatch(content);
      if (m == null) continue;
      price = _toPrice(m);
      name = _trimSeparators(content.substring(0, m.start));
    } else {
      continue;
    }

    if (name.isEmpty || price <= 0) continue;
    items.add({
      'item_id': 'backend_${name.hashCode}',
      'name': name,
      'price': price,
    });
  }

  return items;
}

double _toPrice(RegExpMatch m) {
  final raw =
      (m.groupCount >= 2 ? (m.group(1) ?? m.group(2)) : m.group(1)) ?? '0';
  return double.tryParse(raw.replaceAll(',', '')) ?? 0;
}

/// Finds the store a markdown menu belongs to, e.g. `### SAVOR Menu`,
/// `**Menu for SAVOR**` or `Here's the menu for SAVOR:`.
String? _parseMenuStoreName(String text) {
  final forRe = RegExp(
    r'menu\s+(?:for|at|from|of)\s+\**([^:\n*!.]+)',
    caseSensitive: false,
  );
  final m = forRe.firstMatch(text);
  if (m != null) {
    final name = _trimSeparators(_cleanInline(m.group(1)!));
    if (name.isNotEmpty) return name;
  }

  for (final line in text.split('\n')) {
    final t = line.trim();
    String? heading;
    final h = RegExp(r'^#{1,6}\s*(.+)$').firstMatch(t);
    if (h != null) heading = h.group(1);
    final b = RegExp(r'^\*\*(.+?)\*\*:?$').firstMatch(t);
    if (heading == null && b != null) heading = b.group(1);
    if (heading == null) continue;

    final name = _trimSeparators(
      _cleanInline(
        heading,
      ).replaceAll(RegExp(r"\b(?:'s)?\s*menu\b", caseSensitive: false), ''),
    );
    if (name.isNotEmpty) return name;
  }
  return null;
}

/// Parses store lines such as `1. **Pizza Hut** - Distance: 1.8 km` or
/// `* SAVOR (0.6 km)` into stores entries.
List<Map<String, dynamic>> _parseMarkdownStores(String text) {
  final stores = <Map<String, dynamic>>[];

  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (!_listMarkerRe.hasMatch(trimmed)) continue;
    final content = _cleanInline(trimmed.replaceFirst(_listMarkerRe, ''));
    final m = _kmRe.firstMatch(content);
    if (m == null) continue;

    final name = _trimSeparators(content.substring(0, m.start));
    if (name.isEmpty) continue;
    stores.add({'name': name, 'distance': '${m.group(1)} km'});
  }

  return stores;
}

/// The plain-prose part of a markdown reply (headings, lists and tables
/// removed), used as the bubble text above the cards.
String? _introText(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where(
        (l) =>
            l.isNotEmpty &&
            !l.startsWith('#') &&
            !l.startsWith('|') &&
            !_listMarkerRe.hasMatch(l) &&
            !RegExp(r'^\*\*.+\*\*:?$').hasMatch(l),
      )
      .toList();
  if (lines.isEmpty) return null;
  return lines.join('\n');
}
