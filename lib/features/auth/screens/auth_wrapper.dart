import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:yeniapex/features/auth/screens/login_screen.dart';
import 'package:yeniapex/features/auth/screens/profile_setup_screen.dart';
import 'package:yeniapex/features/home/screens/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = AuthController.to;
    return Obx(() {
      if (authController.isProfileChecking.value) {
        // Kontrol sırasında siyah ekran göster (Splash sonrası geçiş efekti gibi olur)
        return const Scaffold(backgroundColor: Colors.black);
      }

      if (authController.currentUser.value == null) {
        return const LoginScreen();
      } else {
        if (authController.isProfileComplete.value) {
          return const HomeScreen();
        } else {
          return const ProfileSetupScreen();
        }
      }
    });
  }
}
