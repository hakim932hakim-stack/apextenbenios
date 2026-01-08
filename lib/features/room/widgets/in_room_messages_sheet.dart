import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/features/messages/controllers/messages_controller.dart';
import 'package:yeniapex/features/messages/screens/chat_screen.dart';
import 'package:yeniapex/core/widgets/user_name_text.dart';

/// Oda içinden erişilebilen mini mesajlar popup'ı
class InRoomMessagesSheet extends StatefulWidget {
  const InRoomMessagesSheet({super.key});

  @override
  State<InRoomMessagesSheet> createState() => _InRoomMessagesSheetState();
}

class _InRoomMessagesSheetState extends State<InRoomMessagesSheet> {
  late final MessagesController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<MessagesController>();
    // Popup açıldığında badge'i temizle
    controller.clearUnreadNotification();
    // Listeyi yenile
    controller.fetchConversations();
  }

  @override
  void dispose() {
    // Popup kapanırken klavyeyi kapat (Garanti olsun)
    FocusManager.instance.primaryFocus?.unfocus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * 0.45, // ShareRoomSheet ile aynı
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black, // Siyah tema
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // 1. Tutamaç
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // 2. Başlık
          Row(
            children: [
              const Icon(LucideIcons.messageCircle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                "Mesajlar",
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // 3. Mesaj Listesi
          Expanded(
            child: Obx(() {
              if (controller.isLoadingInbox.value) {
                return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2));
              }

              if (controller.conversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.messageSquare, size: 40, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 12),
                      Text("Henüz mesajın yok", style: TextStyle(color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: controller.conversations.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final chat = controller.conversations[index];
                  final user = chat['user'];
                  String lastMessage = chat['last_message'] ?? '';
                  
                  // Görsel ve davet kontrolü
                  if (lastMessage.startsWith('http') && lastMessage.contains('chat_images')) {
                    lastMessage = "📷 Görsel";
                  } else if (lastMessage.startsWith("[ROOM_INVITE]")) {
                    lastMessage = "📩 Oda daveti";
                  }
                  
                  final unreadCount = chat['unread_count'] as int? ?? 0;

                  return GestureDetector(
                    onTap: () {
                      Get.back(); // Popup'ı kapat
                      Get.to(() => ChatScreen(
                        partnerId: user['id'],
                        partnerName: user['display_name'] ?? user['username'] ?? 'User',
                        partnerAvatar: user['avatar_url'],
                      ));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[900],
                            backgroundImage: CachedNetworkImageProvider(
                              user['avatar_url'] ?? "https://ui-avatars.com/api/?name=${user['username']}&background=random"
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // İsim ve Son Mesaj
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserNameText(
                                  displayName: user['display_name'] ?? user['username'] ?? 'Kullanıcı',
                                  isAdmin: user['is_admin'] == true,
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontWeight: FontWeight.w600, 
                                    fontSize: 14
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lastMessage,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Okunmamış Badge
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
