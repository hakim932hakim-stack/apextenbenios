import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yeniapex/core/widgets/star_background.dart';

class RoomLoadingWidget extends StatefulWidget {
  const RoomLoadingWidget({super.key});

  @override
  State<RoomLoadingWidget> createState() => _RoomLoadingWidgetState();
}

class _RoomLoadingWidgetState extends State<RoomLoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // React: 1.5s
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Arka Plan
          const StarBackground(),

          // 2. Merkez (Logo + Dönen Halka)
          Center(
            child: SizedBox(
              width: 192, // React: w-48 (48 * 4 = 192px)
              height: 192,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Dönen Halka (Beyaz)
                  Positioned.fill(
                    top: -16, right: -16, bottom: -16, left: -16,
                    child: RotationTransition(
                      turns: _controller,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 4,
                          ),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border(
                              top: BorderSide(color: Colors.white, width: 4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Parlama Efekti (Static Outer Glow)
                  Container(
                    width: 192, height: 192,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05), // React: bg-white/20
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),

                  // Logo İmajı
                  CachedNetworkImage(
                    imageUrl: "https://ik.imagekit.io/csngb8mm6/97e34457-86f5-4f4a-8a22-be2e50898321-Photoroom%20(1).png",
                    fit: BoxFit.contain,
                    width: 180,
                    height: 180,
                  ),
                ],
              ),
            ),
          ),

          // Alt Metin (Kaldırıldı)
        ],
      ),
    );
  }
}
