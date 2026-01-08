import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF6366F1);
  static const Color secondary = Color(0xFFA855F7);
  
  // Backgrounds
  static const Color background = Color(0xFF0F0F14);
  static const Color backgroundLight = Color(0xFF1E1E24);
  
  // Glassmorphism
  static Color glassWhite = Colors.white.withOpacity(0.08);
  static Color glassBlack = Colors.black.withOpacity(0.2);
  static Color glassBorder = Colors.white.withOpacity(0.05);
  
  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textAccent = Color(0xFF6366F1); // Indigo-400
  
  // States
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient mainBgGradient = LinearGradient(
    colors: [
      Color(0xFF1A1A2E), // Deep Blue/Black
      Color(0xFF0F0F14), // Almost Black
      Color(0xFF16213E), 
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
