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

/// Premium palette: ZMall brand red for action, deep ink for exclusivity,
/// gold for the premium accent and green for trust/active states.
class _Premium {
  static Color get red => kSecondaryColor;
  static const redDeep = Color(0xFFC8102E);
  static const ink = Color(0xFF0F1422);
  static const inkSoft = Color(0xFF1C2435);
  static const gold = Color(0xFFD4A64A);
  static const goldLight = Color(0xFFF2D58A);
  static const trust = Color(0xFF12B76A);
  static const surface = Color(0xFFF6F7FB);
  static const border = Color(0xFFE7E9F0);
  static const textMuted = Color(0xFF667085);
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
  static const double _expandedHeaderHeight = 340.0;

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
      'gradient': [_Premium.inkSoft, _Premium.ink],
      'accentColor': _Premium.red,
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

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 0.8, curve: Curves.easeOutBack),
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
          // Only treat the header as collapsed once the dark hero has fully
          // scrolled away, so the dark title never shows over it mid-transition.
          final double collapsePoint = _expandedHeaderHeight -
              kToolbarHeight -
              MediaQuery.of(context).padding.top -
              4;
          final bool collapsed = _scrollController.offset >= collapsePoint;
          if (collapsed != _isCollapsed) {
            setState(() => _isCollapsed = collapsed);
          }
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

  // ── UI helpers ───────────────────────────────────────────────────────────
  void _openCheckout() {
    if (_subscriptionPlans.isEmpty) return;
    final plan = _subscriptionPlans[0];
    ShowPaymentOption(price: (plan['price'] as num).toDouble(), plan: plan);
  }

  String _formatPrice(num price) =>
      price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }

  Widget _goldBadge({IconData icon = Icons.workspace_premium_rounded, double size = 28}) {
    return Container(
      padding: EdgeInsets.all(size * 0.45),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Premium.goldLight, _Premium.gold],
        ),
        boxShadow: [
          BoxShadow(
            color: _Premium.gold.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: size, color: _Premium.ink),
    );
  }

  Widget _premiumPill(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _Premium.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Premium.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: _Premium.goldLight),
          SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              color: _Premium.goldLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool isActive, {bool onDark = true}) {
    final Color fg = isActive
        ? (onDark ? Color(0xFF6CE9A6) : _Premium.trust)
        : (onDark ? Colors.white70 : _Premium.textMuted);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? _Premium.trust.withValues(alpha: onDark ? 0.18 : 0.1)
            : (onDark ? Colors.white.withValues(alpha: 0.1) : _Premium.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Expired',
            style: GoogleFonts.inter(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData icon = Icons.arrow_forward_rounded,
    bool expand = false,
  }) {
    final bool enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_Premium.red, _Premium.redDeep],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _Premium.red.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(icon, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _Premium.ink,
          side: BorderSide(color: _Premium.ink.withValues(alpha: 0.15)),
          padding: EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _Premium.ink,
            letterSpacing: -0.4,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _Premium.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  BoxDecoration _cardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _Premium.border),
      boxShadow: [
        BoxShadow(
          color: _Premium.ink.withValues(alpha: 0.04),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // If admin has disabled subscriptions, show a simple message
    if (!_loading && !_subscriptionEnabled) {
      return Scaffold(
        backgroundColor: _Premium.surface,
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
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _Premium.ink.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    size: 48,
                    color: _Premium.textMuted,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Subscription Not Available',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _Premium.ink,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'The subscription feature is currently unavailable.\nPlease check back later.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _Premium.textMuted,
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
        backgroundColor: _Premium.surface,
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

    return SliverAppBar(
      expandedHeight: _expandedHeaderHeight,
      floating: false,
      pinned: true,
      stretch: true,
      centerTitle: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: _isCollapsed ? Colors.white : _Premium.ink,
      leading: CustomBackButton(
        color: _isCollapsed ? kBlackColor : Colors.white,
      ),
      // Title lives on the bar itself (not the flexible space) so it never
      // scales or slides over the dark hero; it only appears once collapsed.
      title: AnimatedOpacity(
        opacity: _isCollapsed ? 1 : 0,
        duration: Duration(milliseconds: 150),
        child: Text(
          'ZMall Premium',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _Premium.ink,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRect(
          child: OverflowBox(
            minHeight: 0.0,
            maxHeight: 360.0,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 340,
              child: isActive
                  ? PremiumStatusCard(
                      amount: _subscriptionPrice.toInt(),
                      color: _Premium.gold,
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

  Widget _buildHeroBackground({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Premium.ink, _Premium.inkSoft, Color(0xFF2A1520)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -60,
            child: _glow(260, _Premium.red.withValues(alpha: 0.32)),
          ),
          Positioned(
            left: -70,
            bottom: -90,
            child: _glow(240, _Premium.gold.withValues(alpha: 0.2)),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isSubscribed, int amount) {
    return _buildHeroBackground(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _goldBadge(size: 26),
                    SizedBox(height: 14),
                    _premiumPill('ZMALL PREMIUM'),
                    SizedBox(height: 12),
                    Text(
                      isSubscribed
                          ? "Welcome back"
                          : "Free delivery on every order",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      isSubscribed
                          ? "Your membership has ended. Renew to keep your perks."
                          : "One simple plan · ETB ${_formatPrice(_subscriptionPrice)} for $_subscriptionDurationDays days",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 20),
                    _primaryButton(
                      label: isSubscribed ? "Renew Membership" : "Become a Member",
                      onPressed: _openCheckout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    final progress =
        (planDay > 0 && isActive) ? (daysLeft / planDay).clamp(0.0, 1.0) : 0.0;

    return _buildHeroBackground(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, kToolbarHeight - 8, 20, 20),
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF26304A), Color(0xFF121826)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _Premium.gold.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 20,
                          color: _Premium.goldLight,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'ZMALL PREMIUM',
                          style: GoogleFonts.inter(
                            color: _Premium.goldLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        Spacer(),
                        _statusPill(isActive),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$daysLeft',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 36,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 8),
                        Padding(
                          padding: EdgeInsets.only(bottom: 3),
                          child: Text(
                            daysLeft == 1 ? 'day left' : 'days left',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _Premium.goldLight,
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _subscriptionExpiry != null
                                ? 'Renews manually · until ${DateFormat('MMM d, yyyy').format(_subscriptionExpiry!)}'
                                : '$planType plan · ETB ${_formatPrice(amount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (isActive)
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (!isLatestPlan) {
                                _openCheckout();
                              } else {
                                _showManageSubscriptionSheet(
                                  planType: planType,
                                  amount: amount,
                                  daysLeft: daysLeft,
                                  endDate: _subscriptionExpiry,
                                );
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isLatestPlan ? 'Manage' : 'Upgrade',
                                style: GoogleFonts.inter(
                                  color: _Premium.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    Widget detailRow(String label, String value) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 14, color: _Premium.textMuted),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _Premium.ink,
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _Premium.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  _goldBadge(size: 18),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZMall Premium',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _Premium.ink,
                          ),
                        ),
                        Text(
                          'Membership details',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _Premium.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusPill(true, onDark: false),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _Premium.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    detailRow('Plan', '$planType Plan'),
                    Divider(height: 1, color: _Premium.border),
                    detailRow('Price', 'ETB ${_formatPrice(amount)}'),
                    Divider(height: 1, color: _Premium.border),
                    detailRow('Days left', '$daysLeft days'),
                    if (endDate != null) ...[
                      Divider(height: 1, color: _Premium.border),
                      detailRow(
                        'Valid until',
                        DateFormat('MMM d, yyyy').format(endDate),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: _Premium.trust),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enjoy free delivery and exclusive member offers on all your orders. Your plan never renews automatically.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _Premium.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Premium.ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(
                    'Done',
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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_Premium.inkSoft, _Premium.ink],
                ),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_Premium.goldLight),
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Checking your membership…',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _Premium.ink,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'This only takes a moment',
              style: GoogleFonts.inter(fontSize: 13, color: _Premium.textMuted),
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
      padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              ),
            ),
            child: _sectionTitle(
              isSubscribed ? 'Renew your membership' : 'Why go Premium?',
              subtitle: isSubscribed
                  ? 'Your subscription has expired. Renew now to continue enjoying premium benefits.'
                  : 'Everything you love about ZMall, with more savings and less waiting.',
            ),
          ),
          SizedBox(height: 16),
          _buildFeaturesList(),
          SizedBox(height: 28),
          _buildSubscriptionPlans(),
          SizedBox(height: 4),
          _buildTrustStrip(),
          SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildTrustStrip() {
    Widget item(IconData icon, String label) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: _cardDecoration(radius: 16),
          child: Column(
            children: [
              Icon(icon, size: 20, color: _Premium.trust),
              SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _Premium.ink,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: [
          item(Icons.lock_outline_rounded, 'Secure\npayment'),
          SizedBox(width: 10),
          item(Icons.bolt_rounded, 'Instant\nactivation'),
          SizedBox(width: 10),
          item(Icons.event_available_outlined, 'No auto\nrenewal'),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      (
        Icons.local_shipping_outlined,
        'Free Express Delivery',
        'Get your orders faster with priority delivery',
      ),
      (
        Icons.discount_outlined,
        'Exclusive Discounts',
        'Save more on every purchase with member pricing',
      ),
      (
        Icons.support_agent_outlined,
        'Priority Support',
        '24/7 dedicated assistance from our team',
      ),
      (
        Icons.card_giftcard_outlined,
        'Early Access Offers',
        'Get special deals before anyone else',
      ),
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              for (int i = 0; i < features.length; i++) ...[
                _buildBenefitItem(
                  icon: features[i].$1,
                  title: features[i].$2,
                  subtitle: features[i].$3,
                ),
                if (i < features.length - 1)
                  Divider(height: 1, color: _Premium.border),
              ],
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
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _Premium.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _Premium.red, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _Premium.ink,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: _Premium.textMuted,
                    height: 1.35,
                  ),
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
        _sectionTitle('Your plan'),
        SizedBox(height: 14),
        ..._subscriptionPlans.map((plan) {
          final isPopular = plan['isPopular'] == true;
          final isCurrentPlan = isActive && plan['price'] == currentPlanPrice;

          return ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: EdgeInsets.only(bottom: 20),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: plan['gradient'],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _Premium.gold.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _Premium.ink.withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -60,
                    top: -60,
                    child: _glow(200, _Premium.red.withValues(alpha: 0.25)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isPopular) _premiumPill('BEST VALUE'),
                            Spacer(),
                            if (isCurrentPlan) _statusPill(true),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          plan['title'],
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (plan['subtitle'] != null) ...[
                          SizedBox(height: 4),
                          Text(
                            plan['subtitle'],
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _Premium.goldLight,
                            ),
                          ),
                        ],
                        SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                "${plan['currency']} ",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                            Text(
                              _formatPrice(plan['price'] as num),
                              style: GoogleFonts.inter(
                                fontSize: 42,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                ' / ${plan['interval']}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          plan['description'],
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        ...plan['benefits'].map<Widget>((benefit) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: _Premium.gold.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: _Premium.goldLight,
                                    size: 14,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    benefit,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.92),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        SizedBox(height: 10),
                        _primaryButton(
                          label: isCurrentPlan ? 'Subscribed' : 'Subscribe now',
                          icon: isCurrentPlan
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          expand: true,
                          onPressed: () {
                            ShowPaymentOption(
                              price: (plan['price'] as num).toDouble(),
                              plan: plan,
                            );
                          },
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
        padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
        margin: EdgeInsets.only(bottom: kDefaultPadding),
        decoration: BoxDecoration(
          color: _Premium.ink.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Premium.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _Premium.textMuted),
                SizedBox(width: 6),
                Text(
                  'Subscription Terms',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _Premium.ink,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              "Subscriptions do not automatically renew. To continue your subscription, please renew manually before the end of each period. You can manage your subscriptions in your Account Settings.",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _Premium.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    // Navigate to Privacy Policy
                  },
                  child: Text(
                    'Privacy Policy',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: _Premium.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text('•', style: TextStyle(color: _Premium.textMuted)),
                TextButton(
                  onPressed: () {
                    // Navigate to Terms of Service
                  },
                  child: Text(
                    'Terms of Service',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: _Premium.red,
                      fontWeight: FontWeight.w600,
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
    final planType = "Monthly";
    final daysLeft = isActive && _subscriptionExpiry != null
        ? _subscriptionExpiry!.difference(currentDate).inDays.clamp(0, 9999)
        : 0;
    final isLatestPlan = true; // backend only has one plan now
    final planIndex = 0; // single plan

    Widget infoTile(String label, String value) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: _Premium.textMuted),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _Premium.ink,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subscription Status
          Container(
            padding: EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _goldBadge(size: 18),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$planType Plan',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _Premium.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'ETB ${_formatPrice(amount)} / ${planType.toLowerCase()}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _Premium.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusPill(isActive, onDark: false),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: _Premium.border),
                ),
                Row(
                  children: [
                    infoTile(
                      isActive ? 'Valid until' : 'Expired on',
                      DateFormat('MMM d, yyyy').format(endDate),
                    ),
                    infoTile('Days left', '$daysLeft'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Action Buttons
          if (!isActive || daysLeft <= 7) ...[
            _primaryButton(
              label: isActive ? 'Renew Subscription' : 'Resubscribe',
              icon: Icons.refresh_rounded,
              expand: true,
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
            ),
            SizedBox(height: 12),
          ],
          if (isActive && !isLatestPlan) ...[
            _primaryButton(
              label: 'Upgrade to Monthly',
              icon: Icons.upgrade_rounded,
              expand: true,
              onPressed: _openCheckout,
            ),
            SizedBox(height: 12),
          ],
          if (isActive && isLatestPlan)
            _secondaryButton(
              label: 'Manage Subscription',
              icon: Icons.tune_rounded,
              onPressed: () {
                _showManageSubscriptionSheet(
                  planType: planType,
                  amount: amount,
                  daysLeft: daysLeft,
                  endDate: endDate,
                );
              },
            ),
          if (isActive) ...[
            SizedBox(height: 28),
            _sectionTitle('Your active benefits'),
            SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: _subscriptionPlans[planIndex]['benefits'].map<Widget>(
                (benefit) {
                  bool doesContainValue(string) {
                    return benefit.toString().toLowerCase().contains(string);
                  }

                  return _buildBenefitCard(
                    color: _Premium.red,
                    icon: doesContainValue("free deliveries") || doesContainValue("free delivery")
                        ? Icons.local_shipping_outlined
                        : doesContainValue("% off") || doesContainValue("discount")
                        ? Icons.price_check_outlined
                        : doesContainValue("exclusive")
                        ? Icons.card_giftcard_outlined
                        : doesContainValue("support") || doesContainValue("priority")
                        ? Icons.support_agent_outlined
                        : Icons.star_outline_rounded,
                    title: benefit,
                    description: 'Active',
                  );
                },
              ).toList(),
            ),
          ],
          if (!isActive || !isLatestPlan)
            Padding(
              padding: EdgeInsets.only(top: 28),
              child: _buildSubscriptionPlans(),
            ),
          SizedBox(height: 24),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    String? description,
    Color? color,
  }) {
    final Color accent = color ?? _Premium.red;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _Premium.ink,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (description != null && description.isNotEmpty) ...[
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: _Premium.trust),
                    SizedBox(width: 4),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        color: _Premium.trust,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
      backgroundColor: Colors.white,
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
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Checkout',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _Premium.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: _Premium.ink.withValues(alpha: 0.6),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: _Premium.surface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Order summary
                  Container(
                    padding: EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            plan['gradient'] ?? [_Premium.inkSoft, _Premium.ink],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _Premium.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        _goldBadge(size: 18),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${plan['title']}",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '$_subscriptionDurationDays days · Free delivery',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${plan['currency']} ${_formatPrice(price)}",
                          style: GoogleFonts.inter(
                            color: _Premium.goldLight,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Choose payment method',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _Premium.ink,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildPaymentContainer(
                    title: "Telebirr InApp",
                    subtitle: "Pay with the Telebirr app",
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
                  SizedBox(height: 10),
                  _buildPaymentContainer(
                    title: "Telebirr USSD",
                    subtitle: "Pay with a USSD code",
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
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: _Premium.trust,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Secure payment · No automatic renewal',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _Premium.textMuted,
                        ),
                      ),
                    ],
                  ),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _Premium.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _Premium.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Image.asset(imageUrl, width: 28, height: 28),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _Premium.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: _Premium.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _Premium.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _Premium.ink,
                ),
              ),
            ],
          ),
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
