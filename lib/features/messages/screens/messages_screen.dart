import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/messages/controllers/messages_controller.dart';
import 'package:yeniapex/features/messages/screens/chat_screen.dart';
import 'package:yeniapex/features/messages/screens/follow_requests_screen.dart';
import 'package:yeniapex/features/messages/services/pie_socket_service.dart';
import 'package:yeniapex/features/profile/screens/user_profile_screen.dart';
import 'package:yeniapex/features/home/screens/home_screen.dart'; // 🔥 Global callback için
import 'package:yeniapex/core/widgets/user_name_text.dart'; // 🌈 Admin Styling

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MessagesController>();
    
    // Sayfaya girince Home'daki kırmızı noktayı söndür
    WidgetsBinding.instance.addPostFrameCallback((_) {
       controller.clearUnreadNotification();
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const StarBackground(),

          Column(
            children: [
               // --- HEADER ---
               Padding(
                 padding: EdgeInsets.only(
                   top: MediaQuery.of(context).padding.top + 10,
                   left: 16,
                   right: 16,
                   bottom: 10
                 ),
                 child: Row(
                   children: [
                     // Geri
                     IconButton(
                       icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                       onPressed: () => Get.back(),
                     ),
                     
                     // Butonlar
                     Expanded(
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.05),
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: Colors.white.withOpacity(0.1)),
                         ),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                           children: [
                             // Takip İstekleri (Yeni Sayfaya Git)
                             Obx(() => _HeaderButton(
                               icon: LucideIcons.userPlus,
                               text: "Takip İst.",
                               onTap: () => Get.to(() => const FollowRequestsScreen()), 
                               badgeCount: controller.pendingRequestsCount.value,
                             )),

                             // Kullanıcı Ara
                             _HeaderButton(
                               icon: LucideIcons.user,
                               text: "Kul. Ara",
                               onTap: () => _showSearchModal(context, controller),
                             ),

                             // R. Etme
                             Obx(() => _HeaderButton(
                               icon: LucideIcons.moon,
                               text: controller.doNotDisturb.value ? "Açık" : "R. Etme",
                               isActive: controller.doNotDisturb.value,
                               activeColor: Colors.amber,
                               onTap: () => controller.toggleDND(),
                             )),
                           ],
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
              
              // --- INBOX ---
              Expanded(
                child: Obx(() {
                  if (controller.isLoadingInbox.value) {
                    return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                  }

                  if (controller.conversations.isEmpty) {
                    // Boş durum
                    return RefreshIndicator(
                      onRefresh: controller.fetchConversations,
                      color: Colors.cyanAccent,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                             SizedBox(height: Get.height * 0.3),
                             Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.messageSquare, size: 64, color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Henüz mesajın yok",
                                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
                                  ),
                                ],
                              ),
                             ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: controller.fetchConversations,
                    color: Colors.cyanAccent,
                    child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    itemCount: controller.conversations.length,
                    itemBuilder: (context, index) {
                      final chat = controller.conversations[index];
                      final user = chat['user'];
                      String lastMessage = chat['last_message'] ?? '';
                      // Görsel kontrolü
                       if (lastMessage.startsWith('http') && (lastMessage.contains('chat_images') || lastMessage.endsWith('.jpg') || lastMessage.endsWith('.png') || lastMessage.endsWith('.jpeg') || lastMessage.endsWith('.webp'))) {
                           lastMessage = "📷 Görsel";
                       } else if (lastMessage.startsWith("[ROOM_INVITE]")) {
                           lastMessage = "📩 Seni odaya davet etti";
                       }
                      
                      final date = DateTime.parse(chat['created_at']);
                      final unreadCount = chat['unread_count'] as int;
                      final timeStr = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

                      return GestureDetector(
                        onTap: () {
                          Get.to(() => ChatScreen(
                            partnerId: user['id'],
                            partnerName: user['display_name'] ?? user['username'] ?? 'User',
                            partnerAvatar: user['avatar_url'],
                          ));
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                // Avatar
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: const BoxDecoration(shape: BoxShape.circle),
                                      child: ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: user['avatar_url'] ?? 'https://ui-avatars.com/api/?name=${user['username']}&background=random',
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: Colors.grey[900]),
                                          errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    // Online Badge
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Obx(() {
                                        final isOnline = Get.find<PieSocketService>().onlineUsers.contains(user['id']);
                                        if (!isOnline) return const SizedBox.shrink();
                                        
                                        return Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black, width: 2),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          UserNameText(
                                            displayName: user['display_name'] ?? user['username'] ?? 'User',
                                            isAdmin: user['is_admin'] == true,
                                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(timeStr, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: unreadCount > 0 ? Colors.white : Colors.white54, 
                                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                                fontSize: 14
                                              ),
                                            ),
                                          ),
                                          if (unreadCount > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.cyanAccent, borderRadius: BorderRadius.circular(10)),
                                              child: Text(
                                                unreadCount.toString(),
                                                style: GoogleFonts.inter(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Kullanıcı Arama Modalı
  void _showSearchModal(BuildContext context, MessagesController controller) {
     final TextEditingController searchCtrl = TextEditingController();
     
     showGeneralDialog(
       context: context,
       barrierDismissible: true,
       barrierLabel: "Close",
       transitionDuration: const Duration(milliseconds: 200),
       pageBuilder: (ctx, anim1, anim2) {
         return Scaffold(
           backgroundColor: Colors.black.withOpacity(0.95),
           body: SafeArea(
             child: Column(
               children: [
                 Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Row(
                     children: [
                       IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Get.back()),
                       Expanded(
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16),
                           decoration: BoxDecoration(
                             color: Colors.white.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: TextField(
                             controller: searchCtrl,
                             style: const TextStyle(color: Colors.white),
                             autofocus: true,
                             decoration: const InputDecoration(
                               hintText: "Kullanıcı adı ara...",
                               hintStyle: TextStyle(color: Colors.white54),
                               border: InputBorder.none,
                             ),
                             onChanged: (val) {
                               controller.searchText.value = val;
                             },
                             onSubmitted: (val) => controller.searchUsers(val),
                           ),
                         ),
                       ),
                       const SizedBox(width: 8),
                       IconButton(
                         icon: const Icon(Icons.search, color: Colors.cyanAccent), 
                         onPressed: () => controller.searchUsers(searchCtrl.text)
                       ),
                     ],
                   ),
                 ),
                 Expanded(
                   child: Obx(() {
                     if (controller.isSearching.value) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                     
                     return ListView.builder(
                       itemCount: controller.searchResults.length,
                       itemBuilder: (context, index) {
                         final user = controller.searchResults[index];
                         return ListTile(
                           leading: CircleAvatar(
                             backgroundImage: NetworkImage(user['avatar_url'] ?? "https://ui-avatars.com/api/?name=${user['username']}&background=random")
                           ),
                           title: UserNameText(
                             displayName: user['display_name'] ?? user['username'],
                             isAdmin: user['is_admin'] == true,
                             style: const TextStyle(color: Colors.white)
                           ),
                           subtitle: Text("@${user['username']}", style: const TextStyle(color: Colors.white54)),
                           onTap: () {
                             // Profile Git
                             Get.back();
                             Future.delayed(const Duration(milliseconds: 100), () {
                                Get.to(() => UserProfileScreen(userId: user['id']));
                             });
                           },
                           trailing: ElevatedButton(
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.cyanAccent, 
                               foregroundColor: Colors.black,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                             ),
                             child: const Text("Mesaj"),
                             onPressed: () {
                               Get.back(); // Modalı kapat
                               Future.delayed(const Duration(milliseconds: 100), () {
                                  Get.to(() => ChatScreen(
                                    partnerId: user['id'],
                                    partnerName: user['display_name'] ?? user['username'],
                                    partnerAvatar: user['avatar_url'],
                                  ));
                               });
                             },
                           ),
                         );
                       },
                     );
                   }),
                 ),
               ],
             ),
           ),
         );
       },
     );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;
  final int badgeCount;

  const _HeaderButton({
    required this.icon, 
    required this.text, 
    required this.onTap, 
    this.isActive = false, 
    this.activeColor = Colors.cyanAccent,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Sıkışmayı önle
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: isActive ? activeColor : Colors.white70, size: 16),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text(
                        badgeCount.toString(),
                        style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Flexible( // Text taşmalarını önle
              child: Text(
                text, 
                style: GoogleFonts.inter(
                  fontSize: 12, 
                  color: isActive ? activeColor : Colors.white70,
                  fontWeight: FontWeight.w500
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
