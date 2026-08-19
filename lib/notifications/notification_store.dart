import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/services/app_update_service.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/item/item_screen.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/pagination_controller.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/widgets/product_item_card.dart';
import 'package:zmall/widgets/shimmer_widget.dart';

class NotificationStore extends StatefulWidget {
  const NotificationStore({
    super.key,
    required this.storeId,
    this.storeName = "",
  });

  final String storeId;
  final String storeName;

  @override
  _NotificationStoreState createState() => _NotificationStoreState();
}

class _NotificationStoreState extends State<NotificationStore> {
  final productsPagination = PaginationController();
  bool _loading = true;

  // var responseData;
  var products;
  Cart? cart;
  bool isLoggedIn = false;
  bool isOpen = false;
  var userData;
  String storeName = "";
  var store;
  // pagination variables
  int currentPage = 1;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    productsPagination.init(
      onLoadMore: () =>
          _loadPage(productsPagination.currentPage + 1, isLoadMore: true),
    );
    _loadPage(1, isRefresh: true);
    storeName = widget.storeName;
    isLogged();
    getCart();
    // _getStoreProductList();
  }

  @override
  void dispose() {
    productsPagination.dispose();
    super.dispose();
  }

  /// Fetch cart data from local storage
  void getCart() async {
    var data = await Service.read('cart');
    if (data != null) {
      setState(() {
        cart = Cart.fromJson(data);
      });
    }
  }

  void isLogged() async {
    var data = await Service.readBool('logged');
    if (data != null) {
      setState(() {
        isLoggedIn = data;
      });
      getUser();
    }
  }

  void getUser() async {
    var data = await Service.read('user');
    if (data != null) {
      setState(() {
        userData = data;
      });
    }
  }

  // Fetch app keys and check for updates
  void _getAppKeys() async {
    await AppUpdateService.fetchAndCheck(context, showDialogIfNeeded: false);
  }

  void addToCart(item, destination, storeLocation, storeId) {
    cart = Cart(
      userId: userData['user']['_id'],
      items: [item],
      serverToken: userData['user']['server_token'],
      destinationAddress: destination,
      storeId: storeId,
      storeLocation: storeLocation,
    );

    Service.save('cart', cart!.toJson());
    // Service.showMessage(
    //     context: context, title: "Item added to cart!", error: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        title: Text(
          Service.capitalizeFirstLetters(
            storeName.isNotEmpty ? storeName : "Loading..",
          ),

          // storeName == "" ? "Loading.." : storeName,
          style: TextStyle(color: kBlackColor),
        ),
        leading: BackButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              "/start",
              (Route<dynamic> route) => false,
            );
          },
          color: kBlackColor,
        ),
      ),
      bottomNavigationBar:
          !_loading && (cart != null && cart!.items!.length > 0)
          ? SafeArea(
              child: Container(
                width: double.infinity,
                // height: kDefaultPadding * 4,
                padding: EdgeInsets.symmetric(
                  vertical: getProportionateScreenHeight(kDefaultPadding),
                  horizontal: getProportionateScreenHeight(kDefaultPadding),
                ),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  border: Border(top: BorderSide(color: kWhiteColor)),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kDefaultPadding),
                    topRight: Radius.circular(kDefaultPadding),
                  ),
                ),

                child: CustomButton(
                  title: "Go to Cart",
                  press: () {
                    Navigator.pushNamed(
                      context,
                      '/cart',
                    ).then((value) => getCart());
                  },
                  color: kSecondaryColor,
                ),
              ),
            )
          : SizedBox.shrink(),
      body: SafeArea(
        child: ModalProgressHUD(
          inAsyncCall: _loading,
          color: kPrimaryColor,
          // progressIndicator:
          //     CustomLinearProgressIndicator(message: "Loading store.."),
          progressIndicator: products != null
              ? LinearLoadingIndicator()
              : ProductListShimmer(itemCount: 7),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(kDefaultPadding / 2),
              vertical: getProportionateScreenHeight(kDefaultPadding / 2),
            ),
            child: products != null
                ? _buildProductsList()
                : !_loading
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionateScreenWidth(
                        kDefaultPadding * 4,
                      ),
                      vertical: getProportionateScreenHeight(
                        kDefaultPadding * 4,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CustomButton(
                          title: "Retry",
                          press: () => _loadPage(1, isRefresh: true),
                          color: kSecondaryColor,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  // ===================== PRODUCTS LIST =====================
  Widget _buildProductsList() {
    return CustomScrollView(
      controller: productsPagination.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...products.map((category) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: getProportionateScreenHeight(kDefaultPadding / 2),
              ),
              child: ExpansionTile(
                textColor: kBlackColor,
                backgroundColor: kPrimaryColor,
                collapsedBackgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: kWhiteColor),
                  borderRadius: BorderRadius.circular(kDefaultPadding),
                ),
                collapsedShape: RoundedRectangleBorder(
                  side: BorderSide(color: kWhiteColor),
                  borderRadius: BorderRadius.circular(kDefaultPadding),
                ),
                leading: const Icon(Icons.dining, size: 18, color: kBlackColor),
                childrenPadding: EdgeInsets.only(
                  left: getProportionateScreenWidth(kDefaultPadding / 2),
                  right: getProportionateScreenWidth(kDefaultPadding / 2),
                  bottom: getProportionateScreenHeight(kDefaultPadding),
                ),
                title: Text(
                  Service.capitalizeFirstLetters(category["_id"]["name"]),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                children: [
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: category['items'].length,
                    separatorBuilder: (_, __) => SizedBox(
                      height: getProportionateScreenHeight(kDefaultPadding / 2),
                    ),
                    itemBuilder: (context, idx) {
                      final item = category['items'][idx];
                      return ProductItemCard(
                        item: item,
                        isOpen: isOpen,
                        onTap: () async {
                          isOpen
                              ? Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return ItemScreen(
                                        item: item,
                                        location: store['location'],
                                      );
                                    },
                                  ),
                                ).then((value) => getCart())
                              : Service.showMessage(
                                  context: context,
                                  title:
                                      "Sorry the store is closed at this time!",
                                  error: true,
                                );
                        },
                        onAddTap: () async {
                          if (item['specifications'] != null &&
                              item['specifications'].length > 0) {
                            isOpen
                                ? Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) {
                                        return ItemScreen(
                                          item: item,
                                          location: store['location'],
                                        );
                                      },
                                    ),
                                  ).then((value) => getCart())
                                : Service.showMessage(
                                    context: context,
                                    title:
                                        "Sorry the store is closed at this time!",
                                    error: true,
                                  );
                          } else {
                            Item cartItem = Item(
                              id: item['_id'],
                              quantity: 1,
                              specification: [],
                              noteForItem: "",
                              price: Service.getPrice(item).isNotEmpty
                                  ? double.parse(Service.getPrice(item))
                                  : 0,
                              itemName: item['name'],
                              imageURL:
                                  item['image_url'] != null &&
                                      item['image_url'].length > 0
                                  ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${item['image_url'][0]}"
                                  : "https://ibb.co/vkhzjd6",
                              odooProductId: extractOdooProductId(item),
                            );
                            StoreLocation storeLocation = StoreLocation(
                              long: store['location'][1],
                              lat: store['location'][0],
                            );
                            DestinationAddress destination = DestinationAddress(
                              long: store['location'][1],
                              lat: store['location'][0],
                              name: "Current Location",
                              note: "User current location",
                            );

                            if (cart != null) {
                              if (userData != null) {
                                if (cart!.storeId == item['store_id']) {
                                  setState(() {
                                    Service.addOrMergeCartItem(cart!, cartItem);
                                    Service.save('cart', cart!.toJson());
                                  });
                                  Service.showMessage(
                                    context: context,
                                    title: "Item added to cart",
                                    error: false,
                                  );
                                } else {
                                  _showDialog(
                                    cartItem,
                                    destination,
                                    storeLocation,
                                    item['store_id'],
                                  );
                                }
                              } else {
                                Service.showMessage(
                                  context: context,
                                  title: "Please login in...",
                                  error: true,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        LoginScreen(firstRoute: false),
                                  ),
                                ).then((value) => getUser());
                              }
                            } else {
                              if (userData != null) {
                                addToCart(
                                  cartItem,
                                  destination,
                                  storeLocation,
                                  item['store_id'],
                                );
                                getCart();
                              } else {
                                Service.showMessage(
                                  context: context,
                                  title: "Please login in...",
                                  error: true,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        LoginScreen(firstRoute: false),
                                  ),
                                ).then((value) => getUser());
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        // Reusable footer (loader + "No more products")
        // SliverToBoxAdapter(
        //   child: PaginationFooter(
        //     isLoadingMore: productsPagination.isLoadingMore,
        //     hasMore: productsPagination.hasMore,
        //     hasItems: products != null && products.isNotEmpty,
        //     noMoreText: "No more products to load.",
        //   ),
        // ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  ////////////// page loader ///////////////////
  Future<void> _loadPage(
    int page, {
    bool isLoadMore = false,
    bool isRefresh = false,
  }) async {
    _getAppKeys();

    if (isLoadMore) {
      if (productsPagination.isLoadingMore || !productsPagination.hasMore)
        return;
      setState(() => productsPagination.isLoadingMore = true);
    } else {
      setState(() {
        _loading = true;
        if (isRefresh) {
          productsPagination.reset();
          products = null;
        }
      });
    }

    final result = await getStoreProductList(page: page);
    if (!mounted) return;

    if (result != null && result['success'] == true) {
      final newProducts = result['products'] ?? [];
      final calculatedTotalPages = Service.calculateTotalPages(result);

      if (result['store'] != null) {
        store = result['store'];
        storeName = result['store']['name'] ?? storeName;
        isOpen = await Service.isStoreOpen(result['store']);
      }

      setState(() {
        productsPagination.update(
          page: page,
          calculatedTotalPages: calculatedTotalPages,
        );

        products = isLoadMore
            ? Service.appendPage(products, newProducts)
            : newProducts;
      });

      productsPagination.checkAndLoadMoreIfNeeded();
    } else {
      if (mounted && result != null) {
        final code = result['error_code']?.toString() ?? '';
        final msg = (code.isNotEmpty && errorCodes.containsKey(code))
            ? errorCodes[code]
            : result['message']?.toString() ?? 'Failed to load products';
        Service.showMessage(context: context, title: msg, error: true);
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        productsPagination.isLoadingMore = false;
      });
    }
  }

  // product list with pageination
  Future<dynamic> getStoreProductList({int page = 1}) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/user_get_store_product_item_list";
    Map data = {"store_id": widget.storeId};
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
            Duration(seconds: 60),
            onTimeout: () {
              Service.showMessage(
                context: context,
                title: "Something went wrong!",
                error: true,
                duration: 3,
              );
              throw TimeoutException("The connection has timed out!");
            },
          );

      return json.decode(response.body);
    } catch (e) {
      return null;
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showDialog(item, destination, storeLocation, storeId) {
    showDialog(
      context: context,
      builder: (BuildContext alertContext) {
        return AlertDialog(
          backgroundColor: kPrimaryColor,
          title: Text("Warning"),
          content: Text(
            "Item(s) from a different store found in cart! Would you like to clear your cart?",
          ),
          actions: [
            TextButton(
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: kBlackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(alertContext).pop();
              },
            ),
            TextButton(
              child: Text(
                "Clear",
                style: TextStyle(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                setState(() {
                  cart!.toJson();
                  Service.remove('cart');
                  Service.remove('aliexpressCart');
                  cart = Cart();
                  addToCart(item, destination, storeLocation, storeId);
                });

                Navigator.of(alertContext).pop();
                // Future.delayed(Duration(seconds: 2));
                // Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
