import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:yeniapex/features/profile/controllers/user_profile_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    // Kendi işlemlerimiz için controller (Tag yok çünkü genel)
    final UserProfileController userController = Get.put(UserProfileController());

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const StarBackground(),
          SafeArea(
            child: Column(
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _buildCircleButton(icon: Icons.arrow_back, onTap: () => Get.back()),
                      const SizedBox(width: 16),
                      Text(
                        "Ayarlar",
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        // --- YASAL ---
                        _buildSectionHeader("YASAL", LucideIcons.fileText),
                        _buildActionCard(
                          title: "Gizlilik Politikası",
                          subtitle: "Verilerinizi nasıl kullanıyoruz",
                          icon: LucideIcons.fileText,
                          iconColor: Colors.blueAccent,
                          onTap: () => _launchUrl("https://gist.github.com/dermany0/privacy"),
                        ),
                        const SizedBox(height: 10),
                        _buildActionCard(
                          title: "Kullanım Koşulları",
                          subtitle: "Hizmet şartlarımız",
                          icon: LucideIcons.scale,
                          iconColor: Colors.greenAccent,
                          onTap: () => _launchUrl("https://gist.github.com/dermany0/terms"),
                        ),

                        const SizedBox(height: 20),

                        // --- HESAP İŞLEMLERİ ---
                        _buildSectionHeader("HESAP İŞLEMLERİ", LucideIcons.userCog),
                        
                        // 👻 GHOST MODE (Yetkili ise göster)
                        Obx(() {
                          final profile = authController.currentProfile.value;
                          if (profile != null && profile['can_use_privacy'] == true) {
                             return Padding(
                               padding: const EdgeInsets.only(bottom: 15),
                               child: _buildSwitchCard(
                                 title: "Görünmez Mod (Ghost)",
                                 subtitle: "Odalara gizlice gir, listelerde görünme.",
                                 value: profile['is_ghost_mode'] == true,
                                 onChanged: (val) async {
                                    // Optimistic Update
                                    final newProfile = Map<String, dynamic>.from(profile);
                                    newProfile['is_ghost_mode'] = val;
                                    authController.currentProfile.value = newProfile;
                                    
                                    // DB Update
                                    await userController.toggleGhostMode(val); 
                                    await authController.refreshUser(); // Sync
                                 }
                               ),
                             );
                          }
                          return const SizedBox.shrink();
                        }),
                        
                        // HESAP BİLGİLERİ (İçinde Engellenenler ve Hesap Sil var)
                        _buildActionCard(
                          title: "Hesap Bilgileri",
                          subtitle: "Kişisel ayarlar ve engellenenler",
                          icon: LucideIcons.user,
                          iconColor: Colors.orangeAccent,
                          onTap: () => _showAccountInfoSheet(context, userController),
                        ),

                        const SizedBox(height: 10),

                        // ÖNBELLEĞİ TEMİZLE
                        _buildActionCard(
                          title: "Önbelleği Temizle",
                          subtitle: "Gereksiz dosyaları siler (Yer açar)",
                          icon: LucideIcons.trash,
                          iconColor: Colors.cyanAccent,
                          onTap: () => _clearCache(),
                        ),
                        
                        const SizedBox(height: 10),

                        // ÇIKIŞ YAP
                        _buildActionCard(
                          title: "Çıkış Yap",
                          subtitle: "Oturumu sonlandır",
                          icon: LucideIcons.logOut,
                          iconColor: Colors.grey,
                          onTap: () {
                             authController.signOut();
                             Get.offAllNamed("/");
                          },
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

  // --- POP-UPS & SHEETS ---

  // 1. HESAP BİLGİLERİ POP-UP (KARA POPUP)
  void _showAccountInfoSheet(BuildContext context, UserProfileController userController) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F), // Siyah/Koyu
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text("Hesap Bilgileri", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),

            // ENGELLENENLER
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.ban, color: Colors.red),
              ),
              title: Text("Engellenen Kullanıcılar", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
              onTap: () {
                Get.back(); // Önce bunu kapat
                _showBlockedUsersSheet(context, userController); // Sonra listeyi aç
              },
            ),
            
            const Divider(color: Colors.white10),

            // HESAP SİL
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.trash2, color: Colors.redAccent),
              ),
              title: Text("Hesabımı Sil", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () {
                Get.back();
                _showDeleteAccountDialog(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      isScrollControlled: true
    );
  }

  // 2. ENGELLENENLER LİSTESİ (SİYAH OVAL POPUP - SCROLL)
  void _showBlockedUsersSheet(BuildContext context, UserProfileController userController) {
    // Listeyi çek
    userController.fetchBlockedUsers();

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.6, // Yari ekran
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
             Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
             const SizedBox(height: 20),
             Text("Engellenenler", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
             const SizedBox(height: 20),
             
             // LİSTE
             Expanded(
               child: Obx(() {
                  if (userController.blockedUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.shieldCheck, size: 48, color: Colors.white24),
                          const SizedBox(height: 10),
                          Text("Engellenen kimse yok", style: GoogleFonts.inter(color: Colors.white54)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: userController.blockedUsers.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final user = userController.blockedUsers[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[800],
                          backgroundImage: (user['avatar_url'] != null) ? CachedNetworkImageProvider(user['avatar_url']) : null,
                          child: (user['avatar_url'] == null) ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                        title: Text(user['display_name'] ?? 'Kullanıcı', style: GoogleFonts.inter(color: Colors.white)),
                        subtitle: Text("@${user['username']}", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                        trailing: TextButton(
                          onPressed: () {
                             // ENGELİ KALDIR
                             userController.unblockUser(user['id']);
                             // Listeden sil (Optimistic UI)
                             userController.blockedUsers.removeAt(index);
                          },
                          child: Text("KALDIR", style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  );
               }),
             ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  // --- DİĞER FONKSİYONLAR ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title, required String subtitle, required IconData icon, 
    required Color iconColor, required VoidCallback onTap, bool isDestructive = false
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        width: double.infinity, height: 70, borderRadius: 16, blur: 10, alignment: Alignment.center, border: 1,
        linearGradient: LinearGradient(
          colors: isDestructive 
            ? [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)]
            : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]
        ),
        borderGradient: LinearGradient(
          colors: isDestructive 
             ? [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)]
             : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDestructive ? Colors.red.withOpacity(0.1) : iconColor.withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, 
                        color: isDestructive ? Colors.redAccent : Colors.white
                      )
                    ),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: isDestructive ? Colors.red.withOpacity(0.5) : Colors.white54)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: isDestructive ? Colors.redAccent : Colors.white30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged
  }) {
    return GlassmorphicContainer(
      width: double.infinity, height: 80, borderRadius: 16, blur: 10, alignment: Alignment.center, border: 1,
      linearGradient: LinearGradient(colors: [Colors.indigo.withOpacity(0.1), Colors.indigo.withOpacity(0.05)]),
      borderGradient: LinearGradient(colors: [Colors.indigo.withOpacity(0.3), Colors.indigo.withOpacity(0.1)]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(LucideIcons.ghost, color: Colors.indigoAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.indigoAccent,
              activeTrackColor: Colors.indigo.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        width: 40, height: 40, borderRadius: 20, blur: 10, alignment: Alignment.center, border: 1,
        linearGradient: LinearGradient(colors: [Colors.white10, Colors.white12]),
        borderGradient: LinearGradient(colors: [Colors.white24, Colors.white10]),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      Get.snackbar("Hata", "Link açılamadı");
    }
  }

  Future<void> _clearCache() async {
    try {
      Get.snackbar("Temizleniyor", "Önbellek temizleniyor...", showProgressIndicator: true);
      await DefaultCacheManager().emptyCache();
      // Görsel önbelleği (image_picker vs)
      PaintingBinding.instance.imageCache.clear();
      
      Get.closeAllSnackbars();
      Get.snackbar("Başarılı", "Önbellek temizlendi! Uygulama hafızası rahatlatıldı.");
    } catch (e) {
      Get.closeAllSnackbars();
      Get.snackbar("Hata", "Önbellek temizlenirken hata oluştu: $e");
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: GlassmorphicContainer(
          width: 300, height: 320, borderRadius: 24, blur: 20, alignment: Alignment.center, border: 1,
          linearGradient: LinearGradient(colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.6)]),
          borderGradient: LinearGradient(colors: [Colors.red.withOpacity(0.5), Colors.red.withOpacity(0.2)]),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.trash2, color: Colors.red, size: 32),
                ),
                const SizedBox(height: 16),
                Text("Emin misin?", style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  "Bu işlem geri alınamaz. Tüm verilerin kalıcı olarak silinecek.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Get.back(),
                        child: Text("Vazgeç", style: GoogleFonts.inter(color: Colors.white60)),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                           Get.back();
                           Get.snackbar("Hata", "Bu işlem için yetkiniz yok.");
                        },
                        child: Text("Sil", style: GoogleFonts.inter(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
