import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/star_background.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = Get.find<AuthController>();

  @override
  void dispose() {
    _usernameController.dispose();
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
                        const SizedBox(height: 20),

                        // 📧 Başlık
                        Icon(
                          Icons.person_add_rounded,
                          size: 64,
                          color: const Color(0xFF8B5CF6).withOpacity(0.8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kayıt Ol',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'APEX Dünyasına Katıl',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Username Input
                        _buildTextField(
                          controller: _usernameController,
                          hint: 'Kullanıcı Adı',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

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

                        // 🔵 Kayıt Ol Butonu
                        Obx(() => _authController.isLoading.value
                            ? const CircularProgressIndicator(color: Color(0xFF8B5CF6))
                            : _buildRegisterButton()),

                        const SizedBox(height: 24),

                        // ❓ Zaten hesabın var mı?
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Zaten hesabın var mı? ',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Get.back(),
                              child: Text(
                                'Giriş Yap',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFA78BFA),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),
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

  /// 🔵 Kayıt Ol Butonu
  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: () {
        if (_usernameController.text.isEmpty ||
            _emailController.text.isEmpty ||
            _passwordController.text.isEmpty) {
          Get.snackbar(
            'Hata',
            'Lütfen tüm alanları doldurun',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
          return;
        }
        _authController.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _usernameController.text.trim(),
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
            'Kayıt Ol',
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
