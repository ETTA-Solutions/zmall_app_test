import 'dart:async';
import 'dart:convert';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/comments/review_screen.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/global/cart/global_cart.dart';
import 'package:zmall/global/items/global_items.dart';
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

class GlobalProduct extends StatefulWidget {
  static String routeName = "/product";

  const GlobalProduct({
    Key? key,
    required this.store,
    required this.location,
    required this.isOpen,
    required this.longitude,
    required this.latitude,
  }) : super(key: key);

  final store;
  final location;
  final bool isOpen;
  final double longitude;
  final double latitude;

  @override
  _GlobalProductState createState() => _GlobalProductState();
}

class _GlobalProductState extends State<GlobalProduct> {
  TextEditingController customPriceController = TextEditingController();
  TextEditingController controller = TextEditingController();
  final GlobalKey _filterButtonKey = GlobalKey();

  bool _loading = true;

  var products;
  var price = [];
  AbroadCart? cart;
  List<dynamic> _searchResult = [];
  bool isLoggedIn = false;
  var userData;

  // price finter variables
  String dropDownValue = "Lower than:";
  var items = ["Lower than:", "Greater than:"];

  // Search pagination
  String _lastSearchQuery = '';

  // Scroll controllers

  final productsPagination = PaginationController();
  final searchPagination = PaginationController();

  @override
  void initState() {
    super.initState();
    //
    productsPagination.init(
      onLoadMore: () =>
          _loadPage(productsPagination.currentPage + 1, isLoadMore: true),
    );

    searchPagination.init(
      onLoadMore: () =>
          _loadSearchPage(searchPagination.currentPage + 1, isLoadMore: true),
    );

    _loadPage(1, isRefresh: true);
    // isLogged();
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

  //
  void getCart() async {
    var data = await Service.read('abroad_cart');

    if (data != null) {
      setState(() {
        cart = AbroadCart.fromJson(data);
      });
    }
  }

  // void isLogged() async {
  //   var data = await Service.readBool('logged');
  //   if (data != null) {
  //     setState(() {
  //       isLoggedIn = data;
  //     });
  //     getUser();
  // }

  // void getUser() async {
  //   var data = await Service.read('user');
  //   if (data != null) {
  //     setState(() {
  //       userData = data;
  //     });
  //   }
  // }

  //////////////////// load paginated products /////////////////////////////////
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

  /////// search paginated items //////
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

  ///////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Service.capitalizeFirstLetters(widget.store['name']),
          style: TextStyle(color: kBlackColor),
        ),
        elevation: 0.0,
        backgroundColor: kPrimaryColor,
        actions: [
          InkWell(
            onTap: () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommentsScreen(
                    userId: "5e2c19606d5f9e6f08626e9e",
                    storeId: widget.store['_id'],
                    serverToken: "",
                    isLocal: false,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(
              getProportionateScreenWidth(kDefaultPadding * 2.5),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: getProportionateScreenWidth(kDefaultPadding * .75),
                horizontal: getProportionateScreenWidth(kDefaultPadding / 4),
              ),
              child: Icon(HeroiconsOutline.chatBubbleBottomCenterText),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return GlobalCart();
                  },
                ),
              ).then((value) => getCart());
            },
            borderRadius: BorderRadius.circular(
              getProportionateScreenWidth(kDefaultPadding * 2.5),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(
                    getProportionateScreenWidth(kDefaultPadding * .75),
                  ),
                  child: Icon(HeroiconsOutline.shoppingCart),
                ),
                Positioned(
                  left: 0,
                  top: 5,
                  child: Container(
                    height: getProportionateScreenWidth(kDefaultPadding * .9),
                    width: getProportionateScreenWidth(kDefaultPadding * .9),
                    decoration: BoxDecoration(
                      color: kSecondaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(width: 1.5, color: kWhiteColor),
                    ),
                    child: Center(
                      child: Text(
                        cart != null ? "${cart!.items!.length}" : "0",
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(
                            kDefaultPadding / 2,
                          ),
                          height: 1,
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return GlobalCart();
                        },
                      ),
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
          progressIndicator: LinearLoadingIndicator(),
          child: Column(
            children: [
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

              SizedBox(
                height: getProportionateScreenHeight(kDefaultPadding / 5),
              ),
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
    );
  }

  // ===================== SEARCH LIST =====================
  Widget _buildSearchList() {
    return CustomScrollView(
      controller: searchPagination.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ..._searchResult.map((item) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getProportionateScreenWidth(kDefaultPadding),
                vertical: getProportionateScreenHeight(kDefaultPadding / 4),
              ),
              child: ProductItemCard(
                item: item,
                isOpen: widget.isOpen,
                onTap: () async {
                  productClicked(item['_id']);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return GlobalItem(
                          isOpen: widget.isOpen,
                          item: item,
                          location: widget.location,
                        );
                      },
                    ),
                  ).then((value) => getCart());
                },
              ),
            ),
          );
        }).toList(),

        SliverToBoxAdapter(
          child: PaginationFooter(
            isLoadingMore: searchPagination.isLoadingMore,
            hasMore: searchPagination.hasMore,
            hasItems: _searchResult.isNotEmpty,
            noMoreText: "No more items to load.",
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
                        isOpen: widget.isOpen,
                        onTap: () async {
                          productClicked(item['_id']);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return GlobalItem(
                                  isOpen: widget.isOpen,
                                  item: item,
                                  location: widget.location,
                                );
                              },
                            ),
                          ).then((value) => getCart());
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        SliverToBoxAdapter(
          child: PaginationFooter(
            isLoadingMore: productsPagination.isLoadingMore,
            hasMore: productsPagination.hasMore,
            hasItems: products != null && products.isNotEmpty,
            noMoreText: "No more products to load",
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ),
      ],
    );
  }

  ////////////////// New search filter function ////////////////////////////////
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

  // product list with pagination
  Future<dynamic> getStoreProductList({int page = 1}) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/user_get_store_product_item_list";
    Map data = {"store_id": widget.store['_id']};
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Something went wrong!"),
                  backgroundColor: kSecondaryColor,
                ),
              );
              throw TimeoutException("The connection has timed out!");
            },
          );
      return json.decode(response.body);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Your internet connection is bad!"),
          backgroundColor: kSecondaryColor,
        ),
      );
      return null;
    }
  }

  //////////////////////// search items ////////////////////////////////////////
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
    }
  }

  /////////////////////////////////////////////////////////////////////
  ///////////////price filter popup///////////////////////////////////////
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
      }
    }
  }

  //////////////////////////////////////////
  void productClicked(String productId) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/admin/add_user_and_store";
    Map data = {
      "store_id": widget.store['_id'],
      "product_id": productId,
      "user_id": "zm_abroad_user",
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
    } catch (e) {}
  }
}
