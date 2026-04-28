import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/User.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/notification_service.dart';

class UserProvider extends ChangeNotifier {
  User? _user;

  UserProvider() {
    autoLogin();
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;

  void login(User user) {
    _user = user;
    NotificationService().init(); // Benachrichtigungen starten
    notifyListeners();
  }

  Future<void> autoLogin() async {
    try {
      if (await LoginService.isLoggedIn()) {
        final user = await LoginService.currentUser;
        _user = user;
        NotificationService().init(); // Benachrichtigungen starten
        notifyListeners();
      }
    } catch (e) {
      await LoginService.logout();
      _user = null;
      notifyListeners();
    }
  }

  void logout() {
    _user = null;
    NotificationService().disconnect(); // Verbindung trennen
    notifyListeners();
  }
}
