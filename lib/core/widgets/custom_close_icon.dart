import 'package:flutter/material.dart';

/// Custom Close Icon - Özel X kapatma ikonu (Android vector'ün Flutter karşılığı)
class CustomCloseIcon extends StatelessWidget {
  final double size;
  final Color color;
  
  const CustomCloseIcon({
    super.key, 
    this.size = 24, 
    this.color = Colors.white70
  });
  
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.7508), // 100:75.08 aspect ratio
      painter: _CloseIconPainter(color: color),
    );
  }
}

class _CloseIconPainter extends CustomPainter {
  final Color color;
  
  _CloseIconPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 75.08;
    
    final path = Path();
    
    // Android Vector Path Data dönüşümü
    path.moveTo(94.78 * scaleX, 3.74 * scaleY);
    path.relativeCubicTo(-8.19 * scaleX, -5.72 * scaleY, -14.27 * scaleX, -5.12 * scaleY, -22.93 * scaleX, 3.5 * scaleY);
    path.relativeCubicTo(-0.3 * scaleX, 0.27 * scaleY, -0.58 * scaleX, 0.54 * scaleY, -0.82 * scaleX, 0.81 * scaleY);
    path.relativeLineTo(-0.24 * scaleX, 0.28 * scaleY);
    path.relativeCubicTo(-1.28 * scaleX, 1.34 * scaleY, -2.62 * scaleX, 2.84 * scaleY, -4.02 * scaleX, 4.52 * scaleY);
    path.relativeLineTo(0.03 * scaleX, 0.02 * scaleY);
    path.lineTo(49.69 * scaleX, 32.3 * scaleY);
    path.lineTo(32.85 * scaleX, 12.9 * scaleY);
    path.relativeCubicTo(-1.62 * scaleX, -2.02 * scaleY, -3.15 * scaleX, -3.79 * scaleY, -4.61 * scaleX, -5.31 * scaleY);
    path.lineTo(28.23 * scaleX, 7.57 * scaleY);
    path.relativeCubicTo(-0.2 * scaleX, -0.22 * scaleY, -0.42 * scaleX, -0.44 * scaleY, -0.65 * scaleX, -0.66 * scaleY);
    path.cubicTo(19.56 * scaleX, -1.18 * scaleY, 13.6 * scaleX, -1.74 * scaleY, 5.52 * scaleX, 3.59 * scaleY);
    path.relativeCubicTo(-5.03 * scaleX, 3.32 * scaleY, -7.03 * scaleX, 11.44 * scaleY, -4.29 * scaleX, 17.65 * scaleY);
    path.relativeCubicTo(0.23 * scaleX, 0.62 * scaleY, 3.14 * scaleX, 5.17 * scaleY, 3.5 * scaleX, 5.64 * scaleY);
    path.relativeCubicTo(2.11 * scaleX, 2.73 * scaleY, 4.86 * scaleX, 3.98 * scaleY, 6.71 * scaleX, 2.73 * scaleY);
    path.relativeCubicTo(1.85 * scaleX, -1.25 * scaleY, 1.84 * scaleX, -4.5 * scaleY, -0.02 * scaleX, -7.26 * scaleY);
    path.relativeCubicTo(0 * scaleX, 0 * scaleY, -1.94 * scaleX, -2.68 * scaleY, -2.46 * scaleX, -3.65 * scaleY);
    path.relativeCubicTo(-1.63 * scaleX, -3.07 * scaleY, -1.01 * scaleX, -6.47 * scaleY, 1.46 * scaleX, -8.37 * scaleY);
    path.relativeCubicTo(3.86 * scaleX, -2.97 * scaleY, 7.38 * scaleX, -1.19 * scaleY, 10.9 * scaleX, 2.14 * scaleY);
    path.relativeLineTo(22.94 * scaleX, 25.99 * scaleY);
    path.lineTo(19.67 * scaleX, 66.42 * scaleY);
    path.relativeCubicTo(-2.26 * scaleX, 2.57 * scaleY, -2.88 * scaleX, 6.03 * scaleY, -1.39 * scaleX, 7.73 * scaleY);
    path.relativeCubicTo(1.5 * scaleX, 1.7 * scaleY, 4.55 * scaleX, 0.99 * scaleY, 6.81 * scaleX, -1.58 * scaleY);
    path.relativeLineTo(24.61 * scaleX, -27.97 * scaleY);
    path.relativeLineTo(24.65 * scaleX, 27.92 * scaleY);
    path.relativeCubicTo(2.27 * scaleX, 2.57 * scaleY, 5.32 * scaleX, 3.27 * scaleY, 6.81 * scaleX, 1.57 * scaleY);
    path.relativeCubicTo(1.5 * scaleX, -1.7 * scaleY, 0.87 * scaleX, -5.16 * scaleY, -1.4 * scaleX, -7.73 * scaleY);
    path.lineTo(55.12 * scaleX, 38.45 * scaleY);
    path.relativeLineTo(18.52 * scaleX, -21.05 * scaleY);
    path.relativeCubicTo(5.44 * scaleX, -5.84 * scaleY, 10.51 * scaleX, -11.55 * scaleY, 16.05 * scaleX, -7.05 * scaleY);
    path.relativeCubicTo(2.42 * scaleX, 1.97 * scaleY, 2.95 * scaleX, 5.38 * scaleY, 1.24 * scaleX, 8.4 * scaleY);
    path.relativeCubicTo(-0.54 * scaleX, 0.96 * scaleY, -2.55 * scaleX, 3.58 * scaleY, -2.55 * scaleX, 3.58 * scaleY);
    path.relativeCubicTo(-1.93 * scaleX, 2.71 * scaleY, -2.02 * scaleX, 5.96 * scaleY, -0.21 * scaleX, 7.25 * scaleY);
    path.relativeCubicTo(1.81 * scaleX, 1.3 * scaleY, 4.61 * scaleX, 0.12 * scaleY, 6.78 * scaleX, -2.55 * scaleY);
    path.relativeCubicTo(0.37 * scaleX, -0.46 * scaleY, 3.41 * scaleX, -4.93 * scaleY, 3.65 * scaleX, -5.54 * scaleY);
    path.cubicTo(101.51 * scaleX, 15.36 * scaleY, 99.72 * scaleX, 7.2 * scaleY, 94.78 * scaleX, 3.74 * scaleY);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
