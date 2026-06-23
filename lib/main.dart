import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:zmall/utils/firebase_options.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zmall/mcp/mcp_cart_screen.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/utils/navigator_key.dart';
import 'package:zmall/utils/routes.dart';
import 'package:zmall/splash/splash_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable all debug prints in production (release builds)
  if (!kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  final info = await PackageInfo.fromPlatform();
  appVersion = info.version; // ← real version from the build
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

// Static analytics instances - accessible app-wide
class MyApp extends StatefulWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseInAppMessaging messaging = FirebaseInAppMessaging.instance;
  static final facebookAppEvents = FacebookAppEvents();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;
  Timer? _cartNavigationTimer;
  String? _lastHandledDeepLink;
  DateTime? _lastHandledDeepLinkAt;

  bool _shouldIgnoreDeepLink(Uri uri) {
    final now = DateTime.now();
    final uriText = uri.toString();

    if (_lastHandledDeepLink == uriText &&
        _lastHandledDeepLinkAt != null &&
        now.difference(_lastHandledDeepLinkAt!) < const Duration(seconds: 2)) {
      return true;
    }

    _lastHandledDeepLink = uriText;
    _lastHandledDeepLinkAt = now;
    return false;
  }

  void _handleDeepLink(Uri uri) {
    if (_shouldIgnoreDeepLink(uri)) return;

    // debugPrint('=== DEEP LINK RECEIVED === $uri');
    // debugPrint(
    //   'DeepLink parts -> scheme:${uri.scheme} host:${uri.host} path:${uri.path}',
    // );
    // print('=== DEEP LINK RECEIVED === $uri');
    // print(
    //   'DeepLink parts -> scheme:${uri.scheme} host:${uri.host} path:${uri.path}',
    // );

    // Always log the incoming deep link so we can verify handling in logs
    try {
      // print('DEEP LINK HANDLER invoked with uri: $uri');
    } catch (e) {}

    String? cartId;

    if (uri.scheme == 'zmall' && uri.host == 'cart') {
      // zmall://cart/{cartId}
      if (uri.pathSegments.isNotEmpty) {
        cartId = uri.pathSegments.first;
      }
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'ai-cart') {
      // https://testapp.zmall.et/ai-cart/{cartId} or https://zmall-web.vercel.app/ai-cart/{cartId}
      cartId = uri.pathSegments[1];
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.pathSegments.length >= 3 &&
        uri.pathSegments[0] == 'go' &&
        uri.pathSegments[1] == 'cart') {
      // https://testapp.zmall.et/go/cart/{cartId}
      cartId = uri.pathSegments[2];
    }

    if (cartId != null && cartId.isNotEmpty) {
      // print(
      //   'DEEP LINK -> Scheduling McpCartScreen navigation for cartId=$cartId',
      // );
      isProcessingDeepLinkCart = true;
      _scheduleCartNavigation(cartId);
    }
  }

  void _scheduleCartNavigation(String cartId) {
    _cartNavigationTimer?.cancel();
    _cartNavigationTimer = null;
    int attempts = 0;
    bool pushed = false;

    // Wait 3 seconds before the first attempt so the SplashScreen's
    // pushReplacement (8-second timer + SharedPreferences reads) has fully
    // settled. This avoids the Flutter debug "_debugLocked" / "deactivated
    // widget" race that fires when pushReplacement and pushNamed overlap.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || pushed) return;
      _cartNavigationTimer = Timer.periodic(const Duration(milliseconds: 500), (
        timer,
      ) {
        if (!mounted || pushed || attempts++ >= 20) {
          timer.cancel();
          _cartNavigationTimer = null;
          return;
        }
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        try {
          nav.pushNamed(McpCartScreen.routeName, arguments: {'cartId': cartId});
          pushed = true;
          timer.cancel();
          _cartNavigationTimer = null;
          // print('DEEP LINK -> Navigated to McpCartScreen (attempt $attempts)');
        } catch (e) {
          // print('DEEP LINK -> Attempt $attempts failed: $e');
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();

    appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    _deepLinkSub = appLinks.uriLinkStream.listen(_handleDeepLink);

    // Handle AI cart push notifications
    FirebaseMessaging.instance.getInitialMessage().then(_handleFcmMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage);
  }

  void _handleFcmMessage(RemoteMessage? message) {
    if (message == null) return;
    final type = message.data['type'];
    final cartId = message.data['cart_id'];
    if (type == 'ai_cart' && cartId != null && cartId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamed(
          McpCartScreen.routeName,
          arguments: {'cartId': cartId},
        );
      });
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _cartNavigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ZMetaData>(create: (_) => ZMetaData()),
        ChangeNotifierProvider<ZLanguage>(create: (_) => ZLanguage()),
      ],
      child: OverlaySupport.global(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: Platform.isIOS ? "Nunito" : "Nunito",
            primarySwatch: Colors.red,

            scaffoldBackgroundColor: kPrimaryColor,
            // kWhiteColor,
            appBarTheme: AppBarTheme(
              backgroundColor: kWhiteColor,
              // backgroundColor: kPrimaryColor,
              surfaceTintColor: kPrimaryColor,
              // titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              //       color: kGreyColor,
              //     ),
              titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: kBlackColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              iconTheme: IconThemeData(color: kBlackColor),
            ),
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: kBlackColor,
              fontFamily: Platform.isIOS ? "Nunito" : "Nunito",
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: kSecondaryColor),
            ),
          ),
          routes: routes,
          initialRoute: SplashScreen.routeName,
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: MyApp.analytics),
          ],
        ),
      ),
    );
  }
}

