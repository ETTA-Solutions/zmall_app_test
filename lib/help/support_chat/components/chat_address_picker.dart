import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/help/support_chat/components/zmall_ui.dart';
import 'package:zmall/help/support_chat/service/chat_basket.dart';
import 'package:zmall/location/location_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/models/metadata.dart';
import 'package:zmall/services/service.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

/// Bottom sheet listing the user's saved addresses (the same list the
/// delivery screen uses) plus "Add new address". Returns the chosen address,
/// already saved as the chat delivery address.
class ChatAddressPicker {
  static Future<DestinationAddress?> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<DestinationAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _ChatAddressSheet(),
    );
  }
}

class _ChatAddressSheet extends StatefulWidget {
  const _ChatAddressSheet();

  @override
  State<_ChatAddressSheet> createState() => _ChatAddressSheetState();
}

class _ChatAddressSheetState extends State<_ChatAddressSheet> {
  List<DestinationAddress> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<DestinationAddress> list = [];
    try {
      final data = await Service.read('delivery');
      if (data != null) {
        list =
            DeliveryLocation.fromJson(Map<String, dynamic>.from(data)).list ??
            [];
      }
    } catch (e) {
      debugPrint("⚠️ [CHAT ADDRESS] Couldn't read saved addresses: $e");
    }
    if (mounted) {
      setState(() {
        _addresses = list
            .where((a) => (a.name ?? '').trim().isNotEmpty)
            .toList();
        _loading = false;
      });
    }
  }

  Future<void> _select(DestinationAddress address) async {
    HapticFeedback.selectionClick();
    await saveChatDeliveryAddress(address);
    if (mounted) Navigator.pop(context, address);
  }

  Future<void> _addNew() async {
    final meta = Provider.of<ZMetaData>(context, listen: false);
    final before = _addresses.length;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LocationScreen(currLat: meta.latitude, currLon: meta.longitude),
      ),
    );
    await _load();
    // A new address was added → use it straight away.
    if (mounted && _addresses.length > before) {
      await _select(_addresses.last);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = chatDeliveryAddress.value;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        getProportionateScreenWidth(16),
        getProportionateScreenHeight(10),
        getProportionateScreenWidth(16),
        getProportionateScreenHeight(16) + bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: getProportionateScreenWidth(38),
              height: 4,
              decoration: BoxDecoration(
                color: kZBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(14)),
          Text(
            'Deliver to',
            style: TextStyle(
              fontSize: getProportionateScreenWidth(18),
              fontWeight: FontWeight.w800,
              color: kZInk,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(4)),
          Text(
            'Choose where your order should go.',
            style: TextStyle(
              fontSize: getProportionateScreenWidth(12.5),
              color: kZMuted,
            ),
          ),
          SizedBox(height: getProportionateScreenHeight(14)),
          if (_loading)
            Padding(
              padding: EdgeInsets.all(getProportionateScreenWidth(24)),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kSecondaryColor,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _addresses.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: getProportionateScreenHeight(8)),
                itemBuilder: (context, i) {
                  final a = _addresses[i];
                  final isSelected =
                      selected != null &&
                      selected.name == a.name &&
                      selected.lat == a.lat &&
                      selected.long == a.long;
                  return ZPressable(
                    onTap: () => _select(a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.all(getProportionateScreenWidth(14)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kSecondaryColor.withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? kSecondaryColor : kZBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            HeroiconsSolid.mapPin,
                            size: getProportionateScreenWidth(18),
                            color: isSelected ? kSecondaryColor : kZMuted,
                          ),
                          SizedBox(width: getProportionateScreenWidth(12)),
                          Expanded(
                            child: Text(
                              a.name!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: getProportionateScreenWidth(14),
                                fontWeight: FontWeight.w600,
                                color: kZInk,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              HeroiconsSolid.checkCircle,
                              size: getProportionateScreenWidth(20),
                              color: kSecondaryColor,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: getProportionateScreenHeight(12)),
          ZOutlineButton(label: '＋  Add new address', onPressed: _addNew),
        ],
      ),
    );
  }
}

/// Tappable delivery address — shows the chosen address with "Change ▾", or
/// a "Choose delivery address" prompt when none is set.
class ChatAddressField extends StatefulWidget {
  /// Pill style (store list) vs boxed input style (basket).
  final bool pill;

  const ChatAddressField({super.key, this.pill = false});

  @override
  State<ChatAddressField> createState() => _ChatAddressFieldState();
}

class _ChatAddressFieldState extends State<ChatAddressField> {
  @override
  void initState() {
    super.initState();
    loadChatDeliveryAddress();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DestinationAddress?>(
      valueListenable: chatDeliveryAddress,
      builder: (context, address, _) {
        final name = address?.name?.trim() ?? '';
        final hasAddress = name.isNotEmpty;

        return ZPressable(
          onTap: () => ChatAddressPicker.show(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: getProportionateScreenWidth(12),
              vertical: getProportionateScreenHeight(widget.pill ? 9 : 12),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.pill ? 24 : 6),
              border: Border.all(
                color: hasAddress
                    ? (widget.pill ? kZBorder : const Color(0xFFD1D5DB))
                    : kSecondaryColor.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  HeroiconsSolid.mapPin,
                  size: getProportionateScreenWidth(14),
                  color: kSecondaryColor,
                ),
                SizedBox(width: getProportionateScreenWidth(6)),
                if (widget.pill && hasAddress)
                  Text(
                    'Delivering to: ',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(12),
                      color: kZMuted,
                    ),
                  ),
                Expanded(
                  child: Text(
                    hasAddress ? name : 'Choose delivery address',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(
                        widget.pill ? 12.5 : 14,
                      ),
                      fontWeight: widget.pill || !hasAddress
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: hasAddress ? kZInk : kSecondaryColor,
                    ),
                  ),
                ),
                SizedBox(width: getProportionateScreenWidth(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(9),
                    vertical: getProportionateScreenHeight(3),
                  ),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: kSecondaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    hasAddress ? 'Change ▾' : 'Select ▾',
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(11.5),
                      fontWeight: FontWeight.w700,
                      color: kSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
