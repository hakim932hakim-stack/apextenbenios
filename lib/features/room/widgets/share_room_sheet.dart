import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/features/room/controllers/room_controller.dart';
import 'package:yeniapex/core/app_colors.dart';

class ShareRoomSheet extends StatefulWidget {
  final RoomController controller;
  const ShareRoomSheet({super.key, required this.controller});

  @override
  State<ShareRoomSheet> createState() => _ShareRoomSheetState();
}

class _ShareRoomSheetState extends State<ShareRoomSheet> {
  late final RoomController controller;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    // Popup açıldığında arkadaşları yükle
    controller.fetchMutualFriends();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * 0.45, // 🔥 Yükseklik daha da azaltıldı
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black, // 🔥 Kullanıcı isteği: Tam Siyah
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // 1. Tutamaç & Başlık
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Arkadaşlarını Davet Et",
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              
              // Tümünü Davet Et (Küçültüldü)
              TextButton.icon(
                onPressed: controller.sendInviteToAll,
                icon: const Icon(LucideIcons.send, color: Colors.cyanAccent, size: 14), // İkon Küçüldü
                label: Text("Tümünü Davet Et", style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 11)), // Font Küçüldü
                style: TextButton.styleFrom(
                  backgroundColor: Colors.cyanAccent.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Padding Azaldı
                  minimumSize: Size.zero, 
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Boşlukları al
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // 2. Arama Çubuğu
          Container(
            height: 40, // Yükseklik sabitlendi
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: controller.filterFriends,
              decoration: InputDecoration(
                hintText: "Kullanıcı adı veya isim ara...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                border: InputBorder.none,
                icon: const Icon(LucideIcons.search, color: Colors.white38, size: 18),
                contentPadding: const EdgeInsets.only(bottom: 8), // Hizalama
              ),
            ),
          ),
          
          const SizedBox(height: 12),

          // 3. Arkadaş Listesi
          Expanded(
            child: Obx(() {
              if (controller.isLoadingFriends.value) {
                return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2));
              }

              if (controller.friendsList.isEmpty) {
                 return Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(LucideIcons.users, size: 40, color: Colors.white.withOpacity(0.1)),
                       const SizedBox(height: 12),
                       Text("Listen boş.", style: TextStyle(color: Colors.white24, fontSize: 12)),
                     ],
                   ),
                 );
              }

              if (controller.filteredFriendsList.isEmpty) {
                return const Center(child: Text("Sonuç yok", style: TextStyle(color: Colors.white24, fontSize: 12)));
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(), // Kaydırma efekti
                itemCount: controller.filteredFriendsList.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final user = controller.filteredFriendsList[index];
                  final isInvited = false.obs;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), // Arkadaki kutu kalktı, sadece padding
                    decoration: const BoxDecoration(
                      color: Colors.transparent, // 🔥 ŞEFFAF OLDU
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[900],
                          backgroundImage: CachedNetworkImageProvider(
                            user['avatar_url'] ?? "https://ui-avatars.com/api/?name=${user['username']}&background=random"
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // İsim
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['display_name'] ?? user['username'],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                "@${user['username']}",
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ),

                        // Davet Et Butonu
                        Obx(() => SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: isInvited.value 
                              ? null 
                              : () async {
                                  isInvited.value = true;
                                  await controller.sendRoomInvite(user['id']);
                                },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isInvited.value ? Colors.white10 : Colors.cyanAccent,
                              foregroundColor: isInvited.value ? Colors.white38 : Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              isInvited.value ? "Davet Edildi" : "Davet Et",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                      ],
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
