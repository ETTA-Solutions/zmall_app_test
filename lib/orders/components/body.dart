import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/orders/components/courier_detail.dart';
import 'package:zmall/orders/components/order_detail.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/store/components/image_container.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/widgets/shimmer_widget.dart';
import 'package:zmall/orders/models/combo_order_entry.dart';
import 'package:zmall/orders/components/combo_order_card.dart';

class Body extends StatefulWidget {
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  var userData;
  bool _loading = false;
  var responseData;
  dynamic localCombos;

  @override
  void initState() {
    super.initState();
    getUser();
  }

  void _getOrders(userId, serverToken) async {
    setState(() {
      _loading = true;
    });
    var data = await getOrders(userId, serverToken);
    if (data != null && data['success']) {
      setState(() {
        _loading = false;
        responseData = data;
      });
    } else {
      setState(() {
        _loading = false;
      });
      // 652
      if (data['error_code'] != null && data['error_code'] != 652) {
        Service.showMessage(
          context: context,
          title: "${errorCodes['${data['error_code']}']}!",
          error: true,
        );
      }

      if (data['error_code'] != null && data['error_code'] == 999) {
        await Service.saveBool('logged', false);
        await Service.remove('user');
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
  }

  void getUser() async {
    setState(() {
      _loading = true;
    });
    var data = await Service.read('user');
    var combos = await Service.read('combo_orders');
    if (data != null) {
      setState(() {
        userData = data;
        localCombos = combos;
      });
      _getOrders(userData['user']['_id'], userData['user']['server_token']);
    }
  }

  void _showComboOrderPicker(BuildContext context, OrderEntry entry) {
    if (entry.comboOrders.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetail(
            order: entry.comboOrders[0],
            userId: userData['user']['_id'],
            userPhone: userData['user']['phone'],
            serverToken: userData['user']['server_token'],
          ),
        ),
      ).then((_) => getUser());
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kDefaultPadding)),
      ),
      backgroundColor: kPrimaryColor,
      builder: (ctx) {
        final meta = Provider.of<ZMetaData>(context, listen: false);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(kDefaultPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Order from 2 Stores",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Select a store to view individual order details and tracking:",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kGreyColor),
                ),
                SizedBox(height: kDefaultPadding),
                ...entry.comboOrders.map((childOrder) {
                  final name = childOrder['store_name'] ??
                      childOrder['store_detail']?['name'] ??
                      "Store";
                  final uniqueId = childOrder['unique_id'] ?? "";
                  final price = (childOrder['total_order_price'] ??
                          childOrder['total'] ??
                          0)
                      .toDouble();
                  final img = childOrder['store_image'] ??
                      childOrder['store_detail']?['image_url'] ??
                      "";
                  return Card(
                    color: kWhiteColor,
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: img.toString().isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: img.toString().startsWith("http")
                                      ? img.toString()
                                      : "${meta.baseUrl}/$img",
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: kWhiteColor,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(kGreyColor),
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: kWhiteColor,
                                    child: Icon(HeroiconsOutline.buildingStorefront, color: kGreyColor),
                                  ),
                                )
                              : Container(
                                  color: kWhiteColor,
                                  child: Icon(HeroiconsOutline.buildingStorefront, color: kGreyColor),
                                ),
                        ),
                      ),
                      title: Text(
                        Service.capitalizeFirstLetters(name.toString()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                        ),
                      ),
                      subtitle: Text("Order #$uniqueId"),
                      trailing: Text(
                        "${meta.currency} ${price.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderDetail(
                              order: childOrder,
                              userId: userData['user']['_id'],
                              userPhone: userData['user']['phone'],
                              serverToken: userData['user']['server_token'],
                            ),
                          ),
                        ).then((_) => getUser());
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalProgressHUD(
      inAsyncCall: _loading && userData != null,
      progressIndicator: userData != null && responseData != null
          ? LinearLoadingIndicator()
          : ProductListShimmer(),
      color: kPrimaryColor,
      child: userData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    HeroiconsOutline.lockClosed,
                    size: getProportionateScreenHeight(kDefaultPadding * 4),
                    color: kSecondaryColor.withValues(alpha: 0.7),
                  ),
                  SizedBox(
                    height: getProportionateScreenHeight(kDefaultPadding),
                  ),
                  Text(
                    "Access Denied",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kGreyColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    height: getProportionateScreenHeight(kDefaultPadding / 4),
                  ),
                  Text(
                    "Please log in to view your order history.",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kGreyColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : userData != null && responseData != null
          ? Padding(
              padding:
                  EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(
                      kDefaultPadding / 2,
                    ),
                  ).copyWith(
                    top: getProportionateScreenHeight(kDefaultPadding) / 2,
                  ),
              child: Builder(
                builder: (context) {
                  final List<OrderEntry> orderEntries =
                      (responseData['order_list'] is List)
                          ? groupOrders(responseData['order_list'], localCombos)
                          : [];
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: orderEntries.length,
                    padding: EdgeInsets.only(
                      bottom: getProportionateScreenHeight(kDefaultPadding) / 2,
                    ),
                    separatorBuilder: (BuildContext context, int index) =>
                        SizedBox(
                          height:
                              getProportionateScreenHeight(kDefaultPadding / 2),
                        ),
                    itemBuilder: (context, index) {
                      final entry = orderEntries[index];
                      if (entry.isCombo) {
                        return ComboOrderCard(
                          entry: entry,
                          onTap: () => _showComboOrderPicker(context, entry),
                        );
                      }
                      final order = entry.singleOrder ?? entry.allOrders.first;
                      return InkWell(
                        onTap: () {
                          if (order['delivery_type'] == 2) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return CourierDetail(
                                    courierData: order,
                                    userId: userData['user']['_id'],
                                    userPhone: userData['user']['phone'],
                                    serverToken:
                                        userData['user']['server_token'],
                                  );
                                },
                              ),
                            ).then((value) => getUser());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) {
                                  return OrderDetail(
                                    order: order,
                                    userId: userData['user']['_id'],
                                    userPhone: userData['user']['phone'],
                                    serverToken:
                                        userData['user']['server_token'],
                                  );
                                },
                              ),
                            ).then((value) => getUser());
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            border: Border.all(color: kWhiteColor),
                            borderRadius: BorderRadius.circular(kDefaultPadding),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: getProportionateScreenHeight(
                              kDefaultPadding / 2,
                            ),
                            horizontal: getProportionateScreenWidth(
                              kDefaultPadding / 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              ImageContainer(
                                url:
                                    "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${order['store_image']}",
                              ),
                              SizedBox(
                                width: getProportionateScreenWidth(
                                  kDefaultPadding / 1.5,
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: getProportionateScreenHeight(
                                    kDefaultPadding / 5,
                                  ),
                                  children: [
                                    Text(
                                      order['store_name'] == "Courier"
                                          ? order['destination_addresses'][0]['note'] ==
                                                    "Lunch from Home"
                                                ? "Lunch From Home"
                                                : Service.capitalizeFirstLetters(
                                                    order['store_name'],
                                                  )
                                          : Service.capitalizeFirstLetters(
                                              order['store_name'],
                                            ),
                                      style: Theme.of(context).textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: kBlackColor,
                                          ),
                                      softWrap: true,
                                    ),
                                    Text(
                                      "Order No. #${order['unique_id']}",
                                      style: Theme.of(context).textTheme.titleSmall
                                          ?.copyWith(color: kGreyColor),
                                    ),
                                    Text(
                                      "${order['created_at'].split('T')[0].split('-')[1]}/${order['created_at'].split('T')[0].split('-')[2]} ${int.parse(order['created_at'].split('T')[1].split('.')[0].split(':')[0]) + 3}:${order['created_at'].split('T')[1].split('.')[0].split(':')[1]}:${order['created_at'].split('T')[1].split('.')[0].split(':')[2]}",
                                      style: Theme.of(context).textTheme.bodySmall
                                          ?.copyWith(color: kGreyColor),
                                    ),
                                    Text(
                                      isOdooStoreByName(order['store_name'])
                                          ? "${order_status['${order['order_status']}']}"
                                          : order['order_status'] == 7
                                              ? order['delivery_status'] != null
                                                    ? "${order_status['${order['delivery_status']}']}"
                                                    : "Waiting to accept order"
                                              : "${order_status['${order['order_status']}']}",
                                      style: Theme.of(context).textTheme.bodySmall
                                          ?.copyWith(
                                            color:
                                                order['order_status'] == 25
                                                    ? Colors.green
                                                    : kSecondaryColor,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Spacer(),
                              Column(
                                children: [
                                  Text(
                                    "${Provider.of<ZMetaData>(context, listen: false).currency} ${(order['total_order_price'] as num).toDouble().toStringAsFixed(2)}",
                                    style: Theme.of(context).textTheme.titleSmall
                                        ?.copyWith(
                                          color: kBlackColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          : _loading
          ? Container()
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    HeroiconsOutline.shoppingBag,
                    size: getProportionateScreenHeight(kDefaultPadding * 4),
                    color: kSecondaryColor.withValues(alpha: 0.8),
                  ),
                  SizedBox(
                    height: getProportionateScreenHeight(kDefaultPadding),
                  ),
                  Text(
                    "No Active Orders Yet",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kGreyColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    height: getProportionateScreenHeight(kDefaultPadding / 4),
                  ),
                  Text(
                    "Place an order to see it here!",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: kGreyColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Future<dynamic> getOrders(userId, serverToken) async {
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_orders";
    Map data = {"user_id": userId, "server_token": serverToken};

    var body = json.encode(data);
    try {
      http.Response response = await http
          .post(
            Uri.parse(url),
            headers: <String, String>{
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              if (mounted) {
                setState(() {
                  this._loading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Something went wrong!"),
                    backgroundColor: kSecondaryColor,
                  ),
                );
              }
              throw TimeoutException("The connection has timed out!");
            },
          );
      setState(() {
        this._loading = false;
      });

      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      if (mounted) {
        setState(() {
          this._loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Your internet connection is bad!"),
            backgroundColor: kSecondaryColor,
          ),
        );
      }
      return null;
    }
  }
}
