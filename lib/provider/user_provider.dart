import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/User.dart';
import 'package:productivity/dataservice/login_service.dart';

class UserProvider extends ChangeNotifier {
  User? _user;

  UserProvider() {
    autoLogin();
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;

  void login(User user) {
    _user = user;
    notifyListeners();
  }

  Future<void> autoLogin() async {
    try {
      if (await LoginService.isLoggedIn()) {
        final user = await LoginService.currentUser;
        _user = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Auto-login failed: $e');
      // If auto-login fails (e.g. token expired), we ensure the user is logged out
      await LoginService.logout();
      _user = null;
      notifyListeners();
    }
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
