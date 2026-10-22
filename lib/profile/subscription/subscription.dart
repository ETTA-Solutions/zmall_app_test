import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/profile/subscription/subscription_kifiya/inapp_subscription_payment.dart';
import 'package:zmall/profile/subscription/subscription_kifiya/ussd_subscription_payment.dart';
import 'package:zmall/widgets/custom_back_button.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/services/core_services.dart';
import 'package:flutter/cupertino.dart';

/// Compatibility helper to provide inter text styles without external package dependency
class GoogleFonts {
  static TextStyle inter({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    dynamic fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return TextStyle(
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }
}

class SubscriptionScreen extends StatefulWidget {
  static String routeName = '/subscription';
  final userData;

  const SubscriptionScreen({super.key, this.userData});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  var userData;

  // ── Subscription state from /api/user/get_subscription_detail ──
  bool _subscriptionEnabled = true; // show UI while loading
  num _subscriptionPrice = 1; // test 1 birr
  int _subscriptionDurationDays = 30;
  bool _isActive = false;
  DateTime? _subscriptionExpiry;

  // UI state
  bool _loading = true; // start true — we fetch before showing
  bool _isSubscribed = false; // kept for backward-compat with existing views
  bool _isCollapsed = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late ScrollController _scrollController;

  // Single plan driven by the server price
  List<Map<String, dynamic>> get _subscriptionPlans => [
    {
      'title': 'Monthly Premium',
      'subtitle': 'Free Delivery on every order',
      'description': 'Pay once, enjoy free delivery for $_subscriptionDurationDays days',
      'benefits': [
        'Free delivery on all orders',
        'Priority service',
        'Exclusive member offers',
      ],
      'price': _subscriptionPrice,
      'currency': 'ETB',
      'interval': 'month',
      'isPopular': true,
      'gradient': [Color(0xFF4A3298), Color(0xFF6A52B8)],
      'accentColor': Color(0xFF4A3298),
    },
  ];

  @override
  void initState() {
    super.initState();
    userData = widget.userData;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.hasClients) {
          setState(() {
            _isCollapsed = _scrollController.offset > kToolbarHeight;
          });
        }
      });

    // Load subscription state from the backend
    _loadSubscriptionDetail();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── API: load subscription detail ────────────────────────────────────────
  Future<void> _loadSubscriptionDetail() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final data = await CoreServices.getSubscriptionDetail(
      userId: userData['user']['_id'],
      serverToken: userData['user']['server_token'],
      context: context,
    );

    if (!mounted) return;

