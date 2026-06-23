import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Set true as soon as a cart deep link is received so SplashScreen skips
// its pushReplacement and lets McpCartScreen drive navigation to CartScreen.
bool isProcessingDeepLinkCart = false;
