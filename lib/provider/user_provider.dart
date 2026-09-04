import 'package:flutter/material.dart';
import 'package:productivity/dataclasses/user.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/background_task_manager.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/notification_service.dart';

class UserProvider extends ChangeNotifier {
  User? _user;

  UserProvider() {
    // Laeuft das Token mitten in der Sitzung ab, meldet der ApiClient das hier
    // und die App springt zurueck auf den Login-Screen.
    ApiClient.onUnauthorized = logout;
    autoLogin();
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;

  void login(User user) {
    _user = user;
    NotificationService().init(); // Benachrichtigungen starten
    BackgroundTaskManager.init(); // Hintergrund-Jobs (no-op auf Web)
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
    if (_user == null) return;
    _user = null;
    NotificationService().disconnect(); // Verbindung trennen
    // Ohne das liefen die Workmanager-Jobs nach dem Logout weiter und weckten
    // das Geraet alle 6 Stunden, obwohl niemand mehr angemeldet ist.
    BackgroundTaskManager.stop();
    notifyListeners();
  }
}
