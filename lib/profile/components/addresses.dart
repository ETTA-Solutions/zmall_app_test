import 'package:fl_location/fl_location.dart';
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/location/location_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class MyAddresseScreen extends StatefulWidget {
  const MyAddresseScreen({super.key, required this.userData});
  final dynamic userData;

  @override
  State<MyAddresseScreen> createState() => _MyAddresseScreenState();
}

class _MyAddresseScreenState extends State<MyAddresseScreen> {
  LocationPermission _permissionStatus = LocationPermission.denied;
  DeliveryLocation? deliveryLocation;
  double? latitude, longitude;
  late dynamic userData;
  Cart? cart;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    getCart();
    _doLocationTask();
    getLocations();
  }

  Future<void> getCart() async {
    if (!mounted) return;
    var data = await Service.read('cart');
    if (!mounted) return;
    if (data != null) {
      setState(() => cart = Cart.fromJson(data));
    }
  }

  void addLocation() async {
    _doLocationTask();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationScreen(
          currLat: Provider.of<ZMetaData>(context, listen: false).latitude,
          currLon: Provider.of<ZMetaData>(context, listen: false).longitude,
        ),
      ),
    ).then((_) => getLocations(returned: true));
  }

  // ---------- Address helpers ----------
  String _getPrimaryAddress(String? full) {
    if (full == null || full.trim().isEmpty) return 'Unknown location';

    // Remove leading Plus Code (e.g. "2QFW+R9F, ")
    String cleaned = full.replaceFirst(
      RegExp(r'^[A-Z0-9+]+\+?[A-Z0-9]*,\s*'),
      '',
    );

    final parts = cleaned
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return full;

    // Prefer street + neighborhood if available
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return parts.first;
  }

  String _getSecondaryAddress(String? full) {
    if (full == null || full.trim().isEmpty) return '';

    String cleaned = full.replaceFirst(
      RegExp(r'^[A-Z0-9+]+\+?[A-Z0-9]*,\s*'),
      '',
    );

    final parts = cleaned
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length <= 2) return '';
    // City + Country
    return parts.sublist(2).join(', ');
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final hasAddresses =
        deliveryLocation != null &&
        (deliveryLocation!.list?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("My Addresses"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: kBlackColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addLocation,
        backgroundColor: kSecondaryColor,
        foregroundColor: kWhiteColor,
        icon: const Icon(HeroiconsOutline.plus),
        label: const Text("Add Address"),
      ),
      body: SafeArea(
        child: hasAddresses
            ? Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        getProportionateScreenWidth(kDefaultPadding),
                        getProportionateScreenHeight(kDefaultPadding / 1.5),
                        getProportionateScreenWidth(kDefaultPadding),
                        getProportionateScreenHeight(100), // space for FAB
                      ),
                      itemCount: deliveryLocation!.list!.length,
                      separatorBuilder: (_, __) => SizedBox(
                        height: getProportionateScreenHeight(
                          kDefaultPadding / 1.5,
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final item = deliveryLocation!.list![index];
                        final primary = _getPrimaryAddress(item.name);
                        final secondary = _getSecondaryAddress(item.name);
                        final note = (item.note ?? '').trim().isEmpty
                            ? 'Address'
                            : item.note!.trim();
                        final icon = _getAddressIcon(note);
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
                              HeroiconsOutline.trash,
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

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$removedName removed'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            return true; // allow the dismiss animation
                          },

                          child: _AddressCard(
                            primary: primary,
                            secondary: secondary,
                            note: note,
                            icon: icon,
                            onTap: () {
                              // optional: handle address selection or editing here
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  // Hint text at the bottom
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_left_alt_rounded,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Swipe left to delete an address",
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(12.5),
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : _EmptyState(onAdd: addLocation),
      ),
    );
  }

  // ---------- Location helpers (kept from original) ----------
  void getLocations({bool returned = false}) async {
    var data = await Service.read('delivery');
    if (!mounted) return;
    if (data != null) {
      setState(() {
        deliveryLocation = DeliveryLocation.fromJson(data);
      });
    }
  }

  void getLocation() async {
    var currentLocation = await FlLocation.getLocation();
    if (mounted) {
      setState(() {
        latitude = currentLocation.latitude;
        longitude = currentLocation.longitude;
        cart?.destinationAddress?.lat = latitude;
        cart?.destinationAddress?.long = longitude;
      });
      Provider.of<ZMetaData>(
        context,
        listen: false,
      ).setLocation(currentLocation.latitude, currentLocation.longitude);
    }
  }

  void _doLocationTask() async {
    LocationPermission status = await FlLocation.checkLocationPermission();
    if (status == LocationPermission.whileInUse ||
        status == LocationPermission.always) {
      if (await FlLocation.isLocationServicesEnabled) {
        getLocation();
      } else {
        final serviceStatus = await FlLocation.requestLocationPermission();
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

  void _requestLocationPermission() async {
    bool isLocationServicesEnabled = await FlLocation.isLocationServicesEnabled;

    if (isLocationServicesEnabled) {
      _permissionStatus = await FlLocation.checkLocationPermission();
      if (_permissionStatus == LocationPermission.always ||
          _permissionStatus == LocationPermission.whileInUse) {
        getLocation();
      } else {
        Service.showMessage(
          context: context,
          title: "Location permission denied. Please enable and try again",
          error: true,
        );
        FlLocation.requestLocationPermission();
      }
    } else {
      Service.showMessage(
        context: context,
        title:
            "Location services are turned off. Please enable them in your device settings.",
        error: true,
      );
    }
  }

  // Get the appropriate icon based on the address note
  IconData _getAddressIcon(String note) {
    final n = note.toLowerCase().trim();

    if (n.contains('home') || n.contains('house') || n.contains('apartment')) {
      return HeroiconsOutline.home;
    }
    if (n.contains('office') || n.contains('work') || n.contains('company')) {
      return HeroiconsOutline.briefcase;
    }
    if (n.contains('school') ||
        n.contains('university') ||
        n.contains('college')) {
      return HeroiconsOutline.academicCap;
    }
    if (n.contains('gym') || n.contains('fitness')) {
      return HeroiconsOutline.heart;
    }
    if (n.contains('hotel') || n.contains('stay')) {
      return HeroiconsOutline.buildingLibrary;
    }
    if (n.contains('shop') || n.contains('store') || n.contains('market')) {
      return HeroiconsOutline.shoppingBag;
    }
    if (n.contains('hospital') ||
        n.contains('clinic') ||
        n.contains('doctor')) {
      return HeroiconsOutline.heart;
    }
    if (n.contains('friend') || n.contains('family')) {
      return HeroiconsOutline.userGroup;
    }

    // Default
    return HeroiconsOutline.mapPin;
  }
}

// ===================== Widgets =====================

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.primary,
    required this.secondary,
    required this.note,
    required this.onTap,
    required this.icon,
  });

  final String primary;
  final String secondary;
  final String note;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPrimaryColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(getProportionateScreenWidth(16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kWhiteColor),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withValues(alpha: 0.04),
            //     blurRadius: 10,
            //     offset: const Offset(0, 4),
            //   ),
            // ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kWhiteColor,
                  // kSecondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kBlackColor, size: 22),
              ),
              SizedBox(width: getProportionateScreenWidth(14)),

              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Note chip + primary
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kWhiteColor,
                            // kSecondaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: getProportionateScreenWidth(10),
                              fontWeight: FontWeight.w600,
                              color: kSecondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: getProportionateScreenHeight(8)),
                    Text(
                      primary,
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(14.5),
                        fontWeight: FontWeight.w600,
                        color: kBlackColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondary.isNotEmpty) ...[
                      SizedBox(height: getProportionateScreenHeight(4)),
                      Text(
                        secondary,
                        style: TextStyle(
                          fontSize: getProportionateScreenWidth(13),
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: getProportionateScreenWidth(kDefaultPadding * 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: getProportionateScreenWidth(80),
              height: getProportionateScreenWidth(80),
              decoration: BoxDecoration(
                color: kWhiteColor,
              borderRadius: BorderRadius.circular(kDefaultPadding*2),
              ),
              child: Icon(
                HeroiconsOutline.mapPin,
                size: 42,
                color: kBlackColor,
              ),
            ),
            SizedBox(height: getProportionateScreenHeight(24)),
            Text(
              "No addresses yet",
              style: TextStyle(
                fontSize: getProportionateScreenWidth(18),
                fontWeight: FontWeight.w700,
                color: kBlackColor,
              ),
            ),
            SizedBox(height: getProportionateScreenHeight(8)),
            Text(
              "Add your home, office or any delivery location so we can deliver faster.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getProportionateScreenWidth(14),
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            // SizedBox(height: getProportionateScreenHeight(28)),
            // ElevatedButton.icon(
            //   onPressed: onAdd,
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: kSecondaryColor,
            //     foregroundColor: Colors.white,
            //     padding: EdgeInsets.symmetric(
            //       horizontal: getProportionateScreenWidth(24),
            //       vertical: getProportionateScreenHeight(14),
            //     ),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     elevation: 0,
            //   ),
            //   icon: const Icon(HeroiconsOutline.plus, size: 20),
            //   label: const Text(
            //     "Add Address",
            //     style: TextStyle(fontWeight: FontWeight.w600),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
