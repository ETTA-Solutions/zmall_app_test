import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zmall/services/app_update_service.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/item/item_screen.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/notifications/notification_store.dart';
import 'package:zmall/services/service.dart';
import 'package:http/http.dart' as http;
import 'package:zmall/utils/constants.dart';
import 'skip_button.dart';

class SplashContainer extends StatefulWidget {
  const SplashContainer({
    super.key,
    required this.urlLink,
    required this.adId,
    required this.imageUrl,
    required this.logged,
  });

  final String urlLink, adId, imageUrl;
  final bool logged;

  @override
  State<SplashContainer> createState() => _SplashContainerState();
}

class _SplashContainerState extends State<SplashContainer> {
  // bool _loading = false;
  // bool _isClosed = false;
  var notificationItem;

  ({String type, String id})? _extractTarget(String link) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;

    final direct = RegExp(
      r'^(store|item)/([^/?#]+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (direct != null) {
      return (type: direct.group(1)!.toLowerCase(), id: direct.group(2)!);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        final first = segments[0].toLowerCase();
        if (first == 'store' || first == 'item') {
          return (type: first, id: segments[1]);
        }
      }

      final qStore =
          uri.queryParameters['store_id'] ?? uri.queryParameters['storeId'];
      if (qStore != null && qStore.isNotEmpty) {
        return (type: 'store', id: qStore);
      }

      final qItem =
          uri.queryParameters['item_id'] ?? uri.queryParameters['itemId'];
      if (qItem != null && qItem.isNotEmpty) {
        return (type: 'item', id: qItem);
      }
    }

    final storeInPath = RegExp(
      r'(^|/)store/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (storeInPath != null && storeInPath.groupCount >= 2) {
      return (type: 'store', id: storeInPath.group(2)!);
    }

    final itemInPath = RegExp(
      r'(^|/)item/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (itemInPath != null && itemInPath.groupCount >= 2) {
      return (type: 'item', id: itemInPath.group(2)!);
    }

    return null;
  }

  void _getItemInformation(String itemId) async {
    // setState(() {
    //   _loading = true;
    // });
    // Ensure app metadata is loaded before checking store status
    _getAppKeys();
    await getItemInformation(itemId);
    if (notificationItem != null && notificationItem['success']) {
      bool isOpen = await Service.isStoreOpen(notificationItem['item']);
      if (isOpen) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              return ItemScreen(
                item: notificationItem['item'],
                location: notificationItem['item']['store_location'],
                isSplashRedirect: true,
              );
            },
          ),
        );
      } else {
        if (mounted) {
          Service.showMessage(
            context: context,
            title:
                "Store is currently closed. We highly recommend you to try other store. We've got them all...",
            error: false,
            duration: 3,
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${errorCodes['${notificationItem['error_code']}']}"),
        ),
      );
    }
  }

  void _getAppKeys() async {
    await AppUpdateService.fetchAndCheck(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // debugPrint("=== SPLASH AD TAP ===");
        // debugPrint("urlLink: ${widget.urlLink}");
        // debugPrint("adId: ${widget.adId}");
        CoreServices.saveAdClick(widget.adId, context);
        final target = _extractTarget(widget.urlLink);

        if (target != null && target.type == 'item') {
          _getItemInformation(target.id);
        } else if (target != null && target.type == 'store') {
          // Redirect to notification store
          // debugPrint("Redirect to notification store");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                return NotificationStore(storeId: target.id);
              },
            ),
          );
        } else {
          final url = widget.urlLink.trim();
          if (url.isNotEmpty) {
            Service.launchInWebViewOrVC(url);
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: kSecondaryColor,
              child: Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              ),
            ),
            errorWidget: (context, url, error) {
              debugPrint("###[SPLASH] Image load error: $error, url: $url");
              return Container(
                color: kSecondaryColor,
                child: Center(
                  child: Image.asset('images/zmall.jpg', fit: BoxFit.contain),
                ),
              );
            },
          ),
          SafeArea(child: SkipButton(logged: widget.logged)),
        ],
      ),
    );
  }

  Future<dynamic> getItemInformation(itemId) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/admin/get_item_information";
    Map data = {"item_id": itemId};
    var body = json.encode(data);

    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () {
              setState(() {});

              Service.showMessage(
                context: context,
                title: "Something went wrong!",
                error: true,
                duration: 3,
              );
              throw TimeoutException("The connection has timed out!");
            },
          );
      setState(() {
        this.notificationItem = json.decode(response.body);
      });

      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);

      return null;
    } finally {
      // setState(() {
      //   this._loading = false;
      // });
    }
  }
}
