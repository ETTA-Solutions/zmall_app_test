import 'dart:async';
import 'dart:convert';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/cart/cart_screen.dart';
import 'package:zmall/comments/review_screen.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/item/item_screen.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/pagination_controller.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/custom_search_bar.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/widgets/pagination_footer.dart';
import 'package:zmall/widgets/product_item_card.dart';
import 'package:zmall/widgets/shimmer_widget.dart';
import 'components/store_header.dart';

class ProductScreen extends StatefulWidget {
  static String routeName = "/product";

  const ProductScreen({
    super.key,
    @required this.store,
    @required this.location,
    @required this.isOpen,
    @required this.longitude,
    @required this.latitude,
  });

  final store;
  final location;
  final bool? isOpen;
  final double? longitude;
  final double? latitude;

  @override
  _ProductScreenState createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final GlobalKey _filterButtonKey = GlobalKey();
  bool _loading = true;
  // var responseData;
  var favoriteResponseData;
  var products;
  var price = [];
  Cart? cart;
  TextEditingController controller = TextEditingController();
  TextEditingController customPriceController = TextEditingController();
  List<dynamic> _searchResult = [];
  bool isLoggedIn = false;
  var userData;
  bool isFavorite = false;
  String loadingMessage = "Loading...";

  double? longitude, latitude;
  List<Specification> specification = [];

  // price finter variables
  String dropDownValue = "Lower than:";
  var items = ["Lower than:", "Greater than:"];

  //
  String _lastSearchQuery = '';

  final productsPagination = PaginationController();
  final searchPagination = PaginationController();

  @override
  void initState() {
    super.initState();

    productsPagination.init(
      onLoadMore: () =>
          _loadPage(productsPagination.currentPage + 1, isLoadMore: true),
    );

    searchPagination.init(
      onLoadMore: () =>
          _loadSearchPage(searchPagination.currentPage + 1, isLoadMore: true),
    );
    _loadPage(1, isRefresh: true);
    isLogged();
    getCart();
    // _getStoreProductList();
  }

  @override
  void dispose() {
    productsPagination.dispose();
    searchPagination.dispose();
    controller.dispose();
    customPriceController.dispose();
    super.dispose();
  }

  /// Function to check if the current store is in the user's favorites
  void checkFavorite() {
    if (userData != null) {
      bool isFav = userData['user']['favourite_stores'].contains(
        widget.store['_id'],
      );
      setState(() {
        isFavorite = isFav;
      });
    }
  }

  /// Refresh handler for pull-to-refresh
  Future<void> _onRefresh() async {
    isLogged();
    getCart();
    // _getStoreProductList();
    await _loadPage(1, isRefresh: true);
  }