///for debugging FacebookAppEvents
// import 'dart:io' show Platform;
// import 'package:facebook_app_events/facebook_app_events.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:overlay_support/overlay_support.dart';
// import 'package:provider/provider.dart';
// import 'package:zmall/utils/constants.dart';
// import 'package:zmall/models/language.dart';
// import 'package:zmall/models/metadata.dart';
// import 'package:zmall/utils/routes.dart';
// import 'package:zmall/splash/splash_screen.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   if (kDebugMode) {
//     debugPrint('🚀 ===== ZMall App Starting =====');
//   }

//   // Initialize Firebase
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   if (kDebugMode) {
//     debugPrint('✅ Firebase initialized successfully');
//   }

//   // Initialize Facebook App Events
//   final facebookAppEvents = FacebookAppEvents();

//   if (kDebugMode) {
//     debugPrint('📱 Facebook App Events initialized');
//     debugPrint('🔍 App ID: 1050203588837738');

//     // Log app open event manually to see it in console
//     await facebookAppEvents.logEvent(
//       name: 'fb_mobile_app_open',
//       parameters: {
//         'app_name': 'ZMall',
//         'timestamp': DateTime.now().toIso8601String(),
//       },
//     );

//     debugPrint('✅ Facebook Event Logged: fb_mobile_app_open');
//     debugPrint(
//       '📊 Event Parameters: {app_name: ZMall, timestamp: ${DateTime.now()}}',
//     );
//   }

//   runApp(MyApp());
// }

// class MyApp extends StatefulWidget {
//   static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
//   static FirebaseInAppMessaging messaging = FirebaseInAppMessaging.instance;
//   static final facebookAppEvents = FacebookAppEvents();

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);

//     if (kDebugMode) {
//       debugPrint('✅ FacebookAppEvents instance created');
//       debugPrint('🎯 Lifecycle observer attached - will log app state changes');
//       debugPrint('═══════════════════════════════════════════════════════');
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);

//     if (kDebugMode) {
//       switch (state) {
//         case AppLifecycleState.resumed:
//           debugPrint('📱 App State: RESUMED (foreground)');
//           debugPrint('   → Facebook will track: fb_mobile_activate_app');
//           MyApp.facebookAppEvents.logEvent(
//             name: 'fb_mobile_activate_app',
//             parameters: {'timestamp': DateTime.now().toIso8601String()},
//           );
//           debugPrint('✅ Facebook Event Logged: fb_mobile_activate_app');
//           break;
//         case AppLifecycleState.inactive:
//           debugPrint('📱 App State: INACTIVE (transitioning)');
//           break;
//         case AppLifecycleState.paused:
//           debugPrint('📱 App State: PAUSED (background)');
//           debugPrint('   → Facebook will track: fb_mobile_deactivate_app');
//           MyApp.facebookAppEvents.logEvent(
//             name: 'fb_mobile_deactivate_app',
//             parameters: {'timestamp': DateTime.now().toIso8601String()},
//           );
//           debugPrint('✅ Facebook Event Logged: fb_mobile_deactivate_app');
//           break;
//         case AppLifecycleState.detached:
//           debugPrint('📱 App State: DETACHED (closing)');
//           break;
//         case AppLifecycleState.hidden:
//           debugPrint('📱 App State: HIDDEN');
//           break;
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider<ZMetaData>(create: (_) => ZMetaData()),
//         ChangeNotifierProvider<ZLanguage>(create: (_) => ZLanguage()),
//       ],
//       child: OverlaySupport.global(
//         child: MaterialApp(
//           debugShowCheckedModeBanner: false,
//           theme: ThemeData(
//             fontFamily: Platform.isIOS ? "Nunito" : "Nunito",
//             primarySwatch: Colors.red,
//             scaffoldBackgroundColor: kPrimaryColor,
//             // kWhiteColor,
//             appBarTheme: AppBarTheme(
//               backgroundColor: kWhiteColor,
//               // backgroundColor: kPrimaryColor,
//               surfaceTintColor: kPrimaryColor,
//               // titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
//               //       color: kGreyColor,
//               //     ),
//               titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
//                 color: kBlackColor,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 20,
//               ),
//               iconTheme: IconThemeData(color: kBlackColor),
//             ),
//             textTheme: Theme.of(context).textTheme.apply(
//               bodyColor: kBlackColor,
//               fontFamily: Platform.isIOS ? "Nunito" : "Nunito",
//             ),
//             textButtonTheme: TextButtonThemeData(
//               style: TextButton.styleFrom(foregroundColor: kSecondaryColor),
//             ),
//           ),
//           routes: routes,
//           initialRoute: SplashScreen.routeName,
//           navigatorObservers: [
//             FirebaseAnalyticsObserver(analytics: MyApp.analytics),`
//           ],
//         ),
//       ),
//     );
//   }
// }
