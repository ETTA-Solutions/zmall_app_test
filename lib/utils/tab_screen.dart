import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:zmall/home/home_screen.dart';
import 'package:zmall/models/language.dart';
import 'package:zmall/orders/orders_screen.dart';
import 'package:zmall/profile/profile_screen.dart';
import 'constants.dart';

class TabScreen extends StatefulWidget {
  static String routeName = '/start';
  const TabScreen({this.isLaunched = false});

  final bool isLaunched;

  @override
  _TabScreenState createState() => _TabScreenState();
}

class _TabScreenState extends State<TabScreen> {
  int _selectedIndex = 0;

  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _initializeScreensAndNav();
  }

  void _initializeScreensAndNav() {
    _screens = [
      HomeScreen(isLaunched: widget.isLaunched),
      OrdersScreen(),
      ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<BottomNavigationBarItem> navItems = [
      BottomNavigationBarItem(
        icon: Icon(HeroiconsOutline.home),
        activeIcon: Icon(HeroiconsMini.home),
        label: Provider.of<ZLanguage>(context).home,
      ),
      BottomNavigationBarItem(
        icon: Icon(HeroiconsOutline.listBullet),
        activeIcon: Icon(Icons.view_list),
        label: Provider.of<ZLanguage>(context).orders,
      ),
      BottomNavigationBarItem(
        icon: Icon(HeroiconsOutline.user),
        activeIcon: Icon(HeroiconsMini.user),
        label: Provider.of<ZLanguage>(context).profile,
      ),
    ];

    return Scaffold(
      backgroundColor: kWhiteColor,
      body: _screens.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        elevation: 0,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: kSecondaryColor,
        unselectedItemColor: kGreyColor,
        selectedLabelStyle: Theme.of(context).textTheme.bodySmall,
        unselectedLabelStyle: Theme.of(context).textTheme.bodySmall,
        backgroundColor: kWhiteColor.withValues(alpha: 0.8),
        items: navItems,
      ),
    );
  }
}