    debugPrint("subscription detail response: $data");
    if (data != null && data['success'] == true) {
      final bool enabled = true;
      final bool active = data['is_active'] == true;
      final DateTime? expiry = data['subscription_expiry'] != null
          ? DateTime.tryParse(data['subscription_expiry'])
          : null;

      setState(() {
        _subscriptionEnabled = enabled;
        _subscriptionPrice = 1; // test 1 birr
        _subscriptionDurationDays =
            (data['subscription_duration_days'] ?? 30) as int;
        _isActive = active;
        _subscriptionExpiry = expiry;
        _isSubscribed = active;
        _loading = false;
      });

      if (enabled) _animationController.forward();
    } else {
      // Network error — show whatever we can from cached userData
      _fallbackToLegacyData();
    }
  }

  /// Falls back to reading the old subscritption_data field when the new
  /// endpoint is unreachable (e.g. network error).
  void _fallbackToLegacyData() {
    final sub = userData['user']['subscritption_data'];
    final now = DateTime.now();
    final dateOfSub = sub != null && sub['date_of_subscription'] != null
        ? DateTime.tryParse(sub['date_of_subscription']) ?? now
        : now;
    final amount = (sub != null ? sub['subscription_amount'] ?? 0 : 0) as num;
    final planDay = amount == 100 ? 30 : 30; // default to 30
    final expiry = dateOfSub.add(Duration(days: planDay));
    final isSubscribed = sub != null && sub['is_user_subscribed'] == true;
    final isExpired = now.isAfter(expiry);

    if (mounted) {
      setState(() {
        _subscriptionEnabled = true;
        _subscriptionPrice = 1; // test 1 birr
        _subscriptionDurationDays = planDay;
        _isActive = isSubscribed && !isExpired;
        _subscriptionExpiry = expiry;
        _isSubscribed = isSubscribed && !isExpired;
        _loading = false;
      });
    }
  }

  // ── API: poll after payment until is_active == true ──────────────────────
  Future<void> _pollUntilActive() async {
    const maxAttempts = 20;
    const interval = Duration(seconds: 3);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(interval);
      if (!mounted) return;

      final data = await CoreServices.getSubscriptionDetail(
        userId: userData['user']['_id'],
        serverToken: userData['user']['server_token'],
        context: context,
      );

      if (!mounted) return;

      if (data != null &&
          data['success'] == true &&
          data['is_active'] == true) {
        final DateTime? expiry = data['subscription_expiry'] != null
            ? DateTime.tryParse(data['subscription_expiry'])
            : null;
        setState(() {
          _isActive = true;
          _isSubscribed = true;
          _subscriptionExpiry = expiry;
          _loading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Subscription activated! Enjoy free delivery.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              backgroundColor: kBlackColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    // Timed out
    if (mounted) {
      setState(() => _loading = false);
      Service.showMessage(
        context: context,
        title: "Payment received but activation is taking longer than expected. Please refresh.",
        error: true,
        duration: 5,
      );
    }
  }

  /// Called by payment screens when the aggregator reports success.
  void _buyProduct(int index) {
    setState(() => _loading = true);
    _pollUntilActive();
  }

  @override
  Widget build(BuildContext context) {
    // If admin has disabled subscriptions, show a simple message
    if (!_loading && !_subscriptionEnabled) {
      return Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: CustomBackButton(),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.subscriptions_outlined,
                    size: 64, color: Colors.grey.shade400),
                SizedBox(height: 16),
                Text(
                  'Subscription Not Available',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'The subscription feature is currently unavailable.\nPlease check back later.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      child: Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: _loading
                  ? _buildLoadingView()
                  : _isSubscribed
                  ? _buildSubscribedView()
                  : _buildSubscriptionContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final bool isActive = _isActive;
    final int daysLeft = (isActive && _subscriptionExpiry != null)
        ? _subscriptionExpiry!.difference(DateTime.now()).inDays.clamp(0, 9999)
        : 0;
    final Color color = Color(0xFF6A52B8);

    return SliverAppBar(
      expandedHeight: 310.0,
      floating: false,
      pinned: true,
      stretch: true,
      centerTitle: true,
      elevation: 0,
      backgroundColor: _isCollapsed ? kPrimaryColor : Colors.transparent,
      leading: CustomBackButton(
        color: _isCollapsed ? kBlackColor : Colors.white,
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          opacity: _isCollapsed ? 1 : 0,
          duration: Duration(milliseconds: 300),
          child: Text(
            'Premium Membership',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kBlackColor,
            ),
          ),
        ),
        background: ClipRect(
          child: OverflowBox(
            minHeight: 0.0,
            maxHeight: 330.0,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 310,
              child: isActive
                  ? PremiumStatusCard(
                      amount: _subscriptionPrice.toInt(),
                      color: color,
                      daysLeft: daysLeft,
                      planDay: _subscriptionDurationDays,
                      planType: "Monthly",
                      isLatestPlan: true,
                    )
                  : _buildHeroSection(_isSubscribed, _subscriptionPrice.toInt()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isSubscribed, int amount) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFF6B73FF)],
        ),
      ),
      child: Stack(
        children: [
          // Animated background elements
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.diamond_outlined,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      isSubscribed ? "Subscription Expired" : "Unlock Premium",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      isSubscribed
                          ? "Renew to continue enjoying benefits"
                          : "Experience premium features",
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          final plan = _subscriptionPlans.isNotEmpty
                              ? _subscriptionPlans[0]
                              : null;
                          if (plan != null) {
                            ShowPaymentOption(
                              price: (plan['price'] as num).toDouble(),
                              plan: plan,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF667EEA),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              kDefaultPadding / 1.5,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: kDefaultPadding * 1.2,
                            vertical: kDefaultPadding / 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSubscribed ? "Resubscribe" : "Get Started",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget PremiumStatusCard({
    required int amount,
    required Color color,
    required int daysLeft,
    required int planDay,
    required String planType,
    required bool isLatestPlan,
  }) {
    final isActive = daysLeft > 0;
    final buttonText = isLatestPlan ? "Manage Subscription" : "Upgrade";
    final progress =
        (planDay > 0 && isActive) ? (daysLeft / planDay).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: amount == 100
              ? [Color(0xFF4A3298), Color(0xFF6A52B8)]
              : [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified, size: 32, color: Colors.white),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Premium Member',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isActive ? "Active" : "Expired",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              '$planType Plan (ETB ${amount.toStringAsFixed(2)})',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              isActive ? '$daysLeft days remaining' : 'Subscription expired',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isActive) ...[
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (!isLatestPlan && _subscriptionPlans.isNotEmpty) {
                    final plan = _subscriptionPlans[0];
                    ShowPaymentOption(
                      price: (plan['price'] as num).toDouble(),
                      plan: plan,
                    );
                  } else {
                    _showManageSubscriptionSheet(
                      planType: planType,
                      amount: amount,
                      daysLeft: daysLeft,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(
                  buttonText,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showManageSubscriptionSheet({
    required String planType,
    required num amount,
    required int daysLeft,
    DateTime? endDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subscription Details',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Active',
                      style: GoogleFonts.inter(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.verified, color: kPrimaryColor),
                ),
                title: Text(
                  '$planType Plan',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text('ETB ${amount.toStringAsFixed(2)}'),
                trailing: Text(
                  '$daysLeft days left',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: kPrimaryColor,
                  ),
                ),
              ),
              if (endDate != null) ...[
                SizedBox(height: 8),
                Text(
                  'Valid until: ${DateFormat('MMMM d, yyyy').format(endDate)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              Divider(height: 28),
              Text(
                'Enjoy unlimited deliveries and exclusive member discounts on all your orders.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Processing your subscription...',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait a moment',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionContent() {
    final subscription = userData['user']['subscritption_data'];
    final isSubscribed =
        subscription != null && subscription['is_user_subscribed'] == true;

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSubscribed ? 'Renew Your Premium' : 'Choose Your Plan',
                    style: Theme.of(context).textTheme.titleLarge,
                    // style: GoogleFonts.inter(
                    //   fontSize: 20,
                    //   fontWeight: FontWeight.bold,
                    //   color: Colors.black87,
                    //   letterSpacing: -0.5,
                    // ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isSubscribed
                        ? 'Your subscription has expired. Renew now to continue enjoying premium benefits!'
                        : 'Unlock premium features and get the most out of your experience',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    // style: GoogleFonts.inter(
                    //   fontSize: 12,
                    //   color: Colors.grey.shade600,
                    //   height: 1.5,
                    // ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: kDefaultPadding),
          _buildFeaturesList(),
          SizedBox(height: kDefaultPadding),
          _buildSubscriptionPlans(),
          SizedBox(height: kDefaultPadding),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.3),
          end: Offset.zero,
        ).animate(_animationController),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: kDefaultPadding,
            horizontal: kDefaultPadding * 1.2,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kDefaultPadding),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(kDefaultPadding / 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF667EEA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: Color(0xFF667EEA),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Premium Features',
                    style: Theme.of(context).textTheme.titleMedium,

                    // GoogleFonts.inter(
                    //   fontSize: 18,
                    //   fontWeight: FontWeight.bold,
                    //   color: Colors.black87,
                    // ),
                  ),
                ],
              ),
              SizedBox(height: kDefaultPadding),
              _buildBenefitItem(
                icon: Icons.local_shipping_outlined,
                title: 'Free Express Delivery',
                subtitle: 'Get your orders faster with priority shipping',
              ),
              _buildBenefitItem(
                icon: Icons.discount_outlined,
                title: 'Exclusive Discounts',
                subtitle: 'Save more on every purchase with member pricing',
              ),
              _buildBenefitItem(
                icon: Icons.support_agent_outlined,
                title: 'Priority Support',
                subtitle: '24/7 dedicated assistance from our team',
              ),
              _buildBenefitItem(
                icon: Icons.star_outline,
                title: 'Exclusive Offers',
                subtitle: 'Access special deals before anyone else',
              ),
              _buildBenefitItem(
                icon: Icons.headset_mic_outlined,
                title: 'VIP Support',
                subtitle: 'Premium customer service experience',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: kDefaultPadding),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(kDefaultPadding / 2),
            decoration: BoxDecoration(
              color: Color(0xFF667EEA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Color(0xFF667EEA), size: 18),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge,
                  // style: GoogleFonts.inter(
                  //   fontWeight: FontWeight.w600,
                  //   fontSize: 14,
                  //   color: Colors.black87,
                  // ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w100,
                  ),
                  // style: GoogleFonts.inter(
                  //   color: Colors.grey[600],
                  //   fontSize: 12,
                  //   fontWeight: FontWeight.w400,
                  // ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans() {
    final subscription = userData['user']['subscritption_data'];
    final currentDate = DateTime.now();
    final dateOfSubscription =
        subscription != null && subscription['date_of_subscription'] != null
        ? DateTime.tryParse(subscription['date_of_subscription'].toString()) ?? DateTime.now()
        : DateTime.now();
    final amount = subscription != null
        ? subscription['subscription_amount'] ?? 0
        : 0;
    final planDay = _subscriptionDurationDays;
    final endDate = _subscriptionExpiry ?? dateOfSubscription.add(Duration(days: planDay));
    final isSubscribed = _isSubscribed;
    final isExpired = _subscriptionExpiry != null
        ? currentDate.isAfter(_subscriptionExpiry!)
        : currentDate.isAfter(endDate);
    final isActive = _isActive && isSubscribed && !isExpired;
    final currentPlanPrice = isActive ? _subscriptionPrice.toDouble() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pricing Plans',
          style: Theme.of(context).textTheme.titleLarge,
          // style: GoogleFonts.inter(
          //   fontSize: 24,
          //   fontWeight: FontWeight.bold,
          //   color: Colors.black87,
          // ),
        ),
        SizedBox(height: 20),
        ..._subscriptionPlans.asMap().entries.map((entry) {
          final index = entry.key;
          final plan = entry.value;
          final isPopular = plan['isPopular'];
          final isCurrentPlan = isActive && plan['price'] == currentPlanPrice;

          return ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isPopular
                    ? LinearGradient(
                        colors: plan['gradient'],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isPopular ? null : Colors.white,
                border: isPopular
                    ? null
                    : Border.all(color: Colors.grey.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: isPopular
                        ? plan['accentColor'].withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (isPopular)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'BEST VALUE',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isCurrentPlan)
                    Positioned(
                      top: 16,
                      right: isPopular ? 120 : 16,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPopular
                              ? Colors.white.withValues(alpha: 0.2)
                              : Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Current',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan['title'],
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                color: isPopular
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                          // style: GoogleFonts.inter(
                          //   fontSize: 24,
                          //   fontWeight: FontWeight.bold,
                          //   color: isPopular ? Colors.white : Colors.black87,
                          // ),
                        ),
                        if (plan['subtitle'] != null)
                          Text(
                            plan['subtitle'],
                            style: Theme.of(context).textTheme.labelLarge!
                                .copyWith(
                                  // fontSize: 14,
                                  color: isPopular
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        SizedBox(height: 8),
                        Text(
                          plan['description'],
                          style: Theme.of(context).textTheme.labelMedium!
                              .copyWith(
                                color: isPopular
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                        SizedBox(height: 24),
                        ...plan['benefits'].map<Widget>((benefit) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: isPopular
                                      ? Colors.white
                                      : Color(0xFF10B981),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  benefit,
                                  style: Theme.of(context).textTheme.labelLarge!
                                      .copyWith(
                                        fontSize: 14,
                                        color: isPopular
                                            ? Colors.white
                                            : Colors.grey[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "${plan['currency']} ",
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: isPopular
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "${plan['price'].toInt()}",
                                        style: GoogleFonts.inter(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: isPopular
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '/${plan['interval']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: isPopular
                                              ? Colors.white.withValues(
                                                  alpha: 0.8,
                                                )
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isCurrentPlan
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  ShowPaymentOption(
                                    price: (plan['price'] as num).toDouble(),
                                    plan: plan,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: isPopular
                                      ? plan['accentColor']
                                      : Colors.white,
                                  backgroundColor: isPopular
                                      ? Colors.white
                                      : plan['accentColor'],
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  isCurrentPlan ? 'Subscribed' : 'Subscribe',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFooter() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(kDefaultPadding),
        margin: EdgeInsets.only(bottom: kDefaultPadding),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              'Subscription Terms',
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              "Subscriptions do not automatically renew. To continue your subscription, please renew manually before the end of each period. You can manage your subscriptions in your Account Settings.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: kDefaultPadding),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    // Navigate to Privacy Policy
                  },
                  child: Text(
                    'Privacy Policy',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: Color(0xFF667EEA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text('•', style: TextStyle(color: Colors.grey[600])),
                TextButton(
                  onPressed: () {
                    // Navigate to Terms of Service
                  },
                  child: Text(
                    'Terms of Service',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: Color(0xFF667EEA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribedView() {
    // Use server-driven state — is_active is the source of truth for membership
    final currentDate = DateTime.now();
    final isActive = _isActive;
    final endDate = _subscriptionExpiry ?? currentDate;
    final amount = _subscriptionPrice;
    final planDay = _subscriptionDurationDays;
    final planType = "Monthly";
    final daysLeft = isActive && _subscriptionExpiry != null
        ? _subscriptionExpiry!.difference(currentDate).inDays.clamp(0, 9999)
        : 0;
    final isLatestPlan = true; // backend only has one plan now
    final Color color = Color(0xFF6A52B8);
    final planIndex = 0; // single plan

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription Status
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$planType Plan',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? Color(0xFF10B981) : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Expired',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'ETB ${amount.toStringAsFixed(2)} / $planType',
                    style: GoogleFonts.inter(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isActive
                        ? 'Expires: ${DateFormat('MMM d, yyyy').format(endDate)}'
                        : 'Subscription expired on ${DateFormat('MMM d, yyyy').format(endDate)}',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Action Buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!isActive || daysLeft <= 7)
                  ElevatedButton.icon(
                    onPressed: () {
                      final plan = _subscriptionPlans.isNotEmpty
                          ? (planIndex < _subscriptionPlans.length
                              ? _subscriptionPlans[planIndex]
                              : _subscriptionPlans[0])
                          : null;
                      if (plan != null) {
                        ShowPaymentOption(
                          price: (plan['price'] as num).toDouble(),
                          plan: plan,
                        );
                      }
                    },
                    icon: Icon(Icons.refresh),
                    label: Text(
                      isActive ? 'Renew Subscription' : 'Resubscribe',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                if (isActive && !isLatestPlan)
                  ElevatedButton.icon(
                    onPressed: () {
                      final plan = _subscriptionPlans.isNotEmpty
                          ? _subscriptionPlans[0]
                          : null;
                      if (plan != null) {
                        ShowPaymentOption(
                          price: (plan['price'] as num).toDouble(),
                          plan: plan,
                        );
                      }
                    },
                    icon: Icon(Icons.upgrade_outlined),
                    label: Text(
                      'Upgrade to Monthly',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                if (isActive && isLatestPlan)
                  ElevatedButton.icon(
                    onPressed: () {
                      _showManageSubscriptionSheet(
                        planType: planType,
                        amount: amount,
                        daysLeft: daysLeft,
                        endDate: endDate,
                      );
                    },
                    icon: Icon(Icons.settings),
                    label: Text(
                      'Manage Subscription',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
            if (isActive) ...[
              SizedBox(height: 32),
              Text(
                'Your Active Benefits',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: _subscriptionPlans[planIndex]['benefits'].map<Widget>(
                  (benefit) {
                    bool doesContainValue(string) {
                      return benefit.toString().toLowerCase().contains(string);
                    }

                    return _buildBenefitCard(
                      color: color,
                      icon: doesContainValue("free deliveries") || doesContainValue("free delivery")
                          ? Icons.local_shipping_outlined
                          : doesContainValue("% off") || doesContainValue("discount")
                          ? Icons.price_check_outlined
                          : doesContainValue("exclusive")
                          ? Icons.discount_outlined
                          : doesContainValue("support")
                          ? Icons.support_agent_outlined
                          : Icons.star_outline,
                      title: benefit,
                      description: 'Active',
                    );
                  },
                ).toList(),
              ),
            ],
            if (!isActive || !isLatestPlan)
              Padding(
                padding: EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive
                          ? 'Upgrade to Monthly for More Benefits'
                          : 'Choose a Plan to Reactivate',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildSubscriptionPlans(),
                  ],
                ),
              ),
            SizedBox(height: 24),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    String? description,
    Color? color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color ?? Color(0xFF4A3298)),
          SizedBox(height: 6),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(
              description,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  ShowPaymentOption({
    required num price,
    required Map<String, dynamic> plan,
  }) {
    final double numericPrice = price.toDouble();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: kPrimaryColor,
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height * 0.55,
        maxHeight: MediaQuery.sizeOf(context).height * 1.0,
      ),
      builder: (BuildContext context) {
        var uuid = Uuid();
        String uniqueId = uuid
            .v4()
            .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
            .substring(0, 10);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(kDefaultPadding),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: kDefaultPadding,
                vertical: kDefaultPadding / 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // spacing: kDefaultPadding,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Spacer(),
                      // Container(
                      //   width: 40,
                      //   height: 4,
                      //   decoration: BoxDecoration(
                      //     color: Colors.grey.shade300,
                      //     borderRadius: BorderRadius.circular(2),
                      //   ),
                      // ),
                      Container(
                        // width: double.infinity,
                        padding: EdgeInsets.all(kDefaultPadding),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                plan['gradient'] ??
                                [Colors.grey, Colors.grey.shade600],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "${plan['currency']} ${price.toStringAsFixed(0)}",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                              ),
                            ),
                            Text(
                              "${plan['title']}",
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Spacer(),
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.cancel_outlined,
                            color: kBlackColor.withValues(alpha: 0.5),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: kWhiteColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Align(
                  //   alignment: Alignment.topRight,
                  //   child: IconButton(
                  //     onPressed: () => Navigator.pop(context),
                  //     icon: Icon(
                  //       Icons.cancel_outlined,
                  //       color: kBlackColor.withValues(alpha: 0.5),
                  //     ),
                  //     style: IconButton.styleFrom(backgroundColor: kWhiteColor),
                  //   ),
                  // ),

                  // SizedBox(height: kDefaultPadding / 2),
                  // Container(
                  //   // width: double.infinity,
                  //   padding: EdgeInsets.all(kDefaultPadding),
                  //   decoration: BoxDecoration(
                  //     gradient: LinearGradient(
                  //       colors: plan['gradient'] ??
                  //           [Colors.grey, Colors.grey.shade600],
                  //     ),
                  //     borderRadius: BorderRadius.circular(16),
                  //   ),
                  //   child: Column(
                  //     children: [
                  //       Text(
                  //         "${plan['currency']} ${price.toStringAsFixed(0)}",
                  //         style: GoogleFonts.inter(
                  //           color: Colors.white,
                  //           fontWeight: FontWeight.bold,
                  //           fontSize: 32,
                  //         ),
                  //       ),
                  //       Text(
                  //         "${plan['title']}",
                  //         style: GoogleFonts.inter(
                  //           color: Colors.white.withValues(alpha: 0.9),
                  //           fontWeight: FontWeight.w500,
                  //           fontSize: 16,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  SizedBox(height: kDefaultPadding),
                  Text(
                    'Choose Payment Method',
                    style: Theme.of(context).textTheme.titleMedium,
                    // style: GoogleFonts.inter(
                    //   fontSize: 20,
                    //   fontWeight: FontWeight.bold,
                    //   color: Colors.black87,
                    // ),
                  ),
                  SizedBox(height: kDefaultPadding / 2),
                  // SizedBox(height: kDefaultPadding / 2),
                  _buildPaymentContainer(
                    title: "Telebirr InApp",
                    subtitle: "Pay with mobile app",
                    imageUrl: "images/payment/telebirr.png",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return SubscriptionPaymentInApp(
                              amount: numericPrice,
                              context: context,
                              traceNo: uniqueId,
                              phone: userData['user']['phone'],
                            );
                          },
                        ),
                      ).then((value) {
                        Navigator.of(context).pop();
                        if (value != null && value == true) {
                          _buyProduct(_subscriptionPlans.indexOf(plan));
                        } else {
                          Future.delayed(Duration(milliseconds: 100), () {
                            if (mounted) {
                              Service.showMessage(
                                title:
                                    "Payment not completed. Please choose your payment method.",
                                error: true,
                                context: context,
                              );
                            }
                          });
                        }
                      });
                    },
                  ),
                  SizedBox(height: kDefaultPadding / 2),
                  _buildPaymentContainer(
                    title: "Telebirr USSD",
                    subtitle: "Pay with USSD code",
                    imageUrl: "images/payment/telebirr.png",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return SubscriptionPaymentUssd(
                              amount: numericPrice,
                              traceNo: uniqueId,
                              phone: userData['user']['phone'],
                              userId: userData['user']['_id'],
                              url:
                                  "http://196.189.44.60:8069/telebirr/ussd/send_sms",
                            );
                          },
                        ),
                      );
                    },
                  ),
                  // SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentContainer({
    required String title,
    required String imageUrl,
    required Function()? onPressed,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(0xFF667EEA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Image.asset(imageUrl, width: 24, height: 24),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// //modifed UI and Logic
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:uuid/uuid.dart';
// import 'package:intl/intl.dart';
// import 'package:zmall/constants.dart';
// import 'package:zmall/custom_widgets/custom_button.dart';
// import 'package:zmall/profile/subscription/subscription_kifiya/inapp_subscription_payment.dart';
// import 'package:zmall/profile/subscription/subscription_kifiya/ussd_subscription_payment.dart';
// import 'package:zmall/size_config.dart';
// import 'package:zmall/widgets/custom_back_button.dart';
// import 'package:zmall/service.dart';

// class SubscriptionScreen extends StatefulWidget {
//   static String routeName = '/subscription';
//   final userData;

//   const SubscriptionScreen({super.key, this.userData});

//   @override
//   State<SubscriptionScreen> createState() => _SubscriptionScreenState();
// }

// class _SubscriptionScreenState extends State<SubscriptionScreen>
//     with SingleTickerProviderStateMixin {
//   var userData;
//   bool _loading = false;
//   bool _isSubscribed = false;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<double> _scaleAnimation;
//   late ScrollController _scrollController;
//   bool _isCollapsed = false;

//   final List<Map<String, dynamic>> _subscriptionPlans = [
//     {
//       'title': 'Weekly Premium',
//       'description': 'Perfect for trying out our premium features',
//       'benefits': ['Free deliveries', 'Priority service', '10% off all orders'],
//       'price': 10.00,
//       'currency': 'ETB',
//       'interval': 'week',
//       'isPopular': false,
//       'color': Color(0xFFF5F6F9),
//     },
//     {
//       'title': 'Monthly Premium',
//       'description': 'Our best value plan with maximum benefits',
//       'benefits': [
//         'Free deliveries',
//         'Priority service',
//         '15% off all orders',
//         'Exclusive offers',
//         'VIP support'
//       ],
//       'price': 100.00,
//       'currency': 'ETB',
//       'interval': 'month',
//       'isPopular': true,
//       'color': Color(0xFF4A3298),
//     },
//   ];

//   @override
//   void initState() {
//     super.initState();
//     userData = widget.userData;
//     final subscription = userData['user']['subscritption_data'];
//     final currentDate = DateTime.now();
//     final dateOfSubscription =
//         subscription != null && subscription['date_of_subscription'] != null
//             ? DateTime.parse(subscription['date_of_subscription'])
//             : DateTime.now();
//     final amount =
//         subscription != null ? subscription['subscription_amount'] ?? 0 : 0;
//     final planDay = amount == 100 ? 30 : 7;
//     final endDate = dateOfSubscription.add(Duration(days: planDay));
//     final isSubscribed =
//         subscription != null && subscription['is_user_subscribed'] == true;
//     final isExpired = currentDate.isAfter(endDate);
//     _isSubscribed = isSubscribed && !isExpired;

//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     )..forward();

//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: Interval(0.0, 0.5, curve: Curves.easeOut),
//       ),
//     );

//     _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: Interval(0.3, 0.8, curve: Curves.elasticOut),
//       ),
//     );

//     _scrollController = ScrollController()
//       ..addListener(() {
//         if (_scrollController.hasClients) {
//           setState(() {
//             _isCollapsed = _scrollController.offset > kToolbarHeight;
//           });
//         }
//       });
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _buyProduct(int index) {
//     setState(() {
//       _loading = true;
//     });

//     Future.delayed(Duration(seconds: 2), () {
//       setState(() {
//         _loading = false;
//         _isSubscribed = true;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Subscription successful! Enjoy premium features.',
//             style: GoogleFonts.inter(
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           backgroundColor: kBlackColor,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Theme(
//       data: Theme.of(context).copyWith(
//         pageTransitionsTheme: PageTransitionsTheme(
//           builders: {
//             TargetPlatform.android: ZoomPageTransitionsBuilder(),
//             TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
//           },
//         ),
//       ),
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         body: CustomScrollView(
//           controller: _scrollController,
//           slivers: [
//             _buildSliverAppBar(),
//             SliverToBoxAdapter(
//               child: _loading
//                   ? _buildLoadingView()
//                   : _isSubscribed
//                       ? _buildSubscribedView()
//                       : _buildSubscriptionContent(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSliverAppBar() {
//     final subscription = userData['user']['subscritption_data'];
//     final currentDate = DateTime.now();
//     final dateOfSubscription =
//         subscription != null && subscription['date_of_subscription'] != null
//             ? DateTime.parse(subscription['date_of_subscription'])
//             : DateTime.now();
//     final amount =
//         subscription != null ? subscription['subscription_amount'] ?? 0 : 0;
//     final planDay = amount == 100 ? 30 : 7;
//     final planType = amount == 100 ? "Monthly" : "Weekly";
//     final endDate = dateOfSubscription.add(Duration(days: planDay));
//     final isSubscribed =
//         subscription != null && subscription['is_user_subscribed'] == true;
//     final isExpired = currentDate.isAfter(endDate);
//     final isActive = isSubscribed && !isExpired;
//     final isLatestPlan = amount == 100;
//     final daysLeft = isActive ? endDate.difference(currentDate).inDays : 0;
//     final Color color = amount == 100 ? Color(0xFF6A52B8) : kBlackColor;

//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       stretch: true,
//       centerTitle: true,
//       leading:
//           CustomBackButton(color: _isCollapsed ? kBlackColor : kPrimaryColor),
//       flexibleSpace: FlexibleSpaceBar(
//         title: Opacity(
//           opacity: _isCollapsed ? 1 : 0,
//           child: Text(
//             'Premium Membership',
//             style: GoogleFonts.playfairDisplay(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: _isCollapsed ? kBlackColor : kPrimaryColor,
//               letterSpacing: 0.5,
//             ),
//           ),
//         ),
//         background: isActive
//             ? PremiumStatusCard(
//                 amount: amount,
//                 color: color,
//                 daysLeft: daysLeft,
//                 planDay: planDay,
//                 planType: planType,
//                 isLatestPlan: isLatestPlan,
//               )
//             : Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: [
//                       kSecondaryColor,
//                       kSecondaryColor.withValues(alpha: 0.8),
//                     ],
//                   ),
//                 ),
//                 child: Stack(
//                   children: [
//                     Positioned(
//                       right: -30,
//                       top: -30,
//                       child: CircleAvatar(
//                         radius: 100,
//                         backgroundColor: Colors.white.withValues(alpha: 0.1),
//                       ),
//                     ),
//                     Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.diamond_outlined,
//                             size: 80,
//                             color: Colors.white.withValues(alpha: 0.6),
//                           ),
//                           SizedBox(height: kDefaultPadding / 2),
//                           Text(
//                             isSubscribed
//                                 ? "Subscription Expired"
//                                 : "Unlock Premium Features",
//                             style: GoogleFonts.inter(
//                               color: kWhiteColor,
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           SizedBox(height: kDefaultPadding / 2),
//                           CustomButton(
//                             title: isSubscribed ? "Resubscribe" : "Subscribe",
//                             color: kBlackColor,
//                             radius: kDefaultPadding / 2,
//                             textFontSize: 14,
//                             width: getProportionateScreenWidth(120),
//                             onPressed: () {
//                               ShowPaymentOption(
//                                 price: _subscriptionPlans[isSubscribed
//                                     ? (amount == 100 ? 1 : 0)
//                                     : 1]['price'],
//                                 plan: _subscriptionPlans[
//                                     isSubscribed ? (amount == 100 ? 1 : 0) : 1],
//                               );
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//       ),
//     );
//   }

//   Widget PremiumStatusCard({
//     required int amount,
//     required Color color,
//     required int daysLeft,
//     required int planDay,
//     required String planType,
//     required bool isLatestPlan,
//   }) {
//     final isActive = daysLeft > 0;
//     final buttonText = isLatestPlan ? "Manage Subscription" : "Upgrade";

//     return Container(
//       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: amount == 100
//               ? [Color(0xFF4A3298), Color(0xFF6A52B8)]
//               : [color, color.withValues(alpha: 0.8)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: color.withValues(alpha: 0.3),
//             blurRadius: 15,
//             offset: Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             padding: EdgeInsets.all(
//                 getProportionateScreenWidth(kDefaultPadding / 2)),
//             decoration: BoxDecoration(
//               color: kPrimaryColor.withValues(alpha: 0.2),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               Icons.diamond,
//               size: 50,
//               color: kPrimaryColor,
//             ),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 'Premium Member',
//                 style: GoogleFonts.playfairDisplay(
//                   color: kPrimaryColor,
//                   fontSize: 26,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               SizedBox(width: kDefaultPadding / 2),
//               Container(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: kDefaultPadding / 2,
//                   vertical: kDefaultPadding / 4,
//                 ),
//                 decoration: BoxDecoration(
//                   color: kWhiteColor,
//                   borderRadius: BorderRadius.circular(kDefaultPadding / 2),
//                 ),
//                 child: Text(
//                   isActive ? "Active" : "Expired",
//                   style: GoogleFonts.inter(
//                     color: isActive ? color : kGreyColor,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
//           Text(
//             '$planType Plan (\$${amount.toStringAsFixed(2)})',
//             style: GoogleFonts.inter(
//               color: kPrimaryColor.withValues(alpha: 0.8),
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
//           LinearProgressIndicator(
//             value: isActive ? daysLeft / planDay : 0,
//             backgroundColor: kPrimaryColor.withValues(alpha: 0.2),
//             valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
//           Text(
//             isActive ? '$daysLeft days remaining' : 'Subscription expired',
//             style: GoogleFonts.inter(
//               color: kPrimaryColor,
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           if (isActive) ...[
//             SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
//             CustomButton(
//               title: buttonText,
//               color: kWhiteColor,
//               titleColor: color,
//               radius: kDefaultPadding / 2,
//               textFontSize: 14,
//               width: getProportionateScreenWidth(140),
//               onPressed: () {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   Service.showMessage(
//                     "Visit https://x.ai/grok for subscription details",
//                     false,
//                   ),
//                 );
//               },
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingView() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
//           CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(kSecondaryColor),
//           ),
//           SizedBox(
//               height: getProportionateScreenHeight(kDefaultPadding * 1.33)),
//           Text(
//             'Processing...',
//             style: GoogleFonts.inter(
//               color: kSecondaryColor,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSubscriptionContent() {
//     final subscription = userData['user']['subscritption_data'];
//     final isSubscribed =
//         subscription != null && subscription['is_user_subscribed'] == true;

//     return Padding(
//       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             isSubscribed
//                 ? 'Your subscription has expired. Renew now to continue enjoying premium benefits!'
//                 : 'Unlock Premium Features with a Subscription',
//             style: GoogleFonts.playfairDisplay(
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//               color: kBlackColor,
//               letterSpacing: 0.5,
//             ),
//           ),
//           SizedBox(height: kDefaultPadding),
//           _buildFeaturesList(),
//           SizedBox(height: 24),
//           _buildSubscriptionPlans(),
//           SizedBox(height: 24),
//           _buildFooter(),
//         ],
//       ),
//     );
//   }

//   Widget _buildFeaturesList() {
//     return FadeTransition(
//       opacity: _fadeAnimation,
//       child: SlideTransition(
//         position: Tween<Offset>(
//           begin: Offset(0, 0.3),
//           end: Offset.zero,
//         ).animate(_animationController),
//         child: Card(
//           elevation: 2,
//           color: kPrimaryColor,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Padding(
//             padding:
//                 EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'What You’ll Get',
//                   style: GoogleFonts.playfairDisplay(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
//                 _buildBenefitItem(
//                   icon: Icons.local_shipping_outlined,
//                   title: 'Free Express Delivery',
//                   subtitle: 'Get your orders faster',
//                 ),
//                 _buildBenefitItem(
//                   icon: Icons.discount_outlined,
//                   title: 'Exclusive Discounts',
//                   subtitle: 'Save more on every purchase',
//                 ),
//                 _buildBenefitItem(
//                   icon: Icons.support_agent_outlined,
//                   title: 'Priority Support',
//                   subtitle: '24/7 dedicated assistance',
//                 ),
//                 _buildBenefitItem(
//                   icon: Icons.star_outline,
//                   title: 'Exclusive Offers',
//                   subtitle: 'Access special deals',
//                 ),
//                 _buildBenefitItem(
//                   icon: Icons.support_agent_outlined,
//                   title: 'VIP Support',
//                   subtitle: 'Priority customer service',
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBenefitItem({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//   }) {
//     return Padding(
//       padding: EdgeInsets.symmetric(
//           vertical: getProportionateScreenHeight(kDefaultPadding / 2)),
//       child: Row(
//         spacing: getProportionateScreenWidth(kDefaultPadding),
//         children: [
//           Container(
//             padding: EdgeInsets.all(
//                 getProportionateScreenWidth(kDefaultPadding / 2)),
//             decoration: BoxDecoration(
//               color: kSecondaryColor.withValues(alpha: 0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(
//               icon,
//               color: kSecondaryColor,
//             ),
//           ),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: GoogleFonts.inter(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 15,
//                   ),
//                 ),
//                 Text(
//                   subtitle,
//                   style: GoogleFonts.inter(
//                     color: Colors.grey[600],
//                     fontSize: 13,
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSubscriptionPlans() {
//     final subscription = userData['user']['subscritption_data'];
//     final currentDate = DateTime.now();
//     final dateOfSubscription =
//         subscription != null && subscription['date_of_subscription'] != null
//             ? DateTime.parse(subscription['date_of_subscription'])
//             : DateTime.now();
//     final amount =
//         subscription != null ? subscription['subscription_amount'] ?? 0 : 0;
//     final planDay = amount == 100 ? 30 : 7;
//     final endDate = dateOfSubscription.add(Duration(days: planDay));
//     final isSubscribed =
//         subscription != null && subscription['is_user_subscribed'] == true;
//     final isExpired = currentDate.isAfter(endDate);
//     final isActive = isSubscribed && !isExpired;
//     final currentPlanPrice = isActive ? amount.toDouble() : null;

//     return Column(
//       children: _subscriptionPlans.asMap().entries.map((entry) {
//         final index = entry.key;
//         final plan = entry.value;
//         final isPopular = plan['isPopular'];
//         final isCurrentPlan = isActive && plan['price'] == currentPlanPrice;
//         return ScaleTransition(
//           scale: _scaleAnimation,
//           child: Padding(
//             padding: EdgeInsets.only(bottom: 16),
//             child: Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(
//                   color: isPopular ? Color(0xFF4A3298) : kBlackColor,
//                   width: isPopular ? 2 : 1,
//                 ),
//               ),
//               child: Stack(
//                 children: [
//                   if (isPopular)
//                     Positioned(
//                       top: 12,
//                       right: 12,
//                       child: Container(
//                         padding: EdgeInsets.symmetric(
//                             horizontal: getProportionateScreenWidth(
//                                 kDefaultPadding / 2),
//                             vertical: getProportionateScreenHeight(
//                                 kDefaultPadding / 4)),
//                         decoration: BoxDecoration(
//                           color: Color(0xFF4A3298),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           spacing:
//                               getProportionateScreenWidth(kDefaultPadding / 4),
//                           children: [
//                             Icon(
//                               Icons.star,
//                               size: 16,
//                               color: Colors.white,
//                             ),
//                             Text(
//                               'BEST VALUE',
//                               style: GoogleFonts.inter(
//                                 color: Colors.white,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                                 letterSpacing: 0.5,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   if (isCurrentPlan)
//                     Positioned(
//                       top: 12,
//                       right: isPopular ? 100 : 12,
//                       child: Container(
//                         padding: EdgeInsets.symmetric(
//                             horizontal: getProportionateScreenWidth(
//                                 kDefaultPadding / 2),
//                             vertical: getProportionateScreenHeight(
//                                 kDefaultPadding / 4)),
//                         decoration: BoxDecoration(
//                           color: kSecondaryColor,
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Text(
//                           'Current',
//                           style: GoogleFonts.inter(
//                             color: kWhiteColor,
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 0.5,
//                           ),
//                         ),
//                       ),
//                     ),
//                   Padding(
//                     padding: EdgeInsets.all(
//                         getProportionateScreenHeight(kDefaultPadding / 1.3)),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           plan['title'],
//                           style: GoogleFonts.playfairDisplay(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: isPopular ? Color(0xFF4A3298) : Colors.black,
//                             letterSpacing: 0.3,
//                           ),
//                         ),
//                         SizedBox(
//                             height: getProportionateScreenHeight(
//                                 kDefaultPadding / 2)),
//                         Text(
//                           plan['description'],
//                           style: GoogleFonts.inter(
//                             color: Colors.grey[600],
//                             fontSize: 14,
//                             fontWeight: FontWeight.w400,
//                           ),
//                         ),
//                         SizedBox(
//                             height:
//                                 getProportionateScreenHeight(kDefaultPadding)),
//                         ...plan['benefits'].map<Widget>((benefit) {
//                           return Padding(
//                             padding: EdgeInsets.only(
//                                 bottom: getProportionateScreenHeight(
//                                     kDefaultPadding / 2)),
//                             child: Row(
//                               children: [
//                                 Icon(
//                                   Icons.check_circle_outline,
//                                   color: isPopular
//                                       ? Color(0xFF4A3298)
//                                       : Colors.green,
//                                   size: 20,
//                                 ),
//                                 SizedBox(
//                                     width: getProportionateScreenWidth(
//                                         kDefaultPadding / 2)),
//                                 Text(
//                                   benefit,
//                                   style: GoogleFonts.inter(
//                                     fontSize: 14,
//                                     color: Colors.grey[800],
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           );
//                         }).toList(),
//                         SizedBox(
//                             height: getProportionateScreenHeight(
//                                 kDefaultPadding * 1.2)),
//                         Row(
//                           children: [
//                             RichText(
//                               text: TextSpan(
//                                 children: [
//                                   TextSpan(
//                                     text: "${plan['currency']} ",
//                                     style: GoogleFonts.inter(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.w600,
//                                       color: isPopular
//                                           ? Color(0xFF4A3298)
//                                           : Colors.black,
//                                     ),
//                                   ),
//                                   TextSpan(
//                                     text: "${plan['price'].toInt()}",
//                                     style: GoogleFonts.playfairDisplay(
//                                       fontSize: 32,
//                                       fontWeight: FontWeight.bold,
//                                       color: isPopular
//                                           ? Color(0xFF4A3298)
//                                           : Colors.black,
//                                     ),
//                                   ),
//                                   TextSpan(
//                                     text: '/${plan['interval']}',
//                                     style: GoogleFonts.inter(
//                                       fontSize: 16,
//                                       color: Colors.grey[600],
//                                       fontWeight: FontWeight.w400,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             Spacer(),
//                             ElevatedButton(
//                               onPressed: isCurrentPlan
//                                   ? null
//                                   : () {
//                                       ShowPaymentOption(
//                                           price: plan['price'], plan: plan);
//                                     },
//                               style: ElevatedButton.styleFrom(
//                                 foregroundColor: kPrimaryColor,
//                                 backgroundColor:
//                                     isPopular ? Color(0xFF4A3298) : kBlackColor,
//                                 padding: EdgeInsets.symmetric(
//                                     horizontal: 24, vertical: 12),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                                 disabledForegroundColor:
//                                     kGreyColor.withValues(alpha: 0.5),
//                                 disabledBackgroundColor:
//                                     kGreyColor.withValues(alpha: 0.3),
//                               ),
//                               child: Text(
//                                 isCurrentPlan ? 'Subscribed' : 'Subscribe',
//                                 style: GoogleFonts.inter(
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 15,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildFooter() {
//     return Column(
//       children: [
//         Divider(height: getProportionateScreenHeight(kDefaultPadding * 2)),
//         FadeTransition(
//           opacity: _fadeAnimation,
//           child: Column(
//             spacing: getProportionateScreenHeight(kDefaultPadding),
//             children: [
//               Container(
//                 padding: EdgeInsets.all(
//                     getProportionateScreenWidth(kDefaultPadding)),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Column(
//                   spacing: getProportionateScreenHeight(kDefaultPadding / 2),
//                   children: [
//                     Text(
//                       'Subscription Terms',
//                       style: GoogleFonts.playfairDisplay(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 18,
//                       ),
//                     ),
//                     Text(
//                       "Subscriptions do not automatically renew. To continue your subscription, please renew manually before the end of each period. You can manage your subscriptions in your Account Settings.",
//                       style: GoogleFonts.inter(
//                         color: Colors.grey[600],
//                         fontSize: 13,
//                         fontWeight: FontWeight.w400,
//                         height: 1.4,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   TextButton(
//                     onPressed: () {
//                       // Navigate to Privacy Policy
//                     },
//                     child: Text(
//                       'Privacy Policy',
//                       style: GoogleFonts.inter(
//                         color: Colors.grey[600],
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                   Text('•', style: TextStyle(color: Colors.grey[600])),
//                   TextButton(
//                     onPressed: () {
//                       // Navigate to Terms of Service
//                     },
//                     child: Text(
//                       'Terms of Service',
//                       style: GoogleFonts.inter(
//                         color: Colors.grey[600],
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSubscribedView() {
//     final subscription = userData['user']['subscritption_data'];
//     final currentDate = DateTime.now();
//     final dateOfSubscription =
//         subscription != null && subscription['date_of_subscription'] != null
//             ? DateTime.parse(subscription['date_of_subscription'])
//             : DateTime.now();
//     final amount =
//         subscription != null ? subscription['subscription_amount'] ?? 0 : 0;
//     final planDay = amount == 100 ? 30 : 7;
//     final planType = amount == 100 ? "Monthly" : "Weekly";
//     final endDate = dateOfSubscription.add(Duration(days: planDay));
//     final isExpired = currentDate.isAfter(endDate);
//     final isActive = !isExpired;
//     final daysLeft = isActive ? endDate.difference(currentDate).inDays : 0;
//     final isLatestPlan = amount == 100;
//     final Color color = amount == 100 ? Color(0xFF6A52B8) : kBlackColor;
//     final planIndex = amount == 100 ? 1 : 0;

//     return SingleChildScrollView(
//       child: Padding(
//         padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Subscription Status
//             Card(
//               elevation: 2,
//               color: kPrimaryColor,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Padding(
//                 padding: EdgeInsets.all(
//                     getProportionateScreenWidth(kDefaultPadding)),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           '$planType Plan',
//                           style: GoogleFonts.playfairDisplay(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: color,
//                           ),
//                         ),
//                         Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: kDefaultPadding / 2,
//                             vertical: kDefaultPadding / 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: isActive ? kSecondaryColor : kGreyColor,
//                             borderRadius:
//                                 BorderRadius.circular(kDefaultPadding / 2),
//                           ),
//                           child: Text(
//                             isActive ? 'Active' : 'Expired',
//                             style: GoogleFonts.inter(
//                               color: kWhiteColor,
//                               fontSize: 12,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: kDefaultPadding / 2),
//                     Text(
//                       'ETB ${amount.toStringAsFixed(2)} / $planType',
//                       style: GoogleFonts.inter(
//                         color: kBlackColor,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     SizedBox(height: kDefaultPadding / 4),
//                     Text(
//                       isActive
//                           ? 'Expires: ${DateFormat('MMM d, yyyy').format(endDate)}'
//                           : 'Subscription expired on ${DateFormat('MMM d, yyyy').format(endDate)}',
//                       style: GoogleFonts.inter(
//                         color: kGreyColor,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(height: kDefaultPadding),
//             // Action Buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 if (!isActive || daysLeft <= 7)
//                   ElevatedButton.icon(
//                     onPressed: () {
//                       ShowPaymentOption(
//                         price: _subscriptionPlans[planIndex]['price'],
//                         plan: _subscriptionPlans[planIndex],
//                       );
//                     },
//                     icon: Icon(Icons.refresh),
//                     label: Text(
//                       isActive ? 'Renew Subscription' : 'Resubscribe',
//                       style: GoogleFonts.inter(fontWeight: FontWeight.w600),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color,
//                       foregroundColor: kPrimaryColor,
//                       padding:
//                           EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 if (isActive && !isLatestPlan)
//                   ElevatedButton.icon(
//                     onPressed: () {
//                       ShowPaymentOption(
//                         price: _subscriptionPlans[1]['price'],
//                         plan: _subscriptionPlans[1],
//                       );
//                     },
//                     icon: Icon(Icons.upgrade_outlined),
//                     label: Text(
//                       'Upgrade to Monthly',
//                       style: GoogleFonts.inter(fontWeight: FontWeight.w600),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color,
//                       foregroundColor: kPrimaryColor,
//                       padding:
//                           EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 if (isActive && isLatestPlan)
//                   ElevatedButton.icon(
//                     onPressed: () {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         Service.showMessage(
//                           "Visit https://x.ai/grok for subscription details",
//                           false,
//                         ),
//                       );
//                     },
//                     icon: Icon(Icons.settings),
//                     label: Text(
//                       'Manage Subscription',
//                       style: GoogleFonts.inter(fontWeight: FontWeight.w600),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color,
//                       foregroundColor: kPrimaryColor,
//                       padding:
//                           EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             if (isActive) ...[
//               SizedBox(
//                   height: getProportionateScreenHeight(kDefaultPadding * 2)),
//               Text(
//                 'Your Active Benefits',
//                 style: GoogleFonts.playfairDisplay(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                   color: kBlackColor,
//                   letterSpacing: 0.3,
//                 ),
//               ),
//               SizedBox(
//                   height: getProportionateScreenHeight(kDefaultPadding / 2)),
//               GridView.count(
//                 shrinkWrap: true,
//                 physics: NeverScrollableScrollPhysics(),
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 15,
//                 mainAxisSpacing: 15,
//                 childAspectRatio: 1.4,
//                 children: _subscriptionPlans[planIndex]['benefits']
//                     .map<Widget>((benefit) {
//                   bool doesContainValue(string) {
//                     return benefit.toString().toLowerCase().contains(string);
//                   }

//                   return _buildBenefitCard(
//                     color: color,
//                     icon: doesContainValue("free deliveries")
//                         ? Icons.local_shipping_outlined
//                         : doesContainValue("% off")
//                             ? Icons.price_check_outlined
//                             : doesContainValue("exclusive")
//                                 ? Icons.discount_outlined
//                                 : doesContainValue("support")
//                                     ? Icons.support_agent_outlined
//                                     : Icons.star_outline,
//                     title: benefit,
//                     description: 'Active',
//                   );
//                 }).toList(),
//               ),
//             ],
//             if (!isActive || !isLatestPlan)
//               Padding(
//                 padding: EdgeInsets.only(top: kDefaultPadding),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       isActive
//                           ? 'Upgrade to Monthly for More Benefits'
//                           : 'Choose a Plan to Reactivate',
//                       style: GoogleFonts.playfairDisplay(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                         color: kBlackColor,
//                       ),
//                     ),
//                     SizedBox(height: kDefaultPadding),
//                     _buildSubscriptionPlans(),
//                   ],
//                 ),
//               ),
//             SizedBox(height: kDefaultPadding),
//             _buildFooter(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBenefitCard({
//     required IconData icon,
//     required String title,
//     String? description,
//     Color? color,
//   }) {
//     return Container(
//       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding / 8)),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(15),
//         border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withValues(alpha: 0.1),
//             blurRadius: 10,
//             offset: Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             icon,
//             size: 28,
//             color: color ?? Color(0xFF4A3298),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
//           Text(
//             title,
//             style: GoogleFonts.inter(
//               fontWeight: FontWeight.w600,
//               fontSize: 14,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           SizedBox(height: 4),
//           Text(
//             description ?? '',
//             style: GoogleFonts.inter(
//               color: Colors.grey[600],
//               fontSize: 12,
//               fontWeight: FontWeight.w400,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   ShowPaymentOption(
//       {required double price, required Map<String, dynamic> plan}) {
//     showModalBottomSheet(
//         context: context,
//         showDragHandle: true,
//         backgroundColor: kPrimaryColor,
//         isScrollControlled: true,
//         constraints: BoxConstraints(
//           minHeight: MediaQuery.of(context).size.height * 0.4,
//           maxHeight: MediaQuery.of(context).size.height * 0.95,
//         ),
//         shape: const RoundedRectangleBorder(
//             borderRadius:
//                 BorderRadius.vertical(top: Radius.circular(kDefaultPadding))),
//         builder: (BuildContext context) {
//           var uuid = Uuid();
//           String uniqueId = uuid.v4().substring(0, 10);

//           return StatefulBuilder(
//               builder: (BuildContext context, StateSetter setState) {
//             return Padding(
//               padding: EdgeInsets.symmetric(
//                   horizontal: getProportionateScreenWidth(kDefaultPadding * 2)),
//               child: ListView(
//                 shrinkWrap: true,
//                 children: [
//                   Container(
//                     child: Column(
//                       spacing: getProportionateScreenWidth(kDefaultPadding / 8),
//                       children: [
//                         Text(
//                           "${plan['currency']} ${price.toStringAsFixed(2)}",
//                           style: GoogleFonts.playfairDisplay(
//                               color: kBlackColor,
//                               fontWeight: FontWeight.w900,
//                               fontSize: getProportionateScreenHeight(
//                                   kDefaultPadding * 1.2)),
//                         ),
//                         Text(
//                           "${plan['title']}",
//                           style: GoogleFonts.inter(
//                             color: kGreyColor,
//                             fontWeight: FontWeight.w600,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ],
//                     ),
//                     padding: EdgeInsets.all(
//                         getProportionateScreenWidth(kDefaultPadding)),
//                     margin: EdgeInsets.symmetric(
//                         horizontal:
//                             getProportionateScreenWidth(kDefaultPadding * 4)),
//                     decoration: BoxDecoration(
//                         color: kWhiteColor,
//                         borderRadius: BorderRadius.circular(kDefaultPadding)),
//                   ),
//                   SizedBox(
//                       height: getProportionateScreenHeight(kDefaultPadding)),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceAround,
//                     children: [
//                       _buildPaymentContainer(
//                         title: "Telebirr InApp",
//                         imageUrl: "images/telebirr.png",
//                         onPressed: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) {
//                                 return SubscriptionPaymentInApp(
//                                   amount: price,
//                                   context: context,
//                                   traceNo: uniqueId,
//                                   phone: userData['user']['phone'],
//                                 );
//                               },
//                             ),
//                           ).then((value) {
//                             Navigator.of(context).pop();
//                             if (value != null && value == true) {
//                               _buyProduct(_subscriptionPlans.indexOf(plan));
//                             } else {
//                               Future.delayed(Duration(milliseconds: 100), () {
//                                 if (mounted) {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                       Service.showMessage(
//                                           "Payment not completed. Please choose your payment method.",
//                                           true));
//                                 }
//                               });
//                             }
//                           });
//                         },
//                       ),
//                       _buildPaymentContainer(
//                         title: "Telebirr USSD",
//                         imageUrl: "images/telebirr.png",
//                         onPressed: () {
//                           Navigator.push(context, MaterialPageRoute(
//                             builder: (context) {
//                               return SubscriptionPaymentUssd(
//                                 amount: price,
//                                 traceNo: uniqueId,
//                                 phone: userData['user']['phone'],
//                                 userId: userData['user']['_id'],
//                                 url:
//                                     "http://196.189.44.60:8069/telebirr/ussd/send_sms",
//                               );
//                             },
//                           ));
//                         },
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           });
//         });
//   }

//   Widget _buildPaymentContainer(
//       {required String title,
//       required String imageUrl,
//       required Function()? onPressed}) {
//     return ElevatedButton(
//         onPressed: onPressed,
//         style: ElevatedButton.styleFrom(
//           foregroundColor: kBlackColor,
//           backgroundColor: kPrimaryColor,
//           padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               width: getProportionateScreenWidth(kDefaultPadding * 4),
//               height: getProportionateScreenHeight(kDefaultPadding * 3),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(
//                   getProportionateScreenWidth(kDefaultPadding / 2),
//                 ),
//               ),
//               child: Image.asset(imageUrl),
//             ),
//             Text(
//               title,
//               textAlign: TextAlign.center,
//               style: GoogleFonts.inter(
//                 fontWeight: FontWeight.w700,
//                 color: kBlackColor,
//                 fontSize: getProportionateScreenWidth(
//                   kDefaultPadding,
//                 ),
//               ),
//             ),
//           ],
//         ));
//   }
// }

// // ///working UI
// // import 'package:flutter/material.dart';
// // import 'package:google_fonts/google_fonts.dart';
// // import 'package:uuid/uuid.dart';
// // import 'package:zmall/constants.dart';
// // import 'package:zmall/custom_widgets/custom_button.dart';
// // import 'package:zmall/profile/subscription/subscription_kifiya/inapp_subscription_payment.dart';
// // import 'package:zmall/profile/subscription/subscription_kifiya/ussd_subscription_payment.dart';
// // import 'package:zmall/size_config.dart';
// // import 'package:zmall/widgets/custom_back_button.dart';
// // import 'package:zmall/service.dart';

// // class SubscriptionScreen extends StatefulWidget {
// //   static String routeName = '/subscription';
// //   final userData;

// //   const SubscriptionScreen({super.key, this.userData});

// //   @override
// //   State<SubscriptionScreen> createState() => _SubscriptionScreenState();
// // }

// // class _SubscriptionScreenState extends State<SubscriptionScreen>
// //     with SingleTickerProviderStateMixin {
// //   var userData;
// //   bool _loading = false;
// //   bool _isSubscribed = false;
// //   late AnimationController _animationController;
// //   late Animation<double> _fadeAnimation;
// //   late Animation<double> _scaleAnimation;
// //   late ScrollController _scrollController;
// //   bool _isCollapsed = false;

// //   final List<Map<String, dynamic>> _subscriptionPlans = [
// //     {
// //       'title': 'Weekly Premium',
// //       'description': 'Perfect for trying out our premium features',
// //       'benefits': ['Free deliveries', 'Priority service', '10% off all orders'],
// //       'price': 10.00,
// //       'currency': 'ETB',
// //       'interval': 'weak',
// //       'isPopular': false,
// //       'color': Color(0xFFF5F6F9),
// //     },
// //     {
// //       'title': 'Monthly Premium',
// //       'description': 'Our best value plan with maximum benefits',
// //       'benefits': [
// //         'Free deliveries',
// //         'Priority service',
// //         '15% off all orders',
// //         'Exclusive offers',
// //         'VIP support'
// //       ],
// //       'price': 100.00,
// //       'currency': 'ETB',
// //       'interval': 'month',
// //       'isPopular': true,
// //       'color': Color(0xFF4A3298),
// //     },
// //   ];

// //   @override
// //   void initState() {
// //     super.initState();
// //     userData = widget.userData;
// //     print("userData>>>> ${userData}");
// //     print("sub>>>> ${userData['user']['subscritption_data']}");

// //     _isSubscribed = userData['user']['subscritption_data'] != null &&
// //         userData['user']['subscritption_data']['is_user_subscribed'];

// //     print("isSubscribed $_isSubscribed");

// //     _animationController = AnimationController(
// //       vsync: this,
// //       duration: const Duration(milliseconds: 1200),
// //     )..forward();

// //     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
// //       CurvedAnimation(
// //         parent: _animationController,
// //         curve: Interval(0.0, 0.5, curve: Curves.easeOut),
// //       ),
// //     );

// //     _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
// //       CurvedAnimation(
// //         parent: _animationController,
// //         curve: Interval(0.3, 0.8, curve: Curves.elasticOut),
// //       ),
// //     );

// //     _scrollController = ScrollController()
// //       ..addListener(() {
// //         if (_scrollController.hasClients) {
// //           setState(() {
// //             _isCollapsed = _scrollController.offset > kToolbarHeight;
// //           });
// //         }
// //       });
// //   }

// //   @override
// //   void dispose() {
// //     _animationController.dispose();
// //     super.dispose();
// //   }

// //   void _buyProduct(int index) {
// //     setState(() {
// //       _loading = true;
// //     });

// //     Future.delayed(Duration(seconds: 2), () {
// //       setState(() {
// //         _loading = false;
// //         _isSubscribed = true;
// //       });

// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(
// //             'Subscription successful! Enjoy premium features.',
// //             style: GoogleFonts.inter(
// //               fontWeight: FontWeight.w500,
// //             ),
// //           ),
// //           backgroundColor: kBlackColor,
// //           behavior: SnackBarBehavior.floating,
// //         ),
// //       );
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Theme(
// //       data: Theme.of(context).copyWith(
// //         pageTransitionsTheme: PageTransitionsTheme(
// //           builders: {
// //             TargetPlatform.android: ZoomPageTransitionsBuilder(),
// //             TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
// //           },
// //         ),
// //       ),
// //       child: Scaffold(
// //         backgroundColor: Colors.white,
// //         body: CustomScrollView(
// //           controller: _scrollController,
// //           slivers: [
// //             _buildSliverAppBar(),
// //             SliverToBoxAdapter(
// //               child: _loading
// //                   ? _buildLoadingView()
// //                   : _isSubscribed
// //                       ? _buildSubscribedView()
// //                       : _buildSubscriptionContent(),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   // Widget _buildSliverAppBar() {
// //   //   final subscription = userData['user']['subscritption_data'];
// //   //   final dateofSub = subscription != null
// //   //       ? DateTime.parse(subscription['date_of_subscription'])
// //   //       : DateTime.now();
// //   //   final amount =
// //   //       subscription != null ? subscription['subscription_amount'] : 0.0;

// //   //   var planDay = amount == 100 ? 30 : 7;
// //   //   String planType = amount == 100 ? "Monthly" : "Weekly";
// //   //   final endDate = dateofSub.add(Duration(days: planDay));
// //   //   final daysLeft = endDate.difference(DateTime.now()).inDays;
// //   //   Color color = amount == 100 ? Color(0xFF6A52B8) : kBlackColor;

// //   //   return SliverAppBar(
// //   //     expandedHeight: 200.0,
// //   //     floating: false,
// //   //     pinned: true,
// //   //     stretch: true,
// //   //     centerTitle: true,
// //   //     leading:
// //   //         CustomBackButton(color: _isCollapsed ? kBlackColor : kPrimaryColor),
// //   //     flexibleSpace: FlexibleSpaceBar(
// //   //       title: Opacity(
// //   //         opacity: _isSubscribed ? 0 : 1,
// //   //         child: Text(
// //   //           'Premium Membership',
// //   //           style: GoogleFonts.playfairDisplay(
// //   //             fontSize: 18,
// //   //             fontWeight: FontWeight.bold,
// //   //             color: _isCollapsed ? kBlackColor : kPrimaryColor,
// //   //             letterSpacing: 0.5,
// //   //           ),
// //   //         ),
// //   //       ),
// //   //       background: _isSubscribed
// //   //           ? PremiumStatusCard(
// //   //               amount: amount,
// //   //               color: color,
// //   //               daysLeft: daysLeft,
// //   //               planDay: planDay,
// //   //               planType: planType)
// //   //           : Container(
// //   //               decoration: BoxDecoration(
// //   //                 gradient: LinearGradient(
// //   //                   begin: Alignment.topLeft,
// //   //                   end: Alignment.bottomRight,
// //   //                   colors: [
// //   //                     kSecondaryColor,
// //   //                     kSecondaryColor.withValues(alpha: 0.8)
// //   //                   ],
// //   //                 ),
// //   //               ),
// //   //               child: Stack(
// //   //                 children: [
// //   //                   Positioned(
// //   //                     right: -30,
// //   //                     top: -30,
// //   //                     child: CircleAvatar(
// //   //                       radius: 100,
// //   //                       backgroundColor: Colors.white.withValues(alpha: 0.1),
// //   //                     ),
// //   //                   ),
// //   //                   Center(
// //   //                     child: Icon(
// //   //                       Icons.diamond_outlined,
// //   //                       size: 80,
// //   //                       color: Colors.white.withValues(alpha: 0.6),
// //   //                     ),
// //   //                   ),
// //   //                 ],
// //   //               ),
// //   //             ),
// //   //     ),
// //   //   );
// //   // }
// // // Updated SliverAppBar method
// //   Widget _buildSliverAppBar() {
// //     final subscription = userData['user']['subscritption_data'];
// //     final currentDate = DateTime.now(); // Current date: July 21, 2025
// //     final dateOfSubscription =
// //         subscription != null && subscription['date_of_subscription'] != null
// //             ? DateTime.parse(subscription['date_of_subscription'])
// //             : DateTime.now();
// //     final amount =
// //         subscription != null ? subscription['subscription_amount'] ?? 0 : 0;
// //     final planDay = amount == 100 ? 30 : 7;
// //     final planType = amount == 100 ? "Monthly" : "Weekly";
// //     final endDate = dateOfSubscription.add(Duration(days: planDay));
// //     final isSubscribed =
// //         subscription != null && subscription['is_user_subscribed'] == true;
// //     final isExpired = currentDate.isAfter(endDate);
// //     final isActive = isSubscribed && !isExpired;
// //     final isLatestPlan = amount == 100; // Monthly is the latest plan
// //     final daysLeft = isActive ? endDate.difference(currentDate).inDays : 0;
// //     final Color color = amount == 100 ? Color(0xFF6A52B8) : kBlackColor;

// //     return SliverAppBar(
// //       expandedHeight: 200.0,
// //       floating: false,
// //       pinned: true,
// //       stretch: true,
// //       centerTitle: true,
// //       leading:
// //           CustomBackButton(color: _isCollapsed ? kBlackColor : kPrimaryColor),
// //       flexibleSpace: FlexibleSpaceBar(
// //         title: Opacity(
// //           opacity: isActive ? 0 : 1, // Hide title for active subscriptions
// //           child: Text(
// //             'Premium Membership',
// //             style: GoogleFonts.playfairDisplay(
// //               fontSize: 18,
// //               fontWeight: FontWeight.bold,
// //               color: _isCollapsed ? kBlackColor : kPrimaryColor,
// //               letterSpacing: 0.5,
// //             ),
// //           ),
// //         ),
// //         background: isActive
// //             ? PremiumStatusCard(
// //                 amount: amount,
// //                 color: color,
// //                 daysLeft: daysLeft,
// //                 planDay: planDay,
// //                 planType: planType,
// //                 isLatestPlan: isLatestPlan,
// //               )
// //             : Container(
// //                 decoration: BoxDecoration(
// //                   gradient: LinearGradient(
// //                     begin: Alignment.topLeft,
// //                     end: Alignment.bottomRight,
// //                     colors: [
// //                       kSecondaryColor,
// //                       kSecondaryColor.withValues(alpha: 0.8),
// //                     ],
// //                   ),
// //                 ),
// //                 child: Stack(
// //                   children: [
// //                     Positioned(
// //                       right: -30,
// //                       top: -30,
// //                       child: CircleAvatar(
// //                         radius: 100,
// //                         backgroundColor: Colors.white.withValues(alpha: 0.1),
// //                       ),
// //                     ),
// //                     Center(
// //                       child: Column(
// //                         mainAxisAlignment: MainAxisAlignment.center,
// //                         children: [
// //                           Icon(
// //                             Icons.diamond_outlined,
// //                             size: 80,
// //                             color: Colors.white.withValues(alpha: 0.6),
// //                           ),
// //                           SizedBox(height: kDefaultPadding / 2),
// //                           Text(
// //                             isSubscribed
// //                                 ? "Subscription Expired"
// //                                 : "Unlock Premium Features",
// //                             style: GoogleFonts.inter(
// //                               color: kWhiteColor,
// //                               fontSize: 16,
// //                               fontWeight: FontWeight.w600,
// //                             ),
// //                           ),
// //                           SizedBox(height: kDefaultPadding / 2),
// //                           CustomButton(
// //                             title: "Subscribe",
// //                             color: kBlackColor,
// //                             radius: kDefaultPadding / 2,
// //                             textFontSize: 14,
// //                             width: getProportionateScreenWidth(120),
// //                             onPressed: () {
// //                               ScaffoldMessenger.of(context).showSnackBar(
// //                                 Service.showMessage(
// //                                   "Visit https://x.ai/grok for subscription details",
// //                                   false,
// //                                 ),
// //                               );
// //                             },
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //       ),
// //     );
// //   }

// //   Widget _buildLoadingView() {
// //     return Center(
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
// //           CircularProgressIndicator(
// //             valueColor: AlwaysStoppedAnimation<Color>(kSecondaryColor),
// //           ),
// //           SizedBox(
// //               height: getProportionateScreenHeight(kDefaultPadding * 1.33)),
// //           Text(
// //             'Processing...',
// //             style: GoogleFonts.inter(
// //               color: kSecondaryColor,
// //               fontSize: 16,
// //               fontWeight: FontWeight.w500,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildSubscriptionContent() {
// //     return Padding(
// //       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           _buildFeaturesList(),
// //           SizedBox(height: 24),
// //           _buildSubscriptionPlans(),
// //           SizedBox(height: 24),
// //           _buildFooter(),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildFeaturesList() {
// //     return FadeTransition(
// //       opacity: _fadeAnimation,
// //       child: SlideTransition(
// //         position: Tween<Offset>(
// //           begin: Offset(0, 0.3),
// //           end: Offset.zero,
// //         ).animate(_animationController),
// //         child: Card(
// //           elevation: 2,
// //           color: kPrimaryColor,
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(16),
// //           ),
// //           child: Padding(
// //             padding:
// //                 EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   'Premium Benefits',
// //                   style: GoogleFonts.playfairDisplay(
// //                     fontSize: 22,
// //                     fontWeight: FontWeight.bold,
// //                     letterSpacing: 0.5,
// //                   ),
// //                 ),
// //                 SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
// //                 _buildBenefitItem(
// //                   icon: Icons.local_shipping_outlined,
// //                   title: 'Free Express Delivery',
// //                   subtitle: 'Get your orders faster',
// //                 ),
// //                 _buildBenefitItem(
// //                   icon: Icons.discount_outlined,
// //                   title: 'Exclusive Discounts',
// //                   subtitle: 'Save more on every purchase',
// //                 ),
// //                 _buildBenefitItem(
// //                   icon: Icons.support_agent_outlined,
// //                   title: 'Priority Support',
// //                   subtitle: '24/7 dedicated assistance',
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildBenefitItem({
// //     required IconData icon,
// //     required String title,
// //     required String subtitle,
// //   }) {
// //     return Padding(
// //       padding: EdgeInsets.symmetric(
// //           vertical: getProportionateScreenHeight(kDefaultPadding / 2)),
// //       child: Row(
// //         spacing: getProportionateScreenWidth(kDefaultPadding),
// //         children: [
// //           Container(
// //             padding: EdgeInsets.all(
// //                 getProportionateScreenWidth(kDefaultPadding / 2)),
// //             decoration: BoxDecoration(
// //               color: kSecondaryColor.withValues(alpha: 0.1),
// //               borderRadius: BorderRadius.circular(8),
// //             ),
// //             child: Icon(
// //               icon,
// //               color: kSecondaryColor,
// //             ),
// //           ),
// //           Expanded(
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   title,
// //                   style: GoogleFonts.inter(
// //                     fontWeight: FontWeight.w600,
// //                     fontSize: 15,
// //                   ),
// //                 ),
// //                 Text(
// //                   subtitle,
// //                   style: GoogleFonts.inter(
// //                     color: Colors.grey[600],
// //                     fontSize: 13,
// //                     fontWeight: FontWeight.w400,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildSubscriptionPlans() {
// //     return Column(
// //       children: _subscriptionPlans.map((plan) {
// //         bool isPopular = plan['isPopular'];
// //         return ScaleTransition(
// //           scale: _scaleAnimation,
// //           child: Padding(
// //             padding: EdgeInsets.only(bottom: 16),
// //             child: Container(
// //               decoration: BoxDecoration(
// //                 borderRadius: BorderRadius.circular(16),
// //                 border: Border.all(
// //                   color: isPopular ? Color(0xFF4A3298) : kBlackColor,
// //                   width: isPopular ? 2 : 1,
// //                 ),
// //               ),
// //               child: Stack(
// //                 children: [
// //                   if (isPopular)
// //                     Positioned(
// //                       top: 12,
// //                       right: 12,
// //                       child: Container(
// //                         padding: EdgeInsets.symmetric(
// //                             horizontal: getProportionateScreenWidth(
// //                                 kDefaultPadding / 2),
// //                             vertical: getProportionateScreenHeight(
// //                                 kDefaultPadding / 4)),
// //                         decoration: BoxDecoration(
// //                           color: Color(0xFF4A3298),
// //                           borderRadius: BorderRadius.circular(12),
// //                         ),
// //                         child: Row(
// //                           mainAxisSize: MainAxisSize.min,
// //                           spacing:
// //                               getProportionateScreenWidth(kDefaultPadding / 4),
// //                           children: [
// //                             Icon(
// //                               Icons.star,
// //                               size: 16,
// //                               color: Colors.white,
// //                             ),
// //                             Text(
// //                               'BEST VALUE',
// //                               style: GoogleFonts.inter(
// //                                 color: Colors.white,
// //                                 fontSize: 12,
// //                                 fontWeight: FontWeight.bold,
// //                                 letterSpacing: 0.5,
// //                               ),
// //                             ),
// //                           ],
// //                         ),
// //                       ),
// //                     ),
// //                   Padding(
// //                     padding: EdgeInsets.all(
// //                         getProportionateScreenHeight(kDefaultPadding / 1.3)),
// //                     child: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         Text(
// //                           plan['title'],
// //                           style: GoogleFonts.playfairDisplay(
// //                             fontSize: 20,
// //                             fontWeight: FontWeight.bold,
// //                             color: isPopular ? Color(0xFF4A3298) : Colors.black,
// //                             letterSpacing: 0.3,
// //                           ),
// //                         ),
// //                         SizedBox(
// //                             height: getProportionateScreenHeight(
// //                                 kDefaultPadding / 2)),
// //                         Text(
// //                           plan['description'],
// //                           style: GoogleFonts.inter(
// //                             color: Colors.grey[600],
// //                             fontSize: 14,
// //                             fontWeight: FontWeight.w400,
// //                           ),
// //                         ),
// //                         SizedBox(
// //                             height:
// //                                 getProportionateScreenHeight(kDefaultPadding)),
// //                         ...plan['benefits'].map<Widget>((benefit) {
// //                           return Padding(
// //                             padding: EdgeInsets.only(
// //                                 bottom: getProportionateScreenHeight(
// //                                     kDefaultPadding / 2)),
// //                             child: Row(
// //                               children: [
// //                                 Icon(
// //                                   Icons.check_circle_outline,
// //                                   color: isPopular
// //                                       ? Color(0xFF4A3298)
// //                                       : Colors.green,
// //                                   size: 20,
// //                                 ),
// //                                 SizedBox(
// //                                     width: getProportionateScreenWidth(
// //                                         kDefaultPadding / 2)),
// //                                 Text(
// //                                   benefit,
// //                                   style: GoogleFonts.inter(
// //                                     fontSize: 14,
// //                                     color: Colors.grey[800],
// //                                     fontWeight: FontWeight.w500,
// //                                   ),
// //                                 ),
// //                               ],
// //                             ),
// //                           );
// //                         }).toList(),
// //                         SizedBox(
// //                             height: getProportionateScreenHeight(
// //                                 kDefaultPadding * 1.2)),
// //                         Row(
// //                           children: [
// //                             RichText(
// //                               text: TextSpan(
// //                                 children: [
// //                                   TextSpan(
// //                                     text: "${plan['currency']} ",
// //                                     style: GoogleFonts.inter(
// //                                       fontSize: 18,
// //                                       fontWeight: FontWeight.w600,
// //                                       color: isPopular
// //                                           ? Color(0xFF4A3298)
// //                                           : Colors.black,
// //                                     ),
// //                                   ),
// //                                   TextSpan(
// //                                     text: "${plan['price'].toInt()}",
// //                                     style: GoogleFonts.playfairDisplay(
// //                                       fontSize: 32,
// //                                       fontWeight: FontWeight.bold,
// //                                       color: isPopular
// //                                           ? Color(0xFF4A3298)
// //                                           : Colors.black,
// //                                     ),
// //                                   ),
// //                                   TextSpan(
// //                                     text: '/${plan['interval']}',
// //                                     style: GoogleFonts.inter(
// //                                       fontSize: 16,
// //                                       color: Colors.grey[600],
// //                                       fontWeight: FontWeight.w400,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ),
// //                             Spacer(),
// //                             ElevatedButton(
// //                               onPressed: () {
// //                                 ShowPaymentOption(
// //                                     price: plan['price'], plan: plan);
// //                               },
// //                               style: ElevatedButton.styleFrom(
// //                                 foregroundColor: kPrimaryColor,
// //                                 backgroundColor:
// //                                     isPopular ? Color(0xFF4A3298) : kBlackColor,
// //                                 padding: EdgeInsets.symmetric(
// //                                     horizontal: 24, vertical: 12),
// //                                 shape: RoundedRectangleBorder(
// //                                   borderRadius: BorderRadius.circular(12),
// //                                 ),
// //                               ),
// //                               child: Text(
// //                                 'Subscribe',
// //                                 style: GoogleFonts.inter(
// //                                   fontWeight: FontWeight.w600,
// //                                   fontSize: 15,
// //                                 ),
// //                               ),
// //                             ),
// //                           ],
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         );
// //       }).toList(),
// //     );
// //   }

// //   Widget _buildFooter() {
// //     return Column(
// //       children: [
// //         Divider(height: getProportionateScreenHeight(kDefaultPadding * 2)),
// //         FadeTransition(
// //           opacity: _fadeAnimation,
// //           child: Column(
// //             spacing: getProportionateScreenHeight(kDefaultPadding),
// //             children: [
// //               Container(
// //                 padding: EdgeInsets.all(
// //                     getProportionateScreenWidth(kDefaultPadding)),
// //                 decoration: BoxDecoration(
// //                   color: Colors.grey[100],
// //                   borderRadius: BorderRadius.circular(12),
// //                 ),
// //                 child: Column(
// //                   spacing: getProportionateScreenHeight(kDefaultPadding / 2),
// //                   children: [
// //                     Text(
// //                       'Subscription Terms',
// //                       style: GoogleFonts.playfairDisplay(
// //                         fontWeight: FontWeight.bold,
// //                         fontSize: 18,
// //                       ),
// //                     ),
// //                     Text(
// //                       "Subscriptions do not automatically renew. To continue your subscription, please renew manually before the end of each period. You can manage your subscriptions in your Account Settings.",
// //                       style: GoogleFonts.inter(
// //                         color: Colors.grey[600],
// //                         fontSize: 13,
// //                         fontWeight: FontWeight.w400,
// //                         height: 1.4,
// //                       ),
// //                       textAlign: TextAlign.center,
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //               Row(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   TextButton(
// //                     onPressed: () {
// //                       // Navigate to Privacy Policy
// //                     },
// //                     child: Text(
// //                       'Privacy Policy',
// //                       style: GoogleFonts.inter(
// //                         color: Colors.grey[600],
// //                         fontWeight: FontWeight.w500,
// //                       ),
// //                     ),
// //                   ),
// //                   Text('•', style: TextStyle(color: Colors.grey[600])),
// //                   TextButton(
// //                     onPressed: () {
// //                       // Navigate to Terms of Service
// //                     },
// //                     child: Text(
// //                       'Terms of Service',
// //                       style: GoogleFonts.inter(
// //                         color: Colors.grey[600],
// //                         fontWeight: FontWeight.w500,
// //                       ),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ],
// //           ),
// //         ),
// //       ],
// //     );
// //   }

// //   ShowPaymentOption(
// //       {required double price, required Map<String, dynamic> plan}) {
// //     showModalBottomSheet(
// //         context: context,
// //         showDragHandle: true,
// //         backgroundColor: kPrimaryColor,
// //         isScrollControlled: true,
// //         constraints: BoxConstraints(
// //           minHeight: MediaQuery.of(context).size.height * 0.4,
// //           maxHeight: MediaQuery.of(context).size.height * 0.95,
// //         ),
// //         shape: const RoundedRectangleBorder(
// //             borderRadius:
// //                 BorderRadius.vertical(top: Radius.circular(kDefaultPadding))),
// //         builder: (BuildContext context) {
// //           var uuid = Uuid();
// //           String uniqueId = uuid.v4().substring(0, 10);

// //           return StatefulBuilder(
// //               builder: (BuildContext context, StateSetter setState) {
// //             return Padding(
// //               padding: EdgeInsets.symmetric(
// //                   horizontal: getProportionateScreenWidth(kDefaultPadding * 2)),
// //               child: ListView(
// //                 shrinkWrap: true,
// //                 children: [
// //                   Container(
// //                     child: Column(
// //                       spacing: getProportionateScreenWidth(kDefaultPadding / 8),
// //                       children: [
// //                         Text(
// //                           "${plan['currency']} ${price.toStringAsFixed(2)}",
// //                           style: GoogleFonts.playfairDisplay(
// //                               color: kBlackColor,
// //                               fontWeight: FontWeight.w900,
// //                               fontSize: getProportionateScreenHeight(
// //                                   kDefaultPadding * 1.2)),
// //                         ),
// //                         Text(
// //                           "${plan['title']}",
// //                           style: GoogleFonts.inter(
// //                             color: kGreyColor,
// //                             fontWeight: FontWeight.w600,
// //                             fontSize: 16,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                     padding: EdgeInsets.all(
// //                         getProportionateScreenWidth(kDefaultPadding)),
// //                     margin: EdgeInsets.symmetric(
// //                         horizontal:
// //                             getProportionateScreenWidth(kDefaultPadding * 4)),
// //                     decoration: BoxDecoration(
// //                         color: kWhiteColor,
// //                         borderRadius: BorderRadius.circular(kDefaultPadding)),
// //                   ),
// //                   SizedBox(
// //                       height: getProportionateScreenHeight(kDefaultPadding)),
// //                   Row(
// //                     mainAxisAlignment: MainAxisAlignment.spaceAround,
// //                     children: [
// //                       _buildPaymentContainer(
// //                         title: "Telebirr InApp",
// //                         imageUrl: "images/telebirr.png",
// //                         onPressed: () {
// //                           Navigator.push(
// //                             context,
// //                             MaterialPageRoute(
// //                               builder: (context) {
// //                                 return SubscriptionPaymentInApp(
// //                                   amount: price,
// //                                   context: context,
// //                                   traceNo: uniqueId,
// //                                   phone: userData['user']['phone'],
// //                                 );
// //                               },
// //                             ),
// //                           ).then((value) {
// //                             Navigator.of(context).pop();
// //                             print("Value: $value");
// //                             if (value != null && value == true) {
// //                               print("Payment Successful>>>");
// //                               _buyProduct(_subscriptionPlans.indexOf(plan));
// //                             } else {
// //                               print("Payment NOT Successful>>>");
// //                               Future.delayed(Duration(milliseconds: 100), () {
// //                                 if (mounted) {
// //                                   ScaffoldMessenger.of(context).showSnackBar(
// //                                       Service.showMessage(
// //                                           "Payment not completed. Please choose your payment method.",
// //                                           true));
// //                                 }
// //                               });
// //                             }
// //                           });
// //                         },
// //                       ),
// //                       _buildPaymentContainer(
// //                         title: "Telebirr USSD",
// //                         imageUrl: "images/telebirr.png",
// //                         onPressed: () {
// //                           Navigator.push(context, MaterialPageRoute(
// //                             builder: (context) {
// //                               return SubscriptionPaymentUssd(
// //                                 amount: price,
// //                                 traceNo: uniqueId,
// //                                 phone: userData['user']['phone'],
// //                                 userId: userData['user']['_id'],
// //                                 url:
// //                                     "http://196.189.44.60:8069/telebirr/ussd/send_sms",
// //                               );
// //                             },
// //                           ));
// //                         },
// //                       ),
// //                     ],
// //                   ),
// //                 ],
// //               ),
// //             );
// //           });
// //         });
// //   }

// //   Widget _buildPaymentContainer(
// //       {required String title,
// //       required String imageUrl,
// //       required Function()? onPressed}) {
// //     return ElevatedButton(
// //         onPressed: onPressed,
// //         style: ElevatedButton.styleFrom(
// //           foregroundColor: kBlackColor,
// //           backgroundColor: kPrimaryColor,
// //           padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(12),
// //           ),
// //         ),
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             Container(
// //               width: getProportionateScreenWidth(kDefaultPadding * 4),
// //               height: getProportionateScreenHeight(kDefaultPadding * 3),
// //               decoration: BoxDecoration(
// //                 borderRadius: BorderRadius.circular(
// //                   getProportionateScreenWidth(kDefaultPadding / 2),
// //                 ),
// //               ),
// //               child: Image.asset(imageUrl),
// //             ),
// //             Text(
// //               title,
// //               textAlign: TextAlign.center,
// //               style: GoogleFonts.inter(
// //                 fontWeight: FontWeight.w700,
// //                 color: kBlackColor,
// //                 fontSize: getProportionateScreenWidth(
// //                   kDefaultPadding,
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ));
// //   }

// //   // Widget PremiumStatusCard(
// //   //     {required int amount,
// //   //     required Color color,
// //   //     daysLeft,
// //   //     planDay,
// //   //     planType}) {
// //   //   return Container(
// //   //     padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
// //   //     decoration: BoxDecoration(
// //   //       gradient: LinearGradient(
// //   //         colors: amount == 100
// //   //             ? [Color(0xFF4A3298), Color(0xFF6A52B8)]
// //   //             : [color, color.withValues(alpha: 0.8)],
// //   //         begin: Alignment.topLeft,
// //   //         end: Alignment.bottomRight,
// //   //       ),
// //   //       boxShadow: [
// //   //         BoxShadow(
// //   //           color: color.withValues(alpha: 0.3),
// //   //           blurRadius: 15,
// //   //           offset: Offset(0, 5),
// //   //         ),
// //   //       ],
// //   //     ),
// //   //     child: Column(
// //   //       mainAxisSize: MainAxisSize.min,
// //   //       children: [
// //   //         Container(
// //   //           padding: EdgeInsets.all(
// //   //               getProportionateScreenWidth(kDefaultPadding / 2)),
// //   //           decoration: BoxDecoration(
// //   //             color: kPrimaryColor.withValues(alpha: 0.2),
// //   //             shape: BoxShape.circle,
// //   //           ),
// //   //           child: Icon(
// //   //             Icons.diamond,
// //   //             size: 50,
// //   //             color: kPrimaryColor,
// //   //           ),
// //   //         ),
// //   //         SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //   //         Text(
// //   //           'Premium Member',
// //   //           style: GoogleFonts.playfairDisplay(
// //   //             color: kPrimaryColor,
// //   //             fontSize: 26,
// //   //             fontWeight: FontWeight.bold,
// //   //             letterSpacing: 0.5,
// //   //           ),
// //   //         ),
// //   //         SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
// //   //         Text(
// //   //           '$planType Plan',
// //   //           style: GoogleFonts.inter(
// //   //             color: kPrimaryColor.withValues(alpha: 0.8),
// //   //             fontSize: 16,
// //   //             fontWeight: FontWeight.w500,
// //   //           ),
// //   //         ),
// //   //         SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //   //         LinearProgressIndicator(
// //   //           value: daysLeft / planDay,
// //   //           backgroundColor: kPrimaryColor.withValues(alpha: 0.2),
// //   //           valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
// //   //         ),
// //   //         SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
// //   //         Text(
// //   //           '$daysLeft days remaining',
// //   //           style: GoogleFonts.inter(
// //   //             color: kPrimaryColor,
// //   //             fontSize: 14,
// //   //             fontWeight: FontWeight.w500,
// //   //           ),
// //   //         ),
// //   //       ],
// //   //     ),
// //   //   );
// //   // }
// //   // Note: Only the PremiumStatusCard widget is updated here
// //   Widget PremiumStatusCard({
// //     required int amount,
// //     required Color color,
// //     required int daysLeft,
// //     required int planDay,
// //     required String planType,
// //     required bool isLatestPlan,
// //   }) {
// //     final isActive = daysLeft > 0; // Active if days remain
// //     final buttonText = isLatestPlan ? "Manage Subscription" : "Upgrade";

// //     return Container(
// //       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
// //       decoration: BoxDecoration(
// //         gradient: LinearGradient(
// //           colors: amount == 100
// //               ? [Color(0xFF4A3298), Color(0xFF6A52B8)]
// //               : [color, color.withValues(alpha: 0.8)],
// //           begin: Alignment.topLeft,
// //           end: Alignment.bottomRight,
// //         ),
// //         boxShadow: [
// //           BoxShadow(
// //             color: color.withValues(alpha: 0.3),
// //             blurRadius: 15,
// //             offset: Offset(0, 5),
// //           ),
// //         ],
// //       ),
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Container(
// //             padding: EdgeInsets.all(
// //                 getProportionateScreenWidth(kDefaultPadding / 2)),
// //             decoration: BoxDecoration(
// //               color: kPrimaryColor.withValues(alpha: 0.2),
// //               shape: BoxShape.circle,
// //             ),
// //             child: Icon(
// //               Icons.diamond,
// //               size: 50,
// //               color: kPrimaryColor,
// //             ),
// //           ),
// //           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //           Row(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               Text(
// //                 'Premium Member',
// //                 style: GoogleFonts.playfairDisplay(
// //                   color: kPrimaryColor,
// //                   fontSize: 26,
// //                   fontWeight: FontWeight.bold,
// //                   letterSpacing: 0.5,
// //                 ),
// //               ),
// //               SizedBox(width: kDefaultPadding / 2),
// //               Container(
// //                 padding: EdgeInsets.symmetric(
// //                   horizontal: kDefaultPadding / 2,
// //                   vertical: kDefaultPadding / 4,
// //                 ),
// //                 decoration: BoxDecoration(
// //                   color: kWhiteColor,
// //                   borderRadius: BorderRadius.circular(kDefaultPadding / 2),
// //                 ),
// //                 child: Text(
// //                   isActive ? "Active" : "Expired",
// //                   style: GoogleFonts.inter(
// //                     color: isActive ? color : kGreyColor,
// //                     fontSize: 12,
// //                     fontWeight: FontWeight.w600,
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
// //           Text(
// //             '$planType Plan (\$${amount.toStringAsFixed(2)})',
// //             style: GoogleFonts.inter(
// //               color: kPrimaryColor.withValues(alpha: 0.8),
// //               fontSize: 16,
// //               fontWeight: FontWeight.w500,
// //             ),
// //           ),
// //           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //           LinearProgressIndicator(
// //             value: isActive ? daysLeft / planDay : 0,
// //             backgroundColor: kPrimaryColor.withValues(alpha: 0.2),
// //             valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
// //           ),
// //           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
// //           Text(
// //             isActive ? '$daysLeft days remaining' : 'Subscription expired',
// //             style: GoogleFonts.inter(
// //               color: kPrimaryColor,
// //               fontSize: 14,
// //               fontWeight: FontWeight.w500,
// //             ),
// //           ),
// //           if (isActive) ...[
// //             SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
// //             CustomButton(
// //               title: buttonText,
// //               color: kWhiteColor,
// //               titleColor: color,
// //               radius: kDefaultPadding / 2,
// //               textFontSize: 14,
// //               width: getProportionateScreenWidth(140),
// //               onPressed: () {
// //                 ScaffoldMessenger.of(context).showSnackBar(
// //                   Service.showMessage(
// //                     "Visit https://x.ai/grok for subscription details",
// //                     false,
// //                   ),
// //                 );
// //               },
// //             ),
// //           ],
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildSubscribedView() {
// //     final subscription = userData['user']['subscritption_data'];
// //     final dateofSub = DateTime.parse(subscription['date_of_subscription']);
// //     final amount = subscription['subscription_amount'];

// //     var planDay = amount == 100 ? 30 : 7;
// //     String planType = amount == 100 ? "Monthly" : "Weekly";
// //     final endDate = dateofSub.add(Duration(days: planDay));
// //     final daysLeft = endDate.difference(DateTime.now()).inDays;
// //     Color color = amount == 100 ? Color(0xFF6A52B8) : kBlackColor;

// //     return SingleChildScrollView(
// //       child: Padding(
// //         padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // Renewal Button
// //             Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceAround,
// //               children: [
// //                 if (daysLeft <= 7)
// //                   ElevatedButton.icon(
// //                     onPressed: () {
// //                       // Handle renewal
// //                     },
// //                     icon: Icon(Icons.refresh),
// //                     label: Text(
// //                       'Renew Subscription',
// //                       style: GoogleFonts.inter(
// //                         fontWeight: FontWeight.w600,
// //                       ),
// //                     ),
// //                     style: ElevatedButton.styleFrom(
// //                       backgroundColor: color,
// //                       foregroundColor: kPrimaryColor,
// //                       padding:
// //                           EdgeInsets.symmetric(horizontal: 20, vertical: 16),
// //                       shape: RoundedRectangleBorder(
// //                         borderRadius: BorderRadius.circular(12),
// //                       ),
// //                     ),
// //                   ),
// //                 if (planType == "Weekly")
// //                   ElevatedButton.icon(
// //                     onPressed: () {
// //                       // Handle renewal
// //                     },
// //                     icon: Icon(Icons.upgrade_outlined),
// //                     label: Text(
// //                       'Upgrade Plan',
// //                       style: GoogleFonts.inter(
// //                         fontWeight: FontWeight.w600,
// //                       ),
// //                     ),
// //                     style: ElevatedButton.styleFrom(
// //                       backgroundColor: color,
// //                       foregroundColor: kPrimaryColor,
// //                       padding:
// //                           EdgeInsets.symmetric(horizontal: 20, vertical: 16),
// //                       shape: RoundedRectangleBorder(
// //                         borderRadius: BorderRadius.circular(12),
// //                       ),
// //                     ),
// //                   ),
// //               ],
// //             ),
// //             SizedBox(height: getProportionateScreenHeight(kDefaultPadding * 2)),
// //             // Active Benefits Section
// //             Text(
// //               'Your Active Benefits',
// //               style: GoogleFonts.playfairDisplay(
// //                 fontSize: 22,
// //                 fontWeight: FontWeight.bold,
// //                 color: kBlackColor,
// //                 letterSpacing: 0.3,
// //               ),
// //             ),
// //             SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //             // Benefits Grid
// //             GridView.count(
// //               shrinkWrap: true,
// //               physics: NeverScrollableScrollPhysics(),
// //               crossAxisCount: 2,
// //               crossAxisSpacing: 15,
// //               mainAxisSpacing: 15,
// //               childAspectRatio: 1.4,
// //               children:
// //                   _subscriptionPlans[1]['benefits'].map<Widget>((benefit) {
// //                 bool doesContainValue(string) {
// //                   bool value =
// //                       benefit.toString().toLowerCase().contains(string);
// //                   return value;
// //                 }

// //                 return _buildBenefitCard(
// //                     color: color,
// //                     icon: doesContainValue("free deliveries")
// //                         ? Icons.local_shipping_outlined
// //                         : doesContainValue("% off")
// //                             ? Icons.price_check_outlined
// //                             : doesContainValue("exclusive")
// //                                 ? Icons.discount_outlined
// //                                 : doesContainValue("support")
// //                                     ? Icons.support_agent_outlined
// //                                     : Icons.star_outline,
// //                     title: benefit);
// //               }).toList(),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildBenefitCard({
// //     required IconData icon,
// //     required String title,
// //     String? description,
// //     Color? color,
// //   }) {
// //     return Container(
// //       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding / 8)),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(15),
// //         border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.grey.withValues(alpha: 0.1),
// //             blurRadius: 10,
// //             offset: Offset(0, 3),
// //           ),
// //         ],
// //       ),
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           Icon(
// //             icon,
// //             size: 28,
// //             color: color ?? Color(0xFF4A3298),
// //           ),
// //           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //           Text(
// //             title,
// //             style: GoogleFonts.inter(
// //               fontWeight: FontWeight.w600,
// //               fontSize: 14,
// //             ),
// //             textAlign: TextAlign.center,
// //           ),
// //           SizedBox(height: 4),
// //           Text(
// //             description ?? '',
// //             style: GoogleFonts.inter(
// //               color: Colors.grey[600],
// //               fontSize: 12,
// //               fontWeight: FontWeight.w400,
// //             ),
// //             textAlign: TextAlign.center,
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
