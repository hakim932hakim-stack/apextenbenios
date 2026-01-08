import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/star_background.dart';
import '../controllers/auth_controller.dart';
import 'email_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authController = Get.find<AuthController>();
  
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Stack(
        children: [
          // 🌟 Arka Plan (Mevcut Star Background)
          const StarBackground(),

          // 📱 İçerik
          SafeArea(
            child: SingleChildScrollView(
              child: SizedBox(
                height: screenHeight - MediaQuery.of(context).padding.top,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // 🖼️ LOGO - Büyük
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40), // 2 tık aşağı
                          child: Center(
                            child: CachedNetworkImage(
                              imageUrl: 'https://ik.imagekit.io/csngb8mm6/APEXLOGO.png',
                              width: 460,
                              height: 460,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const SizedBox(),
                              errorWidget: (context, url, error) => Text(
                                'APEX',
                                style: GoogleFonts.inter(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 📝 Giriş Butonları
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // 🔴 Google ile Giriş Yap (Şimdilik Pasif)
                            _buildGoogleButton(),
                            
                            const SizedBox(height: 16),

                            // 📧 E-posta ile Giriş (Ayrı Sayfaya Yönlendir)
                            _buildEmailLoginButton(),

                            const SizedBox(height: 24),

                            // ✅ Terms Checkbox
                            _buildTermsCheckbox(),

                            const Spacer(),

                            // 📌 Footer
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                '© 2026 Apex Inc.',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔴 Google ile Giriş Butonu (Şimdilik Pasif)
  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _termsAccepted 
          ? () {
              // TODO: Google Sign-In entegrasyonu
              Get.snackbar(
                'Yakında',
                'Google ile giriş yakında aktif olacak',
                backgroundColor: Colors.white.withOpacity(0.1),
                colorText: Colors.white,
              );
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _termsAccepted ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google SVG Icon
              _buildGoogleIcon(),
              const SizedBox(width: 12),
              Text(
                'Google ile Giriş Yap',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151), // gray-700
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎨 Google Renkli İkon
  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }

  /// 📧 E-posta ile Giriş Butonu (Ayrı Sayfaya Yönlendirir)
  Widget _buildEmailLoginButton() {
    return GestureDetector(
      onTap: () {
        // Ayrı sayfaya git
        Get.to(() => const EmailLoginScreen());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline_rounded,
              size: 20,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(width: 12),
            Text(
              'E-posta ile Giriş',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Terms Checkbox
  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _termsAccepted = !_termsAccepted;
        });
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _termsAccepted 
                  ? const Color(0xFF8B5CF6) 
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _termsAccepted 
                    ? const Color(0xFF8B5CF6) 
                    : Colors.white.withOpacity(0.3),
              ),
            ),
            child: _termsAccepted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: 'Gizlilik Politikası',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFA78BFA),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' ve '),
                  TextSpan(
                    text: 'Kullanım Koşulları',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFA78BFA),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: "'nı okudum ve kabul ediyorum."),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 Google Logo Custom Painter
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Scale paths to fit 20x20
    final scale = size.width / 24;
    
    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(
      Path()
        ..moveTo(22.56 * scale, 12.25 * scale)
        ..cubicTo(22.56 * scale, 11.47 * scale, 22.49 * scale, 10.72 * scale, 22.36 * scale, 10 * scale)
        ..lineTo(12 * scale, 10 * scale)
        ..lineTo(12 * scale, 14.26 * scale)
        ..lineTo(17.92 * scale, 14.26 * scale)
        ..cubicTo(17.66 * scale, 15.63 * scale, 16.88 * scale, 16.79 * scale, 15.71 * scale, 17.57 * scale)
        ..lineTo(15.71 * scale, 20.34 * scale)
        ..lineTo(19.28 * scale, 20.34 * scale)
        ..cubicTo(21.36 * scale, 18.42 * scale, 22.56 * scale, 15.6 * scale, 22.56 * scale, 12.25 * scale)
        ..close(),
      paint,
    );
    
    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(
      Path()
        ..moveTo(12 * scale, 23 * scale)
        ..cubicTo(14.97 * scale, 23 * scale, 17.46 * scale, 22.02 * scale, 19.28 * scale, 20.34 * scale)
        ..lineTo(15.71 * scale, 17.57 * scale)
        ..cubicTo(14.73 * scale, 18.23 * scale, 13.48 * scale, 18.63 * scale, 12 * scale, 18.63 * scale)
        ..cubicTo(9.14 * scale, 18.63 * scale, 6.71 * scale, 16.7 * scale, 5.84 * scale, 14.1 * scale)
        ..lineTo(2.18 * scale, 14.1 * scale)
        ..lineTo(2.18 * scale, 16.94 * scale)
        ..cubicTo(3.99 * scale, 20.53 * scale, 7.7 * scale, 23 * scale, 12 * scale, 23 * scale)
        ..close(),
      paint,
    );
    
    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(
      Path()
        ..moveTo(5.84 * scale, 14.09 * scale)
        ..cubicTo(5.62 * scale, 13.43 * scale, 5.49 * scale, 12.73 * scale, 5.49 * scale, 12 * scale)
        ..cubicTo(5.49 * scale, 11.27 * scale, 5.62 * scale, 10.57 * scale, 5.84 * scale, 9.91 * scale)
        ..lineTo(5.84 * scale, 7.07 * scale)
        ..lineTo(2.18 * scale, 7.07 * scale)
        ..cubicTo(1.43 * scale, 8.55 * scale, 1 * scale, 10.22 * scale, 1 * scale, 12 * scale)
        ..cubicTo(1 * scale, 13.78 * scale, 1.43 * scale, 15.45 * scale, 2.18 * scale, 16.93 * scale)
        ..lineTo(5.84 * scale, 14.09 * scale)
        ..close(),
      paint,
    );
    
    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(
      Path()
        ..moveTo(12 * scale, 5.38 * scale)
        ..cubicTo(13.62 * scale, 5.38 * scale, 15.06 * scale, 5.94 * scale, 16.21 * scale, 7.02 * scale)
        ..lineTo(19.36 * scale, 3.87 * scale)
        ..cubicTo(17.45 * scale, 2.09 * scale, 14.97 * scale, 1 * scale, 12 * scale, 1 * scale)
        ..cubicTo(7.7 * scale, 1 * scale, 3.99 * scale, 3.47 * scale, 2.18 * scale, 7.07 * scale)
        ..lineTo(5.84 * scale, 9.91 * scale)
        ..cubicTo(6.71 * scale, 7.31 * scale, 9.14 * scale, 5.38 * scale, 12 * scale, 5.38 * scale)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
