import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/features/profile/screens/user_profile_screen.dart';

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;

  const NotificationCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final actorProfile = notification['actor_profile'] as Map<String, dynamic>?;
    final type = notification['type'] as String;
    final isRead = notification['is_read'] as bool? ?? true;
    final createdAt = DateTime.tryParse(notification['created_at'] ?? '') ?? DateTime.now();
    
    // Sistem bildirimi kontrolü
    final isSystem = type == 'system';
    
    final actorUsername = actorProfile?['username'] ?? 'Kullanıcı';
    final displayName = isSystem ? 'APEX Ekibi' : (actorProfile?['display_name'] ?? actorUsername);
    final actorAvatarUrl = actorProfile?['avatar_url'] ?? 
        'https://ui-avatars.com/api/?name=$actorUsername&background=random';
    final actorId = notification['actor_id'] as String?;

    // Mesaj oluştur
    String message = '';
    if (type == 'post_like') {
      message = 'postunuzu beğendi';
    } else if (type == 'post_comment') {
      final commentContent = notification['content'] as String? ?? '';
      final truncated = commentContent.length > 50 
          ? '${commentContent.substring(0, 50)}...' 
          : commentContent;
      message = 'postunuza yorum yaptı: "$truncated"';
    } else if (isSystem) {
      message = notification['content'] ?? '';
    } else {
      message = notification['content'] ?? 'Bildirim';
    }

    return GestureDetector(
      onTap: actorId != null 
          ? () => Get.to(() => UserProfileScreen(userId: actorId))
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? Colors.transparent : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            isSystem 
            ? Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.bell, color: AppColors.primary, size: 20),
              )
            : CircleAvatar(
                radius: 22,
                backgroundImage: CachedNetworkImageProvider(actorAvatarUrl),
              ),
            const SizedBox(width: 12),
            
            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İsim + Mesaj
                  RichText(
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                      children: [
                        TextSpan(
                          text: displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextSpan(text: isSystem ? ' $message' : ' $message'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Zaman
                  Text(
                    timeago.format(createdAt, locale: 'tr'),
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            // Okunmamış göstergesi
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
