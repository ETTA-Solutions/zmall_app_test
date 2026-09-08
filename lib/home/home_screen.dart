import 'package:flutter/material.dart';
import 'package:zmall/help/support_chat/components/floating_chat_button.dart';
import 'package:zmall/help/support_chat/support_chat_screen.dart';
import 'package:zmall/models/cart.dart';
import 'package:zmall/services/service.dart';
import 'components/home_body.dart';

class HomeScreen extends StatefulWidget {
  static String routeName = "/home";

  const HomeScreen({this.isLaunched = false});

  final bool isLaunched;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Cart? cart;

  void getCart() async {
    // debugPrint("Fetching data");
    var data = await Service.read('cart');
    if (data != null) {
      setState(() {
        cart = Cart.fromJson(data);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getCart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeBody(isLaunched: widget.isLaunched),
      floatingActionButton: FloatingChatButton(
        onTap: () {
          Navigator.pushNamed(context, SupportChatScreen.routeName);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
