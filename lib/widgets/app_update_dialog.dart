import 'package:flutter/material.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    super.key,
    required this.isForceUpdate,
    this.onDismissed,
  });

  final bool isForceUpdate;
  final VoidCallback? onDismissed;

  static void show({
    required BuildContext context,
    bool isForceUpdate = false,
    VoidCallback? onDismissed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (_) => AppUpdateDialog(
        isForceUpdate: isForceUpdate,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isForceUpdate,
      child: AlertDialog(
        backgroundColor: kPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "New Version Update",
          style: TextStyle(
            color: kBlackColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Looks like you're using an older version of the app. "
          "Update now to enjoy the latest features and improvements!",
          style: TextStyle(color: kBlackColor),
        ),
        actions: <Widget>[
          if (!isForceUpdate)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismissed?.call();
              },
              child: Text(
                "Remind Later",
                style: TextStyle(color: kGreyColor),
              ),
            ),
          TextButton(
            onPressed: () {
              Service.launchInWebViewOrVC("http://onelink.to/vnchst");
              Navigator.of(context).pop();
              onDismissed?.call();
            },
            child: Text(
              "Update Now",
              style: TextStyle(
                color: kSecondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
