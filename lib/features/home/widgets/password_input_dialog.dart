import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PasswordInputDialog extends StatefulWidget {
  final String correctPassword;
  final VoidCallback onSuccess;

  const PasswordInputDialog({
    super.key,
    required this.correctPassword,
    required this.onSuccess,
  });

  @override
  State<PasswordInputDialog> createState() => _PasswordInputDialogState();
}

class _PasswordInputDialogState extends State<PasswordInputDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isError = false;

  void _verify() {
    if (_controller.text.toUpperCase() == widget.correctPassword.toUpperCase()) {
      Get.back();
      widget.onSuccess();
    } else {
      setState(() => _isError = true);
      _controller.clear();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _isError = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          borderRadius: BorderRadius.circular(32), // Oval
          border: Border.all(
            color: _isError ? const Color(0xFFDC2626) : Colors.white.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              LucideIcons.lock,
              color: _isError ? const Color(0xFFDC2626) : Colors.white,
              size: 40,
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              "Bu oda kilitli",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              "Devam etmek için şifreyi girin",
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Input Field
            TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              autofocus: true,
              keyboardType: TextInputType.number, // Sadece sayı klavyesi
              maxLength: 4, // Max 4 karakter
              style: GoogleFonts.spaceMono(
                fontSize: 36, // 4 haneli için daha büyük
                color: Colors.white,
                letterSpacing: 16, // Daha geniş
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _isError 
                        ? const Color(0xFFDC2626) 
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _isError 
                        ? const Color(0xFFDC2626) 
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                hintText: "····",
                hintStyle: GoogleFonts.spaceMono(
                  color: Colors.white30,
                  letterSpacing: 16,
                  fontSize: 36,
                ),
                counterText: "", // Karakter sayacını gizle
                errorText: _isError ? "Yanlış şifre!" : null,
                errorStyle: GoogleFonts.inter(
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onSubmitted: (_) => _verify(),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "İptal",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Gir",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
