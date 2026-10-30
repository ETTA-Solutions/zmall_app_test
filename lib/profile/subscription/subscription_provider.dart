import 'package:flutter/material.dart';

class SubscriptionProvider with ChangeNotifier {
  bool _isSubscribed = false;

  bool get isSubscribed => _isSubscribed;

  void setSubscriptionStatus(bool status) {
    _isSubscribed = status;
    notifyListeners();
  }
}
// subscription_provider.dart

class SubscriptionProvider2 with ChangeNotifier {
  bool _isSubscribed = false;
  String? _plan;
  int? _currentPeriodEnd;

  bool get isSubscribed => _isSubscribed;
  String? get plan => _plan;
  int? get currentPeriodEnd => _currentPeriodEnd;

  void setSubscriptionStatus(bool status,
      {String? plan, int? currentPeriodEnd}) {
    _isSubscribed = status;
    _plan = plan;
    _currentPeriodEnd = currentPeriodEnd;
    notifyListeners();
  }
}
