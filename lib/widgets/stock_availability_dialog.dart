import 'package:flutter/material.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/services/zmall_availability_service.dart';
import 'package:zmall/utils/constants.dart';

class StockItemIssue {
  const StockItemIssue({
    required this.item,
    required this.requestedQty,
    required this.availableQty,
    required this.isCompletelyOutOfStock,
    this.errorMessage,
  });

  final Item item;
  final int requestedQty;
  final int availableQty;
  final bool isCompletelyOutOfStock;
  final String? errorMessage;
}

class StockAvailabilityDialog extends StatelessWidget {
  const StockAvailabilityDialog({
    super.key,
    required this.issues,
    this.branchName,
    this.onAdjustAll,
    this.onAdjustItem,
    this.onReviewCart,
  });

  final List<StockItemIssue> issues;
  final String? branchName;
  final VoidCallback? onAdjustAll;
  final void Function(Item item, int maxAvailable)? onAdjustItem;
  final VoidCallback? onReviewCart;

  static Future<void> show({
    required BuildContext context,
    required List<Item> cartItems,
    required ZmallAvailabilityResult availabilityResult,
    VoidCallback? onAdjustAll,
    void Function(Item item, int maxAvailable)? onAdjustItem,
    VoidCallback? onReviewCart,
  }) async {
    final List<StockItemIssue> issues = [];

    for (final item in cartItems) {
      final int? odooId = item.odooProductId;
      if (odooId == null) continue;

      for (final p in availabilityResult.products) {
        if (p.productId == odooId && !p.isAvailableForRequestedQuantity) {
          final int requested = item.quantity ?? p.quantity;
          final double forecasted = p.forecastedQuantity ?? 0;
          final int available = forecasted > 0 ? forecasted.toInt() : 0;
          issues.add(
            StockItemIssue(
              item: item,
              requestedQty: requested,
              availableQty: available,
              isCompletelyOutOfStock: available <= 0,
              errorMessage: p.error,
            ),
          );
          break;
        }
      }
    }

    if (issues.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StockAvailabilityDialog(
        issues: issues,
        branchName: availabilityResult.branch,
        onAdjustAll: onAdjustAll,
        onAdjustItem: onAdjustItem,
        onReviewCart: onReviewCart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canAutoAdjustAny = issues.any((i) => !i.isCompletelyOutOfStock);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kGreyColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFFE65100),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title
                  const Text(
                    "Item Stock Notice",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    branchName != null && branchName!.isNotEmpty
                        ? "Some items in your cart exceed available stock at the ${branchName!.toUpperCase()} branch."
                        : "Some items in your cart exceed available stock in store.",
                    style: TextStyle(
                      fontSize: 13,
                      color: kGreyColor.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Items List
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: issues.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final issue = issues[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: issue.isCompletelyOutOfStock
                                    ? const Color(0xFFFFCDD2)
                                    : const Color(0xFFFFE0B2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Item Icon / Status Badge
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: issue.isCompletelyOutOfStock
                                        ? const Color(0xFFFFEBEE)
                                        : const Color(0xFFFFF8E1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    issue.isCompletelyOutOfStock
                                        ? Icons.remove_shopping_cart_outlined
                                        : Icons.production_quantity_limits_rounded,
                                    color: issue.isCompletelyOutOfStock
                                        ? Colors.red[700]
                                        : Colors.orange[800],
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Name & Stock Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        issue.item.itemName ?? "Item",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: kBlackColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            "Requested: ${issue.requestedQty}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red[800],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: issue.isCompletelyOutOfStock
                                                  ? Colors.red[50]
                                                  : Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              issue.isCompletelyOutOfStock
                                                  ? "Out of stock"
                                                  : "In stock: ${issue.availableQty}",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: issue
                                                        .isCompletelyOutOfStock
                                                    ? Colors.red[800]
                                                    : Colors.green[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Individual Adjust Button
                                if (!issue.isCompletelyOutOfStock &&
                                    onAdjustItem != null)
                                  GestureDetector(
                                    onTap: () {
                                      onAdjustItem!(
                                        issue.item,
                                        issue.availableQty,
                                      );
                                      Navigator.of(context).pop();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kSecondaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Set to ${issue.availableQty}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons
                  Row(
                    children: [
                      // Secondary button (Review/Close)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onReviewCart?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kBlackColor,
                            side: BorderSide(
                              color: kGreyColor.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Review Cart",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Primary button (Adjust all)
                      if (canAutoAdjustAny && onAdjustAll != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              onAdjustAll!();
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSecondaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Adjust All",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
