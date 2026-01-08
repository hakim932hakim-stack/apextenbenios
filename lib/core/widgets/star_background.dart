import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StarBackground extends StatelessWidget {
  const StarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black, // Fallback background
        child: Opacity(
          opacity: 0.8,
          child: Lottie.asset(
            'assets/animations/apex_starbg.json',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
