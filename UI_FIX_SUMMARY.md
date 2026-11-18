# UI Issue Fix Report

## 1. Problem Summary
When tapping on a combo order in active orders, Flutter crashed with:
```text
════════ Exception caught by rendering library ═════════════════════════════════
RenderBox was not laid out: _RenderListTile#5ca86 relayoutBoundary=up23 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'
The relevant error-causing widget was:
    ListTile ListTile:file:///Users/apple/Desktop/etta/main_app/zmall_app/lib/orders/components/body.dart:143:28
════════════════════════════════════════════════════════════════════════════════
```

## 2. Root Cause
- In `_showComboOrderPicker()`, the `ListTile`'s `leading` widget was an unconstrained `ImageContainer(url: "${meta.baseUrl}/$img")`.
- `ImageContainer` internally renders a `CachedNetworkImage` whose placeholder is `Center(child: Container(...))`.
- Inside `ListTile`, the leading icon constraints allow `maxWidth` up to the full width of the tile (`tileWidth`).
- Because `Center` has no tight width constraints, it expanded to fill the entire tile width horizontally (`leadingSize.width == tileWidth`).
- Flutter's `_RenderListTile` asserts that `leading` must not consume the entire tile width, and computes negative available text width:
  `tighten(width: tileWidth - titleStart - trailingWidth)`
- This threw an exception midway through `_RenderListTile.performLayout()`.
- Because layout aborted prematurely, `_RenderListTile` never had `_size` assigned (`hasSize == false`).
- During the subsequent paint phase, accessing `size` triggered cascading `hasSize` assertion failures across `Card`, `Column`, `Padding`, `SafeArea`, and `MaterialApp`.

## 3. What Was Changed
1. **Bounded Sizing**: Wrapped the leading store image in an explicit `SizedBox(width: 48, height: 48)` so it strictly adheres to `ListTile`'s icon constraints and never expands.
2. **Clean Image Loading**: Used `CachedNetworkImage` directly inside `ClipRRect(borderRadius: BorderRadius.circular(8))` with a compact 20x20 spinner and `HeroiconsOutline.buildingStorefront` error fallback.
3. **Text Overflow Prevention**: Added `maxLines: 1` and `overflow: TextOverflow.ellipsis` to the store name title.
4. **Consistency**: Applied the exact same fix to `orders_history.dart` to prevent identical crashes in past orders history.

---

## 4. Git Diff

### `lib/orders/components/body.dart`

```diff
diff --git a/lib/orders/components/body.dart b/lib/orders/components/body.dart
index 04799a3..57f3bb2 100644
--- a/lib/orders/components/body.dart
+++ b/lib/orders/components/body.dart
@@ -1,5 +1,6 @@
 import 'dart:async';
 import 'dart:convert';
+import 'package:cached_network_image/cached_network_image.dart';
 import 'package:heroicons_flutter/heroicons_flutter.dart';
 import 'package:http/http.dart' as http;
 import 'package:flutter/material.dart';
@@ -141,11 +142,45 @@ class _BodyState extends State<Body> {
                     color: kWhiteColor,
                     margin: EdgeInsets.only(bottom: 8),
                     child: ListTile(
-                      leading: img.toString().isNotEmpty
-                          ? ImageContainer(url: "${meta.baseUrl}/$img")
-                          : Icon(HeroiconsOutline.buildingStorefront),
+                      leading: SizedBox(
+                        width: 48,
+                        height: 48,
+                        child: ClipRRect(
+                          borderRadius: BorderRadius.circular(8),
+                          child: img.toString().isNotEmpty
+                              ? CachedNetworkImage(
+                                  imageUrl: img.toString().startsWith("http")
+                                      ? img.toString()
+                                      : "${meta.baseUrl}/$img",
+                                  fit: BoxFit.cover,
+                                  placeholder: (context, url) => Container(
+                                    color: kWhiteColor,
+                                    child: Center(
+                                      child: SizedBox(
+                                        width: 20,
+                                        height: 20,
+                                        child: CircularProgressIndicator(
+                                          strokeWidth: 2,
+                                          valueColor: AlwaysStoppedAnimation<Color>(kGreyColor),
+                                        ),
+                                      ),
+                                    ),
+                                  ),
+                                  errorWidget: (context, url, error) => Container(
+                                    color: kWhiteColor,
+                                    child: Icon(HeroiconsOutline.buildingStorefront, color: kGreyColor),
+                                  ),
+                                )
+                              : Container(
+                                  color: kWhiteColor,
+                                  child: Icon(HeroiconsOutline.buildingStorefront, color: kGreyColor),
+                                ),
+                        ),
+                      ),
                       title: Text(
                         Service.capitalizeFirstLetters(name.toString()),
+                        maxLines: 1,
+                        overflow: TextOverflow.ellipsis,
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           color: kBlackColor,
```

---

### `lib/orders/components/orders_history.dart`

```diff
diff --git a/lib/orders/components/orders_history.dart b/lib/orders/components/orders_history.dart
index 80ee14d..561816e 100644
--- a/lib/orders/components/orders_history.dart
+++ b/lib/orders/components/orders_history.dart
@@ -1,5 +1,6 @@
 import 'dart:async';
 import 'dart:convert';
+import 'package:cached_network_image/cached_network_image.dart';
 import 'package:heroicons_flutter/heroicons_flutter.dart';
 import 'package:http/http.dart' as http;
 import 'package:flutter/material.dart';
@@ -141,11 +142,45 @@ class _OrderHistoryState extends State<OrderHistory> {
                     color: kWhiteColor,
                     margin: EdgeInsets.only(bottom: 8),
                     child: ListTile(
-                      leading: img.toString().isNotEmpty
-                          ? ImageContainer(url: "${meta.baseUrl}/$img")
-                          : Icon(HeroiconsOutline.buildingStorefront),
+                      leading: SizedBox(
+                        width: 48,
+                        height: 48,
+                        child: ClipRRect(
+                          borderRadius: BorderRadius.circular(8),
+                          child: img.toString().isNotEmpty
+                              ? CachedNetworkImage(
+                                  imageUrl: img.toString().startsWith("http")
+                                      ? img.toString()
+                                      : "${meta.baseUrl}/$img",
+                                  fit: BoxFit.cover,
+                                  placeholder: (context, url) => Container(
+                                    color: kWhiteColor,
+                                    child: Center(
+                                      child: SizedBox(
+                                        width: 20,
+                                        height: 20,
+                                        child: CircularProgressIndicator(
+                                          strokeWidth: 2,
+                                          valueColor: AlwaysStoppedAnimation<Color>(kGreyColor),
+                                        ),
+                                      ),
+                                    ),
+                                  ),
+                                  errorWidget: (context, url, error) => Container(
+                                    color: kWhiteColor,
+                                    child: Icon(HeroiconsOutline.buildingStorefront, color: kGreyColor),
+                                  ),
+                                )
+                              : Container(
+                                  color: kWhiteColor,
+                                  child: Icon(HeroiconsOutline.buildingStorefront, color: kGreyColor),
+                                ),
+                        ),
+                      ),
                       title: Text(
                         Service.capitalizeFirstLetters(name.toString()),
+                        maxLines: 1,
+                        overflow: TextOverflow.ellipsis,
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           color: kBlackColor,
