import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zmall/help/support_chat/components/chat_bot_icon.dart';
import 'package:zmall/models/chat_message.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/profile/components/profile_list_tile.dart';
import 'package:zmall/help/support_chat/service/chat_service.dart';
import 'package:zmall/help/support_chat/service/gemini_service.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/cart/cart_screen.dart';
import 'package:zmall/help/support_chat/components/chat_bubble.dart';
import 'package:zmall/help/support_chat/components/chat_input.dart';
import 'package:zmall/help/support_chat/components/quick_replies.dart';
import 'package:zmall/help/support_chat/components/zmall_loop_gif.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class SupportChatScreen extends StatefulWidget {
  static String routeName = '/support-chat';
  // final userLocation;

  const SupportChatScreen({
    super.key,
    // this.userLocation,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showQuickReplies = true;
  bool _showScrollToBottom = false;
  bool _isTyping = false; // hides food-banner when user starts typing
  String serverToken = '';
  List userLocation = [];
  String imageUrl = '';
  String userId = '';
  var userData;
  var userLat;
  var userLng;

  // Real nearby stores fetched via get_company_list so the bot can answer
  // "stores near me" and "give me item for <store>" with live data.
  List _nearbyStores = [];
  bool _nearbyStoresLoaded = false;

  ///
  // String userLastOrder = '';
  String?
  userLastOrderId; // Store as String (API returns int, converted to String)
  var userOrderStatus;

  // Chat persistence settings
  static const int _chatExpirationHours = 24; // Auto-delete after 24 hours

  // User-specific storage keys (will be set after user data loads)
  String get _chatStorageKey => 'support_chat_messages_$userId';
  String get _chatTimestampKey => 'support_chat_timestamp_$userId';

  ///

  @override
  void initState() {
    super.initState();
    _getUser(); // Load user data (chat history will load after user data is available)
    _scrollController.addListener(_scrollListener);
    _messageController.addListener(_onTypingChanged);
    userLat = Provider.of<ZMetaData>(context, listen: false).latitude;
    userLng = Provider.of<ZMetaData>(context, listen: false).longitude;
    userLocation = ["$userLat", "$userLng"];
  }

  void _getUser() async {
    var data = await Service.read('user');
    if (data != null && mounted) {
      setState(() {
        userData = data;
        if (userData['user'] != null) {
          imageUrl = userData["user"]["image_url"] ?? "";
          userId = userData["user"]["_id"] ?? "";
          serverToken = userData["user"]["server_token"] ?? "";
          if (userId.isNotEmpty) {
            _getUserOrder(userId: userId, serverToken: serverToken);
          }
        }
      });

      _loadChatHistory();

      try {
        var usrData = await ChatService.userDetails(
          context: context,
          userId: userId,
          serverToken: serverToken,
        );
        if (usrData != null && usrData['success'] == true && mounted) {
          setState(() {
            userData = usrData;
            if (userData['user'] != null) {
              imageUrl = userData["user"]["image_url"] ?? imageUrl;
              userId = userData["user"]["_id"] ?? userId;
              serverToken = userData["user"]["server_token"] ?? serverToken;
            }
          });
          Service.save('user', userData);
        }
      } catch (_) {}
    } else {
      _initializeChat();
    }
  }

  void _scrollListener() {
    // Show button when scrolled up more than 200 pixels from bottom
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      final isNearBottom = (maxScroll - currentScroll) < 200;

      if (_showScrollToBottom == isNearBottom) {
        setState(() {
          _showScrollToBottom = !isNearBottom;
        });
      }
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final chatTimestamp = await Service.read(_chatTimestampKey);
      final chatData = await Service.read(_chatStorageKey);

      // Check if chat exists and is not expired
      if (chatTimestamp != null && chatData != null) {
        final savedTime = DateTime.fromMillisecondsSinceEpoch(chatTimestamp);
        final now = DateTime.now();
        final difference = now.difference(savedTime);

        // If chat is older than expiration time, clear it
        if (difference.inHours >= _chatExpirationHours) {
          await _clearChatHistory();
          _initializeChat();
        } else {
          // Load saved messages
          final List<dynamic> messagesJson = chatData;
          setState(() {
            _messages.clear();
            _messages.addAll(
              messagesJson.map((json) => ChatMessage.fromJson(json)).toList(),
            );
            _showQuickReplies = _messages.length <= 1;
          });
          _scrollToBottom();
        }
      } else {
        // No saved chat, initialize fresh
        _initializeChat();
      }
    } catch (e) {
      // debugPrint("❌ Error loading chat history: $e");
      _initializeChat();
    }
  }

  void _initializeChat() {
    // Add welcome message
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _addBotMessage(
          "Hello! Welcome to ZMall Support. 👋\nHow can I help you today?",
        );
      }
    });
  }

  Future<void> _saveChatHistory() async {
    // Don't save if userId is not set yet (prevents saving to wrong user)
    if (userId.isEmpty) return;

    try {
      // Save messages as JSON using Service
      final messagesJson = _messages
          .map((message) => message.toJson())
          .toList();
      await Service.save(_chatStorageKey, messagesJson);

      // Save current timestamp
      await Service.save(
        _chatTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // debugPrint("❌ Error saving chat history: $e");
    }
  }

  Future<void> _clearChatHistory() async {
    try {
      await Service.remove(_chatStorageKey);
      await Service.remove(_chatTimestampKey);
    } catch (e) {
      // debugPrint("❌ Error clearing chat history: $e");
    }
  }

  void _addBotMessage(String message, {bool showCartAction = false}) {
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: message,
          isUser: false,
          timestamp: DateTime.now(),
          showCartAction: showCartAction,
        ),
      );
    });
    _scrollToBottom();
    _saveChatHistory(); // Save after adding message
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          message: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _showQuickReplies = false;
    });
    _scrollToBottom();
    _saveChatHistory(); // Save after adding message
  }

  void _handleSendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _addUserMessage(message);
    _messageController.clear();

    // Fetch real bot response from API
    _fetchBotResponse(message);
  }

  void _handleQuickReply(String reply) {
    _addUserMessage(reply);
    _fetchBotResponse(reply);
    // Hide quick replies after selection
    setState(() {
      _showQuickReplies = false;
    });
  }

  void _toggleQuickReplies() {
    setState(() {
      _showQuickReplies = !_showQuickReplies;
    });
  }

  Future<void> _fetchBotResponse(String userMessage) async {
    setState(() {
      _isLoading = true;
    });

    // debugPrint("Message: $userMessage");
    // debugPrint("Is Order Related: $isOrderRelated");
    // debugPrint("Sending Order ID: $userLastOrderId");

    try {
      // App-side endpoint integration: answer "stores near me" and
      // "give me item for <store>" using the real backend endpoints
      // (get_company_list / user_get_store_product_item_list) instead of
      // generic or broken replies.
      final localReply = await _handleLocalStoreIntent(userMessage);
      if (!mounted) return;
      if (localReply != null) {
        setState(() {
          _isLoading = false;
        });
        _addBotMessage(
          localReply,
          showCartAction: _shouldShowCartAction(localReply),
        );
        return;
      }

      final response = await ChatService.sendMessage(
        message: userMessage,
        context: context,
        userId: userId,
        orderId: userLastOrderId,
        serverToken: serverToken,
        userLocation: userLocation,
      );

      if (!mounted) return;

      if (response != null && response['error'] != true) {
        // Try different possible response field names from API
        String botMessage =
            response['response'] ??
            response['message'] ??
            response['reply'] ??
            response['answer'] ??
            response['text'] ??
            'I received your message. How else can I help you?';

        setState(() {
          _isLoading = false;
        });
        _addBotMessage(
          botMessage,
          showCartAction: _shouldShowCartAction(botMessage),
        );
      } else {
        // Backend unavailable or returned an error — fall back to Gemini,
        // and to mock data only if Gemini is unreachable too.
        final fallback = await _fallbackReply(userMessage);
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _addBotMessage(
          fallback,
          showCartAction: _shouldShowCartAction(fallback),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final fallback = await _fallbackReply(userMessage);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _addBotMessage(fallback, showCartAction: _shouldShowCartAction(fallback));
    }
  }

  Future<void> _handleViewCartForMessage(int messageIndex) async {
    final message = _messages[messageIndex];
    List<MockProduct> products = searchMockProducts(message.message);
    if (products.isEmpty && messageIndex > 0) {
      products = searchMockProducts(_messages[messageIndex - 1].message);
    }
    if (products.isEmpty) {
      products = [mockProducts.first]; // Default to Cheese Burger
    }

    await addMockProductsToCart(products);

    if (mounted) {
      Navigator.pushNamed(context, CartScreen.routeName);
    }
  }

  /// Tries Gemini for a real AI reply and only falls back to the offline
  /// mock data if Gemini is unreachable.
  Future<String> _fallbackReply(String userMessage) async {
    if (searchMockProducts(userMessage).isNotEmpty) {
      return _getMockResponse(userMessage);
    }
    try {
      final geminiReply = await GeminiService.sendMessage(userMessage);
      if (geminiReply != null) {
        return geminiReply;
      }
    } catch (_) {
      // Gemini failed — fall through to mock data
    }
    return _getMockResponse(userMessage);
  }

  /// Returns true when the bot's reply is actually about the cart or the
  /// user's basket, so the message shows an in-chat "View Cart" action button.
  /// The decision is based on the reply text (not the user's keywords) so the
  /// button never appears on generic error/fallback replies when something
  /// goes wrong.
  bool _shouldShowCartAction(String botReply) {
    final lower = botReply.toLowerCase();
    return lower.contains('view cart') ||
        lower.contains('basket') ||
        lower.contains('cart') ||
        lower.contains('checkout');
  }

  /// Handles store-related requests app-side using the real endpoints
  /// (`get_company_list` for nearby stores, `user_get_store_product_item_list`
  /// for a store's menu). Returns a reply when it can answer, otherwise null
  /// so the normal backend/Gemini/mock flow takes over.
  Future<String?> _handleLocalStoreIntent(String userMessage) async {
    final lower = userMessage.toLowerCase().trim();
    if (lower.isEmpty) return null;

    try {
      // "stores near me" / "nearby stores"
      if (_isNearbyStoresIntent(lower)) {
        final stores = await _loadNearbyStores();
        if (stores != null && stores.isNotEmpty) {
          return _formatNearbyStores(stores);
        }
      }

      // "give me item for <store>" / "menu of <store>"
      if (_isStoreItemsIntent(lower)) {
        final storeName = _extractStoreName(lower);
        if (storeName != null) {
          final stores = await _loadNearbyStores();
          final store = _matchStore(storeName, stores ?? const []);
          if (store != null) {
            final storeId = store['_id'];
            if (storeId != null) {
              final data = await ChatService.getStoreItems(
                context: context,
                storeId: storeId,
              );
              if (data != null && data['success'] == true) {
                final products = data['products'] ?? [];
                final items = <dynamic>[];
                for (final group in products) {
                  final list = group?['items'];
                  if (list is List) items.addAll(list);
                }
                if (items.isNotEmpty) {
                  return _formatStoreItems(
                    items,
                    store['name']?.toString() ?? storeName,
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Fall through to the normal backend flow on any failure.
    }
    return null;
  }

  bool _isNearbyStoresIntent(String lower) {
    return (lower.contains('near') &&
            (lower.contains('store') ||
                lower.contains('restaurant') ||
                lower.contains('shop') ||
                lower.contains('food'))) ||
        lower.contains('nearby') ||
        lower.contains('stores near me') ||
        lower.contains('store near me');
  }

  bool _isStoreItemsIntent(String lower) {
    final hasItemKeyword =
        lower.contains('item') ||
        lower.contains('menu') ||
        lower.contains('product') ||
        lower.contains('show') ||
        lower.contains('list');
    final hasStorePhrase =
        lower.contains(' for ') ||
        lower.contains(' from ') ||
        lower.contains(' of ') ||
        lower.contains(' at ');
    return hasItemKeyword && hasStorePhrase;
  }

  /// Pulls the store name out of a "give me item for X" style message.
  String? _extractStoreName(String lower) {
    var cleaned = lower;
    for (final phrase in [
      'give me',
      'can you',
      'could you',
      'please show',
      'show me',
      'please',
      'items',
      'item',
      'menu',
      'products',
      'product',
      'list',
      'need',
      'want',
      'for',
      'from',
      'of',
      'at',
      'in',
      'the',
      'a',
      'an',
      'and',
      'store',
      'restaurant',
      'shop',
      'near me',
      'nearby',
      'open',
    ]) {
      cleaned = cleaned.replaceAll(' $phrase ', ' ');
      cleaned = cleaned.replaceAll(phrase, ' ');
    }
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9 \-&]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length < 2) return null;
    return cleaned;
  }

  dynamic _matchStore(String name, List stores) {
    final lower = name.toLowerCase().trim();
    for (final store in stores) {
      final storeName = (store['name']?.toString() ?? '').toLowerCase().trim();
      if (storeName.isEmpty) continue;
      if (storeName.contains(lower) || lower.contains(storeName)) {
        return store;
      }
    }
    return null;
  }

  Future<List?> _loadNearbyStores() async {
    if (_nearbyStoresLoaded) return _nearbyStores;
    final data = await ChatService.getNearbyStores(context: context);
    if (data != null && data['success'] == true) {
      final stores = data['stores'];
      if (stores is List) {
        _nearbyStores = stores;
        _nearbyStoresLoaded = true;
        return _nearbyStores;
      }
    }
    return null;
  }

  String _formatNearbyStores(List stores) {
    final lines = stores
        .take(6)
        .toList()
        .asMap()
        .entries
        .map((e) {
          final index = e.key + 1;
          final store = e.value;
          final name = store['name']?.toString() ?? 'Store';
          var distance = store['distance'];
          final suffix = (distance is num)
              ? ' — ${distance.toStringAsFixed(1)} km'
              : '';
          return '**$index. $name**$suffix';
        })
        .join('\n');
    return '📍 Here are some great stores near you:\n\n$lines\n\n'
        'Tell me which one you\'d like and I\'ll pull up its menu. '
        'Or tap **View Cart** if you\'re ready to order! 🍔';
  }

  String _formatStoreItems(List items, String storeName) {
    final lines = items
        .take(10)
        .toList()
        .asMap()
        .entries
        .map((e) {
          final index = e.key + 1;
          final item = e.value;
          final name = item['name']?.toString() ?? 'Item';
          final price = _itemPrice(item);
          return '**$index. $name** — $price';
        })
        .join('\n');
    return '🍽️ Here\'s a taste of **$storeName**:\n\n$lines\n\n'
        'Want the full menu, or shall I add one of these to your cart? 🛒';
  }

  String _itemPrice(dynamic item) {
    final meta = Provider.of<ZMetaData>(context, listen: false);
    final raw = item['price'] ?? item['item_price'];
    if (raw is num && raw > 0) {
      return '${raw.toStringAsFixed(0)} ${meta.currency}';
    }
    final specs = item['specifications'];
    if (specs is List) {
      for (final spec in specs) {
        final list = spec?['list'];
        if (list is List) {
          for (final option in list) {
            if (option?['is_default_selected'] == true &&
                option?['price'] is num) {
              return '${(option['price'] as num).toStringAsFixed(0)} ${meta.currency}';
            }
          }
        }
      }
      if (specs.isNotEmpty) {
        final firstList = specs.first?['list'];
        if (firstList is List && firstList.isNotEmpty) {
          final price = firstList.first['price'];
          if (price is num) {
            return '${price.toStringAsFixed(0)} ${meta.currency}';
          }
        }
      }
    }
    return 'price on request';
  }

  /// Generates a mock bot reply when the backend is unreachable
  /// (e.g. expired token, network issue) so the chat still works offline.
  String _getMockResponse(String message) {
    final lower = message.toLowerCase();

    final products = searchMockProducts(message);
    if (products.isNotEmpty) {
      return formatMockProducts(products);
    }

    if (lower.contains('where') && lower.contains('order') ||
        lower.contains('track') && lower.contains('order')) {
      return "📦 Here's how to track your order:\n\n"
          "1. Open the **Orders** tab\n"
          "2. Tap on your active order\n"
          "3. Follow the **live tracking** map\n\n"
          "Or just send me your order ID and I'll check it for you! ✅";
    }

    if (lower.contains('last order')) {
      if (userLastOrderId != null && userLastOrderId!.isNotEmpty) {
        return "🛍️ Your **last order**:\n\n"
            "• Order #: **$userLastOrderId**\n"
            "• Status: **${userOrderStatus ?? 'In progress'}**\n\n"
            "You can see the full details in the **Orders** tab. Anything else? 😊";
      }
      return "I couldn't find any past orders on your account yet.\n\n"
          "Once you place an order, I'll be the first to show it here! 🛒";
    }

    if (lower.contains('status')) {
      if (userLastOrderId != null && userLastOrderId!.isNotEmpty) {
        return "📈 Your order **#$userLastOrderId** is currently:\n\n"
            "**${userOrderStatus ?? 'processing'}** 🎉\n\n"
            "Live updates are available in the **Orders** tab.";
      }
      return "I couldn't find an order on your account.\n\n"
          "Please place an order first, then I can check its status for you. 😊";
    }

    if (lower.contains('refund')) {
      return "💸 Refunds are usually processed within **3–5 business days**.\n\n"
          "Your money goes back to:\n"
          "• Original payment method\n"
          "• **ZMall Wallet** (instant)\n\n"
          "Share your order ID and I'll check the refund status for you!";
    }

    if (lower.contains('payment') || lower.contains('pay')) {
      return "💳 We accept these payment methods:\n\n"
          "• **Telebirr**\n"
          "• **CBE Birr**\n"
          "• **Amole**\n"
          "• **Credit / Debit cards**\n\n"
          "What payment issue are you facing? I'm happy to help! 😊";
    }

    if (lower.contains('delivery') || lower.contains('deliver')) {
      return "🚚 Delivery times depend on your location:\n\n"
          "• **Standard** — 30–45 mins\n"
          "• **Express** — 15–30 mins\n\n"
          "You'll see your exact estimate at checkout. ⏱️";
    }

    if (lower.contains('cancel')) {
      return "❌ To cancel an order:\n\n"
          "1. Go to **Orders**\n"
          "2. Select the order\n"
          "3. Tap **Cancel Order**\n\n"
          "⚠️ You can cancel anytime *before* the store accepts it.";
    }

    if (lower.contains('special') ||
        lower.contains('offer') ||
        lower.contains('discount') ||
        lower.contains('promo')) {
      return "🎉 Today's hot offers:\n\n"
          "• 🚚 **Free delivery** on orders over 500 ETB\n"
          "• 💥 **20% off** your first order\n"
          "• ⚡ Weekly flash deals on selected stores\n\n"
          "Check the **Home** tab to grab them before they're gone!";
    }

    if (lower.contains('restaurant') || lower.contains('near me')) {
      return "🍔 Looking for food nearby? Here are some popular spots:\n\n"
          "1. **ZMall Burgers** 🍔\n"
          "2. **Pizza Express** 🍕\n"
          "3. **Coffee Corner** ☕\n"
          "4. **Asian Wok** 🍜\n\n"
          "Open any store to browse its menu — or just ask me for items! 😊";
    }

    if (lower.contains('top selling') || lower.contains('top store')) {
      return "🔥 This week's **top stores**:\n\n"
          "1. **ZMall Burgers**\n"
          "2. **Habesha Mart**\n"
          "3. **Coffee Corner**\n"
          "4. **Fresh Basket**\n\n"
          "Tap any store to start shopping! 🛒";
    }

    if (lower.contains('cart') || lower.contains('basket')) {
      return "🛒 You can tap the green **View Cart** button to see your basket.\n\n"
          "From there you can:\n"
          "• Adjust quantities\n"
          "• Remove items\n"
          "• Proceed to **checkout**";
    }

    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('hey') ||
        lower.contains('salam')) {
      return "Hello! 👋 Great to see you! I'm **ZMall Support**.\n\n"
          "I can help you with:\n"
          "• 🛍️ Finding stores & items\n"
          "• 📦 Tracking orders\n"
          "• 💳 Payments & refunds\n\n"
          "What would you like to do today?";
    }

    if (lower.contains('thank')) {
      return "You're very welcome! 😊\n\n"
          "Is there anything else I can help you with today?";
    }

    if (lower.contains('agent') ||
        lower.contains('human') ||
        lower.contains('talk') ||
        lower.contains('live')) {
      return "Sure — let me get a **human agent** for you! 🙋\n\n"
          "📞 Call: +251 967 575757\n"
          "📧 Email: info@zmallshop.com\n"
          "🕗 Hours: 8 AM – 10 PM\n\n"
          "Our team will assist you shortly.";
    }

    return "Great question! Here's what I can help you with:\n\n"
        "• 🛍️ **Find stores & items**\n"
        "• 📦 **Track your order**\n"
        "• 💳 **Payments & refunds**\n"
        "• 🚚 **Delivery info**\n"
        "• ❌ **Cancellations**\n\n"
        "Or if you need a **live agent**, just say the word! What would you like to do?";
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _saveChatHistory(); // Save chat when leaving screen
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTypingChanged() {
    final typing = _messageController.text.isNotEmpty;
    if (typing != _isTyping) {
      setState(() {
        _isTyping = typing;
      });
    }
  }

  ///get user orders
  void _getUserOrder({
    required String userId,
    required String serverToken,
  }) async {
    // Fetch orders silently in background - no loading indicator needed
    try {
      var data = await ChatService.getOrders(
        userId: userId,
        serverToken: serverToken,
        context: context,
      );

      if (data != null &&
          data['success'] &&
          data['order_list'] != null &&
          data['order_list'].isNotEmpty) {
        if (mounted) {
          var userLastOrder = data['order_list'][0];
          setState(() {
            // Convert unique_id to String (API returns int)
            userLastOrderId = userLastOrder['unique_id']?.toString() ?? '';
            // userLastOrder['_id']?.toString() ?? '';
            userOrderStatus = userLastOrder['order_status'];
            // debugPrint("✅ Last Order ID: $userLastOrderId");
            // debugPrint("✅ Order Status: $userOrderStatus");
          });
        }
      } else {
        if (mounted) {
          setState(() {
            userLastOrderId = null; // No order found
          });
        }
        // debugPrint("⚠️ No orders found for user");
      }
    } catch (e) {
      // debugPrint("❌ Error fetching orders: $e");
      if (mounted) {
        setState(() {
          userLastOrderId = null;
        });
      }
    }
  }

  ///

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            ChatBotIcon(width: 40, height: 40, iconSize: 20),
            SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ZMall Support",
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Online • Responds quickly",
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(11),
                    color: kGreenColor,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // IconButton(
          //   icon: Icon(HeroiconsOutline.phone, color: kBlackColor),
          //   onPressed: () {
          //     launchUrl(Uri(scheme: 'tel', path: '+251967575757'));
          //   },
          // ),
          IconButton(
            icon: Icon(HeroiconsOutline.ellipsisVertical, color: kBlackColor),
            onPressed: () {
              _showOptionsMenu(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Soft gradient background
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFCEFF0), Color(0xFFF3F4F8)],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: _messages.length <= 1
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          top: getProportionateScreenHeight(kDefaultPadding),
                          bottom: getProportionateScreenHeight(kDefaultPadding),
                        ),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isLoading) {
                            return _AnimatedMessage(
                              child: _buildTypingIndicator(),
                            );
                          }
                          final message = _messages[index];
                          final previous = index > 0
                              ? _messages[index - 1]
                              : null;
                          final dayHeader = _buildDaySeparator(
                            message,
                            previous,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (dayHeader != null) dayHeader,
                              _AnimatedMessage(
                                child: ChatBubble(
                                  message: message,
                                  imageUrl:
                                      "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/$imageUrl",
                                  onLongPress: message.isUser
                                      ? () => _showMessageOptions(
                                          context,
                                          message,
                                        )
                                      : null,
                                  onViewCart: () =>
                                      _handleViewCartForMessage(index),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              if (_showQuickReplies && _messages.length <= 1 && !_isTyping)
                _buildFoodBanner(),
              if (_showQuickReplies)
                QuickReplies(onReplyTap: _handleQuickReply),
              ChatInput(
                controller: _messageController,
                onSend: _handleSendMessage,
                isLoading: _isLoading,
                onQuickRepliesToggle: _messages.length > 1
                    ? _toggleQuickReplies
                    : null,
              ),
            ],
          ),
          // Scroll to bottom button
          if (_showScrollToBottom)
            Positioned(
              bottom: getProportionateScreenHeight(
                _showQuickReplies ? 230 : 110,
              ),
              right: getProportionateScreenWidth(kDefaultPadding),
              child: Material(
                elevation: 4,
                shape: CircleBorder(),
                color: kGreyColor.withValues(alpha: 0.6),
                // kSecondaryColor,
                child: InkWell(
                  onTap: () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  customBorder: CircleBorder(),
                  child: Container(
                    width: getProportionateScreenWidth(38),
                    height: getProportionateScreenWidth(38),
                    child: Center(
                      child: Icon(
                        HeroiconsSolid.chevronDown,
                        color: kPrimaryColor,
                        size: getProportionateScreenWidth(24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        vertical: getProportionateScreenHeight(kDefaultPadding),
        horizontal: getProportionateScreenWidth(kDefaultPadding),
      ),
      child: Column(
        children: [
          // Hero welcome card
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(kDefaultPadding * 1.4),
              vertical: getProportionateScreenHeight(kDefaultPadding * 1.2),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kSecondaryColor,
                  kSecondaryColor.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: kSecondaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                ZmallLoopGif(
                  height: getProportionateScreenHeight(120),
                  width: getProportionateScreenWidth(180),
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.circular(16),
                ),
                SizedBox(
                  height: getProportionateScreenHeight(kDefaultPadding / 2),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChatBotIcon(width: 26, height: 26, iconSize: 16),
                    SizedBox(width: getProportionateScreenWidth(8)),
                    Text(
                      "Welcome to ZMall Support",
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(17),
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: getProportionateScreenHeight(kDefaultPadding / 2),
                ),
                Text(
                  "I'm here 24/7 to help with orders, deliveries, "
                  "payments, refunds and finding your favorite food!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(12.5),
                    color: kPrimaryColor.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
          Text(
            "What can I do for you?",
            style: TextStyle(
              fontSize: getProportionateScreenWidth(14),
              fontWeight: FontWeight.bold,
              color: kBlackColor,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 1.5)),
          Wrap(
            spacing: getProportionateScreenWidth(kDefaultPadding / 1.5),
            runSpacing: getProportionateScreenHeight(kDefaultPadding / 1.5),
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureCard(
                icon: HeroiconsOutline.shoppingBag,
                color: kSecondaryColor,
                title: "Track Order",
                subtitle: "Where is my order?",
                onTap: () => _handleQuickReply("Where is my order?"),
              ),
              _buildFeatureCard(
                icon: HeroiconsOutline.buildingStorefront,
                color: const Color(0xFF2563EB),
                title: "Find Stores",
                subtitle: "Stores near me",
                onTap: () => _handleQuickReply("Show me restaurants near me"),
              ),
              _buildFeatureCard(
                icon: HeroiconsOutline.sparkles,
                color: const Color(0xFFD97706),
                title: "Offers",
                subtitle: "Today's special offers",
                onTap: () =>
                    _handleQuickReply("What are today's special offers?"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: getProportionateScreenWidth(108),
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(kDefaultPadding / 1.5),
          vertical: getProportionateScreenHeight(kDefaultPadding / 1.2),
        ),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBlackColor.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: kBlackColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: getProportionateScreenWidth(40),
              height: getProportionateScreenWidth(40),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: getProportionateScreenWidth(20),
              ),
            ),
            SizedBox(height: getProportionateScreenHeight(6)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getProportionateScreenWidth(12),
                fontWeight: FontWeight.w700,
                color: kBlackColor,
              ),
            ),
            SizedBox(height: getProportionateScreenHeight(2)),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: getProportionateScreenWidth(9.5),
                color: kGreyColor,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildDaySeparator(ChatMessage current, ChatMessage? previous) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDay = DateTime(
      current.timestamp.year,
      current.timestamp.month,
      current.timestamp.day,
    );
    final previousDay = previous != null
        ? DateTime(
            previous.timestamp.year,
            previous.timestamp.month,
            previous.timestamp.day,
          )
        : null;

    if (previousDay != null && currentDay == previousDay) {
      return null;
    }

    String label;
    final diff = today.difference(currentDay).inDays;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, y').format(current.timestamp);
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding * 2),
        vertical: getProportionateScreenHeight(kDefaultPadding / 2),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(kDefaultPadding),
            vertical: getProportionateScreenHeight(3),
          ),
          decoration: BoxDecoration(
            color: kBlackColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: getProportionateScreenWidth(10),
              fontWeight: FontWeight.w600,
              color: kGreyColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(6),
      ),
      child: Row(
        children: [
          ZmallLoopGif(
            height: getProportionateScreenHeight(52),
            width: getProportionateScreenWidth(52),
            fit: BoxFit.contain,
            borderRadius: BorderRadius.circular(10),
          ),
          SizedBox(width: getProportionateScreenWidth(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Craving something delicious? 🍔',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(13),
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                Text(
                  'Pick a quick reply below or type your question!',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(11),
                    color: kGreyColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(kDefaultPadding / 3.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kSecondaryColor,
                  kSecondaryColor.withValues(alpha: 0.4),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: kSecondaryColor.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const ChatBotIcon(width: 30, height: 30),
          ),
          SizedBox(width: getProportionateScreenWidth(8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(14),
              vertical: getProportionateScreenHeight(12),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: getProportionateScreenWidth(3.5),
                  height: getProportionateScreenHeight(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        kSecondaryColor,
                        kSecondaryColor.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(10)),
                Text(
                  "ZMall Assistant is thinking",
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(11.5),
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(8)),
                const _TypingDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPrimaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(kDefaultPadding),
        ),
      ),
      builder: (context) => SafeArea(
        minimum: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(kDefaultPadding),
          vertical: getProportionateScreenHeight(kDefaultPadding / 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            // Padding(
            //   padding: EdgeInsets.symmetric(
            //     vertical: getProportionateScreenHeight(kDefaultPadding / 2),
            //   ),
            //   child: Text(
            //     "Message Options",
            //     style: TextStyle(
            //       fontSize: getProportionateScreenWidth(16),
            //       fontWeight: FontWeight.bold,
            //       color: kBlackColor,
            //     ),
            //   ),
            // ),
            // Divider(height: 1, color: kGreyColor.withValues(alpha: 0.2)),
            // Resend
            ProfileListTile(
              showTrailing: false,
              borderColor: kPrimaryColor,
              icon: Icon(HeroiconsOutline.arrowPath),
              title: "Resend Message",
              onTap: () {
                Navigator.pop(context);
                _resendMessage(message.message);
              },
            ),
            // Copy
            ProfileListTile(
              showTrailing: false,
              borderColor: kPrimaryColor,
              icon: Icon(HeroiconsOutline.clipboard),
              title: "Copy Message",
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message.message);
              },
            ),
            // Delete
            ProfileListTile(
              showTrailing: false,
              borderColor: kPrimaryColor,
              icon: Icon(HeroiconsOutline.trash, color: Colors.red),
              title: "Delete Message",
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _resendMessage(String message) {
    _addUserMessage(message);
    _fetchBotResponse(message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Message resent"),
        backgroundColor: kSecondaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Message copied to clipboard"),
        backgroundColor: kSecondaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteMessage(ChatMessage message) {
    setState(() {
      _messages.removeWhere((msg) => msg.id == message.id);
    });
    _saveChatHistory(); // Save after deletion

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Message deleted"),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
        action: SnackBarAction(
          label: "Undo",
          textColor: kPrimaryColor,
          onPressed: () {
            setState(() {
              _messages.add(message);
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            });
            _saveChatHistory(); // Save after undo
          },
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPrimaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(kDefaultPadding),
        ),
      ),
      builder: (context) => SafeArea(
        minimum: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(kDefaultPadding),
          vertical: getProportionateScreenHeight(kDefaultPadding / 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileListTile(
              showTrailing: false,
              borderColor: kPrimaryColor,
              icon: Icon(HeroiconsOutline.trash, color: kBlackColor),
              title: "Clear Chat",
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _messages.clear();
                  _showQuickReplies = true;
                });
                _clearChatHistory(); // Clear saved chat
                _initializeChat();
              },
            ),
            ProfileListTile(
              showTrailing: false,
              borderColor: kPrimaryColor,
              icon: Icon(HeroiconsOutline.phone, color: kBlackColor),
              title: "Call Support",
              subtitle: Text("+251 96 757 5757"),
              onTap: () {
                launchUrl(Uri(scheme: 'tel', path: '+251967575757'));
              },
            ),
            ProfileListTile(
              showTrailing: false,
              borderColor: kPrimaryColor,
              icon: Icon(HeroiconsOutline.envelope, color: kBlackColor),
              title: "Email Support",
              subtitle: Text("info@zmallshop.com"),
              onTap: () {
                launchUrl(Uri(scheme: 'mailto', path: "info@zmallshop.com"));
                // launch("mailto:info@zmallshop.com");
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Smooth typing animation widget
class _AnimatedMessage extends StatefulWidget {
  final Widget child;

  const _AnimatedMessage({required this.child});

  @override
  State<_AnimatedMessage> createState() => _AnimatedMessageState();
}

class _AnimatedMessageState extends State<_AnimatedMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({Key? key}) : super(key: key);

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        const SizedBox(width: 3.5),
        _buildDot(1),
        const SizedBox(width: 3.5),
        _buildDot(2),
      ],
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double delay = index * 0.22;
        final double progress = (_controller.value + delay) % 1.0;
        final double sinVal = (progress * 2 * 3.1415926535).abs();
        final double bounce =
            -3.5 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);
        final double opacity =
            0.4 + 0.6 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, bounce),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kSecondaryColor, const Color(0xFFF97316)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kSecondaryColor.withValues(alpha: 0.35),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:heroicons_flutter/heroicons_flutter.dart';
// import 'package:zmall/models/chat_message.dart';
// import 'package:zmall/support_chat/components/chat_bubble.dart';
// import 'package:zmall/support_chat/components/chat_input.dart';
// import 'package:zmall/support_chat/components/quick_replies.dart';
// import 'package:zmall/utils/constants.dart';
// import 'package:zmall/utils/size_config.dart';

// class SupportChatScreen extends StatefulWidget {
//   static String routeName = '/support-chat';

//   const SupportChatScreen({super.key});

//   @override
//   State<SupportChatScreen> createState() => _SupportChatScreenState();
// }

// class _SupportChatScreenState extends State<SupportChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final List<ChatMessage> _messages = [];
//   bool _isLoading = false;
//   bool _showQuickReplies = true;

//   @override
//   void initState() {
//     super.initState();
//     _initializeChat();
//   }

//   void _initializeChat() {
//     // Add welcome message
//     Future.delayed(Duration(milliseconds: 500), () {
//       if (mounted) {
//         _addBotMessage(
//           "Hello! Welcome to ZMall Support. 👋\n\nHow can I help you today?",
//         );
//       }
//     });
//   }

//   void _addBotMessage(String message) {
//     setState(() {
//       _messages.add(
//         ChatMessage(
//           id: DateTime.now().millisecondsSinceEpoch.toString(),
//           message: message,
//           isUser: false,
//           timestamp: DateTime.now(),
//         ),
//       );
//     });
//     _scrollToBottom();
//   }

//   void _addUserMessage(String message) {
//     setState(() {
//       _messages.add(
//         ChatMessage(
//           id: DateTime.now().millisecondsSinceEpoch.toString(),
//           message: message,
//           isUser: true,
//           timestamp: DateTime.now(),
//         ),
//       );
//       _showQuickReplies = false;
//     });
//     _scrollToBottom();
//   }

//   void _handleSendMessage() {
//     final message = _messageController.text.trim();
//     if (message.isEmpty) return;

//     _addUserMessage(message);
//     _messageController.clear();

//     // Simulate bot response
//     _simulateBotResponse(message);
//   }

//   void _handleQuickReply(String reply) {
//     _addUserMessage(reply);
//     _simulateBotResponse(reply);
//   }

//   void _simulateBotResponse(String userMessage) {
//     setState(() {
//       _isLoading = true;
//     });

//     // Simulate thinking delay
//     Future.delayed(Duration(seconds: 1), () {
//       if (!mounted) return;

//       setState(() {
//         _isLoading = false;
//       });

//       final lowerMessage = userMessage.toLowerCase();
//       String response;

//       if (lowerMessage.contains('track') || lowerMessage.contains('order')) {
//         response =
//             "To track your order:\n\n1. Go to Orders tab\n2. Select your active order\n3. View real-time tracking\n\nOr provide your order ID and I'll help you track it!";
//       } else if (lowerMessage.contains('payment')) {
//         response =
//             "I can help with payment issues!\n\nCommon payment methods:\n• Telebirr\n• CBE Birr\n• Amole\n• Credit/Debit Cards\n\nWhat specific payment issue are you facing?";
//       } else if (lowerMessage.contains('delivery') ||
//           lowerMessage.contains('time')) {
//         response =
//             "Delivery times vary by location:\n\n🚴 Standard: 30-45 mins\n🚗 Express: 15-30 mins\n\nYour estimated delivery time is shown at checkout. Is there a specific order you'd like to check?";
//       } else if (lowerMessage.contains('cancel')) {
//         response =
//             "To cancel an order:\n\n1. Go to Orders\n2. Select the order\n3. Tap 'Cancel Order'\n\nNote: You can only cancel before the store accepts it. Need help canceling a specific order?";
//       } else if (lowerMessage.contains('refund')) {
//         response =
//             "Refunds are processed within 3-5 business days.\n\nRefund goes to:\n• Original payment method\n• ZMall Wallet (instant)\n\nProvide your order ID to check refund status.";
//       } else if (lowerMessage.contains('agent') ||
//           lowerMessage.contains('human') ||
//           lowerMessage.contains('talk')) {
//         response =
//             "I'll connect you with a live agent!\n\n📞 Call: +251 967 575757\n📧 Email: info@zmallshop.com\n⏰ Hours: 8 AM - 10 PM\n\nOur team will assist you shortly.";
//       } else if (lowerMessage.contains('hello') ||
//           lowerMessage.contains('hi') ||
//           lowerMessage.contains('hey')) {
//         response =
//             "Hello! 😊 I'm here to help. What can I assist you with today?";
//       } else if (lowerMessage.contains('thank')) {
//         response =
//             "You're welcome! 🎉\n\nIs there anything else I can help you with?";
//       } else {
//         response =
//             "I understand you're asking about \"$userMessage\".\n\nI can help with:\n• Order tracking\n• Payment issues\n• Delivery questions\n• Cancellations\n• Refunds\n\nOr connect you with a live agent. What would you like to know?";
//       }

//       _addBotMessage(response);
//     });
//   }

//   void _scrollToBottom() {
//     Future.delayed(Duration(milliseconds: 100), () {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         elevation: 0,
//         title: Row(
//           children: [
//             Container(
//               width: getProportionateScreenWidth(40),
//               height: getProportionateScreenWidth(40),
//               decoration: BoxDecoration(
//                 color: kSecondaryColor.withValues(alpha: 0.1),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(
//                 Icons.support_agent_rounded,
//                 color: kSecondaryColor,
//                 size: getProportionateScreenWidth(22),
//               ),
//             ),
//             SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "ZMall Support",
//                   style: TextStyle(
//                     fontSize: getProportionateScreenWidth(16),
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   "Online • Responds quickly",
//                   style: TextStyle(
//                     fontSize: getProportionateScreenWidth(11),
//                     color: kGreenColor,
//                     fontWeight: FontWeight.normal,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(HeroiconsOutline.phone, color: kBlackColor),
//             onPressed: () {
//               // TODO: Implement call functionality
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text("Calling +251 967 575757..."),
//                   backgroundColor: kSecondaryColor,
//                 ),
//               );
//             },
//           ),
//           IconButton(
//             icon: Icon(HeroiconsOutline.ellipsisVertical, color: kBlackColor),
//             onPressed: () {
//               _showOptionsMenu(context);
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: _messages.isEmpty
//                 ? _buildEmptyState()
//                 : ListView.builder(
//                     controller: _scrollController,
//                     padding: EdgeInsets.only(
//                       top: getProportionateScreenHeight(kDefaultPadding),
//                       bottom: getProportionateScreenHeight(kDefaultPadding),
//                     ),
//                     itemCount: _messages.length + (_isLoading ? 1 : 0),
//                     itemBuilder: (context, index) {
//                       if (index == _messages.length && _isLoading) {
//                         return _buildTypingIndicator();
//                       }
//                       return ChatBubble(message: _messages[index]);
//                     },
//                   ),
//           ),
//           if (_showQuickReplies && _messages.length <= 1)
//             QuickReplies(onReplyTap: _handleQuickReply),
//           ChatInput(
//             controller: _messageController,
//             onSend: _handleSendMessage,
//             isLoading: _isLoading,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             width: getProportionateScreenWidth(100),
//             height: getProportionateScreenWidth(100),
//             decoration: BoxDecoration(
//               color: kSecondaryColor.withValues(alpha: 0.1),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               Icons.support_agent_rounded,
//               size: getProportionateScreenWidth(50),
//               color: kSecondaryColor,
//             ),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
//           Text(
//             "Welcome to ZMall Support",
//             style: TextStyle(
//               fontSize: getProportionateScreenWidth(18),
//               fontWeight: FontWeight.bold,
//               color: kBlackColor,
//             ),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
//           Padding(
//             padding: EdgeInsets.symmetric(
//               horizontal: getProportionateScreenWidth(kDefaultPadding * 3),
//             ),
//             child: Text(
//               "We're here to help! Ask us anything about your orders, deliveries, or account.",
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: getProportionateScreenWidth(14),
//                 color: kGreyColor,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTypingIndicator() {
//     return Padding(
//       padding: EdgeInsets.symmetric(
//         horizontal: getProportionateScreenWidth(kDefaultPadding),
//         vertical: getProportionateScreenHeight(kDefaultPadding / 3),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: getProportionateScreenWidth(32),
//             height: getProportionateScreenWidth(32),
//             decoration: BoxDecoration(
//               color: kSecondaryColor.withValues(alpha: 0.1),
//               shape: BoxShape.circle,
//               border: Border.all(
//                 color: kSecondaryColor.withValues(alpha: 0.3),
//                 width: 1,
//               ),
//             ),
//             child: Icon(
//               Icons.support_agent_rounded,
//               color: kSecondaryColor,
//               size: getProportionateScreenWidth(18),
//             ),
//           ),
//           SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),
//           Container(
//             padding: EdgeInsets.symmetric(
//               horizontal: getProportionateScreenWidth(kDefaultPadding),
//               vertical: getProportionateScreenHeight(kDefaultPadding / 1.5),
//             ),
//             decoration: BoxDecoration(
//               color: kWhiteColor,
//               borderRadius: BorderRadius.circular(kDefaultPadding),
//               boxShadow: [
//                 BoxShadow(
//                   color: kBlackColor.withValues(alpha: 0.08),
//                   blurRadius: 8,
//                   offset: Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 _buildDot(0),
//                 SizedBox(width: 4),
//                 _buildDot(1),
//                 SizedBox(width: 4),
//                 _buildDot(2),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDot(int index) {
//     return TweenAnimationBuilder<double>(
//       tween: Tween(begin: 0.0, end: 1.0),
//       duration: Duration(milliseconds: 600),
//       builder: (context, value, child) {
//         return Opacity(
//           opacity: (value + index * 0.3) % 1.0,
//           child: Container(
//             width: 8,
//             height: 8,
//             decoration: BoxDecoration(
//               color: kGreyColor,
//               shape: BoxShape.circle,
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _showOptionsMenu(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: kPrimaryColor,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(
//           top: Radius.circular(kDefaultPadding),
//         ),
//       ),
//       builder: (context) => SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: Icon(HeroiconsOutline.trash, color: kBlackColor),
//               title: Text("Clear Chat"),
//               onTap: () {
//                 Navigator.pop(context);
//                 setState(() {
//                   _messages.clear();
//                   _showQuickReplies = true;
//                 });
//                 _initializeChat();
//               },
//             ),
//             ListTile(
//               leading: Icon(HeroiconsOutline.phone, color: kBlackColor),
//               title: Text("Call Support"),
//               subtitle: Text("+251967575757"),
//               onTap: () {
//                 Navigator.pop(context);
//                 // TODO: Implement call
//               },
//             ),
//             ListTile(
//               leading: Icon(HeroiconsOutline.envelope, color: kBlackColor),
//               title: Text("Email Support"),
//               subtitle: Text("info@zmallshop.com"),
//               onTap: () {
//                 Navigator.pop(context);
//                 // TODO: Implement email
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
