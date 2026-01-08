import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:yeniapex/core/widgets/animated_avatar.dart';
import 'package:yeniapex/core/widgets/user_name_text.dart';
import 'package:yeniapex/features/profile/screens/profile_edit_screen.dart';

//...
import 'package:yeniapex/features/profile/controllers/profile_controller.dart';
import 'package:yeniapex/features/profile/screens/settings_screen.dart';
import 'package:yeniapex/features/profile/screens/user_list_screen.dart';
import 'package:yeniapex/features/stories/controllers/story_controller.dart'; // 🔥 Story
import 'package:yeniapex/features/home/widgets/home_header_story_helpers.dart'; // 🔥 Helpers
import 'package:yeniapex/features/posts/controllers/posts_controller.dart'; // 🔥 NEW
import 'package:yeniapex/features/posts/screens/user_posts_screen.dart'; // 🔥 NEW

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    // Controller'ı burada oluşturuyoruz
    final profileController = Get.put(ProfileController());

    // Obx ile tüm sayfayı dinliyoruz ki Auth değişince (isim/avatar) burası da değişsin
    return Obx(() {
      final user = authController.currentUser.value;
      final profile = authController.currentProfile.value;
      final meta = user?.userMetadata;

      final String username = profile?['username'] ?? meta?['username'] ?? 'Kullanıcı';
      final String displayName = profile?['display_name'] ?? meta?['display_name'] ?? username;
      final String avatarUrl = profile?['avatar_url'] ?? meta?['avatar_url'] ?? 'https://ui-avatars.com/api/?name=$username&background=random&size=200';
      final String? bio = profile?['bio'] ?? meta?['bio'];
      final bool isAdmin = profile?['is_admin'] == true; // 🌈 Admin kontrolü

      // Veriler taze kalsın diye her build'de çekmeyi tetikleyebiliriz
      // profileController.fetchStats(); 

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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCircleButton(icon: Icons.arrow_back, onTap: () => Get.back()),
                        Row(
                          children: [
                            _buildCircleButton(
                              icon: LucideIcons.edit3, 
                              onTap: () => Get.to(() => const ProfileEditScreen())?.then((_) => profileController.fetchStats())
                            ),
                            const SizedBox(width: 12),
                            _buildCircleButton(
                                icon: LucideIcons.settings, 
                                onTap: () => Get.to(() => const SettingsScreen()), // Popup yerine tam sayfa
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- AVATAR (Çerçeve Kaldırıldı) ---
                  // --- AVATAR (Çerçeve ve Story) ---
                  Center(
                    child: GestureDetector(
                      onTap: () {
                         final storyController = Get.put(StoryController());
                         // onProfileTap boş fonksiyon veriyoruz çünkü zaten profildeyiz
                         showProfileOptions(context, storyController, () {}); 
                      },
                      child: Obx(() {
                        final storyController = Get.put(StoryController());
                        final hasStory = storyController.hasActiveStory.value;
                        
                        return Container(
                          width: 128, // Halka için +8px
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: hasStory ? Border.all(color: Colors.redAccent, width: 3) : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0), // Halka boşluğu
                            child: ClipOval(
                              child: AnimatedAvatar(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- İSİM ---
                  UserNameText(
                    displayName: displayName,
                    isAdmin: isAdmin,
                    style: GoogleFonts.inter(
                      fontSize: 24, 
                      fontWeight: FontWeight.w900, 
                      color: Colors.white,
                      shadows: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]
                    ),
                  ),
                  Text(
                    "@$username",
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.7)),
                  ),

                  const SizedBox(height: 24),

                  // --- İSTATİSTİKLER (Tıklanabilir) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Get.to(() => UserListScreen(
                              title: "Takip Edilenler", 
                              fetchFunction: profileController.getFollowing
                            )),
                            child: _buildStatCard("Takip", "${profileController.followingCount.value}"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Get.to(() => UserListScreen(
                              title: "Takipçiler", 
                              fetchFunction: profileController.getFollowers
                            )),
                            child: _buildStatCard("Takipçi", "${profileController.followersCount.value}"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Get.to(() => UserListScreen(
                              title: "Ziyaretçiler", 
                              fetchFunction: profileController.getVisitors
                            )),
                            child: _buildStatCard("Ziyaretçi", "${profileController.visitorsCount.value}"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 🔥 POST İSTATİSTİĞİ
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final userId = authController.currentUser.value?.id;
                              if (userId != null) {
                                Get.to(() => UserPostsScreen(
                                  userId: userId,
                                  displayName: displayName,
                                ));
                              }
                            },
                            child: _buildStatCard("Post", "${profileController.postsCount.value}"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // --- BIO ---
                  if (bio != null && bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GlassmorphicContainer(
                        width: double.infinity, height: 80, borderRadius: 16, blur: 20, alignment: Alignment.centerLeft, border: 1,
                        linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]),
                        borderGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(bio, style: GoogleFonts.inter(fontSize: 14, color: Colors.white70), maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  } // build sonu

  // Yuvarlak, cam efektli buton (Geri, Ayarlar vb. için)
  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        width: 44,
        height: 44,
        borderRadius: 22,
        blur: 10,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderGradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // İstatistik Kartı (React'taki dikey kutular)
  Widget _buildStatCard(String label, String value) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 70,
      borderRadius: 16,
      blur: 20,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.01)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label.toUpperCase(), // React tasarımında UPPERCASE
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Ayarlar Menüsü (Bottom Sheet)
  void _showSettingsSheet(BuildContext context, AuthController authController) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
            
            _buildSettingsItem(icon: LucideIcons.user, text: "Hesap Ayarları", onTap: () {}),
            _buildSettingsItem(icon: LucideIcons.shield, text: "Gizlilik", onTap: () {}),
            const Divider(color: Colors.white10),
            _buildSettingsItem(
              icon: LucideIcons.logOut, 
              text: "Çıkış Yap", 
              color: AppColors.error,
              onTap: () {
                Get.back(); // Sheet'i kapat
                authController.signOut();
                Get.offAllNamed('/');
              }
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildSettingsItem({required IconData icon, required String text, required VoidCallback onTap, Color color = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
