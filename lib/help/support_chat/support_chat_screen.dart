import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zmall/help/support_chat/components/product_detail_sheet.dart';
import 'package:zmall/help/support_chat/components/store_menu_sheet.dart';
import 'package:zmall/models/chat_message.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/profile/components/profile_list_tile.dart';
import 'package:zmall/help/support_chat/service/chat_service.dart';
import 'package:zmall/help/support_chat/service/mock_data.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/cart/cart_screen.dart';
import 'package:zmall/help/support_chat/components/chat_bubble.dart';
import 'package:zmall/help/support_chat/components/chat_input.dart';
import 'package:zmall/help/support_chat/components/quick_replies.dart';
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
  final Map<String, List<MockProduct>> _messageProducts = {};
  final Map<String, MockStore?> _messageStores = {};
  final Map<String, List<MockStore>> _messageStoreLists =
      {}; // Store lists from backend
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

  ///
  // String userLastOrder = '';
  String?
  userLastOrderId; // Store as String (API returns int, converted to String)
  var userOrderStatus;

  /// Session ID returned by the /chat_test backend — sent back on every
  /// subsequent turn so the server can maintain conversation context.
  String? _sessionId;

  String get userName {
    if (userData != null && userData['user'] != null) {
      return userData['user']['name'] ?? 'Customer';
    }
    return 'Customer';
  }

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
        }
      });

      _loadChatHistory();
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

  void _addBotMessage(
    String message, {
    bool showCartAction = false,
    List<MockProduct>? productMatches,
    MockStore? storeMatch,
    List<MockStore>? storeMatches, // Multiple stores from backend
  }) {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    if (productMatches != null) {
      _messageProducts[messageId] = productMatches;
    }
    if (storeMatch != null) {
      _messageStores[messageId] = storeMatch;
    }
    if (storeMatches != null && storeMatches.isNotEmpty) {
      _messageStores[messageId] =
          storeMatches.first; // Store first for backward compatibility
      _messageStoreLists[messageId] = storeMatches; // Store all stores
    }

    setState(() {
      _messages.add(
        ChatMessage(
          id: messageId,
          message: _sanitizeBotMessage(message),
          isUser: false,
          timestamp: DateTime.now(),
          showCartAction: showCartAction,
        ),
      );
    });
    _scrollToBottom();
    _saveChatHistory(); // Save after adding message
  }

  /// The backend sometimes returns raw error texts like "Something went
  /// wrong". Replace those with the friendly daily-token message so users
  /// never see a raw backend failure in the chat.
  String _sanitizeBotMessage(String message) {
    final lower = message.toLowerCase();

    // Allow friendly error messages through unchanged
    if (lower.contains('taking too long') ||
        lower.contains('no internet') ||
        lower.contains('check your network') ||
        lower.contains('server returned an error') ||
        lower.contains('temporarily unavailable')) {
      return message;
    }

    if (lower.contains('went wrong') ||
        lower.contains('something is wrong') ||
        lower.contains('something wrong') ||
        lower.contains('error occurred') ||
        lower.contains('internal server') ||
        lower.contains('failed to get response')) {
      return 'You finished your daily token.';
    }

    // Replace old raw timeout string with the friendly variant
    if (lower.contains('connection timed out')) {
      return 'The server is taking too long to respond. Please try again in a moment. ⏳';
    }

    return message;
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

    debugPrint("🚀 [CHAT SCREEN] _handleSendMessage called with: $message");
    debugPrint("🚀 [CHAT SCREEN] Current userId: $userId");
    debugPrint(
      "🚀 [CHAT SCREEN] Current serverToken: ${serverToken.isNotEmpty ? 'Present' : 'Missing'}",
    );

    _addUserMessage(message);
    _messageController.clear();

    // Fetch bot response from backend
    debugPrint("🚀 [CHAT SCREEN] Calling _fetchBotResponse");
    _fetchBotResponse(message);
  }

  void _handleStoreMenuRequest(MockStore store) {
    _messageController.text = 'Show me the menu for ${store.name}';
    _handleSendMessage();
  }

  void _handleStoreMenuRequestWithProducts(
    MockStore store,
    List<MockProduct> products,
  ) {
    StoreMenuSheet.show(context, store: store, products: products);
  }

  void _handleQuickReply(String reply) {
    _addUserMessage(reply);
    setState(() {
      _showQuickReplies = false;
    });
    _fetchBotResponse(reply);
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

    debugPrint("🚀 [CHAT SCREEN] _fetchBotResponse called");
    debugPrint("🚀 [CHAT SCREEN] User ID: $userId");
    debugPrint(
      "🚀 [CHAT SCREEN] Server Token: ${serverToken.isNotEmpty ? 'Present' : 'Missing'}",
    );
    debugPrint("🚀 [CHAT SCREEN] User Message: $userMessage");

    try {
      if (userId.isEmpty || serverToken.isEmpty) {
        debugPrint(
          "⚠️ [CHAT SCREEN] Missing credentials - userId: $userId, serverToken: $serverToken",
        );
        if (mounted) {
          _addBotMessage(
            "I'm here to help with your ZMall orders, menus, and deliveries! 😊",
          );
        }
        return;
      }

      debugPrint("🚀 [CHAT SCREEN] Calling ChatService.sendMessage...");
      final response = await ChatService.sendMessage(
        message: userMessage,
        context: context,
        userId: userId,
        serverToken: serverToken,
        userLocation: userLocation,
        orderId: userLastOrderId,
        sessionId: _sessionId,
      );

      debugPrint("🚀 [CHAT SCREEN] Backend response received: $response");

      if (!mounted) return;

      if (response != null && response['error'] != true) {
        // Update session ID if provided by backend
        if (response['session_id'] != null) {
          _sessionId = response['session_id'].toString();
        }

        // ChatService has already normalized the reply into JSON
        // (message + browse_results / products / stores).
        final rawMessage = response['message']?.toString().trim() ?? '';
        final botMessage = rawMessage.isNotEmpty
            ? rawMessage
            : "I'm here to help with your ZMall orders, menus, and deliveries! 😊";

        debugPrint("🚀 [CHAT SCREEN] Bot message: $botMessage");

        // Check if backend returned product data in a structured format.
        // Support the real backend contract used by /chat_test:
        //   response['browse_results'] = { 'type': 'items', 'store_name': 'SAVOR', 'results': [...] }
        final browseResults = response['browse_results'];
        if (browseResults is Map && browseResults['results'] is List) {
          final typedBrowseResults = Map<String, dynamic>.from(browseResults);
          final parsedProducts = parseBackendBrowseResults(typedBrowseResults);
          if (parsedProducts.isNotEmpty) {
            debugPrint(
              "🚀 [CHAT SCREEN] Backend browse_results returned ${parsedProducts.length} products",
            );

            final productMatches = parsedProducts;
            final storeName =
                browseResults['store_name']?.toString() ?? 'Unknown Store';

            // Create a MockStore for the menu display
            final menuStore = MockStore(
              id: 'backend_${storeName.hashCode}',
              name: storeName,
              category: 'Restaurant',
              location: 'Available now',
              rating: 0.0,
              hasRating: false,
              deliveryTime: 'Delivery available',
              deliveryFee: 0.0,
              logoText: storeName.substring(0, storeName.length.clamp(0, 8)),
              themeColor: const Color(0xFF237249),
            );

            // Use a clean, short message instead of the unformatted backend response
            final cleanMessage = "Here's the menu for $storeName:";

            _addBotMessage(
              cleanMessage,
              showCartAction: _shouldShowCartAction(cleanMessage),
              productMatches: productMatches,
              storeMatch: menuStore,
            );

            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }

        if (response['products'] != null ||
            response['items'] != null ||
            response['menu'] != null) {
          final backendProducts =
              response['products'] ?? response['items'] ?? response['menu'];
          if (backendProducts is List && backendProducts.isNotEmpty) {
            debugPrint(
              "🚀 [CHAT SCREEN] Backend returned ${backendProducts.length} products",
            );
            final parsedProducts = parseSimpleBackendProducts(backendProducts);
            if (parsedProducts.isNotEmpty) {
              // Use a clean message instead of the unformatted backend response
              final cleanMessage = "Here are some items for you:";

              _addBotMessage(
                cleanMessage,
                showCartAction: _shouldShowCartAction(cleanMessage),
                productMatches: parsedProducts,
              );
              if (mounted) setState(() => _isLoading = false);
              return;
            }
          }
        }

        // Check if backend returned store data in structured format
        if (response['stores'] != null || response['companies'] != null) {
          final backendStores = response['stores'] ?? response['companies'];
          if (backendStores is List && backendStores.isNotEmpty) {
            debugPrint(
              "🚀 [CHAT SCREEN] Backend returned ${backendStores.length} stores",
            );

            // Convert backend stores to MockStore objects
            final mockStores = backendStores.map((store) {
              final name =
                  store['name']?.toString() ??
                  store['company_name']?.toString() ??
                  '';
              final distance = store['distance']?.toString() ?? '';
              return MockStore(
                id: 'backend_${name.hashCode}',
                name: name,
                category: 'Restaurant',
                location: distance.isNotEmpty ? '$distance away' : 'Available',
                rating: 0.0,
                hasRating: false,
                deliveryTime: 'Delivery available',
                deliveryFee: 0.0,
                logoText: name.substring(0, name.length.clamp(0, 8)),
                themeColor: const Color(0xFF237249),
              );
            }).toList();

            _addBotMessage(
              "Here are some open stores near you:",
              storeMatches: mockStores,
              showCartAction: _shouldShowCartAction(
                "Here are some open stores near you:",
              ),
            );
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }

        _addBotMessage(
          botMessage,
          showCartAction: _shouldShowCartAction(botMessage),
        );
      } else {
        final errorMessage =
            response?['message'] ?? "Something went wrong. Please try again.";
        debugPrint("⚠️ [CHAT SCREEN] Backend error: $errorMessage");
        _addBotMessage(errorMessage);
      }
    } catch (e) {
      debugPrint("❌ [CHAT SCREEN] Error calling chat API: $e");
      if (mounted) {
        _addBotMessage("Connection timed out. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAddProductToCart(MockProduct product) async {
    await addMockProductsToCart([product]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'View Cart',
            onPressed: () => Navigator.pushNamed(context, CartScreen.routeName),
          ),
        ),
      );
    }
  }

  Future<void> _handleViewCartForMessage(int messageIndex) async {
    final message = _messages[messageIndex];
    List<MockProduct> products = _messageProducts[message.id] ?? const [];
    if (products.isEmpty && messageIndex > 0) {
      final prevMessage = _messages[messageIndex - 1];
      products = _messageProducts[prevMessage.id] ?? const [];
    }

    if (products.isNotEmpty) {
      await addMockProductsToCart(products);
    }

    if (mounted) {
      Navigator.pushNamed(context, CartScreen.routeName);
    }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            HeroiconsOutline.chevronLeft,
            color: kBlackColor,
            size: getProportionateScreenWidth(22),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: getProportionateScreenWidth(34),
              height: getProportionateScreenWidth(34),
              decoration: BoxDecoration(
                color: kSecondaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'Z',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: getProportionateScreenWidth(15),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(width: getProportionateScreenWidth(10)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZMall AI',
                  style: TextStyle(
                    fontSize: getProportionateScreenWidth(15),
                    fontWeight: FontWeight.w700,
                    color: kBlackColor,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: getProportionateScreenWidth(7),
                      height: getProportionateScreenWidth(7),
                      decoration: const BoxDecoration(
                        color: kGreenColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: getProportionateScreenWidth(5)),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11),
                        color: kGreyColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kGreyColor.withValues(alpha: 0.15)),
        ),
        actions: [
          IconButton(
            icon: Icon(
              HeroiconsOutline.shoppingCart,
              color: kBlackColor,
              size: getProportionateScreenWidth(22),
            ),
            onPressed: () => Navigator.pushNamed(context, CartScreen.routeName),
          ),
          IconButton(
            icon: Icon(
              HeroiconsOutline.ellipsisVertical,
              color: kBlackColor,
              size: getProportionateScreenWidth(22),
            ),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _messages.length <= 1
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            top: getProportionateScreenHeight(kDefaultPadding),
                            bottom: getProportionateScreenHeight(
                              kDefaultPadding,
                            ),
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
                            // Products explicitly attached to this message by the backend
                            final messageProducts =
                                !message.isUser &&
                                    _messageProducts.containsKey(message.id)
                                ? _messageProducts[message.id] ??
                                      const <MockProduct>[]
                                : <MockProduct>[];

                            // Store explicitly attached to this message by the backend
                            final messageStore =
                                !message.isUser &&
                                    _messageStores.containsKey(message.id)
                                ? _messageStores[message.id]
                                : null;

                            // Only use real backend-attached products — no mock fallback
                            final matchedProducts = messageProducts;

                            // isStoreReply: message has a real backend store attached
                            final isStoreReply =
                                !message.isUser && messageStore != null;

                            // Only use real backend-attached store — no mock fallback
                            final matchedStore = messageStore;

                            // Show store carousel if we have backend store list data
                            final hasBackendStores =
                                _messageStoreLists[message.id] != null &&
                                _messageStoreLists[message.id]!.isNotEmpty;
                            final isStoreOnly =
                                (isStoreReply && matchedProducts.isEmpty) ||
                                hasBackendStores;

                            final storeProducts = isStoreOnly
                                ? <MockProduct>[]
                                : matchedProducts;
                            final showProducts =
                                !isStoreReply || matchedProducts.isNotEmpty;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (dayHeader != null) dayHeader,
                                _AnimatedMessage(
                                  child: ChatBubble(
                                    message: message,
                                    matchedProducts: storeProducts,
                                    matchedStore: matchedStore,
                                    matchedStores:
                                        _messageStoreLists[message
                                            .id], // Use stored store lists from backend
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
                                    onAddToCart: _handleAddProductToCart,
                                    onMenuRequested: _handleStoreMenuRequest,
                                    onMenuRequestedWithProducts:
                                        (store, products) {
                                          _handleStoreMenuRequestWithProducts(
                                            store,
                                            products,
                                          );
                                        },
                                    onProductTap: (product) => _openMockProduct(
                                      product,
                                      products: storeProducts.isNotEmpty
                                          ? storeProducts
                                          : null,
                                    ),
                                    showProducts: showProducts,
                                    isStoreOnly: isStoreOnly,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                if (_showQuickReplies && _messages.length > 1)
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
                  _showQuickReplies ? 200 : 100,
                ),
                right: getProportionateScreenWidth(kDefaultPadding),
                child: Material(
                  elevation: 4,
                  shape: const CircleBorder(),
                  color: kSecondaryColor,
                  child: InkWell(
                    onTap: () {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: getProportionateScreenWidth(38),
                      height: getProportionateScreenWidth(38),
                      alignment: Alignment.center,
                      child: Icon(
                        HeroiconsSolid.chevronDown,
                        color: kPrimaryColor,
                        size: getProportionateScreenWidth(22),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
    );
  }

  /// Opens the product detail bottom sheet — no page navigation.
  void _openMockProduct(MockProduct product, {List<MockProduct>? products}) {
    ProductDetailSheet.show(
      context,
      product: product,
      onAddToCart: (p, qty) async {
        final items = List<MockProduct>.filled(qty, p);
        await addMockProductsToCart(items);
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$qty × ${p.name} added to cart'),
            backgroundColor: kBlackColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            action: SnackBarAction(
              label: 'View Cart',
              textColor: kSecondaryColor,
              onPressed: () =>
                  Navigator.pushNamed(context, CartScreen.routeName),
            ),
          ),
        );
      },
    );
  }

  /// Returns a day separator widget when [message] starts a new day
  /// compared to [previous], otherwise null (no separator needed).
  Widget? _buildDaySeparator(ChatMessage message, ChatMessage? previous) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      message.timestamp.year,
      message.timestamp.month,
      message.timestamp.day,
    );

    // Skip separator if previous message is on the same day
    if (previous != null) {
      final previousDate = DateTime(
        previous.timestamp.year,
        previous.timestamp.month,
        previous.timestamp.day,
      );
      if (messageDate == previousDate) return null;
    }

    final difference = today.difference(messageDate).inDays;
    String label;
    if (messageDate == today) {
      label = 'Today';
    } else if (difference == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(messageDate);
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: getProportionateScreenHeight(kDefaultPadding / 2),
        horizontal: getProportionateScreenWidth(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              color: kGreyColor.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: getProportionateScreenWidth(11),
                color: kGreyColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              color: kGreyColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final suggestions = [
      {'emoji': '🏪', 'label': 'Stores near me', 'query': 'Stores near me'},
      {'emoji': '🍕', 'label': 'Show me pizza', 'query': 'Show me pizza'},
      {'emoji': '🍔', 'label': 'Show me burgers', 'query': 'Show me burgers'},
      {'emoji': '☕', 'label': 'Show me coffee', 'query': 'Show me coffee'},
      {'emoji': '📦', 'label': 'Track my order', 'query': 'Where is my order?'},
      {
        'emoji': '🔥',
        'label': "Today's offers",
        'query': "What are today's special offers?",
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(20),
        vertical: getProportionateScreenHeight(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ZMall AI identity ──────────────────────────────────────
          Row(
            children: [
              Container(
                width: getProportionateScreenWidth(44),
                height: getProportionateScreenWidth(44),
                decoration: BoxDecoration(
                  color: kSecondaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'Z',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: getProportionateScreenWidth(20),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(width: getProportionateScreenWidth(12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ZMall AI',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(15),
                      fontWeight: FontWeight.w700,
                      color: kBlackColor,
                    ),
                  ),
                  Text(
                    'Your food & order assistant',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(11.5),
                      color: kGreyColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: getProportionateScreenHeight(28)),

          // ── Heading ──────────────────────────────────────────────────
          Text(
            'How can I help\nyou today?',
            style: TextStyle(
              fontSize: getProportionateScreenWidth(26),
              fontWeight: FontWeight.w800,
              color: kBlackColor,
              height: 1.2,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(8)),
          Text(
            'Ask me about food, orders, delivery, or payments.',
            style: TextStyle(
              fontSize: getProportionateScreenWidth(13.5),
              color: kGreyColor,
              height: 1.4,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(28)),

          // ── Section label ─────────────────────────────────────────────
          Text(
            'Suggestions',
            style: TextStyle(
              fontSize: getProportionateScreenWidth(11.5),
              fontWeight: FontWeight.w600,
              color: kGreyColor,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(12)),

          // ── Suggestion chips ──────────────────────────────────────────
          Wrap(
            spacing: getProportionateScreenWidth(8),
            runSpacing: getProportionateScreenHeight(10),
            children: suggestions.map((s) {
              return GestureDetector(
                onTap: () => _handleQuickReply(s['query']!),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(14),
                    vertical: getProportionateScreenHeight(9),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: kGreyColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s['emoji']!,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(14),
                        ),
                      ),
                      SizedBox(width: getProportionateScreenWidth(6)),
                      Text(
                        s['label']!,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(13),
                          fontWeight: FontWeight.w500,
                          color: kBlackColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: getProportionateScreenHeight(20)),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getProportionateScreenWidth(16),
        vertical: getProportionateScreenHeight(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: getProportionateScreenWidth(18),
                height: getProportionateScreenWidth(18),
                decoration: BoxDecoration(
                  color: kSecondaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'Z',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: getProportionateScreenWidth(9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(width: getProportionateScreenWidth(6)),
              Text(
                'ZMall AI',
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(11.5),
                  fontWeight: FontWeight.w600,
                  color: kGreyColor,
                ),
              ),
            ],
          ),
          SizedBox(height: getProportionateScreenHeight(5)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(16),
              vertical: getProportionateScreenHeight(13),
            ),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: kGreyColor.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: const _TypingDots(),
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
        final double bounce =
            -3.5 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);
        final double opacity =
            0.35 + 0.65 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, bounce),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(
                  alpha: opacity.clamp(0.25, 0.75),
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
