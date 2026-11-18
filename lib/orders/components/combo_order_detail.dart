import 'package:flutter/material.dart';
import 'package:zmall/orders/components/order_detail.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';

// ---------------------------------------------------------------------------
// ComboOrderDetail
//
// One page for an active combo order: a tab per store at the top, and each
// tab shows that store's normal OrderDetail (Order Status / Cart tabs, cancel,
// track and confirm actions all unchanged).
// ---------------------------------------------------------------------------
class ComboOrderDetail extends StatelessWidget {
  const ComboOrderDetail({
    super.key,
    required this.orders,
    required this.userId,
    required this.serverToken,
    required this.userPhone,
  });

  final List<Map<String, dynamic>> orders;
  final String userId, serverToken, userPhone;

  String _storeName(Map<String, dynamic> order) => Service.capitalizeFirstLetters(
    (order['store_name'] ?? order['store_detail']?['name'] ?? "Store")
        .toString(),
  );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: orders.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Order Detail", style: TextStyle(color: kBlackColor)),
          elevation: 1.0,
          bottom: TabBar(
            indicatorColor: kSecondaryColor,
            labelColor: kBlackColor,
            unselectedLabelColor: kGreyColor,
            tabs: [
              for (final order in orders)
                Tab(
                  child: Text(
                    _storeName(order),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        body: TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            for (final order in orders)
              OrderDetail(
                order: order,
                userId: userId,
                serverToken: serverToken,
                userPhone: userPhone,
                embedded: true,
              ),
          ],
        ),
      ),
    );
  }
}
