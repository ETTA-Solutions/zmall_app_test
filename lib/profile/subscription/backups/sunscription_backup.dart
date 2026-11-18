// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:uuid/uuid.dart';
// import 'package:zmall/constants.dart';
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
//   // late Animation<double> _slideAnimation;
//   late ScrollController _scrollController;
//   bool _isCollapsed = false;
//   final List<Map<String, dynamic>> _subscriptionPlans = [
//     {
//       'title': 'Weekly Premium',
//       'description': 'Perfect for trying out our premium features',
//       'benefits': ['Free deliveries', 'Priority service', '10% off all orders'],
//       'price': 10.00,
//       'currency': 'ETB',
//       'interval': 'weak',
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
//     print("userData>>>> ${userData}");
//     print("sub>>>> ${userData['user']['subscritption_data']}");
//     _isSubscribed = userData['user']['subscritption_data'] != null &&
//         userData['user']['subscritption_data']['is_user_subscribed'];
//     print("isSubscribed $_isSubscribed");
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

//     // _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
//     //   CurvedAnimation(
//     //     parent: _animationController,
//     //     curve: Interval(0.2, 0.7, curve: Curves.easeOut),
//     //   ),
//     // );
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
//           content: Text('Subscription successful! Enjoy premium features.'),
//           backgroundColor: kBlackColor,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     });
//   }

//   // void _restorePurchases() {
//   //   setState(() {
//   //     _loading = true;
//   //   });
//   //   Future.delayed(Duration(seconds: 2), () {
//   //     setState(() {
//   //       _loading = false;
//   //       _isSubscribed = false;
//   //     });
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //         content: Text('Purchases restored successfully!'),
//   //         backgroundColor: kBlackColor,
//   //         // Color(0xFF4A3298),
//   //         behavior: SnackBarBehavior.floating,
//   //       ),
//   //     );
//   //   });
//   // }

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
//     final dateofSub = subscription != null
//         ? DateTime.parse(subscription['date_of_subscription'])
//         : DateTime.now();
//     final amount =
//         subscription != null ? subscription['subscription_amount'] : 0.0;
//     // int amount = 100;
//     var planDay = amount == 100 ? 30 : 7;
//     String planType = amount == 100 ? "Monthly" : "Weekly";
//     final endDate = dateofSub.add(Duration(days: planDay));
//     final daysLeft = endDate.difference(DateTime.now()).inDays;
//     Color color = amount == 100 ? Color(0xFF6A52B8) : kBlackColor;
//     return SliverAppBar(
//       expandedHeight: 200.0,
//       floating: false,
//       pinned: true,
//       stretch: true,
//       centerTitle: true,
//       // actions: [
//       //   IconButton(
//       //       onPressed: () {
//       //         print("isSubscribed $_isSubscribed");
//       //       },
//       //       icon: Icon(Icons.abc))
//       // ],
//       leading:
//           CustomBackButton(color: _isCollapsed ? kBlackColor : kPrimaryColor),
//       flexibleSpace: FlexibleSpaceBar(
//         title: Opacity(
//           opacity: _isSubscribed ? 0 : 1,
//           child: Text('Premium Membership',
//               style: GoogleFonts.notoSerif(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: _isCollapsed ? kBlackColor : kPrimaryColor,
//               )
//               // TextStyle(
//               //   fontSize: 16,
//               //   color: _isCollapsed ? kBlackColor : kPrimaryColor,
//               //   fontWeight: FontWeight.bold,
//               // ),
//               ),
//         ),
//         background: _isSubscribed
//             ? PremiumStatusCard(
//                 amount: amount,
//                 color: color,
//                 daysLeft: daysLeft,
//                 planDay: planDay,
//                 planType: planType)
//             : Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: [
//                       kSecondaryColor,
//                       kSecondaryColor.withValues(alpha: 0.8)
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
//                       child: Icon(
//                         Icons.diamond_outlined,
//                         size: 80,
//                         color: Colors.white.withValues(alpha: 0.6),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
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
//             style: TextStyle(
//               color: kSecondaryColor,
//               fontSize: 16,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Widget _buildSubscribedView() {
//   //   return Center(
//   //     child: Column(
//   //       mainAxisAlignment: MainAxisAlignment.center,
//   //       children: [
//   //         Icon(
//   //           Icons.check_circle_outline,
//   //           size: 100,
//   //           color: Colors.green,
//   //         ),
//   //         SizedBox(height: getProportionateScreenHeight(kDefaultPadding * 1.3)),
//   //         Text(
//   //           'You\'re Premium!',
//   //           style: TextStyle(
//   //             fontSize: 24,
//   //             fontWeight: FontWeight.bold,
//   //             color: kSecondaryColor,
//   //             // Color(0xFF4A3298),
//   //           ),
//   //         ),
//   //         SizedBox(
//   //             height: getProportionateScreenHeight(kDefaultPadding * 0.67)),
//   //         Text(
//   //           'Enjoy all premium benefits',
//   //           style: TextStyle(
//   //             fontSize: 16,
//   //             color: Colors.grey[600],
//   //           ),
//   //         ),
//   //         // SizedBox(height: 30),
//   //         // ElevatedButton(
//   //         //   onPressed: _restorePurchases,
//   //         //   style: ElevatedButton.styleFrom(
//   //         //     foregroundColor: kPrimaryColor,
//   //         //     backgroundColor: kSecondaryColor, // Color(0xFF4A3298),
//   //         //     padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//   //         //     shape: RoundedRectangleBorder(
//   //         //       borderRadius: BorderRadius.circular(12),
//   //         //     ),
//   //         //   ),
//   //         //   child: Text('Manage Subscription'),
//   //         // ),
//   //       ],
//   //     ),
//   //   );
//   // }

