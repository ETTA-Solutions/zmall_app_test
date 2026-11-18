import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zmall/courier/components/trip_type_button.dart';
import 'package:zmall/services/image_upload_service.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/courier_checkout/courier_checkout_screen.dart';
import 'package:zmall/custom_widgets/custom_button.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/login/login_screen.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:zmall/courier/components/category_card.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/widgets/order_status_row.dart';
import 'package:zmall/widgets/shimmer_widget.dart';

class VehicleScreen extends StatefulWidget {
  static String routeName = '/vehicle';

  const VehicleScreen({
    @required this.userData,
    @required this.orderDetail,
    @required this.pickupAddress,
    @required this.destinationAddress,
  });

  final userData, orderDetail;
  final LatLng? pickupAddress;
  final LatLng? destinationAddress;

  @override
  _VehicleScreenState createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  bool _loading = false;
  bool canAddImage = true;
  bool paidBySender = true;
  bool isRoundTrip = false;
  var vehicleList;
  int selected = 0;
  int quantity = 1;
  List<String> imagePath = [];
  List<File> imageList = [];
  double? distance, time;
  File? _image;
  final imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Clear any old images from previous courier orders
    Service.remove('images');
    _getVehicleList();
  }

  void _getVehicleList() async {
    await Service.remove('images');
    setState(() {
      _loading = true;
    });
    var data = await getVehicleList();
    // debugPrint("fetched vehicle list");
    if (data != null && data['success']) {
      setState(() {
        _loading = false;
        vehicleList = data;
      });
    } else {
      setState(() {
        _loading = false;
      });

      Service.showMessage(
        context: context,
        title: "${errorCodes['${data['error_code']}']}!",
        error: true,
      );
      await Future.delayed(Duration(seconds: 2));
      if (data['error_code'] == 999) {
        await Service.saveBool('logged', false);
        await Service.remove('user');
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
  }

  /// Pick an image from gallery with full error handling.
  /// Delegates all validation to [ImageUploadService].
  Future<void> getImage() async {
    final result = await ImageUploadService.pickAndValidate();

    result.when(
      success: (file) {
        setState(() {
          _image = file;
          imageList.add(file);
          imagePath.add(file.path);
          canAddImage = imageList.length < 2;
        });
      },
      failure: (message, type) {
        // User cancellation — no message needed
        if (type == ImageValidationError.cancelled) return;
        _showImageError(message);
      },
    );
  }

  /// Show a user-friendly error message for image issues.
  void _showImageError(String message) {
    if (!mounted) return;
    Service.showMessage(
      context: context,
      title: message,
      error: true,
      duration: 4,
    );
  }

  void _getTotalDistance() async {
    setState(() {
      _loading = true;
    });
    var data = await getTotalDistance();
    if (data != null && data['rows'][0]['elements'][0]['status'] == 'OK') {
      setState(() {
        distance = data['rows'][0]['elements'][0]['distance']['value']
            .toDouble();
        time = data['rows'][0]['elements'][0]['duration']['value'].toDouble();
      });
      _getCourierInvoice();
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  void _getCourierInvoice() async {
    // debugPrint("Fetching invoice.....");
    setState(() {
      _loading = true;
    });
    // Proof photos go to the courier cart before the invoice/payment.
    if (!await _uploadCourierImages()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    var data = await getCourierInvoice();
    if (data != null && data['success']) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return CourierCheckout(
              orderDetail: widget.orderDetail,
              userData: widget.userData,
              cartInvoice: data,
            );
          },
        ),
      );
    } else {
      Service.showMessage(
        context: context,
        title: "${errorCodes['${data['error_code']}']}!",
        error: true,
      );
      await Future.delayed(Duration(seconds: 2));
      if (data['error_code'] == 999) {
        await Service.saveBool('logged', false);
        await Service.remove('user');
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Courier Delivery Details",
          style: TextStyle(color: kBlackColor),
        ),
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.only(
          left: getProportionateScreenWidth(kDefaultPadding),
          right: getProportionateScreenWidth(kDefaultPadding),
          bottom: getProportionateScreenHeight(kDefaultPadding / 2),
        ),
        child: CustomButton(
          title: "Checkout",
          press: () async {
            if (imagePath.length > 0) {
              // debugPrint("Saving images");
              await Service.save('images', imagePath);
              // debugPrint("Images saved....");
            }
            await Service.saveBool('courier_paid_by_sender', paidBySender);
            _getTotalDistance();
          },
          color: kSecondaryColor,
        ),
      ),
      body: ModalProgressHUD(
        color: kPrimaryColor.withValues(alpha: 0.1),
        inAsyncCall: _loading,
        progressIndicator: LinearLoadingIndicator(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(kDefaultPadding),
              vertical: getProportionateScreenHeight(kDefaultPadding),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: getProportionateScreenHeight(kDefaultPadding),
              children: [
                // Enhanced Vehicle Selection Section
                Container(
                  padding: EdgeInsets.all(
                    getProportionateScreenWidth(kDefaultPadding),
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(
                      getProportionateScreenWidth(kDefaultPadding * 1.2),
                    ),
                    border: Border.all(color: kWhiteColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: getProportionateScreenHeight(
                      kDefaultPadding * 1.5,
                    ),
                    children: [
                      OrderStatusRow(
                        value: "Delivery",
                        title: "Vehicle & trip type",
                        icon: HeroiconsOutline.truck,
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: getProportionateScreenHeight(
                          kDefaultPadding / 2,
                        ),
                        children: [
                          Text(
                            "Select delivery vehicle",
                            style: TextStyle(fontSize: kDefaultPadding),
                          ),

                          vehicleList != null &&
                                  vehicleList['vehicles'].length > 0
                              ? Container(
                                  height: getProportionateScreenHeight(
                                    kDefaultPadding * 6,
                                  ),
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (context, index) => CategoryCard(
                                      imageUrl: selected == index
                                          ? "images/${vehicleList['vehicles'][index]['vehicle_name'].toString().toLowerCase()}_selected.png"
                                          : "images/${vehicleList['vehicles'][index]['vehicle_name'].toString().toLowerCase()}.png",

                                      category: Service.capitalizeFirstLetters(
                                        vehicleList['vehicles'][index]['vehicle_name'],
                                      ),
                                      press: () {
                                        setState(() {
                                          selected = index;
                                        });
                                      },
                                      selected: selected == index,
                                    ),
                                    separatorBuilder:
                                        (BuildContext context, int index) =>
                                            SizedBox(
                                              width:
                                                  getProportionateScreenWidth(
                                                    kDefaultPadding,
                                                  ),
                                            ),
                                    itemCount: vehicleList['vehicles'] != null
                                        ? vehicleList['vehicles'].length
                                        : 0,
                                  ),
                                )
                              : _loading
                              ? Container(
                                  height: getProportionateScreenHeight(
                                    kDefaultPadding * 5.5,
                                  ),
                                  child: ListView.separated(
                                    itemCount: 3,
                                    scrollDirection: Axis.horizontal,
                                    separatorBuilder: (context, index) =>
                                        SizedBox(
                                          width: getProportionateScreenWidth(
                                            kDefaultPadding / 2,
                                          ),
                                        ),
                                    itemBuilder: (context, index) {
                                      return Container(
                                        width: getProportionateScreenWidth(
                                          kDefaultPadding * 6,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          spacing: getProportionateScreenHeight(
                                            kDefaultPadding / 4,
                                          ),
                                          children: [
                                            SearchButtonShimmer(
                                              width:
                                                  getProportionateScreenWidth(
                                                    kDefaultPadding * 5,
                                                  ),
                                              height:
                                                  getProportionateScreenHeight(
                                                    kDefaultPadding * 3,
                                                  ),
                                              borderRadius: kDefaultPadding / 2,
                                            ),
                                            SearchButtonShimmer(
                                              height:
                                                  getProportionateScreenWidth(
                                                    kDefaultPadding * 1.5,
                                                  ),
                                              borderRadius: kDefaultPadding / 2,
                                              width:
                                                  getProportionateScreenWidth(
                                                    kDefaultPadding * 5,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  padding: EdgeInsets.all(
                                    getProportionateScreenWidth(
                                      kDefaultPadding,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    color: kSecondaryColor.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      getProportionateScreenWidth(
                                        kDefaultPadding,
                                      ),
                                    ),
                                    border: Border.all(
                                      color: kSecondaryColor.withValues(
                                        alpha: 0.2,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        HeroiconsOutline.exclamationTriangle,
                                        color: kSecondaryColor,
                                        size: getProportionateScreenWidth(
                                          kDefaultPadding * 2,
                                        ),
                                      ),
                                      SizedBox(
                                        height: getProportionateScreenHeight(
                                          kDefaultPadding / 2,
                                        ),
                                      ),
                                      Text(
                                        "No Vehicles Available",
                                        style: TextStyle(
                                          fontSize:
                                              getProportionateScreenHeight(
                                                kDefaultPadding * 0.8,
                                              ),
                                          fontWeight: FontWeight.bold,
                                          color: kBlackColor,
                                        ),
                                      ),
                                      SizedBox(
                                        height: getProportionateScreenHeight(
                                          kDefaultPadding / 4,
                                        ),
                                      ),
                                      Text(
                                        "All our vehicles are busy completing orders.\nPlease try again in a few minutes.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize:
                                              getProportionateScreenHeight(
                                                kDefaultPadding * 0.65,
                                              ),
                                          color: kGreyColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: getProportionateScreenHeight(
                          kDefaultPadding / 2,
                        ),
                        children: [
                          // OrderStatusRow(
                          //   value: "Trip Type",
                          //   title: "Delivery trip type",
                          //   icon: HeroiconsOutline.arrowPathRoundedSquare,
                          // ),
                          Text(
                            "One way or round trip",
                            style: TextStyle(fontSize: kDefaultPadding),
                          ),
                          // Modern trip type segmented control
                          Container(
                            padding: EdgeInsets.all(
                              getProportionateScreenWidth(5),
                            ),
                            decoration: BoxDecoration(
                              color: kWhiteColor,
                              borderRadius: BorderRadius.circular(
                                getProportionateScreenWidth(
                                  kDefaultPadding * 1.1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // One Way
                                TripTypeButton(
                                  title: "One Way",
                                  icon: HeroiconsOutline.mapPin,
                                  isSelected: !isRoundTrip,
                                  onTap: () {
                                    setState(() => isRoundTrip = false);
                                  },
                                ),

                                // Round Trip
                                TripTypeButton(
                                  title: "Round Trip",
                                  icon: HeroiconsOutline.arrowsRightLeft,
                                  isSelected: isRoundTrip == true,
                                  onTap: () {
                                    setState(() => isRoundTrip = true);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Enhanced Item Quantity and Image Section
                Container(
                  padding: EdgeInsets.all(
                    getProportionateScreenWidth(kDefaultPadding),
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(
                      getProportionateScreenWidth(kDefaultPadding * 1.2),
                    ),
                    border: Border.all(color: kWhiteColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    spacing: getProportionateScreenHeight(
                      kDefaultPadding * 1.5,
                    ),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OrderStatusRow(
                        value: "Item Details",
                        title: "Quantity & proof photos",
                        icon: HeroiconsOutline.informationCircle,
                      ),
                      // Modern quantity stepper
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: getProportionateScreenHeight(
                          kDefaultPadding / 2,
                        ),
                        children: [
                          Text(
                            "How many items are you sending?",
                            style: TextStyle(fontSize: kDefaultPadding),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: getProportionateScreenWidth(6),
                              vertical: getProportionateScreenHeight(6),
                            ),
                            decoration: BoxDecoration(
                              color: kWhiteColor,
                              borderRadius: BorderRadius.circular(
                                getProportionateScreenWidth(
                                  kDefaultPadding * 1.1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // ── Minus ──
                                GestureDetector(
                                  onTap: quantity > 1
                                      ? () => setState(() => quantity--)
                                      : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: getProportionateScreenWidth(44),
                                    height: getProportionateScreenWidth(44),
                                    decoration: BoxDecoration(
                                      color: quantity > 1
                                          ? kWhiteColor
                                          : kGreyColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(
                                        getProportionateScreenWidth(
                                          kDefaultPadding,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: quantity > 1
                                            ? kGreyColor.withValues(alpha: 0.12)
                                            : Colors.transparent,
                                      ),
                                      boxShadow: quantity > 1
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Icon(
                                      HeroiconsOutline.minus,
                                      size: getProportionateScreenWidth(20),
                                      color: quantity > 1
                                          ? kBlackColor
                                          : kGreyColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),

                                // ── Quantity ──
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "$quantity",
                                        style: TextStyle(
                                          fontSize:
                                              getProportionateScreenHeight(26),
                                          fontWeight: FontWeight.w700,
                                          color: kSecondaryColor,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        quantity == 1 ? "Item" : "Items",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: kGreyColor.withValues(
                                                alpha: 0.75,
                                              ),
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Plus ──
                                GestureDetector(
                                  onTap: () => setState(() => quantity++),
                                  child: Container(
                                    width: getProportionateScreenWidth(44),
                                    height: getProportionateScreenWidth(44),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          kSecondaryColor,
                                          kSecondaryColor.withValues(
                                            alpha: 0.85,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        getProportionateScreenWidth(
                                          kDefaultPadding,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kSecondaryColor.withValues(
                                            alpha: 0.28,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      HeroiconsOutline.plus,
                                      size: getProportionateScreenWidth(20),
                                      color: kWhiteColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Image section
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Item proof photo",
                                style: TextStyle(fontSize: kDefaultPadding),
                              ),
                              if (imageList.length < 2)
                                GestureDetector(
                                  onTap: getImage,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: getProportionateScreenWidth(
                                        12,
                                      ),
                                      vertical: getProportionateScreenHeight(8),
                                    ),
                                    decoration: BoxDecoration(
                                      color: kWhiteColor,
                                      borderRadius: BorderRadius.circular(
                                        getProportionateScreenWidth(10),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          HeroiconsOutline.plus,
                                          size: getProportionateScreenWidth(16),
                                          color: kSecondaryColor,
                                        ),
                                        SizedBox(
                                          width: getProportionateScreenWidth(6),
                                        ),
                                        Text(
                                          imageList.isEmpty
                                              ? "Add Image"
                                              : "Add More",
                                          style: TextStyle(
                                            color: kSecondaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize:
                                                getProportionateScreenHeight(
                                                  13,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Image Previews
                          if (imageList.isNotEmpty) ...[
                            SizedBox(
                              height: getProportionateScreenHeight(
                                kDefaultPadding * 1.2,
                              ),
                            ),
                            SizedBox(
                              height: getProportionateScreenHeight(110),
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: imageList.length,
                                separatorBuilder: (_, __) => SizedBox(
                                  width: getProportionateScreenWidth(12),
                                ),
                                itemBuilder: (context, index) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Image
                                      Container(
                                        width: getProportionateScreenWidth(100),
                                        height: getProportionateScreenHeight(
                                          110,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            getProportionateScreenWidth(14),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            getProportionateScreenWidth(14),
                                          ),
                                          child: Image.file(
                                            imageList[index],
                                            fit: BoxFit.cover,
                                            cacheWidth: 300,
                                            errorBuilder: (context, error, stackTrace) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    if (mounted) {
                                                      setState(() {
                                                        imageList.removeAt(
                                                          index,
                                                        );
                                                        if (index <
                                                            imagePath.length) {
                                                          imagePath.removeAt(
                                                            index,
                                                          );
                                                        }
                                                        canAddImage =
                                                            imageList.length <
                                                            2;
                                                      });
                                                      _showImageError(
                                                        'An image could not be loaded and was removed.',
                                                      );
                                                    }
                                                  });
                                              return Container(
                                                color: kGreyColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                                child: Icon(
                                                  HeroiconsOutline.photo,
                                                  color: kGreyColor,
                                                  size:
                                                      getProportionateScreenWidth(
                                                        28,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                      // Delete button
                                      Positioned(
                                        top: -6,
                                        right: -6,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              imageList.removeAt(index);
                                              if (index < imagePath.length) {
                                                imagePath.removeAt(index);
                                              }
                                              canAddImage =
                                                  imageList.length < 2;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: kPrimaryColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: kWhiteColor,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.15),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              HeroiconsOutline.xMark,
                                              size: getProportionateScreenWidth(
                                                14,
                                              ),
                                              color: kSecondaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Payment Method Section with Enhanced UI
                // Container(
                //   padding: EdgeInsets.all(
                //     getProportionateScreenWidth(kDefaultPadding),
                //   ),
                //   decoration: BoxDecoration(
                //     borderRadius: BorderRadius.circular(
                //       getProportionateScreenWidth(kDefaultPadding),
                //     ),
                //     border: Border.all(color: kWhiteColor, width: 1),
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     spacing: getProportionateScreenHeight(kDefaultPadding),
                //     children: [
                //       OrderStatusRow(
                //         value: "Payment Method",
                //         title: "Who will pay for this delivery?",
                //         icon: HeroiconsOutline.banknotes,
                //       ),
                //       Row(
                //         spacing: getProportionateScreenWidth(
                //           kDefaultPadding / 2,
                //         ),
                //         children: [
                //           Expanded(
                //             child: GestureDetector(
                //               onTap: () {
                //                 setState(() {
                //                   paidBySender = true;
                //                 });
                //               },
                //               child: AnimatedContainer(
                //                 duration: Duration(milliseconds: 200),
                //                 padding: EdgeInsets.all(
                //                   getProportionateScreenWidth(
                //                     kDefaultPadding * 0.8,
                //                   ),
                //                 ),
                //                 decoration: BoxDecoration(
                //                   color: kPrimaryColor,
                //                   // color: paidBySender ? null : kWhiteColor,
                //                   borderRadius: BorderRadius.circular(
                //                     getProportionateScreenWidth(
                //                       kDefaultPadding,
                //                     ),
                //                   ),
                //                   border: Border.all(
                //                     color: paidBySender
                //                         ? kSecondaryColor
                //                         : kGreyColor.withValues(alpha: 0.2),
                //                     width: paidBySender ? 2 : 1,
                //                   ),
                //                 ),
                //                 child: Column(
                //                   spacing: getProportionateScreenHeight(
                //                     kDefaultPadding / 3,
                //                   ),
                //                   children: [
                //                     Container(
                //                       padding: EdgeInsets.all(
                //                         getProportionateScreenWidth(
                //                           kDefaultPadding / 2,
                //                         ),
                //                       ),
                //                       decoration: BoxDecoration(
                //                         color: kWhiteColor,
                //                         shape: BoxShape.circle,
                //                       ),
                //                       child: Icon(
                //                         Icons.person_outline_rounded,
                //                         color: kBlackColor,
                //                         size: getProportionateScreenWidth(
                //                           kDefaultPadding * 1.2,
                //                         ),
                //                       ),
                //                     ),
                //                     Text(
                //                       "Sender",
                //                       style: TextStyle(
                //                         color: kBlackColor,
                //                         fontWeight: FontWeight.bold,
                //                         fontSize: getProportionateScreenHeight(
                //                           kDefaultPadding * 0.7,
                //                         ),
                //                       ),
                //                     ),
                //                   ],
                //                 ),
                //               ),
                //             ),
                //           ),
                //           Expanded(
                //             child: GestureDetector(
                //               onTap: () {
                //                 setState(() {
                //                   paidBySender = false;
                //                 });
                //               },
                //               child: AnimatedContainer(
                //                 duration: Duration(milliseconds: 200),
                //                 padding: EdgeInsets.all(
                //                   getProportionateScreenWidth(
                //                     kDefaultPadding * 0.8,
                //                   ),
                //                 ),
                //                 decoration: BoxDecoration(
                //                   color: kPrimaryColor,
                //                   borderRadius: BorderRadius.circular(
                //                     getProportionateScreenWidth(
                //                       kDefaultPadding,
                //                     ),
                //                   ),
                //                   border: Border.all(
                //                     color: !paidBySender
                //                         ? kSecondaryColor
                //                         : kGreyColor.withValues(alpha: 0.2),
                //                     width: !paidBySender ? 2 : 1,
                //                   ),
                //                 ),
                //                 child: Column(
                //                   spacing: getProportionateScreenHeight(
                //                     kDefaultPadding / 3,
                //                   ),
                //                   children: [
                //                     Container(
                //                       padding: EdgeInsets.all(
                //                         getProportionateScreenWidth(
                //                           kDefaultPadding / 2,
                //                         ),
                //                       ),
                //                       decoration: BoxDecoration(
                //                         color: kWhiteColor,
                //                         shape: BoxShape.circle,
                //                       ),
                //                       child: Icon(
                //                         Icons.person_pin_outlined,
                //                         color: kBlackColor,
                //                         size: getProportionateScreenWidth(
                //                           kDefaultPadding * 1.2,
                //                         ),
                //                       ),
                //                     ),
                //                     Text(
                //                       "Receiver",
                //                       style: TextStyle(
                //                         color: kBlackColor,
                //                         fontWeight: FontWeight.bold,
                //                         fontSize: getProportionateScreenHeight(
                //                           kDefaultPadding * 0.7,
                //                         ),
                //                       ),
                //                     ),
                //                   ],
                //                 ),
                //               ),
                //             ),
                //           ),
                //         ],
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<dynamic> getVehicleList() async {
    // debugPrint("getting vehicle list");
    setState(() {
      _loading = true;
    });
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/store/get_vehicle_list";

    Map data = {
      "store_id": "",
      "type": 7,
      "delivery_type": 2,
      "user_id": widget.userData['user']['_id'],
      "server_token": widget.userData['user']['server_token'],
      "city_id": Provider.of<ZMetaData>(context, listen: false).cityId,
    };

    // debugPrint(url);

    var body = json.encode(data);
    // debugPrint(body);
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
              setState(() {
                this._loading = false;
              });
              throw TimeoutException("The connection has timed out!");
            },
          );
      setState(() {
        this._loading = false;
      });

      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      setState(() {
        this._loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Something went wrong. Please check your internet connection!",
          ),
          backgroundColor: kSecondaryColor,
        ),
      );
      return null;
    }
  }

  Future<dynamic> getTotalDistance() async {
    // debugPrint("getting total distance");
    var url =
        "https://maps.googleapis.com/maps/api/distancematrix/json?origins=${widget.pickupAddress!.latitude.toStringAsFixed(6)},${widget.pickupAddress!.longitude.toStringAsFixed(6)}&destinations=${widget.destinationAddress!.latitude.toStringAsFixed(6)},${widget.destinationAddress!.longitude}&key=$apiKey";

    try {
      http.Response response = await http
          .get(Uri.parse(url))
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              setState(() {
                this._loading = false;
              });
              throw TimeoutException("The connection has timed out!");
            },
          );
      // debugPrint(json.decode(response.body));
      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      setState(() {
        this._loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Something went wrong! Please check your internet connectin",
          ),
          backgroundColor: kSecondaryColor,
        ),
      );
      return null;
    }
  }

  // Paths already uploaded: the endpoint appends, so never send one twice.
  final Set<String> _uploadedImages = {};

  /// POST /api/user/upload_courier_image, once per image, for the courier cart.
  /// Returns false if the user must fix something and retry.
  Future<bool> _uploadCourierImages() async {
    if (imagePath.isEmpty) return true;
    final batch = await ImageUploadService.validateBatch(imagePath);
    if (batch.hasIssues && batch.allFailed) {
      _showImageError(
        "Image issue: ${batch.summary}. Please select your images again.",
      );
      return false;
    }
    final courier = await Service.read('courier');
    final cartId = courier?['cart_id'];
    if (cartId == null) return true;
    final url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/upload_courier_image";
    for (final path in batch.validPaths) {
      if (_uploadedImages.contains(path)) continue;
      try {
        final request = http.MultipartRequest("POST", Uri.parse(url))
          ..fields['user_id'] = widget.userData['user']['_id']
          ..fields['server_token'] = widget.userData['user']['server_token']
          ..fields['cart_id'] = cartId.toString();
        request.files.add(await http.MultipartFile.fromPath('file', path));
        final res = await http.Response.fromStream(
          await request.send().timeout(Duration(seconds: 30)),
        );
        final body = json.decode(res.body);
        if (body['success'] == true) {
          _uploadedImages.add(path);
        } else {
          _showImageError(
            body['message']?.toString() ?? "Could not upload your image.",
          );
          return false;
        }
      } catch (e) {
        _showImageError("Could not upload your image. Check your connection.");
        return false;
      }
    }
    return true;
  }

  Future<dynamic> getCourierInvoice() async {
    // debugPrint("getting courier invoice");
    // Schedule values are saved by the courier screen before this step.
    // CourierScreen stores 'is_schedule' with Service.save (a JSON string),
    // so Service.readBool would throw here and leave the screen loading.
    bool isSchedule = false;
    dynamic scheduleStart;
    try {
      isSchedule = (await Service.read('is_schedule')) == true;
      scheduleStart = await Service.read('schedule_start');
    } catch (_) {
      isSchedule = false;
      scheduleStart = null;
    }
    var url =
        "${Provider.of<ZMetaData>(context, listen: false).baseUrl}/api/user/get_courier_order_invoice";

    Map data = {
      "user_id": widget.userData['user']['_id'],
      "total_time": time,
      "total_distance": distance,
      "is_user_pickup_order": false,
      "total_item_count": quantity,
      "is_user_drop_order": true,
      "server_token": widget.userData['user']['server_token'],
      "vehicle_id": vehicleList['vehicles'][selected]['_id'],
      "city_id": Provider.of<ZMetaData>(context, listen: false).cityId,
      "country_id": widget.userData['user']['country_id'],
      "is_round_trip": isRoundTrip,
      // Order intent: saved by the backend with this order_payment and
      // used to create the order itself once payment is confirmed.
      "order_type": 7,
      "delivery_type": 2,
      "paid_by": paidBySender ? 1 : 2,
      "is_schedule_order": isSchedule,
      "schedule_order_start_at": isSchedule && scheduleStart != null
          ? scheduleStart.toString()
          : "",
      "flow": "single",
    };
    var body = json.encode(data);
    // debugPrint(body);
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
              setState(() {
                this._loading = false;
              });
              throw TimeoutException("The connection has timed out!");
            },
          );
      setState(() {
        this._loading = false;
      });

      return json.decode(response.body);
    } catch (e) {
      // debugPrint(e);
      setState(() {
        this._loading = false;
      });

      Service.showMessage(
        context: context,
        title: "Please check your internet connection",
        error: true,
      );
      return null;
    }
  }

  // Widget _buildQuickQuantityButton(int value) {
  //   return GestureDetector(
  //     onTap: () {
  //       setState(() {
  //         quantity = value;
  //       });
  //     },
  //     child: Container(
  //       padding: EdgeInsets.symmetric(
  //         horizontal: getProportionateScreenWidth(kDefaultPadding * 0.6),
  //         vertical: getProportionateScreenHeight(kDefaultPadding * 0.3),
  //       ),
  //       decoration: BoxDecoration(
  //         color: quantity == value
  //             ? kSecondaryColor.withValues(alpha: 0.1)
  //             : kWhiteColor,
  //         borderRadius: BorderRadius.circular(
  //           getProportionateScreenWidth(kDefaultPadding / 2),
  //         ),
  //         border: Border.all(
  //           color: quantity == value
  //               ? kSecondaryColor
  //               : kGreyColor.withValues(alpha: 0.2),
  //           width: quantity == value ? 1.5 : 1,
  //         ),
  //       ),
  //       child: Text(
  //         "$value",
  //         style: TextStyle(
  //           fontSize: getProportionateScreenHeight(kDefaultPadding * 0.65),
  //           fontWeight: quantity == value ? FontWeight.bold : FontWeight.normal,
  //           color: quantity == value ? kSecondaryColor : kGreyColor,
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
