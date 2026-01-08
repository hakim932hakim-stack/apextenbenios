import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ToastUtils {
  static void show(String title, String message, {bool isError = false, bool isSuccess = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF333333), // Koyu gri toast rengi
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      duration: const Duration(seconds: 3),
      icon: isError 
           ? const Icon(Icons.error_outline, color: Colors.redAccent) 
           : (isSuccess ? const Icon(Icons.check_circle_outline, color: Colors.greenAccent) : const Icon(Icons.info_outline, color: Colors.white)),
      overlayBlur: 0, // Toast olduğu için arkası bulanıklaşmasın
      shouldIconPulse: false,
    );
  }
}
