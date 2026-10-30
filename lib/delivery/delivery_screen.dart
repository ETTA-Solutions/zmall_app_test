import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:fl_location/fl_location.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/checkout/checkout_screen.dart';
import 'package:zmall/combo/combo_checkout_screen.dart';
import 'package:zmall/combo/models/combo_cart.dart';
import 'package:zmall/combo/services/combo_service.dart';
import 'package:zmall/combo/widgets/combo_too_far_dialog.dart';
import 'package:zmall/services/address_validation_service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/services/core_services.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/delivery/components/vehicle_container.dart';
import 'package:zmall/location/location_screen.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/custom_text_field.dart';
import 'package:zmall/widgets/section_title.dart';
import 'package:zmall/widgets/shimmer_widget.dart';

import 'components/location_container.dart';

class DeliveryScreen extends StatefulWidget {
  // Delivery location management screen
  static String routeName = '/delivery';

  @override
  _DeliveryScreenState createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  DeliveryLocation? deliveryLocation;
  DestinationAddress? destinationAddress;
  String receiverName = "";
  String receiverPhone = "";
  bool isForOthers = false;

  Cart? cart;
  AliExpressCart? aliexpressCart;
  var userData;
  bool _loading = false;
  bool currSelected =
      true; //  bool currSelected = false; //for defalut current location
  bool selfPickup = false;
  int selected = -1; //  int selected = -2; //for defalut current location

  //for defalut the first vehicle
  int selectedVehicle = -1;
  String vehicleId = "";
  var responseData;
  var vehicleList;

