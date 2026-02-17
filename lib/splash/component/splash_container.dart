import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
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

  String promptMessage = "";

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
    // debugPrint("in _getAppKeys=====");
    var data = await CoreServices.appKeys(context);
    if (data != null && data['success']) {
      if (mounted)
        setState(() {
          Service.saveBool("is_closed", data['message_flag']);
          Service.save("closed_message", data['message']);
          Service.save("ios_app_version", data['ios_user_app_version_code']);
          Service.saveBool(
            "ios_update_dialog",
            data['is_ios_user_app_open_update_dialog'],
          );
          Service.saveBool(
            "ios_force_update",
            data['is_ios_user_app_force_update'],
          );
          Service.save('app_close', data['app_close']);
          Service.save('app_open', data['app_open']);
        });
      if (data['message_flag']) {
        showSimpleNotification(
          Text("⚠️ NOTICE ⚠️", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("${data['message']}\n"),
          background: kBlackColor,
          duration: Duration(seconds: 7),
          elevation: 2.0,
          autoDismiss: false,
          // slideDismiss: true,
          slideDismissDirection: DismissDirection.up,
        );
      }
    } else {
      getAppKeys();
    }
  }

  void getAppKeys() async {
    var data = await Service.read('ios_app_version');
    var currentVersion = await Service.read('version');
    // _isClosed = await Service.readBool('is_closed');
    promptMessage = await Service.read('closed_message');
    var showUpdateDialog = await Service.readBool('ios_update_dialog');
    if (data != null) {
      if (currentVersion.toString() != data.toString()) {
        if (showUpdateDialog) {
          // debugPrint("\t=> \tShowing update dialog...");
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: kPrimaryColor,
                title: Text("New Version Update"),
                content: Text(
                  "We have detected an older version on the App on your phone.",
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text(
                      "Update Now",
                      style: TextStyle(
                        color: kSecondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Service.launchInWebViewOrVC("http://onelink.to/vnchst");
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // debugPrint("=== SPLASH AD TAP ===");
        // debugPrint("urlLink: ${widget.urlLink}");
        // debugPrint("adId: ${widget.adId}");
        CoreServices.saveAdClick(widget.adId, context);
        if (widget.urlLink.split("/")[0] == "item") {
          // debugPrint("Redirecting to item ID: ${widget.urlLink.split("/")[1]}");
          _getItemInformation(widget.urlLink.split("/")[1]);
        } else if (widget.urlLink.split("/")[0] == "store") {
          // Redirect to notification store
          // debugPrint("Redirect to notification store");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                return NotificationStore(storeId: widget.urlLink.split("/")[1]);
              },
            ),
          );
        } else {
          Service.launchInWebViewOrVC(this.widget.urlLink);
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