//   Widget _buildSubscriptionContent() {
//     return Padding(
//       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
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
//                   'Premium Benefits',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
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
//               color:
//                   // Color(0xFF4A3298)
//                   kSecondaryColor.withValues(alpha: 0.1),
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
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   subtitle,
//                   style: TextStyle(
//                     color: Colors.grey[600],
//                     fontSize: 12,
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
//     return Column(
//       children: _subscriptionPlans.map((plan) {
//         bool isPopular = plan['isPopular'];
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
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   Padding(
//                     padding: EdgeInsets.all(
//                         getProportionateScreenHeight(kDefaultPadding / 1.3)),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(plan['title'],
//                             style: GoogleFonts.notoSerif(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color:
//                                   isPopular ? Color(0xFF4A3298) : Colors.black,
//                             )
//                             // TextStyle(
//                             //   fontSize: 18,
//                             //   fontWeight: FontWeight.bold,
//                             //   color: isPopular ? Color(0xFF4A3298) : Colors.black,
//                             // ),
//                             ),
//                         SizedBox(
//                             height: getProportionateScreenHeight(
//                                 kDefaultPadding / 2)),
//                         Text(
//                           plan['description'],
//                           style: TextStyle(
//                             color: Colors.grey[600],
//                             fontSize: 14,
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
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     color: Colors.grey[800],
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
//                             Text(
//                               "${plan['currency']} ${plan['price'].toInt()}",
//                               style: TextStyle(
//                                 fontSize: 28,
//                                 fontWeight: FontWeight.bold,
//                                 color: isPopular
//                                     ? Color(0xFF4A3298)
//                                     : Colors.black,
//                               ),
//                             ),
//                             Text(
//                               '/${plan['interval']}',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                             Spacer(),
//                             ElevatedButton(
//                               onPressed: () {
//                                 ShowPaymentOption(
//                                     price: plan['price'], plan: plan);
//                                 //  _buyProduct(_subscriptionPlans.indexOf(plan)),
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 foregroundColor: kPrimaryColor,
//                                 backgroundColor:
//                                     isPopular ? Color(0xFF4A3298) : kBlackColor,
//                                 padding: EdgeInsets.symmetric(
//                                     horizontal: 24, vertical: 12),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                               child: Text(
//                                 'Subscribe',
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.bold,
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
//               // TextButton(
//               //   onPressed: _restorePurchases,
//               //   child: Text(
//               //     'Restore Purchases',
//               //     style: TextStyle(
//               //       color: kSecondaryColor,
//               //       //  Color(0xFF4A3298),
//               //       fontWeight: FontWeight.w600,
//               //     ),
//               //   ),
//               // ),
//               // SizedBox(height: 16),
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
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     Text(
//                       // 'Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. You can manage your subscriptions in your Account Settings.',
//                       "Subscriptions do not automatically renew. To continue your subscription, please renew manually before the end of each period. You can manage your subscriptions in your Account Settings.",
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 12,
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
//                       style: TextStyle(color: Colors.grey[600]),
//                     ),
//                   ),
//                   Text('•', style: TextStyle(color: Colors.grey[600])),
//                   TextButton(
//                     onPressed: () {
//                       // Navigate to Terms of Service
//                     },
//                     child: Text(
//                       'Terms of Service',
//                       style: TextStyle(color: Colors.grey[600]),
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
//                           style: TextStyle(
//                               color: kBlackColor,
//                               fontWeight: FontWeight.w900,
//                               fontSize: getProportionateScreenHeight(
//                                   kDefaultPadding)),
//                         ),
//                         Text("${plan['title']}",
//                             style: TextStyle(
//                               color: kGreyColor,
//                               fontWeight: FontWeight.w600,
//                               // fontSize: getProportionateScreenHeight(
//                               //     kDefaultPadding)),
//                             )),
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
//                             print("Value: $value");
//                             if (value != null && value == true) {
//                               print("Payment Successful>>>");
//                               _buyProduct(_subscriptionPlans.indexOf(plan));
//                             } else {
//                               print("Payment NOT Successful>>>");
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

//           // Colors.white,
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
//               style: TextStyle(
//                 fontWeight: FontWeight.w900,
//                 color: kBlackColor,
//                 fontSize: getProportionateScreenWidth(
//                   kDefaultPadding,
//                 ),
//               ),
//             ),
//           ],
//         ));
//   }

//   /////////////////////////////////
//   Widget PremiumStatusCard(
//       {required int amount,
//       required Color color,
//       daysLeft,
//       planDay,
//       planType}) {
//     return Container(
//       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: amount == 100
//               ? [Color(0xFF4A3298), Color(0xFF6A52B8)]
//               : [color, color.withValues(alpha: 0.8)],
//           // colors: [Color(0xFF4A3298), Color(0xFF6A52B8)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         // borderRadius: BorderRadius.circular(20),
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
//         // spacing:getProportionateScreenHeight(kDefaultPadding/2) ,
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
//           Text(
//             'Premium Member',
//             style: TextStyle(
//               color: kPrimaryColor,
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
//           Text(
//             '$planType Plan',
//             style: TextStyle(
//               color: kPrimaryColor.withValues(alpha: 0.8),
//               fontSize: 16,
//             ),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
//           LinearProgressIndicator(
//             value: daysLeft / planDay,
//             backgroundColor: kPrimaryColor.withValues(alpha: 0.2),
//             valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 4)),
//           Text(
//             '$daysLeft days remaining',
//             style: TextStyle(
//               color: kPrimaryColor,
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSubscribedView() {
//     final subscription = userData['user']['subscritption_data'];
//     final dateofSub = DateTime.parse(subscription['date_of_subscription']);
//     final amount = subscription['subscription_amount'];
//     // int amount = 100;
//     var planDay = amount == 100 ? 30 : 7;
//     String planType = amount == 100 ? "Monthly" : "Weekly";
//     final endDate = dateofSub.add(Duration(days: planDay));
//     final daysLeft = endDate.difference(DateTime.now()).inDays;
//     Color color = amount == 100 ? Color(0xFF6A52B8) : kBlackColor;
//     //  var  plan =

//     return SingleChildScrollView(
//       child: Padding(
//         padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding)),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Renewal Button

//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 if (daysLeft <= 7)
//                   ElevatedButton.icon(
//                     onPressed: () {
//                       // Handle renewal
//                     },
//                     icon: Icon(Icons.refresh),
//                     label: Text('Renew Subscription'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color,
//                       // maximumSize: Size.fromWidth(double.infinity),
//                       foregroundColor: kPrimaryColor,
//                       padding:
//                           EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 if (planType == "Weekly")
//                   ElevatedButton.icon(
//                     onPressed: () {
//                       // Handle renewal
//                     },
//                     icon: Icon(Icons.upgrade_outlined),
//                     label: Text('Upgrade Plan'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color,
//                       // maximumSize: Size.fromWidth(double.infinity),
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
//             SizedBox(height: getProportionateScreenHeight(kDefaultPadding * 2)),
//             // Active Benefits Section
//             Text(
//               'Your Active Benefits',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: kBlackColor,
//               ),
//             ),
//             SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),

//             // Benefits Grid
//             GridView.count(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               crossAxisCount: 2,
//               crossAxisSpacing: 15,
//               mainAxisSpacing: 15,
//               childAspectRatio: 1.4,
//               // 1.1,
//               children:
//                   _subscriptionPlans[1]['benefits'].map<Widget>((benefit) {
//                 bool doesContainValue(string) {
//                   bool value =
//                       benefit.toString().toLowerCase().contains(string);
//                   return value;
//                 }

//                 //  _subscriptionPlans[0]
//                 // bool isPopular = plan['isPopular'];
//                 return _buildBenefitCard(
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
//                     title: benefit
//                     // description: 'On all orders',
//                     );
//               }).toList(),
//               // [
//               // _buildBenefitCard(
//               //   color: color,
//               //   icon: Icons.local_shipping,
//               //   title: 'Free Delivery',
//               //   description: 'On all orders',
//               // ),
//               // _buildBenefitCard(
//               //   color: color,
//               //   icon: Icons.price_check,
//               //   title: 'Special Discounts',
//               //   description: 'Up to 15% off',
//               // ),
//               // _buildBenefitCard(
//               //   color: color,
//               //   icon: Icons.support_agent,
//               //   title: 'Priority Support',
//               //   description: '24/7 assistance',
//               // ),
//               // _buildBenefitCard(
//               //   color: color,
//               //   icon: Icons.star,
//               //   title: 'Exclusive Offers',
//               //   description: 'Early access',
//               // ),
//               // ],
//             ),
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
//       padding: EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding / 4)),
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
//             size: 32,
//             color: color ?? Color(0xFF4A3298),
//           ),
//           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
//           Text(
//             title,
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           SizedBox(height: 4),
//           Text(
//             description ?? '',
//             style: TextStyle(
//               color: Colors.grey[600],
//               fontSize: 12,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
// }

// ////////////////
// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:provider/provider.dart';
// // import 'package:url_launcher/url_launcher.dart';
// // import 'package:zmall/constants.dart';
// // import 'package:zmall/custom_widgets/custom_button.dart';
// // import 'package:zmall/size_config.dart';
// // import 'package:zmall/subscription_provider.dart';

// // class SubscriptionScreen extends StatefulWidget {
// //   static String routeName = '/subscription';
// //   const SubscriptionScreen({Key? key}) : super(key: key);

// //   @override
// //   State<SubscriptionScreen> createState() => _SubscriptionScreenState();
// // }

// // class _SubscriptionScreenState extends State<SubscriptionScreen>
// //     with SingleTickerProviderStateMixin {
// //   bool _loading = false;
// //   late AnimationController _animationController;
// //   late Animation<double> _fadeAnimation;
// //   late Animation<double> _scaleAnimation;

// //   // Demo subscription plans (replace with real data from backend in production)
// //   final List<Map<String, String>> _demoPlans = [
// //     {
// //       'title': 'Monthly Premium',
// //       'description': 'Free deliveries, priority service, and 10% off all orders.',
// //       'price': '\$4.99/month',
// //       'priceId': 'price_monthly_premium', // Replace with actual Stripe price ID
// //     },
// //     {
// //       'title': 'Yearly Premium',
// //       'description':
// //           'Free deliveries, priority service, 15% off all orders, and exclusive offers.',
// //       'price': '\$49.99/year',
// //       'priceId': 'price_yearly_premium', // Replace with actual Stripe price ID
// //     },
// //   ];

// //   @override
// //   void initState() {
// //     super.initState();
// //     // Initialize animation controller
// //     _animationController = AnimationController(
// //       vsync: this,
// //       duration: const Duration(milliseconds: 800),
// //     )..forward();

// //     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
// //       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
// //     );
// //     _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
// //       CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
// //     );

// //     // Check subscription status on init
// //     _checkSubscriptionStatus();
// //   }

// //   Future<void> _checkSubscriptionStatus() async {
// //     setState(() {
// //       _loading = true;
// //     });

// //     try {
// //       // Replace with your actual user ID (e.g., from authentication)
// //       const userId = 'user123'; // Example user ID
// //       final response = await http.get(
// //         Uri.parse('http://localhost:3000/subscription-status/$userId'),
// //       );

// //       if (response.statusCode == 200) {
// //         final data = json.decode(response.body);
// //         Provider.of<SubscriptionProvider>(context, listen: false).setSubscriptionStatus(
// //           data['isSubscribed'],
// //           plan: data['plan'],
// //           currentPeriodEnd: data['currentPeriodEnd'],
// //         );
// //       } else {
// //         throw Exception('Failed to check subscription status');
// //       }
// //     } catch (e) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Error: $e')),
// //       );
// //     } finally {
// //       setState(() {
// //         _loading = false;
// //       });
// //     }
// //   }

// //   Future<void> _buyProduct(String priceId) async {
// //     setState(() {
// //       _loading = true;
// //     });

// //     try {
// //       // Replace with your actual user ID (e.g., from authentication)
// //       const userId = 'user123'; // Example user ID
// //       final response = await http.post(
// //         Uri.parse('http://localhost:3000/create-checkout-session'),
// //         headers: {'Content-Type': 'application/json'},
// //         body: json.encode({
// //           'userId': userId,
// //           'priceId': priceId,
// //         }),
// //       );

// //       if (response.statusCode == 200) {
// //         final data = json.decode(response.body);
// //         final checkoutUrl = data['url'];

// //         // Open Stripe Checkout in a web browser
// //         if (await canLaunch(checkoutUrl)) {
// //           await launch(checkoutUrl);
// //           // After the user completes the payment, the webhook updates the backend
// //           // Poll the backend to check subscription status
// //           await Future.delayed(Duration(seconds: 5)); // Simulate delay
// //           await _checkSubscriptionStatus();
// //         } else {
// //           throw 'Could not launch $checkoutUrl';
// //         }
// //       } else {
// //         throw Exception('Failed to create checkout session');
// //       }
// //     } catch (e) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Error: $e')),
// //       );
// //     } finally {
// //       setState(() {
// //         _loading = false;
// //       });
// //     }
// //   }

// //   @override
// //   void dispose() {
// //     _animationController.dispose();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
// //     bool isSubscribed = subscriptionProvider.isSubscribed;

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Text(
// //           'Premium Subscription',
// //           style: TextStyle(
// //             color: kBlackColor,
// //             fontWeight: FontWeight.bold,
// //             fontSize: getProportionateScreenWidth(kDefaultPadding * 1.5),
// //           ),
// //         ),
// //         backgroundColor: kPrimaryColor,
// //         elevation: 0,
// //         centerTitle: true,
// //       ),
// //       body: _loading
// //           ? Center(
// //               child: Column(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   CircularProgressIndicator(color: kPrimaryColor),
// //                   SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
// //                   Text(
// //                     'Processing...',
// //                     style: TextStyle(
// //                       fontSize: getProportionateScreenWidth(kDefaultPadding),
// //                       color: kGreyColor,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             )
// //           : isSubscribed
// //               ? _buildSubscribedView()
// //               : _buildSubscriptionPlansView(),
// //     );
// //   }

// //   Widget _buildSubscribedView() {
// //     return Center(
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           Icon(
// //             Icons.check_circle,
// //             color: kPrimaryColor,
// //             size: getProportionateScreenWidth(kDefaultPadding * 5),
// //           ),
// //           SizedBox(height: getProportionateScreenHeight(kDefaultPadding)),
// //           Text(
// //             'You are a Premium Member!',
// //             style: TextStyle(
// //               fontSize: getProportionateScreenWidth(kDefaultPadding * 1.2),
// //               fontWeight: FontWeight.bold,
// //               color: kBlackColor,
// //             ),
// //           ),
// //           SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //           Text(
// //             'Enjoy free deliveries, priority service, and exclusive discounts.',
// //             textAlign: TextAlign.center,
// //             style: TextStyle(
// //               fontSize: getProportionateScreenWidth(kDefaultPadding),
// //               color: kGreyColor,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildSubscriptionPlansView() {
// //     return SingleChildScrollView(
// //       child: Column(
// //         children: [
// //           // Header Section with Gradient Background
// //           Container(
// //             width: double.infinity,
// //             padding: EdgeInsets.only(
// //               top: getProportionateScreenHeight(kDefaultPadding * 2),
// //               bottom: getProportionateScreenHeight(kDefaultPadding * 3),
// //               left: getProportionateScreenWidth(kDefaultPadding),
// //               right: getProportionateScreenWidth(kDefaultPadding),
// //             ),
// //             decoration: BoxDecoration(
// //               gradient: LinearGradient(
// //                 begin: Alignment.topCenter,
// //                 end: Alignment.bottomCenter,
// //                 colors: [
// //                   kPrimaryColor,
// //                   kPrimaryColor.withValues(alpha:0.8),
// //                 ],
// //               ),
// //             ),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.center,
// //               children: [
// //                 Text(
// //                   'Unlock a Premium Experience',
// //                   textAlign: TextAlign.center,
// //                   style: TextStyle(
// //                     fontSize: getProportionateScreenWidth(kDefaultPadding * 1.5),
// //                     fontWeight: FontWeight.bold,
// //                     color: kWhiteColor,
// //                   ),
// //                 ),
// //                 SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //                 Text(
// //                   'Enjoy exclusive benefits with a Premium subscription.',
// //                   textAlign: TextAlign.center,
// //                   style: TextStyle(
// //                     fontSize: getProportionateScreenWidth(kDefaultPadding),
// //                     color: kWhiteColor.withValues(alpha:0.8),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),

// //           // Benefits Section
// //           Padding(
// //             padding: EdgeInsets.symmetric(
// //               horizontal: getProportionateScreenWidth(kDefaultPadding),
// //               vertical: getProportionateScreenHeight(kDefaultPadding),
// //             ),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   'What You Get:',
// //                   style: TextStyle(
// //                     fontSize: getProportionateScreenWidth(kDefaultPadding * 1.2),
// //                     fontWeight: FontWeight.bold,
// //                     color: kBlackColor,
// //                   ),
// //                 ),
// //                 SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //                 _buildBenefitRow(Icons.local_shipping_outlined, 'Free Deliveries'),
// //                 _buildBenefitRow(Icons.priority_high_outlined, 'Priority Service'),
// //                 _buildBenefitRow(Icons.discount_outlined, 'Exclusive Discounts'),
// //                 _buildBenefitRow(Icons.star_border_outlined, 'VIP Support'),
// //               ],
// //             ),
// //           ),

// //           // Subscription Plans Section
// //           Padding(
// //             padding: EdgeInsets.symmetric(
// //               horizontal: getProportionateScreenWidth(kDefaultPadding),
// //             ),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   'Choose Your Plan:',
// //                   style: TextStyle(
// //                     fontSize: getProportionateScreenWidth(kDefaultPadding * 1.2),
// //                     fontWeight: FontWeight.bold,
// //                     color: kBlackColor,
// //                   ),
// //                 ),
// //                 SizedBox(height: getProportionateScreenHeight(kDefaultPadding / 2)),
// //                 ..._demoPlans.asMap().entries.map((entry) {
// //                   int index = entry.key;
// //                   Map<String, String> plan = entry.value;
// //                   bool isYearly = plan['title'] == 'Yearly Premium';
// //                   return FadeTransition(
// //                     opacity: _fadeAnimation,
// //                     child: Card(
// //                       elevation: isYearly ? 4 : 2,
// //                       margin: EdgeInsets.only(
// //                         bottom: getProportionateScreenHeight(kDefaultPadding),
// //                       ),
// //                       shape: RoundedRectangleBorder(
// //                         borderRadius: BorderRadius.circular(kDefaultPadding),
// //                         side: isYearly
// //                             ? BorderSide(color: kPrimaryColor, width: 2)
// //                             : BorderSide.none,
// //                       ),
// //                       child: Stack(
// //                         children: [
// //                           Padding(
// //                             padding: EdgeInsets.all(
// //                               getProportionateScreenWidth(kDefaultPadding),
// //                             ),
// //                             child: Column(
// //                               crossAxisAlignment: CrossAxisAlignment.start,
// //                               children: [
// //                                 Row(
// //                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                                   children: [
// //                                     Text(
// //                                       plan['title']!,
// //                                       style: TextStyle(
// //                                         fontWeight: FontWeight.bold,
// //                                         fontSize: getProportionateScreenWidth(
// //                                             kDefaultPadding),
// //                                         color: kBlackColor,
// //                                       ),
// //                                     ),
// //                                     Container(
// //                                       padding: EdgeInsets.symmetric(
// //                                         horizontal: getProportionateScreenWidth(
// //                                             kDefaultPadding / 2),
// //                                         vertical: getProportionateScreenHeight(
// //                                             kDefaultPadding / 4),
// //                                       ),
// //                                       decoration: BoxDecoration(
// //                                         color: kPrimaryColor,
// //                                         borderRadius: BorderRadius.circular(
// //                                             kDefaultPadding / 2),
// //                                       ),
// //                                       child: Text(
// //                                         plan['price']!,
// //                                         style: TextStyle(
// //                                           fontSize: getProportionateScreenWidth(
// //                                               kDefaultPadding * 0.8),
// //                                           color: kWhiteColor,
// //                                           fontWeight: FontWeight.bold,
// //                                         ),
// //                                       ),
// //                                     ),
// //                                   ],
// //                                 ),
// //                                 SizedBox(
// //                                     height:
// //                                         getProportionateScreenHeight(kDefaultPadding / 2)),
// //                                 Text(
// //                                   plan['description']!,
// //                                   style: TextStyle(
// //                                     fontSize: getProportionateScreenWidth(
// //                                         kDefaultPadding * 0.8),
// //                                     color: kGreyColor,
// //                                   ),
// //                                 ),
// //                                 SizedBox(
// //                                     height: getProportionateScreenHeight(kDefaultPadding)),
// //                                 Align(
// //                                   alignment: Alignment.centerRight,
// //                                   child: ScaleTransition(
// //                                     scale: _scaleAnimation,
// //                                     child: Semantics(
// //                                       label: 'Subscribe to ${plan['title']}',
// //                                       child: CustomButton(
// //                                         title: 'Subscribe Now',
// //                                         color: isYearly ? kPrimaryColor : kSecondaryColor,
// //                                         textColor: kWhiteColor,
// //                                         radius: kDefaultPadding / 2,
// //                                         press: () => _buyProduct(plan['priceId']!),
// //                                       ),
// //                                     ),
// //                                   ),
// //                                 ),
// //                               ],
// //                             ),
// //                           ),
// //                           if (isYearly)
// //                             Positioned(
// //                               top: 0,
// //                               left: 0,
// //                               child: Container(
// //                                 padding: EdgeInsets.symmetric(
// //                                   horizontal:
// //                                       getProportionateScreenWidth(kDefaultPadding / 2),
// //                                   vertical:
// //                                       getProportionateScreenHeight(kDefaultPadding / 4),
// //                                 ),
// //                                 decoration: BoxDecoration(
// //                                   color: kPrimaryColor,
// //                                   borderRadius: BorderRadius.only(
// //                                     topLeft: Radius.circular(kDefaultPadding),
// //                                     bottomRight: Radius.circular(kDefaultPadding),
// //                                   ),
// //                                 ),
// //                                 child: Text(
// //                                   'Best Value',
// //                                   style: TextStyle(
// //                                     color: kWhiteColor,
// //                                     fontSize:
// //                                         getProportionateScreenWidth(kDefaultPadding * 0.7),
// //                                     fontWeight: FontWeight.bold,
// //                                   ),
// //                                 ),
// //                               ),
// //                             ),
// //                         ],
// //                       ),
// //                     ),
// //                   );
// //                 }).toList(),
// //               ],
// //             ),
// //           ),

// //           // Footer Section
// //           Padding(
// //             padding: EdgeInsets.symmetric(
// //               vertical: getProportionateScreenHeight(kDefaultPadding),
// //               horizontal: getProportionateScreenWidth(kDefaultPadding),
// //             ),
// //             child: Column(
// //               children: [
// //                 Text(
// //                   'Subscriptions auto-renew until canceled. Terms apply.',
// //                   textAlign: TextAlign.center,
// //                   style: TextStyle(
// //                     fontSize: getProportionateScreenWidth(kDefaultPadding * 0.7),
// //                     color: kGreyColor,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildBenefitRow(IconData icon, String benefit) {
// //     return Padding(
// //       padding: EdgeInsets.symmetric(
// //         vertical: getProportionateScreenHeight(kDefaultPadding / 4),
// //       ),
// //       child: Row(
// //         children: [
// //           Icon(
// //             icon,
// //             color: kPrimaryColor,
// //             size: getProportionateScreenWidth(kDefaultPadding * 1.2),
// //           ),
// //           SizedBox(width: getProportionateScreenWidth(kDefaultPadding / 2)),
// //           Expanded(
// //             child: Text(
// //               benefit,
// //               style: TextStyle(
// //                 fontSize: getProportionateScreenWidth(kDefaultPadding * 0.9),
// //                 color: kBlackColor,
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
