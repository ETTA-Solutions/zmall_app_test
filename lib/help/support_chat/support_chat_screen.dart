import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zmall/help/support_chat/components/chat_bot_icon.dart';
import 'package:zmall/help/support_chat/components/glowing_ai_orb.dart';
import 'package:zmall/help/support_chat/screens/mock_product_screen.dart';
import 'package:zmall/help/support_chat/screens/mock_store_list_screen.dart';
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
import 'package:zmall/help/support_chat/components/support_chat_canvas.dart';
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

  ///
  // String userLastOrder = '';
  String?
  userLastOrderId; // Store as String (API returns int, converted to String)
  var userOrderStatus;

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
    if (lower.contains('went wrong') ||
        lower.contains('something is wrong') ||
        lower.contains('something wrong') ||
        lower.contains('error occurred') ||
        lower.contains('internal server') ||
        lower.contains('failed to get response')) {
      return 'You finished your daily token.';
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

    // Store / restaurant discovery via free text → open the store list
    final lower = message.toLowerCase();
    if (lower.contains('store') ||
        lower.contains('restaurant') ||
        lower.contains('explore store') ||
        lower.contains('browse store') ||
        lower.contains('near me') ||
        lower.contains('show me store')) {
      _messageController.clear();
      _openStoreList();
      return;
    }

    _addUserMessage(message);
    _messageController.clear();

    // Fetch real bot response from API
    _fetchBotResponse(message);
  }

  void _handleQuickReply(String reply) {
    // Store / restaurant discovery → open the immersive store list first
    final lowerReply = reply.toLowerCase();
    if (lowerReply.contains('store') ||
        lowerReply.contains('restaurant') ||
        lowerReply.contains('explore') ||
        lowerReply.contains('browse') ||
        lowerReply.contains('near me') ||
        lowerReply.contains('shop')) {
      _openStoreList();
      return;
    }

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

  List<Map<String, String>> _getConversationHistory() {
    return _messages
        .map(
          (msg) => {
            'role': msg.isUser ? 'user' : 'model',
            'content': msg.message,
          },
        )
        .toList();
  }

  Future<void> _fetchBotResponse(String userMessage) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate realistic chatbot thinking delay (2-4 seconds random)
      final randomDelay = 2000 + math.Random().nextInt(2001); // 2000-4000ms
      await Future.delayed(Duration(milliseconds: randomDelay));
      if (!mounted) return;

      final activeOrderId =
          (userLastOrderId != null && userLastOrderId!.isNotEmpty)
          ? userLastOrderId
          : mockActiveOrder.orderId;
      final activeOrderStatus = userOrderStatus ?? mockActiveOrder.status;

      // Instant local mock engine response
      final botMessage = getOfflineMockResponse(
        userMessage,
        orderId: activeOrderId,
        status: activeOrderStatus,
      );

      if (!mounted) return;
      _addBotMessage(
        botMessage,
        showCartAction: _shouldShowCartAction(botMessage),
      );
    } catch (e) {
      debugPrint("Error generating mock response: $e");
      if (mounted) {
        _addBotMessage(
          "I'm here to help with your ZMall orders, menus, and deliveries! 😊",
        );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'View Cart',
            onPressed: () =>
                Navigator.pushNamed(context, CartScreen.routeName),
          ),
        ),
      );
    }
  }

  Future<void> _handleViewCartForMessage(int messageIndex) async {
    final message = _messages[messageIndex];
    List<MockProduct> products = searchMockProducts(message.message);
    if (products.isEmpty && messageIndex > 0) {
      products = searchMockProducts(_messages[messageIndex - 1].message);
    }

    if (products.isEmpty) {
      // Default to the first product if cart action tapped without explicit item
      products = [mockProducts.first];
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
      backgroundColor: kPrimaryColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: EdgeInsets.only(left: getProportionateScreenWidth(16)),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: getProportionateScreenWidth(38),
                height: getProportionateScreenWidth(38),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kSecondaryColor.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kSecondaryColor.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    HeroiconsOutline.chevronLeft,
                    color: kBlackColor,
                    size: getProportionateScreenWidth(18),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Container(
          padding: EdgeInsets.symmetric(
            horizontal: getProportionateScreenWidth(14),
            vertical: getProportionateScreenHeight(7),
          ),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: kSecondaryColor.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: kSecondaryColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: getProportionateScreenWidth(8),
                height: getProportionateScreenWidth(8),
                decoration: BoxDecoration(
                  color: kGreenColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kGreenColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              SizedBox(width: getProportionateScreenWidth(8)),
              Text(
                "ZMall AI",
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(14),
                  fontWeight: FontWeight.w800,
                  color: kBlackColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: getProportionateScreenWidth(8)),
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, CartScreen.routeName),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: getProportionateScreenWidth(38),
                      height: getProportionateScreenWidth(38),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kSecondaryColor.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kSecondaryColor.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          HeroiconsOutline.shoppingCart,
                          color: kBlackColor,
                          size: getProportionateScreenWidth(18),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '2',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: getProportionateScreenWidth(9),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: getProportionateScreenWidth(16)),
            child: Center(
              child: GestureDetector(
                onTap: () => _showOptionsMenu(context),
                child: Container(
                  width: getProportionateScreenWidth(38),
                  height: getProportionateScreenWidth(38),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kSecondaryColor.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      HeroiconsOutline.ellipsisVertical,
                      color: kBlackColor,
                      size: getProportionateScreenWidth(18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SupportChatCanvas(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top + kToolbarHeight),
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
                          // Pre-compute matched products from the user's query
                          final matchedProducts = !message.isUser && index > 0
                              ? searchMockProducts(_messages[index - 1].message)
                              : <MockProduct>[];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (dayHeader != null) dayHeader,
                              _AnimatedMessage(
                                child: ChatBubble(
                                  message: message,
                                  matchedProducts: matchedProducts,
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
                                  onProductTap: (product) => _openMockProduct(
                                    product,
                                    products: matchedProducts.isNotEmpty
                                        ? matchedProducts
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                ),
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
      ),
    );
  }

  /// Opens the immersive store-list screen (shows all mock stores with a
  /// "Menu" button on each card that slides into the product viewer).
  void _openStoreList() {
    Navigator.push(
      context,
      SlideStoreListPageRoute(page: const MockStoreListScreen()),
    );
  }

  void _openMockProduct(
    MockProduct product, {
    List<MockProduct>? products,
  }) {
    final list = (products != null && products.isNotEmpty)
        ? products
        : <MockProduct>[product];
    var index = list.indexWhere((p) => p.id == product.id);
    if (index < 0) index = 0;

    Navigator.push(
      context,
      SlideProductPageRoute(
        page: MockProductScreen(
          products: list,
          initialIndex: index,
        ),
      ),
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
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: kSecondaryColor.withValues(alpha: 0.12),
              thickness: 1,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(12),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(10),
                vertical: getProportionateScreenHeight(4),
              ),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kSecondaryColor.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: getProportionateScreenWidth(11),
                  fontWeight: FontWeight.w600,
                  color: kGreyColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: kSecondaryColor.withValues(alpha: 0.12),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final cravings = [
      {
        "emoji": "🏪",
        "label": "Explore nearby stores",
        "query": "Explore stores near me",
      },
      {"emoji": "🍕", "label": "I'm craving pizza", "query": "Show me pizza"},
      {
        "emoji": "🍔",
        "label": "Double cheese burger",
        "query": "Show me burgers",
      },
      {
        "emoji": "🍗",
        "label": "Crispy chicken wings",
        "query": "Show me chicken wings and fries",
      },
      {
        "emoji": "☕",
        "label": "Hot Ethiopian coffee",
        "query": "Show me coffee",
      },
      {
        "emoji": "📦",
        "label": "Where is my order?",
        "query": "Where is my order?",
      },
      {
        "emoji": "🔥",
        "label": "Today's special offers",
        "query": "What are today's special offers?",
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        vertical: getProportionateScreenHeight(20),
        horizontal: getProportionateScreenWidth(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: getProportionateScreenWidth(130),
            height: getProportionateScreenWidth(130),
            child: GlowingAiOrb(
              size: getProportionateScreenWidth(100),
              compact: true,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(20)),

          // ── Heading ──────────────────────────────────────────────────
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [kBlackColor, kSecondaryColor.withValues(alpha: 0.85)],
            ).createShader(bounds),
            child: Text(
              "Hi, I'm ZMall AI 🤖",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getProportionateScreenWidth(22),
                fontWeight: FontWeight.w900,
                color: kPrimaryColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(8)),
          Text(
            "Tell me what you're craving, and I'll find the\nperfect meal for you.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: getProportionateScreenWidth(13),
              color: kGreyColor,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(28)),

          // ── Explore Stores hero button ────────────────────────────────
          GestureDetector(
            onTap: _openStoreList,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(18),
                vertical: getProportionateScreenHeight(16),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kSecondaryColor, kSecondaryColor.withValues(alpha: 0.80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kSecondaryColor.withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: getProportionateScreenWidth(42),
                    height: getProportionateScreenWidth(42),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '🏪',
                        style: TextStyle(fontSize: getProportionateScreenWidth(20)),
                      ),
                    ),
                  ),
                  SizedBox(width: getProportionateScreenWidth(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore Nearby Stores',
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(14),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: getProportionateScreenHeight(3)),
                        Text(
                          'Browse menus & add items to cart',
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(11.5),
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    HeroiconsOutline.chevronRight,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: getProportionateScreenWidth(18),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(20)),

          // ── Quick Craving Pills ──────────────────────────────────────
          Wrap(
            spacing: getProportionateScreenWidth(8),
            runSpacing: getProportionateScreenHeight(10),
            alignment: WrapAlignment.center,
            children: cravings.map((c) {
              return GestureDetector(
                onTap: () => _handleQuickReply(c["query"]!),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(14),
                    vertical: getProportionateScreenHeight(10),
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: kSecondaryColor.withValues(alpha: 0.12),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kSecondaryColor.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c["emoji"]!,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(14),
                        ),
                      ),
                      SizedBox(width: getProportionateScreenWidth(6)),
                      Flexible(
                        child: Text(
                          c["label"]!,
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(12.5),
                            fontWeight: FontWeight.w600,
                            color: kBlackColor,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
          SizedBox(width: getProportionateScreenWidth(8)),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(14),
                vertical: getProportionateScreenHeight(12),
              ),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(22),
                ),
                border: Border.all(
                  color: kSecondaryColor.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kSecondaryColor.withValues(alpha: 0.08),
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
                  Flexible(
                    child: Text(
                      "ZMall Assistant is thinking",
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(11.5),
                        color: kGreyColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: getProportionateScreenWidth(8)),
                  const _TypingDots(),
                ],
              ),
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
