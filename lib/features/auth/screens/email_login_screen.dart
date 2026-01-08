import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/star_background.dart';
import '../controllers/auth_controller.dart';

/// 📧 E-posta ile Giriş Sayfası
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = Get.find<AuthController>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌟 Arka Plan
          const StarBackground(),

          // 📱 İçerik
          SafeArea(
            child: Column(
              children: [
                // 🔙 Geri Butonu
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                // 📝 Form İçeriği
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        // 📧 Başlık
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 64,
                          color: const Color(0xFF8B5CF6).withOpacity(0.8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'E-posta ile Giriş',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hesabınıza giriş yapın',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Email Input
                        _buildTextField(
                          controller: _emailController,
                          hint: 'E-posta',
                          icon: Icons.mail_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Password Input
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'Şifre',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                        ),

                        const SizedBox(height: 32),

                        // 🔵 Giriş Butonu
                        Obx(() => _authController.isLoading.value
                            ? const CircularProgressIndicator(color: Color(0xFF8B5CF6))
                            : _buildSignInButton()),

                        const SizedBox(height: 24),

                        // ❓ Şifremi Unuttum
                        TextButton(
                          onPressed: () {
                            // TODO: Forgot password
                            Get.snackbar(
                              'Yakında',
                              'Şifre sıfırlama yakında aktif olacak',
                              backgroundColor: Colors.white.withOpacity(0.1),
                              colorText: Colors.white,
                            );
                          },
                          child: Text(
                            'Şifremi Unuttum',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFA78BFA),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 📝 Input Field
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  /// 🔵 Giriş Butonu
  Widget _buildSignInButton() {
    return GestureDetector(
      onTap: () {
        if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
          Get.snackbar(
            'Hata',
            'Lütfen tüm alanları doldurun',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
          return;
        }
        _authController.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Giriş Yap',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
