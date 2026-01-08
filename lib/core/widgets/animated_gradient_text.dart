import 'package:flutter/material.dart';

/// 🌈 Animasyonlu Gradient Text Widget
/// Admin kullanıcılar için renkli, sağa doğru kayan text efekti
class AnimatedGradientText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AnimatedGradientText({
    Key? key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : super(key: key);

  @override
  State<AnimatedGradientText> createState() => _AnimatedGradientTextState();
}

class _AnimatedGradientTextState extends State<AnimatedGradientText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // 🎨 SABİT Gradient Renkleri (Base Color - Değişmez)
  static const List<Color> _baseGradientColors = [
    Color(0xFFFF00FF), // Magenta
    Color(0xFFFF1493), // Deep Pink
    Color(0xFFFF4500), // Orange Red
    Color(0xFFFFA500), // Orange
    Color(0xFFFFD700), // Gold
  ];

  @override
  void initState() {
    super.initState();
    
    // 🔥 Renk Akışı Animasyonu - Sürekli sağa doğru akış
    _controller = AnimationController(
      duration: const Duration(seconds: 3), 
      vsync: this,
    )..repeat(); // Sürekli tekrar (reverse yok)

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate( // 0'dan 1'e tam tur
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear, // 🔥 Sabit hızda akış
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            // 🎨 DAHA BASİT VE SAĞLAM GRADIENT ANIMASYONU
            final Gradient gradient = LinearGradient(
              colors: const [
                Color(0xFFFF00FF), // Magenta
                Color(0xFFFF1493), // Deep Pink
                Color(0xFFFF4500), // Orange Red
                Color(0xFFFFA500), // Orange
                Color(0xFFFFD700), // Gold
                Color(0xFFFF00FF), // Magenta (Döngü için başa dönüş)
              ],
              stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlidingGradientTransform(slidePercent: _animation.value),
              tileMode: TileMode.repeated, // 🔥 Sürekli tekrar (Ayna efekti yok, duraksama yok)
            );
            
            return gradient.createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: widget.style?.copyWith(
              color: Colors.white,
              fontWeight: widget.style?.fontWeight ?? FontWeight.bold,
            ) ?? const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Gradient'i X ekseninde kaydır
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
