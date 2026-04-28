import 'package:flutter/material.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/tabs/home.dart';
import 'package:productivity/tabs/login.dart';
import 'package:provider/provider.dart';

class AppAuthWrapper extends StatelessWidget {
  const AppAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.isLoggedIn) {
          return const HomePage();
        } else {
          return const Login();
        }
      },
    );
  }
}
