import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/home/controllers/home_controller.dart';
import 'package:yeniapex/features/messages/controllers/messages_controller.dart'; 
import 'package:yeniapex/features/notifications/controllers/notifications_controller.dart';
import 'package:yeniapex/features/home/widgets/home_header.dart';
import 'package:yeniapex/features/home/widgets/room_card.dart';

import 'package:yeniapex/features/profile/screens/profile_screen.dart';
import 'package:yeniapex/features/messages/screens/messages_screen.dart';
import 'package:yeniapex/features/home/screens/notifications_screen.dart';
import 'package:yeniapex/features/posts/screens/posts_screen.dart';

// Back navigation için global referansa gerek kalmadı (Get.to yapısı)

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller'ı başlat
    final controller = Get.put(HomeController());
    // 🔥 Mesaj dinleyicisini başlat (Global kalmasında fayda var)
    Get.put(MessagesController());
    // 🔥 Bildirim controller'ını başlat (Badge için)
    Get.put(NotificationsController());

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      
      // ODA OLUŞTURMA BUTONU
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 160, right: 10),
        child: SizedBox(
          width: 84,
          height: 84,
          child: FloatingActionButton(
            onPressed: () {
               controller.createRoom();
            },
            backgroundColor: Colors.white,
            elevation: 10,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.add_rounded, 
              color: Colors.black,
              size: 48,
            ),
          ),
        ),
      ),
      
      body: Stack(
        children: [
          // 1. Animated Background
          const StarBackground(),
          
          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                // Header (Sayfalar arası geçişi yönetir)
                HomeHeader(
                  // currentPage artık 0 çünkü burası ana sayfa. Diğerlerine gidince yeni sayfa açılacak.
                  // Ama header'da active state göstermek istiyorsan, bu sayfada hiçbiri aktif değil.
                  currentPage: 0, 
                  onProfileTap: () {
                    Get.to(() => const ProfileScreen());
                  },
                  onMessagesTap: () {
                    Get.to(() => const MessagesScreen());
                  },
                  onPostsTap: () {
                    Get.to(() => const PostsScreen());
                  },
                  onNotificationsTap: () {
                    Get.to(() => const NotificationsScreen());
                  },
                ),

                // 🔥 Rooms List (Tek Sayfa)
                Expanded(
                  child: _buildRoomsList(controller),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Rooms Listesi
  Widget _buildRoomsList(HomeController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      if (controller.rooms.isEmpty) {
        return RefreshIndicator(
          onRefresh: controller.fetchRooms,
          color: Colors.cyanAccent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
               SizedBox(height: Get.height * 0.3),
               Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 48, color: Colors.white54),
                    const SizedBox(height: 16),
                    Text(
                      "Henüz aktif oda yok",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.fetchRooms,
        color: AppColors.primary,
        backgroundColor: AppColors.background,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: controller.rooms.length,
          itemBuilder: (context, index) {
            final room = controller.rooms[index];
            
            // Verileri ayıkla
            final owner = room['owner'];
            final participants = List.from(room['participants'] ?? []);
            final videoStateRaw = room['video_state'];
            Map<String, dynamic>? videoState;
            
            try {
              if (videoStateRaw is List && videoStateRaw.isNotEmpty) {
                videoState = videoStateRaw[0] as Map<String, dynamic>?;
              } else if (videoStateRaw is Map) {
                videoState = videoStateRaw as Map<String, dynamic>?;
              }
            } catch (_) {}

            final hasActiveVideo = videoState != null && 
                                 videoState['video_url'] != null && 
                                 videoState['video_url'].toString().trim().isNotEmpty;
            
            String thumbnail = room['thumbnail_url'] ?? '';
            if (room['cover_image_url'] != null) thumbnail = room['cover_image_url'];
            if (hasActiveVideo && videoState['thumbnail_url'] != null) thumbnail = videoState['thumbnail_url'];

            final title = owner?['display_name'] ?? owner?['username'] ?? room['title'] ?? 'Oda';
            final bool creatorIsAdmin = owner?['is_admin'] == true; // 🌈 Oda sahibi admin mi?
            String subtitle = room['subtitle'] ?? '';
            if (hasActiveVideo && videoState['video_title'] != null) {
              subtitle = videoState['video_title'];
            }

            final avatarUrls = participants
                .map((p) => p['profile']?['avatar_url']?.toString() ?? '')
                .where((url) => url.isNotEmpty)
                .toList();

            return RoomCard(
              key: ValueKey("${room['id']}_$thumbnail"),
              title: title,
              subtitle: subtitle,
              thumbnailUrl: thumbnail.isNotEmpty ? thumbnail : null,
              userCount: participants.length,
              avatarUrls: List<String>.from(avatarUrls),
              isLocked: room['is_locked'] ?? false,
              hasActiveVideo: hasActiveVideo,
              isBanned: room['is_banned'] ?? false,
              creatorIsAdmin: creatorIsAdmin, // 🌈 Admin bilgisini ilet
              onTap: () => controller.joinRoom(room['id']),
            );
          },
        ),
      );
    });
  }
}