  double? latitude, longitude;
  LocationPermission _permissionStatus = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    getUser();
    // getLocation();
    getLocations();
  }

  // void _requestLocationPermission() async {
  //   _permissionStatus = await FlLocation.checkLocationPermission();
  //   if (_permissionStatus == LocationPermission.always ||
  //       _permissionStatus == LocationPermission.whileInUse) {
  //     // Location permission granted, continue with location-related tasks
  //     getLocation();
  //   } else {
  //     // Handle permission denial
  //     setState(() {
  //       currSelected = false;
  //       selfPickup = false;
  //       selected = -2;
  //     });
  //     Service.showMessage(
  //         context: context,
  //         title:
  //             "Location permission denied. Please enable location service from your phone's settings and try again",
  //         error: true,
  //         duration: 6);
  //     FlLocation.requestLocationPermission();
  //   }
  // }
  void _requestLocationPermission() async {
    // First, check if location services are enabled
    bool isLocationServicesEnabled = await FlLocation.isLocationServicesEnabled;
    // debugPrint(  ">\n>>\n>\n>\n>>>>>>\n is location on in permition $isLocationServicesEnabled");

    if (isLocationServicesEnabled == true) {
      // Then check permissions
      _permissionStatus = await FlLocation.checkLocationPermission();
      if (_permissionStatus == LocationPermission.always ||
          _permissionStatus == LocationPermission.whileInUse) {
        // Location permission granted, continue with location-related tasks
        getLocation();
      } else {
        // Handle permission denial

        Service.showMessage(
          context: context,
          title: "Location permission denied. Please enable and try again",
          error: true,
        );
        FlLocation.requestLocationPermission();
      }
    } else {
      // Location services are disabled
      Service.showMessage(
        context: context,
        title:
            "Location services are turned off. Please enable them in your device settings.",
        error: true,
      );
      return;
    }
  }

  void _getVehicleList() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    var data = await getVehicleList();
    if (!mounted) return;
    if (data != null && data['success']) {
      setState(() {
        _loading = false;
        vehicleList = data;
        // debugPrint("selectedVehicle before $selectedVehicle");
        // debugPrint("selected vehicle id  before ${vehicleId}");
        selectedVehicle =
            vehicleList['vehicles'] != null &&
                vehicleList['vehicles'].isNotEmpty
            ? 0
            : -1;

        if (selectedVehicle != -1) {
          // Default to MOTOR BIKE if available
          for (int i = 0; i < vehicleList['vehicles'].length; i++) {
            final vName = (vehicleList['vehicles'][i]['name'] ?? '')
                .toString()
                .toLowerCase();
            if (vName.contains('motor') || vName.contains('bike')) {
              selectedVehicle = i;
              break;
            }
          }
          vehicleId = vehicleList['vehicles'][selectedVehicle]['_id'];
        } else {
          Service.showMessage(
            context: context,
            title:
                "Delivery is not available to this location. Please update your address.",
            error: true,
            duration: 4,
          );
        }
        // debugPrint("selectedVehicle after $selectedVehicle");
        // debugPrint("selected vehicle id  after ${vehicleId}");
      });
    } else {
      if (mounted)
        setState(() {
          _loading = false;
        });
      if (data != null) {
        if (data['error_code'] == 999) {
          await Service.saveBool('logged', false);
          await Service.remove('user');
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, LoginScreen.routeName);
          return;
        }
        Service.showMessage(
          context: context,
          title:
              "${errorCodes['${data['error_code']}'] ?? 'Something went wrong'}",
          error: true,
        );
      }
    }
  }

  void getLocation() async {
    var currentLocation = await FlLocation.getLocation();
    if (mounted) {
      setState(() {
        latitude = currentLocation.latitude;
        longitude = currentLocation.longitude;
        cart!.destinationAddress!.lat = latitude;
        cart!.destinationAddress!.long = longitude;
      });
      Provider.of<ZMetaData>(
        context,
        listen: false,
      ).setLocation(currentLocation.latitude, currentLocation.longitude);
    }
  }

  void _doLocationTask() async {
    LocationPermission _permissionStatus =
        await FlLocation.checkLocationPermission();
    if (_permissionStatus == LocationPermission.whileInUse ||
        _permissionStatus == LocationPermission.always) {
      if (await FlLocation.isLocationServicesEnabled) {
        getLocation();
      } else {
        LocationPermission serviceStatus =
            await FlLocation.requestLocationPermission();
        if (serviceStatus == LocationPermission.always ||
            serviceStatus == LocationPermission.whileInUse) {
          getLocation();
        } else {
          Service.showMessage(
            context: context,
            title: "Location service disabled. Please enable and try again",
            error: true,
          );
        }
      }
    } else {
      _requestLocationPermission();
    }
  }

  void getUser() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    var data = await Service.read('user');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        userData = data;
      });
    }
    await getCart();
    _doLocationTask();
    _getVehicleList();
  }

  void getLocations({bool returned = false}) async {
    var data = await Service.read('delivery');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        deliveryLocation = DeliveryLocation.fromJson(data);
        if (returned) {
          setState(() {
            currSelected = false;
            selfPickup = false;
            selected = deliveryLocation!.list!.length - 1;

            destinationAddress = deliveryLocation!.list![selected];
          });
        }
        //        for (var i = 0; i < deliveryLocation.list.length; i++) {
        //          debugPrint(deliveryLocation.list[i].name);
        //        }
      });
    }
  }

  // void getLocation() async {
  //   setState(() {
  //     _loading = true;
  //   });
  //   // await Future.delayed(Duration(seconds: 2));
  //   // _checkPermission();
  //   if (status == PermissionStatus.granted) {
  //     // setState(() {
  //     //   _loading = true;
  //     // });
  //     try {
  //       Position? position = await Service.getCurrentLocation();
  //       setState(() {
  //         _loading = false;
  //         currSelected = true;
  //         selfPickup = false;
  //         selected = -1;
  //         currPos = position!;
  //         cart.destinationAddress?.long = currPos.longitude;
  //         cart.destinationAddress?.lat = currPos.latitude;
  //       });
  //       await Service.save('cart', cart);
  //     } catch (e) {
  //       setState(() {
  //         _loading = false;
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         Service.showMessage(
  //             "Please check your location settings and restart the App.", true),
  //       );
  //     }
  //   } else {
  //     Location location = Location();
  //     PermissionStatus permission = await location.requestPermission();
  //     setState(() {
  //       status = permission;
  //       getLocation();
  //     });
  //     if (status == PermissionStatus.granted) {
  //       getLocation();
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         Service.showMessage(
  //             "Please check your location settings and restart the App.", true),
  //       );
  //     }
  //   }
  //   setState(() {
  //     _loading = false;
  //   });
  // }

  addLocation() async {
    setState(() {
      _loading = true;
    });
    // await Future.delayed(Duration(seconds: 2));
    _doLocationTask();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          {
            return LocationScreen(
              currLat: Provider.of<ZMetaData>(context, listen: false).latitude,
              currLon: Provider.of<ZMetaData>(context, listen: false).longitude,
            );
          }
        },
      ),
    ).then((value) {
      getLocations(returned: true);
    });
    if (mounted)
      setState(() {
        _loading = false;
      });
  }

  Future<void> getCart() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    var data = await Service.read('cart');
    var aliCart = await Service.read('aliexpressCart');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        cart = Cart.fromJson(data);
      });
    }
    if (aliCart != null) {
      setState(() {
        aliexpressCart = AliExpressCart.fromJson(aliCart);
      });
    }

    setState(() {
      _loading = false;
    });
  }

  void _addToCart() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    final combo = await ComboCart.load();
    if (!mounted) return;
    if (combo != null) {
      await _addToComboCart(combo);
      return;
    }
    var data = await addToCart();
    if (!mounted) return;
    if (data != null && data['success']) {
      setState(() {
        userData['user']['cart_id'] = data['cart_id'];
      });
      await Service.save('user', userData);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return CheckoutScreen(
              isForOthers: isForOthers,
              receiverName: receiverName,
              receiverPhone: receiverPhone,
              vehicleId: vehicleId,
            );
          },
        ),
      );
    } else {
      if (responseData != null) {
        Service.showMessage(
          context: context,
          title:
              "${errorCodes['${responseData['error_code']}'] ?? 'Something went wrong'}!",
          error: true,
        );
        await Future.delayed(Duration(seconds: 2));
        if (!mounted) return;
        if (responseData['error_code'] != null &&
            responseData['error_code'] == 999) {
          await Service.saveBool('logged', false);
          await Service.remove('user');
          Navigator.pushReplacementNamed(context, LoginScreen.routeName);
        }
      }
    }
  }

  // Guard flag: prevents re-entrant calls while the distance check is in flight.
  bool _comboDistanceCheckInProgress = false;

  /// Combo order: sends both stores in one call, then opens combo checkout.
  Future<void> _addToComboCart(ComboCart combo) async {
    // ── Re-entrancy guard ──────────────────────────────────────────────────
    // Prevents multiple simultaneous taps from racing through while the
    // async distance-check API call is awaited.
    if (_comboDistanceCheckInProgress) return;

    if (selfPickup) {
      setState(() {
        _loading = false;
      });
      Service.showMessage(
        context: context,
        title: "Self pickup is not available when ordering from 2 stores.",
        error: true,
        duration: 4,
      );
      return;
    }

    // ── Distance restriction check ─────────────────────────────────────────
    // Ask the backend for the maximum allowed distance between the two stores.
    // We compute the straight-line distance client-side using haversine and
    // compare against the backend's limit before sending any cart data.
    // IMPORTANT: fail-closed — if the API call fails or returns an unexpected
    // response, we block the order rather than letting it through.
    final storeALoc = cart!.storeLocation;
    final storeBLoc = combo.second.storeLocation;
    if (storeALoc != null &&
        storeBLoc != null &&
        storeALoc.lat != null &&
        storeALoc.long != null &&
        storeBLoc.lat != null &&
        storeBLoc.long != null) {
      _comboDistanceCheckInProgress = true;
      try {
        debugPrint(
          '[COMBO-DEBUG] ▶ Distance check: get_combo_max_store_distance\n'
          '  storeA: ${cart!.storeId}  lat=${storeALoc.lat} lng=${storeALoc.long}\n'
          '  storeB: ${combo.second.storeId}  lat=${storeBLoc.lat} lng=${storeBLoc.long}',
        );

        if (!mounted) return;

        final distRes = await ComboService.StoreDistancegetMax(
          context,
          userData: userData,
          storeIdA: cart!.storeId ?? '',
          storeIdB: combo.second.storeId ?? '',
        );

        debugPrint(
          '[COMBO-DEBUG] ◀ Distance check response: '
          '${distRes == null ? "NULL (timeout/network)" : distRes.toString()}',
        );

        if (!mounted) return;

        // Fail-closed: if the API returned null (timeout/network error)
        // or did not return success:true, block the order.
        if (distRes == null || distRes['success'] != true) {
          setState(() {
            _loading = false;
          });
          Service.showMessage(
            context: context,
            title:
                "Could not verify store distance. Please check your connection and try again.",
            error: true,
            duration: 4,
          );
          return;
        }

        final double maxDistM =
            (distRes['max_distance'] as num? ?? 0.0).toDouble();

        final double actualDistM =
            AddressValidationService.calculateDistanceInMeters(
              storeALoc.lat!,
              storeALoc.long!,
              storeBLoc.lat!,
              storeBLoc.long!,
            );

        debugPrint(
          '[COMBO-DEBUG] ✓ Distance check:\n'
          '  actualDistance : ${actualDistM.toStringAsFixed(0)} m\n'
          '  maxDistance    : ${maxDistM.toStringAsFixed(0)} m\n'
          '  allowed        : ${actualDistM <= maxDistM}',
        );

        if (actualDistM > maxDistM) {
          debugPrint(
            '[COMBO-DEBUG] ⛔ BLOCKED by distance restriction:\n'
            '  actualDistance: $actualDistM m (${(actualDistM / 1000).toStringAsFixed(2)} km)\n'
            '  maxDistance   : $maxDistM m (${(maxDistM / 1000).toStringAsFixed(2)} km)\n'
            '  Order will NOT proceed to addItemInCart or ComboCheckoutScreen.',
          );
          setState(() {
            _loading = false;
          });
          await showComboTooFarDialog(
            context: context,
            actualKm: actualDistM / 1000.0,
            maxKm: maxDistM / 1000.0,
          );
          return;
        }
      } finally {
        // Always release the guard, even if an exception is thrown.
        _comboDistanceCheckInProgress = false;
      }
    } else {
      debugPrint(
        '[COMBO-DEBUG] ⚠️ STORE LOCATIONS MISSING! Distance check SKIPPED:\n'
        '  storeA loc: lat=${storeALoc?.lat}, long=${storeALoc?.long}\n'
        '  storeB loc: lat=${storeBLoc?.lat}, long=${storeBLoc?.long}',
      );
    }
    // ── end distance check ─────────────────────────────────────────────────

    debugPrint(
      '[COMBO-DEBUG] ▶ Step 1: addItemInCart\n'
      '  first_store_id : ${cart!.storeId}\n'
      '  second_store_id: ${combo.second.storeId}\n'
      '  existing combo_id: ${combo.comboId ?? "(none)"}\n'
      '  first_items_count : ${cart!.items?.length ?? 0}\n'
      '  second_items_count: ${combo.second.items?.length ?? 0}',
    );

    final data = await ComboService.addItemInCart(
      context,
      userData: userData,
      first: cart!,
      combo: combo,
      destination: cart!.destinationAddress!,
      username: isForOthers
          ? receiverName
          : "${userData['user']['first_name']} ${userData['user']['last_name']}",
      phone: isForOthers ? receiverPhone : "${userData['user']['phone']}",
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
    });

    debugPrint(
      '[COMBO-DEBUG] ◀ Step 1 response: ${data == null ? "NULL (timeout/network)" : data.toString()}',
    );

    if (data != null && data['success'] == true) {
      combo.resetServerState();
      combo.comboId = data['combo_id'];
      // Map by store_id: the a/b labels change at the invoice step.
      for (final side in ['store_a', 'store_b']) {
        final sideData = data[side];
        if (sideData is Map &&
            sideData['store_id'] != null &&
            sideData['cart_id'] != null) {
          combo.cartIdByStore['${sideData['store_id']}'] =
              '${sideData['cart_id']}';
        }
      }
      if (combo.comboId == null || combo.cartIdByStore.length != 2) {
        debugPrint(
          '[COMBO-DEBUG] ✗ Step 1 validation failed: '
          'combo_id=${combo.comboId} cartIdByStore=${combo.cartIdByStore}',
        );
        Service.showMessage(
          context: context,
          title: "Something went wrong. Please try again.",
          error: true,
        );
        return;
      }
      debugPrint(
        '[COMBO-DEBUG] ✓ Step 1 validated:\n'
        '  combo_id     : ${combo.comboId}\n'
        '  cartIdByStore: ${combo.cartIdByStore}',
      );
      await combo.save();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ComboCheckoutScreen()),
      );
    } else if (ComboService.isSessionExpired(data)) {
      Service.showMessage(
        context: context,
        title: "${errorCodes['999']}!",
        error: true,
      );
      await Service.saveBool('logged', false);
      await Service.remove('user');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
    } else {
      Service.showMessage(
        context: context,
        title: ComboService.errorText(data),
        error: true,
        duration: 5,
      );
    }
  }

  Widget wrapperContainer({
    required List<Widget> children,
    double? height,
    double spacing = kDefaultPadding / 3,
    double? horizontalMargin,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal:
            horizontalMargin ?? getProportionateScreenWidth(kDefaultPadding),
        vertical: getProportionateScreenHeight(kDefaultPadding / 2),
      ),
      child: Column(
        spacing: getProportionateScreenHeight(spacing),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        title: Text(
          Provider.of<ZLanguage>(context, listen: false).deliveryDetails,
          style: TextStyle(color: kBlackColor),
        ),
        // elevation: 1.0,
      ),
      body: SafeArea(
        child: ModalProgressHUD(
          color: kPrimaryColor,
          progressIndicator: linearProgressIndicator,
          inAsyncCall:
              _loading &&
              (vehicleList != null && vehicleList['vehicles'].isNotEmpty),
          child: SingleChildScrollView(
            child: userData != null
                ? Column(
                    children: [
                      wrapperContainer(
                        children: [
                          SectionTitle(
                            sectionTitle: Provider.of<ZLanguage>(
                              context,
                              listen: false,
                            ).deliveryDetails,
                            subTitle: " ",
                            onSubTitlePress: () {},
                          ),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              border: Border.all(
                                color: kGreyColor.withValues(alpha: 0.1),
                              ),
                              borderRadius: BorderRadius.circular(
                                getProportionateScreenWidth(
                                  kDefaultPadding / 2,
                                ),
                              ),
                              // boxShadow: [boxShadow],
                            ),
                            padding:
                                EdgeInsets.symmetric(
                                  horizontal: getProportionateScreenWidth(
                                    kDefaultPadding,
                                  ),
                                ).copyWith(
                                  bottom: getProportionateScreenHeight(
                                    kDefaultPadding / 2,
                                  ),
                                ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: getProportionateScreenHeight(
                                kDefaultPadding / 8,
                              ),
                              children: [
                                /////header/////
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Deliver to",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: kBlackColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextButton(
                                      style: ButtonStyle(
                                        padding: WidgetStateProperty.all(
                                          EdgeInsets.only(right: 0, top: 0),
                                        ),
                                      ),
                                      onPressed: () {
                                        _showDeliverToBottomSheet();
                                      },
                                      child: Row(
                                        spacing: getProportionateScreenWidth(
                                          kDefaultPadding / 4,
                                        ),
                                        children: [
                                          Text(
                                            Provider.of<ZLanguage>(
                                              context,
                                              listen: false,
                                            ).changeDetails,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: kSecondaryColor,
                                              fontWeight: FontWeight.bold,
                                              // decoration:TextDecoration.underline,
                                            ),
                                          ),
                                          Icon(
                                            size: 16,
                                            HeroiconsOutline.pencilSquare,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                ///user detail//
                                DetailsRow(
                                  title: Provider.of<ZLanguage>(
                                    context,
                                    listen: false,
                                  ).name,
                                  subtitle:
                                      receiverName.isNotEmpty && isForOthers
                                      ? receiverName
                                      : "${userData['user']['first_name']} ${userData['user']['last_name']} ",
                                ),

                                DetailsRow(
                                  title: Provider.of<ZLanguage>(
                                    context,
                                    listen: false,
                                  ).phone,
                                  subtitle:
                                      receiverPhone.isNotEmpty && isForOthers
                                      ? "${Provider.of<ZMetaData>(context, listen: false).areaCode} $receiverPhone"
                                      : "${Provider.of<ZMetaData>(context, listen: false).areaCode} ${userData['user']['phone']}",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      selfPickup
                          ? SizedBox.shrink()
                          : wrapperContainer(
                              horizontalMargin: 0,
                              height: getProportionateScreenWidth(
                                MediaQuery.sizeOf(context).height * 0.14,
                              ),
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: getProportionateScreenWidth(
                                      kDefaultPadding,
                                    ),
                                  ),
                                  child: SectionTitle(
                                    sectionTitle: Provider.of<ZLanguage>(
                                      context,
                                      listen: false,
                                    ).deliveryOptions,
                                    subTitle: " ",
                                    onSubTitlePress: () {},
                                  ),
                                ),
                                vehicleList != null &&
                                        vehicleList['vehicles'].isNotEmpty
                                    ? Expanded(
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          padding: EdgeInsets.symmetric(
                                            horizontal:
                                                getProportionateScreenWidth(
                                                  kDefaultPadding,
                                                ),
                                          ),
                                          separatorBuilder:
                                              (
                                                BuildContext context,
                                                int index,
                                              ) => SizedBox(
                                                width:
                                                    getProportionateScreenWidth(
                                                      kDefaultPadding,
                                                    ),
                                              ),
                                          itemCount:
                                              vehicleList['vehicles'] != null
                                              ? vehicleList['vehicles'].length
                                              : 0,
                                          itemBuilder: (context, index) => VehicleContainer(
                                            selected: selectedVehicle == index,
                                            imageUrl: selectedVehicle == index
                                                ? "images/${vehicleList['vehicles'][index]['vehicle_name'].toString().toLowerCase()}_selected.png"
                                                : "images/${vehicleList['vehicles'][index]['vehicle_name'].toString().toLowerCase()}.png",
                                            category:
                                                vehicleList['vehicles'][index]['vehicle_name'],
                                            press: () {
                                              setState(() {
                                                if (selectedVehicle != index) {
                                                  selectedVehicle = index;
                                                  vehicleId =
                                                      vehicleList['vehicles'][index]['_id'];
                                                  // debugPrint("selected vehicle id ontap $vehicleId");
                                                } else {
                                                  selectedVehicle = -1;
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      )
                                    : Expanded(
                                        child: ListView.separated(
                                          itemCount: 3,
                                          scrollDirection: Axis.horizontal,
                                          separatorBuilder: (context, index) =>
                                              SizedBox(
                                                width:
                                                    getProportionateScreenWidth(
                                                      kDefaultPadding * 2.5,
                                                    ),
                                              ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal:
                                                getProportionateScreenWidth(
                                                  kDefaultPadding,
                                                ),
                                          ),
                                          itemBuilder: (context, index) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              spacing:
                                                  getProportionateScreenHeight(
                                                    kDefaultPadding / 3,
                                                  ),
                                              children: [
                                                Flexible(
                                                  child: SearchButtonShimmer(
                                                    width:
                                                        getProportionateScreenWidth(
                                                          kDefaultPadding * 5,
                                                        ),
                                                    height:
                                                        getProportionateScreenHeight(
                                                          kDefaultPadding * 3.5,
                                                        ),
                                                    borderRadius:
                                                        kDefaultPadding,
                                                  ),
                                                ),
                                                SearchButtonShimmer(
                                                  height: 16,
                                                  borderRadius: 5,
                                                  width:
                                                      getProportionateScreenWidth(
                                                        kDefaultPadding * 5,
                                                      ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                              ],
                            ),

                      wrapperContainer(
                        spacing: kDefaultPadding / 2,
                        children: [
                          SectionTitle(
                            icon: HeroiconsOutline.plusCircle,
                            subTitleColor: kSecondaryColor,
                            subTitleFontWeight: FontWeight.bold,
                            sectionTitle: Provider.of<ZLanguage>(
                              context,
                              listen: false,
                            ).locations,
                            subTitle: Provider.of<ZLanguage>(
                              context,
                              listen: false,
                            ).addLocation,
                            onSubTitlePress: () {
                              addLocation();
                            },
                          ),

                          //////////current loaction//////////////
                          LocationContainer(
                            title: Provider.of<ZLanguage>(
                              context,
                              listen: false,
                            ).currentLocation,
                            note: Provider.of<ZLanguage>(
                              context,
                              listen: false,
                            ).useCurrentLocation,
                            isSelected: currSelected,
                            press: () async {
                              setState(() {
                                currSelected = true;
                                selfPickup = false;
                                selected = -1;
                              });
                              _doLocationTask();

                              // getLocation();
                            },
                          ),
                          // SizedBox(
                          //   height: kDefaultPadding / 2,
                          // ),
                          //////////self pickup loaction//////////////
                          if (!cart!.isLaundryService)
                            LocationContainer(
                              title: Provider.of<ZLanguage>(
                                context,
                                listen: false,
                              ).selfPickup,
                              note: Provider.of<ZLanguage>(
                                context,
                                listen: false,
                              ).userPickup,
                              isSelected: selfPickup,
                              press: () async {
                                setState(() {
                                  currSelected = false;
                                  selfPickup = true;
                                  selected = -1;
                                  selectedVehicle = 0;
                                  destinationAddress = DestinationAddress(
                                    name: Provider.of<ZLanguage>(
                                      context,
                                      listen: false,
                                    ).userPickup,
                                    long: Provider.of<ZMetaData>(
                                      context,
                                      listen: false,
                                    ).longitude,
                                    lat: Provider.of<ZMetaData>(
                                      context,
                                      listen: false,
                                    ).latitude,
                                  );
                                });
                                // getLocation();
                              },
                            ),
                          // SizedBox(
                          //   height: kDefaultPadding / 2,
                          // ),
                          ////////////////other locations//////////
                          ListView.separated(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount:
                                deliveryLocation != null &&
                                    deliveryLocation!.list!.length > 0
                                ? deliveryLocation!.list!.length
                                : 0,
                            separatorBuilder: (_, __) => SizedBox(
                              height: getProportionateScreenHeight(
                                kDefaultPadding / 2,
                              ),
                            ),
                            itemBuilder: (context, index) {
                              final item = deliveryLocation!.list![index];
                              // Stable unique key – do NOT include the index
                              final uniqueKey = ValueKey(
                                '${item.lat}_${item.long}_${item.name}',
                              );
                              return Dismissible(
                                key: uniqueKey,
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(
                                    right: getProportionateScreenWidth(
                                      kDefaultPadding,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    HeroiconsSolid.trash,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  final removedName = item.name;

                                  setState(() {
                                    deliveryLocation!.list!.removeAt(index);
                                    Service.save(
                                      'delivery',
                                      deliveryLocation!.toJson(),
                                    );
                                  });

                                  Service.showMessage(
                                    context: context,
                                    error: false,
                                    title: '$removedName removed',
                                  );

                                  return true;
                                },

                                child: LocationContainer(
                                  title: deliveryLocation!.list![index].name!
                                      .split(",")[0],
                                  note: deliveryLocation!.list![index].note,
                                  press: () {
                                    setState(() {
                                      currSelected = false;
                                      selfPickup = false;
                                      selected = index;
                                      destinationAddress =
                                          deliveryLocation!.list![index];
                                    });
                                    _getVehicleList();
                                  },
                                  isSelected: index == selected,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  )
                : Container(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpinKitWave(
                            color: kSecondaryColor,
                            size: getProportionateScreenHeight(kDefaultPadding),
                          ),
                          // Padding(
                          //   padding: EdgeInsets.only(
                          //     top:
                          //         getProportionateScreenHeight(kDefaultPadding / 2),
                          //   ),
                          //   child: Text("Locating your current location..."),
                          // ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          // height: kDefaultPadding * 4,
          padding: EdgeInsets.symmetric(
            vertical: getProportionateScreenHeight(kDefaultPadding / 2),
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
            title: Provider.of<ZLanguage>(context, listen: false).cont,
            press: () async {
              if (selected != -2 && selectedVehicle != -1
              // deliveryLocation == null ||
              // deliveryLocation.list.length > selected
              ) {
                if (currSelected) {
                  destinationAddress = DestinationAddress(
                    name: "Current location",
                    long: Provider.of<ZMetaData>(
                      context,
                      listen: false,
                    ).longitude,
                    lat: Provider.of<ZMetaData>(
                      context,
                      listen: false,
                    ).latitude,
                  );
                } else if (selfPickup) {
                  destinationAddress = DestinationAddress(
                    name: "User Pickup",
                    long: Provider.of<ZMetaData>(
                      context,
                      listen: false,
                    ).longitude,
                    lat: Provider.of<ZMetaData>(
                      context,
                      listen: false,
                    ).latitude,
                  );
                }
                if (destinationAddress != null) {
                  double storeToCustomerDistance = calculateDistance(
                    cart!.storeLocation!.lat,
                    cart!.storeLocation!.long,
                    destinationAddress!.lat,
                    destinationAddress!.long,
                  );

                  debugPrint('┌─────────────────────────────────────────────────────');
                  debugPrint('│ [DELIVERY-DEBUG] Continue pressed:');
                  debugPrint('│ vehicle: ${selectedVehicle != -1 ? vehicleList['vehicles'][selectedVehicle]['vehicle_name'] : "(none)"}');
                  debugPrint('│ selfPickup: $selfPickup');
                  debugPrint('│ storeToCustomerDistance: ${storeToCustomerDistance.toStringAsFixed(2)} km');

                  if (selectedVehicle != -1 &&
                      vehicleList['vehicles'][selectedVehicle]['vehicle_name']
                              .toString()
                              .toLowerCase() ==
                          "bicycle" &&
                      storeToCustomerDistance > 5 &&
                      !selfPickup) {
                    debugPrint('│ ⚠️ Far delivery location popup triggered (bicycle & distance > 5 km)!');
                    debugPrint('└─────────────────────────────────────────────────────');
                    Service.showMessage(
                      context: context,
                      title: Provider.of<ZLanguage>(
                        context,
                        listen: false,
                      ).farDeliveryLocation,
                      error: true,
                      duration: 5,
                    );
                  } else {
                    debugPrint('│ ✅ Distance check passed for vehicle. Proceeding to _addToCart...');
                    debugPrint('└─────────────────────────────────────────────────────');
                    setState(() {
                      cart!.destinationAddress = destinationAddress;
                      Service.save('cart', cart);
                      _loading = true;
                    });
                    var categoriesResponse = await CoreServices.getCategoryList(
                      longitude: destinationAddress!.long!,
                      latitude: destinationAddress!.lat!,
                      countryCode: Provider.of<ZMetaData>(
                        context,
                        listen: false,
                      ).countryId!,
                      countryName: Provider.of<ZMetaData>(
                        context,
                        listen: false,
                      ).country,
                      context: context,
                    );

                    if (categoriesResponse != null &&
                        categoriesResponse['success']) {
                      _addToCart();
                    } else if (categoriesResponse != null) {
                      if (categoriesResponse['error_code'] == 999) {
                        await Service.saveBool('logged', false);
                        await Service.remove('user');
                        if (!mounted) return;
                        Service.showMessage(
                          context: context,
                          title:
                              "${errorCodes['${categoriesResponse['error_code']}'] ?? 'Session expired'}",
                          error: true,
                        );
                        Navigator.pushReplacementNamed(
                          context,
                          LoginScreen.routeName,
                        );
                      } else if (categoriesResponse['error_code'] == 813) {
                        Service.showMessage(
                          context: context,
                          title:
                              "Destination address cannot be outside of Addis Ababa",
                          error: true,
                          duration: 4,
                        );
                        if (mounted)
                          setState(() {
                            _loading = false;
                          });
                      } else {
                        Service.showMessage(
                          context: context,
                          title:
                              "${errorCodes['${categoriesResponse['error_code']}'] ?? 'Something went wrong'}",
                          error: true,
                        );
                      }
                      if (mounted)
                        setState(() {
                          _loading = false;
                        });
                    }
                  }
                } else {
                  Service.showMessage(
                    context: context,
                    title: "Please select a delivery address",
                    error: true,
                    duration: 4,
                  );
                }

                // _addToCart();
              } else {
                if (selectedVehicle == -1) {
                  Service.showMessage(
                    context: context,
                    title: "Please select a delivery option",
                    error: true,
                    duration: 4,
                  );
                } else if (selectedVehicle == -1) {
                  Service.showMessage(
                    context: context,
                    title: "Please select a delivery address",
                    error: true,
                    duration: 4,
                  );
                }
              }
            },
            color: kSecondaryColor,
          ),
        ),
      ),
    );
  }

  void _showDeliverToBottomSheet() {
    showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      backgroundColor: kPrimaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(kDefaultPadding),
          topRight: Radius.circular(kDefaultPadding),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext sheetContext, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    kDefaultPadding, // Adjust for keyboard
              ),
              child: SafeArea(
                minimum: EdgeInsets.symmetric(
                  horizontal: getProportionateScreenWidth(kDefaultPadding),
                  vertical: getProportionateScreenHeight(kDefaultPadding),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: getProportionateScreenHeight(kDefaultPadding * 1.5),
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Provider.of<ZLanguage>(
                            context,
                            listen: false,
                          ).orderForOthers,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(HeroiconsOutline.xCircle),
                          color: kSecondaryColor,
                        ),
                      ],
                    ),
                    CustomTextField(
                      style: TextStyle(color: kBlackColor),
                      keyboardType: TextInputType.text,
                      onChanged: (val) {
                        receiverName = val;
                      },
                      labelText: Provider.of<ZLanguage>(context).name,
                      hintText: "Reciever name",
                      // reciever
                    ),
                    CustomTextField(
                      style: TextStyle(color: kBlackColor),
                      keyboardType: TextInputType.number,
                      maxLength: 9,
                      onChanged: (val) {
                        receiverPhone = val;
                      },
                      labelText: Provider.of<ZLanguage>(
                        context,
                        listen: false,
                      ).receiverPhone,
                      hintText: Provider.of<ZLanguage>(
                        context,
                        listen: false,
                      ).startPhone,
                      prefix: Text(
                        "${Provider.of<ZMetaData>(context, listen: false).areaCode} ",
                      ),
                    ),
                    SizedBox(
                      height: getProportionateScreenHeight(kDefaultPadding),
                    ),
                    CustomButton(
                      title: Provider.of<ZLanguage>(
                        context,
                        listen: false,
                      ).submit,
                      color: kSecondaryColor,
                      press: () async {
                        if (receiverPhone.isNotEmpty &&
                                receiverName.isNotEmpty &&
                                receiverPhone.substring(0, 1) == 9.toString() ||
                            receiverPhone.length == 9) {
                          setState(() {
                            isForOthers = true;
                            cart!.userName = receiverName;
                            cart!.phone = receiverPhone;
                            cart!.isForOthers = isForOthers;
                          });

                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<dynamic> clearCart(String cartId) async {
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/clear_cart";
    Map data = {
      "user_id": userData['user']['_id'],
      "cart_id": cartId,
      "server_token": userData['user']['server_token'],
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
            Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      if (mounted)
        setState(() {
          this.responseData = json.decode(response.body);
        });

      return json.decode(response.body);
    } catch (e) {
      if (mounted) {
        Service.showMessage(
          context: context,
          title: "Something went wrong! Check your internet and try again",
          error: true,
          duration: 3,
        );
      }

      return null;
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<dynamic> addToCart() async {
    var url;

    ///if the order is from aliexpress
    if (aliexpressCart != null &&
        aliexpressCart!.cart.storeId == cart!.storeId) {
      url =
          "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/add_item_in_cart_new_for_aliexpress";

      ///else, it is from local stores
    } else {
      url =
          "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/add_item_in_cart_new";
    }

    var body = json.encode(cart!.toJson());
    // TEMP DEBUG: compare with chatbot checkout
    debugPrint("🔎 [MAIN CHECKOUT] add_item_in_cart_new payload: $body", wrapWidth: 800);
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
            Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );
      // TEMP DEBUG: compare with chatbot checkout
      debugPrint("🔎 [MAIN CHECKOUT] add_item_in_cart_new response: ${response.body}", wrapWidth: 800);
      if (mounted)
        setState(() {
          this.responseData = json.decode(response.body);
        });

      return json.decode(response.body);
    } catch (e) {
      if (mounted) {
        Service.showMessage(
          context: context,
          title: "Something went wrong! Check your internet and try again",
          error: true,
          duration: 3,
        );
      }
      return null;
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<dynamic> getVehicleList() async {
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/store/get_vehicle_list";

    Map data = {
      "store_id": "",
      "type": 7,
      "delivery_type": 1,
      "user_id": userData['user']['_id'],
      "server_token": userData['user']['server_token'],
      "city_id": Provider.of<ZMetaData>(context, listen: false).cityId,
      "user_latitude": cart!.storeLocation!.lat,
      "user_longitude": cart!.storeLocation!.long,
      "store_latitude": cart!.destinationAddress!.lat,
      "store_longitude": cart!.destinationAddress!.long,
      "use_calculation": true,
      "is_laundry": cart!.isLaundryService,
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
            Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("The connection has timed out!");
            },
          );

      return json.decode(response.body);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Something went wrong. Please check your internet connection!",
            ),
            backgroundColor: kSecondaryColor,
          ),
        );
      }
      return null;
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }
}
