import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yeniapex/core/widgets/animated_avatar.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/messages/screens/chat_screen.dart';
import 'package:yeniapex/features/profile/controllers/user_profile_controller.dart';
import 'package:yeniapex/features/profile/screens/user_list_screen.dart'; // Eğer kullanılıyorsa
import 'package:yeniapex/features/messages/services/pie_socket_service.dart';
import 'package:yeniapex/features/posts/screens/user_posts_screen.dart'; // 🔥 NEW
import 'package:yeniapex/features/stories/controllers/story_controller.dart'; // 🔥 Story
import 'package:yeniapex/features/stories/screens/story_view_screen.dart'; // 🔥 Story
import 'package:yeniapex/features/home/widgets/home_header_story_helpers.dart'; // 🔥 Helpers (showProfilePhoto)
import 'package:yeniapex/core/widgets/user_name_text.dart'; // 🌈 Admin Styling

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final UserProfileController controller;
  
  // 🔥 Story Variables
  final RxList<Map<String, dynamic>> _userStories = <Map<String, dynamic>>[].obs;
  final RxBool _hasStories = false.obs;
  final StoryController _storyController = Get.put(StoryController());

  @override
  @override
  void initState() {
    super.initState();
    // Unique tag ile controller oluşturuyoruz ki birden fazla profil açılırsa çakışmasın
    // DİĞER EKRANLARLA AYNI TAG FORMATI! ('user_profile_$id')
    controller = Get.put(UserProfileController(), tag: 'user_profile_${widget.userId}');
    
    // UI build sonrası durumu kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadUser(widget.userId);
        controller.checkBlockStatus(widget.userId);
        _fetchStories(); // 🔥 Hikayeleri Çek
    });
  }
  
  void _fetchStories() async {
    final stories = await _storyController.fetchOtherUserStories(widget.userId);
    _userStories.value = stories;
    _hasStories.value = stories.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isLoading.value;
      if (isLoading) {
         return Scaffold(
           body: Stack(
             children: [
               const StarBackground(),
               const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
             ],
           ),
         );
      }

      final profile = controller.userProfile.value;
      if (profile == null) {
         return Scaffold(
           body: Stack(
             children: [
               const StarBackground(),
               Center(child: Text("Kullanıcı bulunamadı", style: GoogleFonts.inter(color: Colors.white))),
               Positioned(top: 50, left: 20, child: BackButton(onPressed: () => Get.back(), color: Colors.white)),
             ],
           ),
         );
      }

      final String username = profile['username'] ?? 'kullanici';
      final String displayName = profile['display_name'] ?? username;
      final String avatarUrl = profile['avatar_url']; // Boşsa fallback CachedNetworkImage içinde
      final String? bio = profile['bio'];
      final bool isAdmin = profile['is_admin'] == true; // 🌈 Admin kontrolü

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
                        // 3 nokta menüsü (Rapor/Engelle)
                        _buildCircleButton(icon: LucideIcons.moreVertical, onTap: () {
                           // BottomSheet aç (Engelle vs)
                           _showOptionsSheet(context);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // --- AVATAR (Story Ring + Durum Noktası) ---
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showUserOptions(context, avatarUrl),
                          child: Obx(() => Container(
                            width: 128,
                            height: 128,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: _hasStories.value ? Border.all(color: Colors.redAccent, width: 3) : null,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
                              ],
                            ),
                            child: Padding( // Halka padding
                              padding: const EdgeInsets.all(4.0),
                              child: ClipOval(
                                child: AnimatedAvatar(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )),
                        ),
                        
                        // 🔵 DURUM NOKTASI
                        Positioned(
                          right: 4, // Biraz içeri aldık halka için
                          bottom: 4,
                          child: Obx(() {
                            final isDND = controller.isDND.value;
                            final isOnline = Get.find<PieSocketService>().onlineUsers.contains(widget.userId);
                            
                            Color dotColor;
                            if (isDND) {
                              dotColor = Colors.red; // 🔴 Rahatsız Etme
                            } else if (isOnline) {
                              dotColor = Colors.greenAccent; // 🟢 Çevrimiçi
                            } else {
                              dotColor = Colors.grey; // ⚫ Çevrimdışı
                            }
                            
                            return Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 3),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- İSİM (Admin Shimmer) ---
                  UserNameText(
                    displayName: displayName,
                    isAdmin: isAdmin,
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, shadows: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]),
                  ),
                  Text(
                    "@$username",
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.7)),
                  ),

                  const SizedBox(height: 24),

                  // --- İSTATİSTİKLER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatBox("Takip", "${controller.followingCount.value}"),
                        const SizedBox(width: 16),
                        _buildStatBox("Takipçi", "${controller.followersCount.value}"),
                        const SizedBox(width: 16),
                        // 🔥 POST İSTATİSTİĞİ (Tıklanabilir)
                        GestureDetector(
                          onTap: () {
                            Get.to(() => UserPostsScreen(
                              userId: widget.userId,
                              displayName: displayName,
                            ));
                          },
                          child: _buildStatBox("Post", "${controller.postsCount.value}"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- BUTONLAR (Takip Et & Mesaj) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        // Takip Butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: (controller.isFollowLoading.value || controller.isBlocked)
                                ? null 
                                : () => controller.toggleFollow(widget.userId),
                            child: GlassmorphicContainer(
                              width: double.infinity,
                              height: 50,
                              borderRadius: 16,
                              blur: 10,
                              alignment: Alignment.center,
                              border: 1,
                              linearGradient: LinearGradient(
                                colors: controller.isBlocked
                                  ? [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)]
                                  : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
                              ),
                              borderGradient: LinearGradient(colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)]),
                              child: controller.isFollowLoading.value
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if(!controller.isBlocked) ...[
                                            Icon(
                                            _getFollowIcon(controller.followStatus.value), 
                                            color: Colors.white, size: 18
                                            ),
                                            const SizedBox(width: 8),
                                        ],
                                        Text(
                                          controller.isBlocked ? '---' : _getFollowLabel(controller.followStatus.value),
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),

                        // Mesaj Butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                               if (controller.isBlocked) return;
                               
                               if (!controller.isMutual.value) {
                                  Get.snackbar("Erişim Reddedildi", "Mesaj göndermek için karşılıklı takipleşmelisiniz.", 
                                    backgroundColor: Colors.black87, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                                  return;
                               }
                               // Sohbete Git
                               Get.to(() => ChatScreen(
                                 partnerId: widget.userId, 
                                 partnerName: displayName, 
                                 partnerAvatar: avatarUrl
                               ));
                            },
                            child: GlassmorphicContainer(
                              width: double.infinity,
                              height: 50,
                              borderRadius: 16,
                              blur: 10,
                              alignment: Alignment.center,
                              border: 1,
                              linearGradient: LinearGradient(
                                colors: controller.isBlocked
                                    ? [Colors.red.withOpacity(0.2), Colors.red.withOpacity(0.1)]
                                    : (controller.isMutual.value 
                                        ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
                                        : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)])
                              ),
                              borderGradient: LinearGradient(
                                colors: controller.isBlocked 
                                  ? [Colors.red.withOpacity(0.5), Colors.red.withOpacity(0.2)]
                                  : [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)]
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!controller.isBlocked)
                                    Icon(LucideIcons.messageCircle, color: controller.isMutual.value ? Colors.white : Colors.white38, size: 18),
                                  
                                  const SizedBox(width: 8),
                                  
                                  Text(
                                      controller.isBlocked ? "ENGELLİ" : "MESAJ", 
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold, 
                                          color: controller.isBlocked 
                                              ? Colors.red 
                                              : (controller.isMutual.value ? Colors.white : Colors.white38), 
                                          fontSize: 12
                                      )
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- BIO ---
                  if (bio != null && bio.trim().isNotEmpty) ...[
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
                  ]
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        width: 44, height: 44, borderRadius: 22, blur: 10, alignment: Alignment.center, border: 1,
        linearGradient: LinearGradient(colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.1)]),
        borderGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54)),
        ],
      ),
    );
  }

  String _getFollowLabel(String status) {
    switch (status) {
      case 'following': return 'TAKİPTE';
      case 'pending': return 'BEKLİYOR';
      default: return 'TAKİP ET';
    }
  }

  IconData _getFollowIcon(String status) {
    switch (status) {
      case 'following': return LucideIcons.check;
      case 'pending': return LucideIcons.clock;
      default: return LucideIcons.userPlus;
    }
  }

  void _showOptionsSheet(BuildContext context) {
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               // RAPOR ET
               ListTile(
                  leading: const Icon(LucideIcons.flag, color: Colors.blue),
                  title: Text('Rapor Et', style: GoogleFonts.inter(color: Colors.white)),
                  onTap: () {
                    Get.back();
                    Get.snackbar('Başarılı', 'Kullanıcı raporlandı', backgroundColor: Colors.green, colorText: Colors.white);
                  },
                ),
                
                // ENGELLE / ENGELİ KALDIR
                Obx(() {
                  final isBlocked = controller.isBlockedByMe.value;
                  return ListTile(
                    leading: Icon(isBlocked ? LucideIcons.unlock : LucideIcons.ban, color: Colors.red),
                    title: Text(isBlocked ? 'Engeli Kaldır' : 'Engelle', style: GoogleFonts.inter(color: Colors.white)),
                    onTap: () {
                      Get.back(); // Menüyü kapat
                      if (isBlocked) {
                        controller.unblockUser(widget.userId);
                      } else {
                        // Onay kutusu
                         Get.defaultDialog(
                          title: "Kullanıcıyı Engelle",
                          middleText: "Bu kullanıcıyı engellemek istediğinize emin misiniz?",
                          textConfirm: "Engelle",
                          textCancel: "Vazgeç",
                          confirmTextColor: Colors.white,
                          buttonColor: Colors.red,
                          onConfirm: () {
                            Get.back(); // Dialog kapat
                            controller.blockUser(widget.userId);
                          } 
                        );
                      }
                    },
                  );
                }),
            ],
          ),
        ),
      );
  }

  void _showUserOptions(BuildContext context, String avatarUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            
            ListTile(
              leading: const Icon(LucideIcons.user, color: Colors.white),
              title: const Text("Profil Fotoğrafını Gör", style: TextStyle(color: Colors.white)),
              onTap: () {
                 Get.back();
                 showProfilePhoto(context, avatarUrl); // Helper'dan
              },
            ),
            
            if (_hasStories.value)
               ListTile(
                leading: const Icon(LucideIcons.playCircle, color: Colors.white),
                title: const Text("Hikayeyi Gör", style: TextStyle(color: Colors.white)),
                onTap: () {
                   Get.back();
                   Get.to(() => StoryViewScreen(
                     stories: _userStories, 
                     isOwner: false,
                     userProfile: controller.userProfile.value, 
                   ));
                },
              ),
          ],
        ),
      ),
    );
  }
}
