import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PasswordDisplayDialog extends StatelessWidget {
  final String password;

  const PasswordDisplayDialog({
    super.key,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.lock,
                color: Color(0xFFDC2626),
                size: 48,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              "Oda Kilitlendi",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              "Odaya girmek için bu şifreyi kullanın",
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Password Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDC2626), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    password,
                    style: GoogleFonts.spaceMono(
                      fontSize: 48, // 4 haneli için daha büyük
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 12, // Daha geniş spacing
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: password));
                      // Toast removed
                    },
                    icon: const Icon(LucideIcons.copy, color: Colors.white70),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Tamam",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
