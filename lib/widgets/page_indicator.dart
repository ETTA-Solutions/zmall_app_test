import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';

class PageIndicator extends StatelessWidget {
  final int currentPage; // 1-based
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int maxVisiblePages; // how many page numbers to show at once
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final EdgeInsetsGeometry padding;

  PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.maxVisiblePages = 5,
    Color? activeColor,
    this.inactiveColor = Colors.grey,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  }) : activeColor = activeColor ?? kSecondaryColor;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous button
            _NavButton(
              icon: Icons.chevron_left,
              enabled: currentPage > 1,
              onTap: () => onPageChanged(currentPage - 1),
            ),

            const SizedBox(width: 8),

            // Page numbers
            ..._buildPageNumbers(),

            const SizedBox(width: 8),

            // Next button
            _NavButton(
              icon: Icons.chevron_right,
              enabled: currentPage < totalPages,
              onTap: () => onPageChanged(currentPage + 1),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final List<Widget> pages = [];

    int start = (currentPage - (maxVisiblePages ~/ 2)).clamp(1, totalPages);
    int end = (start + maxVisiblePages - 1).clamp(1, totalPages);

    // Adjust start if we hit the end
    if (end - start + 1 < maxVisiblePages) {
      start = (end - maxVisiblePages + 1).clamp(1, totalPages);
    }

    // First page + ellipsis
    if (start > 1) {
      pages.add(
        _PageButton(
          page: 1,
          isActive: currentPage == 1,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          onTap: () => onPageChanged(1),
        ),
      );
      if (start > 2) {
        pages.add(_Ellipsis());
      }
    }

    // Middle pages
    for (int i = start; i <= end; i++) {
      pages.add(
        _PageButton(
          page: i,
          isActive: currentPage == i,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          onTap: () => onPageChanged(i),
        ),
      );
    }

    // Last page + ellipsis
    if (end < totalPages) {
      if (end < totalPages - 1) {
        pages.add(_Ellipsis());
      }
      pages.add(
        _PageButton(
          page: totalPages,
          isActive: currentPage == totalPages,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          onTap: () => onPageChanged(totalPages),
        ),
      );
    }

    return pages;
  }
}

// ---------- Helper widgets ----------

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: enabled ? onTap : null,
      color: enabled ? Colors.black87 : Colors.grey.shade400,
    );
  }
}

class _PageButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _PageButton({
    required this.page,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isActive ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isActive ? null : onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Text(
              '$page',
              style: TextStyle(
                color: isActive ? Colors.white : inactiveColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ellipsis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text('…', style: TextStyle(fontSize: 16, color: Colors.grey)),
    );
  }
}
