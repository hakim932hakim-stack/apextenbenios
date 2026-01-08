import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/features/posts/controllers/posts_controller.dart';

class CreatePostSection extends StatelessWidget {
  const CreatePostSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PostsController>();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 140,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.topLeft,
        border: 1,
        linearGradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderGradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text Field
              Expanded(
                child: TextField(
                  controller: controller.contentController,
                  maxLength: 100,
                  maxLines: 2,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Ne düşünüyorsun?",
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    border: InputBorder.none,
                    counterStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              
              // Action Row - MİNİMALİZE EDİLDİ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   // SOL: Araçlar (Görsel & Gizlilik)
                   Row(
                     children: [
                        // Görsel Butonu (Sadece İkon)
                        GestureDetector(
                          onTap: controller.pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1), 
                              shape: BoxShape.circle
                            ),
                            child: const Icon(LucideIcons.image, color: Colors.white70, size: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        // Gizlilik Butonu (Küçültüldü)
                        GestureDetector(
                          onTap: () => _showVisibilityPopup(context, controller),
                          child: Obx(() => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1), 
                              borderRadius: BorderRadius.circular(20)
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  controller.visibility.value == 'public' ? LucideIcons.globe : LucideIcons.users,
                                  color: Colors.white70, 
                                  size: 14
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  controller.visibility.value == 'public' ? "Herkese Açık" : "Arkadaşlar",
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 12),
                              ],
                            ),
                          )),
                        ),
                     ],
                   ),
                   
                   // SAĞ: Önizleme + Paylaş
                   Row(
                     children: [
                        // Seçilen Resim Önizlemesi
                        Obx(() {
                          if (controller.selectedImage.value != null) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      controller.selectedImage.value!, 
                                      width: 32, 
                                      height: 32, 
                                      fit: BoxFit.cover
                                    ),
                                  ),
                                  Positioned(
                                    top: -4, right: -4,
                                    child: GestureDetector(
                                      onTap: controller.removeImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 8, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),

                        // Paylaş Butonu (Küçültüldü)
                        Obx(() => GestureDetector(
                          onTap: controller.isCreating.value ? null : () async {
                              final success = await controller.createPost();
                              if (success) FocusScope.of(context).unfocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))
                              ]
                            ),
                            child: controller.isCreating.value
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text("Paylaş", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        )),
                     ],
                   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVisibilityPopup(BuildContext context, PostsController controller) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              "Kimler Görsün?",
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Public Option
            _buildOption(
              icon: LucideIcons.globe,
              title: "Herkese Açık",
              subtitle: "Tüm kullanıcılar görebilir",
              isSelected: controller.visibility.value == 'public',
              onTap: () {
                controller.setVisibility('public');
                Get.back();
              },
            ),
            const SizedBox(height: 12),
            
            // Friends Option
            _buildOption(
              icon: LucideIcons.users,
              title: "Sadece Arkadaşlar",
              subtitle: "Karşılıklı takipleşenler görebilir",
              isSelected: controller.visibility.value == 'friends',
              onTap: () {
                controller.setVisibility('friends');
                Get.back();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : Colors.white54, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
