import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:provider/provider.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/utils/backend_logger.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/store/components/custom_list_tile.dart';
import 'package:zmall/product/product_screen.dart';
import 'package:zmall/store/store_screen.dart';
import 'package:zmall/utils/size_config.dart';
import 'package:zmall/widgets/linear_loading_indicator.dart';
import 'package:zmall/widgets/shimmer_widget.dart';

class MisakaStoreListScreen extends StatefulWidget {
  const MisakaStoreListScreen({
    super.key,
    required this.curLat,
    required this.curLon,
    this.service,
    this.storeDeliveryId,
    this.companyId,
  });

  final double curLon;
  final double curLat;
  final dynamic service;
  final String? storeDeliveryId;
  final String? companyId;

  @override
  _MisakaStoreListScreenState createState() => _MisakaStoreListScreenState();
}

class _MisakaStoreListScreenState extends State<MisakaStoreListScreen> {
  bool _loading = true;
  var responseData;
  List<dynamic> stores = [];
  List<bool> isOpen = [];

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    setState(() {
      _loading = true;
    });

    final baseUrl = Provider.of<ZMetaData>(context, listen: false).baseUrl;
    final metaCityId = Provider.of<ZMetaData>(context, listen: false).cityId;
    final cityId = metaCityId.isNotEmpty ? metaCityId : kMisakaCityId;
    final storeDeliveryId = kMisakaStoreDeliveryId;
    final latitude = (widget.curLat != 0.0)
        ? widget.curLat
        : kMisakaDefaultLatitude;
    final longitude = (widget.curLon != 0.0)
        ? widget.curLon
        : kMisakaDefaultLongitude;

    //debugPrint('=== MISAKA STORE FETCH ===');
    //debugPrint('Service: ${widget.service?['delivery_name']}');
    //debugPrint('cityId: $cityId (meta: $metaCityId)');
    //debugPrint('storeDeliveryId: $storeDeliveryId');
    //debugPrint('latitude: $latitude');
    //debugPrint('longitude: $longitude');
    //debugPrint('API: get_misaka_list');

    final Map<String, dynamic> data = {
      "city_id": cityId,
      "store_delivery_id": storeDeliveryId,
      "latitude": latitude,
      "longitude": longitude,
    };

    try {
      var decoded = await _postStoreList(
        "$baseUrl/api/user/get_misaka_list",
        data,
      );

      //debugPrint('=== MISAKA RESPONSE ===');
      //debugPrint('Success: ${decoded?['success']}');
      //debugPrint('Message: ${decoded?['message']}');
      //debugPrint('Error Code: ${decoded?['error_code']}');
      //debugPrint('Stores count: ${(decoded?['stores'] as List?)?.length ?? 0}');

      responseData = decoded;

      if (decoded != null && decoded['success'] == true) {
        if (mounted) {
          List<dynamic> newStores = [];
          final rawStores = decoded['stores'];

          //debugPrint('[MISAKA] rawStores type: ${rawStores.runtimeType}');
          //debugPrint( '[MISAKA] rawStores count: ${rawStores is List ? rawStores.length : 'N/A'}', );

          if (rawStores is List) {
            newStores = List<dynamic>.from(rawStores);
          } else if (rawStores is Map) {
            newStores = rawStores.values.toList();
          } else if (rawStores == null) {
            newStores = [];
          } else {
            try {
              newStores = List<dynamic>.from(rawStores);
            } catch (e) {
              //debugPrint('[MISAKA] Error converting stores: $e');
              newStores = [];
            }
          }

          //debugPrint('[MISAKA] Final newStores count: ${newStores.length}');

          setState(() {
            stores = newStores;
          });
          isOpen = await Service.storeOpen(stores);
          if (mounted) setState(() {});
        }
      } else {
        if (mounted) {
          final code = responseData?['error_code']?.toString() ?? '';
          final mapped = (code.isNotEmpty && errorCodes.containsKey(code))
              ? errorCodes[code]
              : responseData?['message'] ?? 'Failed to load stores';
          Service.showMessage(context: context, title: mapped, error: true);
        }
      }
    } catch (e) {
      BackendLogger.error(
        method: 'POST',
        url: "$baseUrl/api/user/get_misaka_list",
        error: e,
      );
      if (mounted) {
        Service.showMessage(
          context: context,
          title: "Something went wrong! Please check your internet connection!",
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _postStoreList(
    String url,
    Map<String, dynamic> data,
  ) async {
    final body = json.encode(data);

    //debugPrint('[MISAKA POST] URL: $url');
    //debugPrint('[MISAKA POST] Body: $body');

    BackendLogger.request(
      method: 'POST',
      url: url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: body,
    );

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      //debugPrint('[MISAKA RESPONSE] Status: ${response.statusCode}');
      //debugPrint('[MISAKA RESPONSE] Body: ${response.body}');

      BackendLogger.response(
        method: 'POST',
        url: url,
        statusCode: response.statusCode,
        body: response.body,
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return json.decode(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      //debugPrint('[MISAKA ERROR] Exception: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = 'LUNCH "ምሳቃ" BOX';
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: kBlackColor)),
        backgroundColor: kPrimaryColor,
        elevation: 1,
      ),
      backgroundColor: kPrimaryColor,
      body: SafeArea(
        child: ModalProgressHUD(
          inAsyncCall: _loading,
          color: kPrimaryColor,
          progressIndicator: SingleChildScrollView(
            child: Container(
              height: screenHeight * 0.7,
              child: ProductListShimmer(),
              padding: const EdgeInsets.only(top: kDefaultPadding),
            ),
          ),
          //  LinearLoadingIndicator(),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: stores.isNotEmpty
                ? ListView.separated(
                    itemCount: stores.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      final open = isOpen.length > index
                          ? isOpen[index]
                          : false;
                      return CustomListTile(
                        store: store,
                        isOpen: open,
                        press: () {
                          final metadata = Provider.of<ZMetaData>(
                            context,
                            listen: false,
                          );
                          try {
                            if ((store['store_count'] ?? 1) > 1) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StoreScreen(
                                    cityId: metadata.cityId,
                                    storeDeliveryId:
                                        widget.storeDeliveryId ??
                                        widget.service?['_id'],
                                    category:
                                        widget.service ??
                                        {'delivery_name': store['name'] ?? ''},
                                    latitude: widget.curLat,
                                    longitude: widget.curLon,
                                    isStore: true,
                                    companyId: store['company_id'],
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductScreen(
                                    store: store,
                                    location: store['location'],
                                    isOpen: open,
                                    latitude: widget.curLat,
                                    longitude: widget.curLon,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductScreen(
                                  store: store,
                                  location: store['location'],
                                  isOpen: open,
                                  latitude: widget.curLat,
                                  longitude: widget.curLon,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  )
                : Center(
                    child: Text(
                      responseData != null && responseData['message'] != null
                          ? responseData['message'].toString()
                          : 'No stores found',
                      style: TextStyle(color: kBlackColor),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
