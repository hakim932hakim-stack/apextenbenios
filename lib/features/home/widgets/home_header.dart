import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:yeniapex/features/messages/controllers/messages_controller.dart';
import 'package:yeniapex/features/notifications/controllers/notifications_controller.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback onProfileTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onPostsTap;
  final int currentPage; // 🔥 Aktif sayfa

  const HomeHeader({
    super.key,
    required this.onProfileTap,
    required this.onMessagesTap,
    required this.onNotificationsTap,
    required this.onPostsTap,
    this.currentPage = 1, // Default: Rooms
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        bottom: 10,
      ),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Profil (Sol) - Sadece Avatar
          GestureDetector(
            onTap: onProfileTap,
            child: Obx(() {
              final authController = Get.find<AuthController>();
              final user = authController.currentUser.value;
              final profile = authController.currentProfile.value;
              final avatarUrl = profile?['avatar_url'] ?? user?.userMetadata?['avatar_url'] ?? 'https://ui-avatars.com/api/?name=User&background=random';

              return Container(
                width: 40, 
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                ),
              );
            }),
          ),

          // 2. APEX Logos (Orta) - REMOVED
          const Spacer(),

          // Right: Icons
          Row(
            children: [
              // 1️⃣ Mesaj İkonu (1. Sayfa)
              Obx(() {
                 bool showDot = false;
                 if (Get.isRegistered<MessagesController>()) {
                    showDot = Get.find<MessagesController>().hasUnreadMessages.value;
                 }
                 
                 return _HeaderImageButton(
                   imagePath: 'assets/icons/ic_message.png',
                   hasUnread: showDot,
                   isActive: currentPage == 1,
                   onTap: onMessagesTap
                 );
              }),
              
              const SizedBox(width: 16),
              
              // 2️⃣ Post İkonu (2. Sayfa)
              _HeaderImageButton(
                imagePath: 'assets/icons/ic_post.png',
                hasUnread: false,
                isActive: currentPage == 2,
                onTap: onPostsTap,
              ),
              
              const SizedBox(width: 16),
              
              // 3️⃣ Bildirim İkonu (3. Sayfa)
              Obx(() {
                 bool showDot = false;
                 if (Get.isRegistered<NotificationsController>()) {
                    showDot = Get.find<NotificationsController>().unreadCount.value > 0;
                 }
                 
                 return Padding(
                   padding: const EdgeInsets.only(top: 2), // 1 tık aşağı
                   child: _HeaderImageButton(
                     imagePath: 'assets/icons/ic_notification.png',
                     hasUnread: showDot,
                     isActive: currentPage == 3,
                     onTap: onNotificationsTap,
                   ),
                 );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// Özel görsel ikon butonu
class _HeaderImageButton extends StatelessWidget {
  final String imagePath;
  final bool hasUnread;
  final bool isActive;
  final VoidCallback onTap;

  const _HeaderImageButton({
    required this.imagePath,
    required this.hasUnread,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Tüm alan tıklanabilir
      child: Padding(
        padding: const EdgeInsets.all(8), // Tıklama alanını genişlet
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              imagePath,
              width: 24,
              height: 24,
              color: Colors.white, // Renk korunuyor
            ),
            if (hasUnread)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