  void getCart() async {
    // debugPrint("Fetching data");
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
    } else {
      // debugPrint("No logged user found");
    }
  }

  void getUser() async {
    var data = await Service.read('user');
    if (data != null) {
      setState(() {
        userData = data;
      });
      checkFavorite();
    }
    var long = await Service.read('longitude');
    var lat = await Service.read('latitude');
    if (long != null && lat != null) {
      setState(() {
        latitude = lat;
        longitude = long;
      });
    }
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: kPrimaryColor,
        actionsPadding: EdgeInsets.only(
          right: getProportionateScreenWidth(kDefaultPadding / 2),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Service.capitalizeFirstLetters(widget.store['name']),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: kBlackColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            StoreHeader(
              storeName: Service.capitalizeFirstLetters(widget.store['name']),
              distance: widget.store['distance'] != null
                  ? widget.store['distance'].toStringAsFixed(2)
                  : "",
              imageUrl:
                  "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${widget.store['image_url']}",
              rating: widget.store['user_rate'].toString(),
              ratingCount: widget.store['user_rate_count'].toString(),
            ),
          ],
        ),
        actions: [
          // InkWell(
          //   onTap: () {
          //     Navigator.of(context).push(MaterialPageRoute(
          //         builder: (context) => StoreMapView(
          //               isOpen: [widget.isOpen],
          //               categoryTitle: {"delivery_name": widget.store['name']},
          //               stores: [widget.store],
          //               cityId: "",
          //               storeDeliveryId: "",
          //               isFromProduct: true,
          //             )));
          //   },
          //   borderRadius: BorderRadius.circular(
          //     getProportionateScreenWidth(kDefaultPadding * 2.5),
          //   ),
          //   child: Padding(
          //     padding: EdgeInsets.symmetric(
          //       vertical: getProportionateScreenWidth(kDefaultPadding * .75),
          //       horizontal: getProportionateScreenWidth(kDefaultPadding / 4),
          //     ),
          //     child: Icon(
          //       Icons.navigation,
          //       // color: kSecondaryColor,
          //     ),
          //   ),
          // ),
          // userData != null
          //     ? InkWell(
          //         onTap: () {
          //           isFavorite ? removeFavorites() : addToFavorites();
          //         },
          //         borderRadius: BorderRadius.circular(
          //           getProportionateScreenWidth(kDefaultPadding * 2.5),
          //         ),
          //         child: Padding(
          //           padding: EdgeInsets.symmetric(
          //             vertical:
          //                 getProportionateScreenWidth(kDefaultPadding * .75),
          //             horizontal:
          //                 getProportionateScreenWidth(kDefaultPadding / 4),
          //           ),
          //           child: Icon(
          //             isFavorite ? Icons.favorite : Icons.favorite_border,
          //             color: isFavorite ? kSecondaryColor : Colors.black,
          //           ),
          //         ),
          //       )
          //     : Container(),
          IconButton(
            onPressed: () {
              goToReviews();
            },
            icon: Icon(HeroiconsOutline.chatBubbleBottomCenterText),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                CartScreen.routeName,
              ).then((value) => getCart());
            },
            icon: Badge.count(
              offset: Offset(8, -6),
              alignment: Alignment.topRight,
              count: cart != null ? cart!.items!.length : 0,
              backgroundColor: kSecondaryColor,
              child: Icon(HeroiconsOutline.shoppingCart),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          !_loading && (cart != null && cart!.items!.length > 0)
          ? SafeArea(
              child: Container(
                width: double.infinity,
                // height: kDefaultPadding * 4,
                padding: EdgeInsets.symmetric(
                  vertical: getProportionateScreenHeight(kDefaultPadding / 4),
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
                  title: Provider.of<ZLanguage>(context).goToCart,
                  press: () {
                    Navigator.pushNamed(
                      context,
                      CartScreen.routeName,
                    ).then((value) => getCart());
                  },
                  color: kSecondaryColor,
                ),
              ),
            )
          : SizedBox.shrink(),
      body: SafeArea(
        child: RefreshIndicator(
          color: kPrimaryColor,
          backgroundColor: kSecondaryColor,
          onRefresh: _onRefresh,
          child: ModalProgressHUD(
            inAsyncCall: _loading,
            color: kPrimaryColor,
            progressIndicator: products != null
                ? LinearLoadingIndicator()
                : Padding(
                    padding: EdgeInsets.only(
                      top: getProportionateScreenHeight(30),
                    ),
                    child: ProductListShimmer(),
                  ),
            // progressIndicator: linearProgressIndicator,
            child: Column(
              children: [
                ///search sections/////
                Container(
                  color: kPrimaryColor,
                  key: _filterButtonKey,
                  child: CustomSearchBar(
                    controller: controller,
                    showFilterButton: true,
                    hintText: Provider.of<ZLanguage>(context).search,
                    onChanged: onSearchTextChanged,
                    onSubmitted: (value) {
                      onSearchTextChanged(value);
                    },
                    onClearButtonTap: () {
                      controller.clear();
                      onSearchTextChanged('');
                      setState(() {});
                    },
                    onFilterButtonTap: () => showFilterPopup(),
                  ),
                ),
                // SizedBox(
                //   height: getProportionateScreenHeight(kDefaultPadding / 4),
                // ),
                // Main content
                Expanded(
                  child: _searchResult.isNotEmpty || controller.text.isNotEmpty
                      ? _buildSearchList()
                      : products != null
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== SEARCH LIST =====================
  Widget _buildSearchList() {
    return CustomScrollView(
      controller: searchPagination.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // items
        ..._searchResult.map((item) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: kDefaultPadding,
                vertical: getProportionateScreenHeight(kDefaultPadding / 4),
              ),
              child: ProductItemCard(
                item: item,
                isOpen: widget.isOpen ?? false,
                onTap: () => _handleItemTap(item),
                onAddTap: () => _handleAddToCart(item),
              ),
            ),
          );
        }).toList(),

        // Loading more indicator (exactly as you wanted)
        SliverToBoxAdapter(
          child: PaginationFooter(
            isLoadingMore: searchPagination.isLoadingMore,
            hasMore: searchPagination.hasMore,
            hasItems: _searchResult.isNotEmpty,
            noMoreText: "No more items to load.",
          ),
        ),
        // Extra space at the bottom so the last item is not stuck under the cart bar
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ===================== PRODUCTS LIST (categories) =====================
  Widget _buildProductsList() {
    return CustomScrollView(
      controller: productsPagination.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...products.map((category) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: kDefaultPadding,
                vertical: getProportionateScreenHeight(kDefaultPadding / 4),
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
                        isOpen: widget.isOpen ?? false,
                        onTap: () => _handleItemTap(item),
                        onAddTap: () => _handleAddToCart(item),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        // Loading more indicator
        SliverToBoxAdapter(
          child: PaginationFooter(
            isLoadingMore: productsPagination.isLoadingMore,
            hasMore: productsPagination.hasMore,
            hasItems: products != null && products.isNotEmpty,
            noMoreText: "No more products to load",
          ),
        ),
         SliverToBoxAdapter(child: SizedBox(height:MediaQuery.of(context).padding.bottom+ 24)),
      ],
    );
  }

  ///reusable function for both Search and Paged products/////////////
  void _handleItemTap(dynamic item) {
    if (isLoggedIn) {
      productClicked(item['_id']);
    }

    if (widget.isOpen!) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ItemScreen(item: item, location: widget.location),
        ),
      ).then((_) => getCart());
    } else {
      Service.showMessage(
        context: context,
        title: "Sorry the store is closed at this time!",
        error: true,
      );
    }
  }

  void _handleAddToCart(dynamic item) async {
    if (!widget.isOpen!) {
      Service.showMessage(
        context: context,
        title: "Sorry the store is closed at this time!",
        error: true,
      );
      return;
    }

    // If the item has specifications → open ItemScreen
    if (item['specifications'] != null && item['specifications'].length > 0) {
      if (isLoggedIn) {
        productClicked(item['_id']);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ItemScreen(item: item, location: widget.location),
        ),
      ).then((value) => getCart());
      return;
    }

    // No specifications → add directly to cart
    final Item cartItem = Item(
      id: item['_id'],
      quantity: 1,
      specification: [],
      noteForItem: "",
      price: Service.getPrice(item).isNotEmpty
          ? double.parse(Service.getPrice(item))
          : 0,
      itemName: item['name'],
      imageURL: item['image_url'] != null && item['image_url'].length > 0
          ? "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/${item['image_url'][0]}"
          : "https://ibb.co/vkhzjd6",
      odooProductId: item['odoo_product_id'],
    );

    final StoreLocation storeLocation = StoreLocation(
      long: widget.location[1],
      lat: widget.location[0],
    );

    final DestinationAddress destination = DestinationAddress(
      long: Provider.of<ZMetaData>(context, listen: false).longitude,
      lat: Provider.of<ZMetaData>(context, listen: false).latitude,
      name: "Current Location",
      note: "User current location",
    );

    if (cart != null) {
      if (userData != null) {
        if (cart!.storeId == item['store_id']) {
          setState(() {
            Service.addOrMergeCartItem(cart!, cartItem);
            Service.save('cart', cart);
          });
          Service.showMessage(
            context: context,
            title: "Item added to cart",
            error: false,
          );
        } else {
          _showDialog(cartItem, destination, storeLocation, item['store_id']);
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
            builder: (context) => LoginScreen(firstRoute: false),
          ),
        ).then((value) => getUser());
      }
    } else {
      if (userData != null) {
        addToCart(cartItem, destination, storeLocation, item['store_id']);
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
            builder: (context) => LoginScreen(firstRoute: false),
          ),
        ).then((value) => getUser());
      }
    }
  }

  //////////////////////////////////////////////////////
  void showFilterPopup() {
    final RenderBox? renderBox =
        _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null) {
      // Calculate the position for the popup menu.
      // final Offset buttonTopLeft = renderBox.localToGlobal(Offset.zero);
      final Offset buttonBottomRight = renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
      );

      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromLTWH(
          buttonBottomRight.dx - getProportionateScreenWidth(200),
          buttonBottomRight.dy,
          getProportionateScreenWidth(200),
          0,
        ),
        Offset.zero & MediaQuery.of(context).size,
      );

      showMenu<int>(
        elevation: 8.0,
        context: context,
        position: position,
        color: kPrimaryColor,
        surfaceTintColor: kPrimaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(kDefaultPadding),
        ),
        items: <PopupMenuEntry<int>>[
          // Explicitly typed list of PopupMenuEntry
          PopupMenuItem(
            child: Row(
              children: [
                Icon(HeroiconsOutline.arrowUp),
                SizedBox(
                  width: getProportionateScreenWidth(kDefaultPadding * 0.4),
                ),
                Text("Price: Lowest to Highest"),
              ],
            ),
            value: 0,
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(HeroiconsOutline.arrowDown),
                SizedBox(
                  width: getProportionateScreenWidth(kDefaultPadding * 0.4),
                ),
                Text("Price: Highest to Lowest"),
              ],
            ),
            value: 1,
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(HeroiconsOutline.cog),
                SizedBox(
                  width: getProportionateScreenWidth(kDefaultPadding * 0.4),
                ),
                Text("Custom Price Filter"),
              ],
            ),
            value: 2,
          ),
        ],
      ).then((int? selectedValue) {
        if (selectedValue != null) {
          popUpMenuClicked(context, selectedValue);
        }
      });
    }
  }

  //////////////////New search filter function////////
  onSearchTextChanged(String text) async {
    if (text.isEmpty) {
      setState(() {
        _searchResult.clear();
        searchPagination.reset();
        _lastSearchQuery = '';
      });
      return;
    }
    await _loadSearchPage(1, query: text, isRefresh: true);
  }

  popUpMenuClicked(BuildContext context, int val) {
    if (!_loading && products != null) {
      List textValues = [
        "Price: Lowest to Highest",
        "Price: Highest to Lowest",
        "Price: Custom",
      ];
      List list = [];
      if (_searchResult.isNotEmpty) {
        list = _searchResult;
      } else {
        for (var i = 0; i < products.length; i++) {
          list += products[i]['items'];
        }
      }
      switch (val) {
        case 0:
          doMerge(list, 1);
          _searchResult = list;
          controller.text = textValues[val];
          setState(() {});
          break;
        case 1:
          doMerge(list, 2);
          _searchResult = list;
          controller.text = textValues[val];
          setState(() {});
          break;
        case 2:
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return AlertDialog(
                    backgroundColor: kPrimaryColor,
                    title: Text("Custom Price Filter"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            DropdownButton(
                              items: items.map((String item) {
                                return DropdownMenuItem(
                                  child: Text(item),
                                  value: item,
                                );
                              }).toList(),
                              onChanged: (String? val) {
                                setState(() {
                                  dropDownValue = val!;
                                });
                              },
                              value: dropDownValue,
                            ),
                            SizedBox(
                              width: getProportionateScreenWidth(
                                kDefaultPadding / 3,
                              ),
                            ),
                            Container(
                              width: getProportionateScreenWidth(
                                kDefaultPadding * 6,
                              ),
                              child: TextField(
                                controller: customPriceController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                decoration: InputDecoration(
                                  label: Text("Price value"),
                                  hintText: 'Price value',
                                  // prefixIcon: Icon(Icons.filter_alt),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text(
                          Provider.of<ZLanguage>(context).cancel,
                          style: TextStyle(color: kBlackColor),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text(
                          Provider.of<ZLanguage>(context).submit,
                          style: TextStyle(
                            color: kSecondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          if (customPriceController.text.isNotEmpty &&
                              customPriceController.text.length > 1) {
                            try {
                              double price = double.parse(
                                customPriceController.text,
                              );
                              customFilter(list, price);
                              Navigator.of(context).pop();
                            } catch (e) {
                              Service.showMessage(
                                context: context,
                                title: "Invalid price value",
                                error: true,
                              );
                            }
                          } else {
                            Service.showMessage(
                              context: context,
                              title:
                                  "Price value should be greater than 10 ${Provider.of<ZMetaData>(context, listen: false).currency}",
                              error: true,
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          );
          break;
        // case 3:
        //   Navigator.of(context).push(MaterialPageRoute(
        //       builder: (context) => StoreMapView(
        //             isOpen: [widget.isOpen],
        //             categoryTitle: {"delivery_name": widget.store['name']},
        //             stores: [widget.store],
        //             cityId: "",
        //             storeDeliveryId: "",
        //             isFromProduct: true,
        //           )));
        //   break;
        // case 4:
        //   goToReviews();
        //   break;
      }
    }
  }

  void goToReviews() async {
    var userData = await Service.getUser();
    if (userData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommentsScreen(
            userId: userData['user']['_id'],
            storeId: widget.store['_id'],
            serverToken: userData['user']['server_token'],
          ),
        ),
      );
    } else {
      Service.showMessage(
        context: context,
        title:
            "Please login to check the reviews for ${Service.capitalizeFirstLetters(widget.store['name'])})",
        error: true,
      );
    }
  }

  void customFilter(List list, double price) {
    List filteredList = [];
    for (int i = 0; i < list.length; i++) {
      var valPrice = Service.getPrice(list[i]).isNotEmpty
          ? Service.getPrice(list[i])
          : 0;
      if (dropDownValue.contains("Lower")) {
        if (double.parse(valPrice.toString()) <= price) {
          filteredList.add(list[i]);
        }
      } else {
        if (double.parse(valPrice.toString()) >= price) {
          filteredList.add(list[i]);
        }
      }
    }
    _searchResult = filteredList;
    controller.text =
        "$dropDownValue ${price}0 ${Provider.of<ZMetaData>(context, listen: false).currency}";
    setState(() {});
  }

  void merge(arr, l, m, r, int sortType) {
    var n1 = m - l + 1;
    var n2 = r - m;

    var L = List.filled(n1, {});
    var R = List.filled(n2, {});
    for (int i = 0; i < n1; i++) L[i] = arr[l + i];
    for (int j = 0; j < n2; j++) R[j] = arr[m + 1 + j];

    var i = 0;
    var j = 0;
    var k = l;

    while (i < n1 && j < n2) {
      var lPrice = Service.getPrice(L[i]).isNotEmpty
          ? Service.getPrice(L[i])
          : 0;
      var rPrice = Service.getPrice(R[j]).isNotEmpty
          ? Service.getPrice(R[j])
          : 0;

      if (sortType == 1) {
        if (double.parse(lPrice.toString()) <=
            double.parse(rPrice.toString())) {
          arr[k] = L[i];
          i++;
        } else {
          arr[k] = R[j];
          j++;
        }
      } else {
        if (double.parse(lPrice.toString()) >=
            double.parse(rPrice.toString())) {
          arr[k] = L[i];
          i++;
        } else {
          arr[k] = R[j];
          j++;
        }
      }
      k++;
    }
    while (i < n1) {
      arr[k] = L[i];
      i++;
      k++;
    }
    while (j < n2) {
      arr[k] = R[j];
      j++;
      k++;
    }
  }

  void mergeSort(arr, l, r, int sortType) {
    if (l >= r) {
      return;
    }
    int m = l + ((r - l) ~/ 2);
    mergeSort(arr, l, m, sortType);
    mergeSort(arr, m + 1, r, sortType);
    merge(arr, l, m, r, sortType);
  }

  void doMerge(List list, int sortType) {
    mergeSort(list, 0, list.length - 1, sortType);
  }

  // void debugPrintList(List list) {
  //   List p = [];
  //   for (int i = 0; i < list.length; i++) {
  //     p.add({"name": list[i]["name"], "price": list[i]['price']});
  //   }
  //   // debugPrint(p);
  // }

  ////////////////////////search items//////////////////////////////////////////////
  Future<dynamic> getStoreProductSearchList({
    required String query,
    int page = 1,
  }) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/search_store_item_by_name";
    Map data = {
      "name": query,
      "page": page.toString(),
      "store_id": widget.store['_id'],
    };

    var body = json.encode(data);
    // debugPrint("body : $body");

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
      // debugPrint("response: ${json.decode(response.body)}");
      return json.decode(response.body);
    } catch (e) {
      // debugPrint("error: $e");

      return null;
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /////////////////////////////////////////////////////////////////////
  Future<void> _loadPage(
    int page, {
    bool isLoadMore = false,
    bool isRefresh = false,
  }) async {
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
      final total = Service.calculateTotalPages(result);

      setState(() {
        productsPagination.update(page: page, calculatedTotalPages: total);
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

  Future<void> _loadSearchPage(
    int page, {
    String? query,
    bool isLoadMore = false,
    bool isRefresh = false,
  }) async {
    final searchQuery = query ?? _lastSearchQuery;
    if (searchQuery.isEmpty) return;

    if (isLoadMore) {
      if (searchPagination.isLoadingMore || !searchPagination.hasMore) return;
      setState(() => searchPagination.isLoadingMore = true);
    } else {
      setState(() {
        _loading = true;
        if (isRefresh) {
          searchPagination.reset();
          _searchResult.clear();
        }
      });
    }

    final data = await getStoreProductSearchList(
      query: searchQuery,
      page: page,
    );
    if (!mounted) return;

    if (data != null && data['success'] == true) {
      final newItems = data['items'] ?? [];
      final total = Service.calculateTotalPages(data);

      setState(() {
        _lastSearchQuery = searchQuery;
        searchPagination.update(page: page, calculatedTotalPages: total);
        _searchResult = isLoadMore
            ? Service.appendPage(_searchResult, newItems)
            : newItems;
      });

      searchPagination.checkAndLoadMoreIfNeeded();
    } else {
      if (mounted && data != null) {
        final code = data['error_code']?.toString() ?? '';
        final msg = (code.isNotEmpty && errorCodes.containsKey(code))
            ? errorCodes[code]
            : data['message']?.toString() ?? 'Failed to load products';
        Service.showMessage(context: context, title: msg, error: true);
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        searchPagination.isLoadingMore = false;
      });
    }
  }

  // product list with pageination
  Future<dynamic> getStoreProductList({int page = 1}) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_store_product_item_list_paginated";
    Map data = {"store_id": widget.store['_id'], "page": page.toString()};
    var body = json.encode(data);
    // debugPrint("body : $body");

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
      // debugPrint("response: ${json.decode(response.body)}");
      return json.decode(response.body);
    } catch (e) {
      // debugPrint("error : $e");

      return null;
    } finally {
      setState(() {
        _loading = false;
      });
    }
    // Old product list API without pagination
    // var url ="${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/user_get_store_product_item_list";
    // Map data = {"store_id": widget.store['_id']};
  }

  void productClicked(String productId) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/admin/add_user_and_store";
    Map data = {
      "store_id": widget.store['_id'],
      "product_id": productId,
      "user_id": userData['user']['_id'],
      "latitude": widget.latitude,
      "longitude": widget.longitude,
      "is_promotional": false,
    };
    var body = json.encode(data);
    try {
      await http.post(
        Uri.parse(url),
        headers: <String, String>{
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: body,
      );
    } catch (e) {
      // debugPrint(e);
    }
  }

  void _showDialog(item, destination, storeLocation, storeId) {
    showDialog(
      context: context,
      builder: (BuildContext alertContext) {
        return AlertDialog(
          backgroundColor: kPrimaryColor,
          title: Text(Provider.of<ZLanguage>(context).warning),
          content: Text(Provider.of<ZLanguage>(context).itemsFound),
          actions: [
            TextButton(
              child: Text(
                Provider.of<ZLanguage>(context).cancel,
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
                Provider.of<ZLanguage>(context).clear,
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
  /////////////Favorites Feature: not needed for now//////////////////////////
  // void addToFavorites() async {
  //   setState(() {
  //     _loading = true;
  //   });
  //   await _addToFavorite(
  //     userData['user']['_id'],
  //     widget.store['_id'],
  //     userData['user']['server_token'],
  //   );
  //   if (favoriteResponseData != null && favoriteResponseData['success']) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text("Added to favorite"),
  //         backgroundColor: kGreyColor,
  //       ),
  //     );
  //     userData['user']['favourite_stores'].add(widget.store['_id']);
  //     await Service.save('user', userData);
  //     checkFavorite();
  //     setState(() {
  //       _loading = false;
  //     });
  //     reSaveFavorites();
  //   } else {
  //     if (responseData['error_code'] != null &&
  //         favoriteResponseData['error_code'] == 999) {
  //       await Service.saveBool('logged', false);
  //       await Service.remove('user');
  //       // Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  //     }
  //     setState(() {
  //       _loading = false;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           "${errorCodes['${favoriteResponseData['error_code']}']}",
  //         ),
  //         backgroundColor: kSecondaryColor,
  //       ),
  //     );
  //   }
  // }

  // void reSaveFavorites() async {
  //   var url =
  //       "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_favourite_store_list";
  //   Map data = {
  //     "user_id": userData['user']['_id'],
  //     "server_token": userData['user']['server_token'],
  //   };
  //   var body = json.encode(data);
  //   try {
  //     http.Response response = await http
  //         .post(
  //           Uri.parse(url),
  //           headers: <String, String>{
  //             "Content-Type": "application/json",
  //             "Accept": "application/json",
  //           },
  //           body: body,
  //         )
  //         .timeout(
  //           Duration(seconds: 10),
  //           onTimeout: () {
  //             Service.showMessage(
  //               context: context,
  //               title: "Network error",
  //               error: true,
  //             );
  //             throw TimeoutException("The connection has timed out!");
  //           },
  //         );
  //     var val = json.decode(response.body);
  //     if (val['success']) {
  //       await Service.save("user_favorite_stores", val);
  //     }
  //   } catch (e) {
  //     // debugPrint(e);
  //     return null;
  //   }
  // }

  // void removeFavorites() async {
  //   setState(() {
  //     _loading = true;
  //   });
  //   await _removeFavorite(
  //     userData['user']['_id'],
  //     widget.store['_id'],
  //     userData['user']['server_token'],
  //   );
  //   if (favoriteResponseData != null && favoriteResponseData['success']) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           "Store removed from favorites",
  //           style: TextStyle(color: kBlackColor),
  //         ),
  //         backgroundColor: kSecondaryColor,
  //       ),
  //     );
  //     userData['user']['favourite_stores'].removeWhere(
  //       (item) => item == widget.store['_id'],
  //     );
  //     await Service.save('user', userData);
  //     checkFavorite();
  //     setState(() {
  //       _loading = false;
  //     });
  //     reSaveFavorites();
  //   } else {
  //     if (responseData['error_code'] != null &&
  //         favoriteResponseData['error_code'] == 999) {
  //       // debugPrint('Server token expired please log user out');
  //       await Service.saveBool('logged', false);
  //       await Service.remove('user');
  //       // Navigator.pushReplacementNamed(context, LoginScreen.routeName);
  //     }
  //     setState(() {
  //       _loading = false;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           "${errorCodes['${favoriteResponseData['error_code']}']}",
  //         ),
  //         backgroundColor: kSecondaryColor,
  //       ),
  //     );
  //   }
  // }
  /////////////////////////////////////
  // ignore: missing_return

  // If no default spec exists, use the first spec’s first price as a fallback.
  // String _getPrice(item) {
  //   if (item['price'] == null || item['price'] == 0) {
  //     // look for a default-selected spec
  //     for (var i = 0; i < item['specifications'].length; i++) {
  //       for (var j = 0; j < item['specifications'][i]['list'].length; j++) {
  //         final spec = item['specifications'][i]['list'][j];
  //         if (spec['is_default_selected'] == true) {
  //           return spec['price'].toStringAsFixed(2);
  //         }
  //       }
  //     }

  //     // fallback to first available price if none are default-selected
  //     if (item['specifications'].isNotEmpty &&
  //         item['specifications'][0]['list'].isNotEmpty) {
  //       final firstSpecPrice = item['specifications'][0]['list'][0]['price'];
  //       return firstSpecPrice.toStringAsFixed(2);
  //     }
  //   } else {
  //     return item['price'].toStringAsFixed(2);
  //   }

  //   return "0.00";
  // }


  // Future<dynamic> _addToFavorite(
  //   var userId,
  //   var storeId,
  //   var serverToken,
  // ) async {
  //   var url =
  //       "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/add_favourite_store";
  //   Map data = {
  //     "user_id": userId,
  //     "store_id": storeId,
  //     "server_token": serverToken,
  //   };
  //   var body = json.encode(data);
  //   try {
  //     http.Response response = await http
  //         .post(
  //           Uri.parse(url),
  //           headers: <String, String>{
  //             "Content-Type": "application/json",
  //             "Accept": "application/json",
  //           },
  //           body: body,
  //         )
  //         .timeout(
  //           Duration(seconds: 10),
  //           onTimeout: () {
  //             Service.showMessage(
  //               context: context,
  //               title: "Network error",
  //               error: true,
  //             );
  //             setState(() {
  //               _loading = false;
  //             });
  //             throw TimeoutException("The connection has timed out!");
  //           },
  //         );
  //     favoriteResponseData = json.decode(response.body);
  //     return json.decode(response.body);
  //   } catch (e) {
  //     // debugPrint(e);
  //     return null;
  //   }
  // }

  // Future<dynamic> _removeFavorite(
  //   var userId,
  //   var storeId,
  //   var serverToken,
  // ) async {
  //   var url =
  //       "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/remove_favourite_store";
  //   Map data = {
  //     "user_id": userId,
  //     "store_id": [storeId],
  //     "server_token": serverToken,
  //   };
  //   var body = json.encode(data);
  //   try {
  //     http.Response response = await http
  //         .post(
  //           Uri.parse(url),
  //           headers: <String, String>{
  //             "Content-Type": "application/json",
  //             "Accept": "application/json",
  //           },
  //           body: body,
  //         )
  //         .timeout(
  //           Duration(seconds: 10),
  //           onTimeout: () {
  //             Service.showMessage(
  //               context: context,
  //               title: "Network error",
  //               error: true,
  //             );
  //             setState(() {
  //               _loading = false;
  //             });
  //             throw TimeoutException("The connection has timed out!");
  //           },
  //         );
  //     favoriteResponseData = json.decode(response.body);
  //     return json.decode(response.body);
  //   } catch (e) {
  //     // debugPrint(e);
  //     return null;
  //   }
  // }
///////////////////////////////////////
///
///













//               // Main content
  //               Expanded(
  //                 child: _searchResult.length != 0 || controller.text.isNotEmpty
  //                     ? ListView.separated(
  //                         shrinkWrap: true,
  //                         itemCount: _searchResult.length,
  //                         physics: ClampingScrollPhysics(),
  //                         padding: EdgeInsets.symmetric(
  //                           horizontal: kDefaultPadding,
  //                           vertical: kDefaultPadding / 2,
  //                         ),
  //                         separatorBuilder: (BuildContext context, int index) {
  //                           return SizedBox(
  //                             height: getProportionateScreenHeight(
  //                               kDefaultPadding / 2,
  //                             ),
  //                           );
  //                         },
  //                         itemBuilder: (BuildContext context, int index) {
  //                           final item = _searchResult[index];
  //                           return ProductItemCard(
  //                             item: item,
  //                             isOpen: widget.isOpen ?? false,
  //                             onTap: () => _handleItemTap(item),
  //                             onAddTap: () => _handleAddToCart(item),
  //                           );
  //                         },
  //                       )
  //                     : products != null
  //                     ? SafeArea(
  //                         child: ListView.separated(
  //                           shrinkWrap: true,
  //                           itemCount: products.length,
  //                           padding: EdgeInsets.symmetric(
  //                             horizontal: kDefaultPadding,
  //                             vertical: getProportionateScreenHeight(
  //                               kDefaultPadding / 2,
  //                             ),
  //                           ),
  //                           separatorBuilder:
  //                               (BuildContext context, int index) {
  //                                 return SizedBox(
  //                                   height: getProportionateScreenHeight(
  //                                     kDefaultPadding / 2,
  //                                   ),
  //                                 );
  //                               },
  //                           itemBuilder: (BuildContext context, int index) {
  //                             final category = products[index];
  //                             return ExpansionTile(
  //                               textColor: kBlackColor,
  //                               backgroundColor: kPrimaryColor,
  //                               collapsedBackgroundColor: kPrimaryColor,
  //                               shape: RoundedRectangleBorder(
  //                                 side: BorderSide(color: kWhiteColor),
  //                                 borderRadius: BorderRadius.circular(
  //                                   kDefaultPadding,
  //                                 ),
  //                               ),
  //                               collapsedShape: RoundedRectangleBorder(
  //                                 side: BorderSide(color: kWhiteColor),
  //                                 borderRadius: BorderRadius.circular(
  //                                   kDefaultPadding,
  //                                 ),
  //                               ),
  //                               leading: const Icon(
  //                                 Icons.dining,
  //                                 size: 18,
  //                                 color: kBlackColor,
  //                               ),
  //                               childrenPadding: EdgeInsets.only(
  //                                 left: getProportionateScreenWidth(
  //                                   kDefaultPadding / 2,
  //                                 ),
  //                                 right: getProportionateScreenWidth(
  //                                   kDefaultPadding / 2,
  //                                 ),
  //                                 bottom: getProportionateScreenHeight(
  //                                   kDefaultPadding,
  //                                 ),
  //                               ),
  //                               title: Text(
  //                                 Service.capitalizeFirstLetters(
  //                                   category["_id"]["name"],
  //                                 ),
  //                                 style: Theme.of(context).textTheme.bodyLarge
  //                                     ?.copyWith(fontWeight: FontWeight.w700),
  //                               ),
  //                               children: [
  //                                 ListView.separated(
  //                                   physics: const ClampingScrollPhysics(),
  //                                   shrinkWrap: true,
  //                                   itemCount: category['items'].length,
  //                                   separatorBuilder: (context, index) =>
  //                                       SizedBox(
  //                                         height: getProportionateScreenHeight(
  //                                           kDefaultPadding / 2,
  //                                         ),
  //                                       ),
  //                                   itemBuilder:
  //                                       (BuildContext context, int idx) {
  //                                         final item = category['items'][idx];
  //                                         return ProductItemCard(
  //                                           item: item,
  //                                           isOpen: widget.isOpen ?? false,
  //                                           onTap: () => _handleItemTap(item),
  //                                           onAddTap: () =>
  //                                               _handleAddToCart(item),
  //                                         );
  //                                       },
  //                                 ),
  //                               ],
  //                             );
  //                           },
  //                         ),
  //                       )
  //                     : !_loading
  //                     ? Padding(
  //                         padding: EdgeInsets.symmetric(
  //                           horizontal: getProportionateScreenWidth(
  //                             kDefaultPadding * 4,
  //                           ),
  //                           vertical: getProportionateScreenHeight(
  //                             kDefaultPadding * 4,
  //                           ),
  //                         ),
  //                         child: Column(
  //                           mainAxisAlignment: MainAxisAlignment.end,
  //                           children: [
  //                             CustomButton(
  //                               title: "Retry",
  //                               press: () => _loadPage(1),
  //                               // press: () {
  //                               //   _getStoreProductList();
  //                               // },
  //                               color: kSecondaryColor,
  //                             ),
  //                           ],
  //                         ),
  //                       )
  //                     : const SizedBox.shrink(),
  //               ),
  //               // // ========== PAGE INDICATOR (always under the list) ==========
  //               // if (products != null &&
  //               //     _searchResult.isEmpty &&
  //               //     controller.text.isEmpty &&
  //               //     totalPages > 1)
  //               //   PageIndicator(
  //               //     currentPage: currentPage,
  //               //     totalPages: totalPages,
  //               //     onPageChanged: (page) {
  //               //       if (page != currentPage) {
  //               //         _loadPage(page);
  //               //       }
  //               //     },
  //               //     activeColor: kSecondaryColor,
  //               //   ),
  //               // ========== PAGE INDICATOR ==========
  //               if (!_loading) ...[
  //                 // Search mode
  //                 if ((_searchResult.isNotEmpty ||
  //                         controller.text.isNotEmpty) &&
  //                     searchTotalPages > 1)
  //                   PageIndicator(
  //                     currentPage: searchCurrentPage,
  //                     totalPages: searchTotalPages,
  //                     onPageChanged: (page) {
  //                       if (page != searchCurrentPage) {
  //                         _loadSearchPage(page);
  //                       }
  //                     },
  //                     activeColor: kSecondaryColor,
  //                   )
  //                 // Normal product list mode
  //                 else if (products != null &&
  //                     _searchResult.isEmpty &&
  //                     controller.text.isEmpty &&
  //                     totalPages > 1)
  //                   PageIndicator(
  //                     currentPage: currentPage,
  //                     totalPages: totalPages,
  //                     onPageChanged: (page) {
  //                       if (page != currentPage) {
  //                         _loadPage(page);
  //                       }
  //                     },
  //                     activeColor: kSecondaryColor,
  //                   ),
  //               ],
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }