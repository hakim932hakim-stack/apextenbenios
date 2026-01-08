import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:yeniapex/features/posts/widgets/full_image_viewer.dart';
import 'package:yeniapex/features/profile/screens/user_profile_screen.dart';
import 'package:yeniapex/features/posts/controllers/posts_controller.dart';
import 'package:yeniapex/features/posts/widgets/comments_sheet.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isOwner;
  final VoidCallback? onDelete;
  final VoidCallback? onVisibilityChange;

  const PostCard({
    super.key,
    required this.post,
    this.isOwner = false,
    this.onDelete,
    this.onVisibilityChange,
  });

  @override
  Widget build(BuildContext context) {
    final profile = post['profile'] as Map<String, dynamic>?;
    final username = profile?['username'] ?? 'Kullanıcı';
    final displayName = profile?['display_name'] ?? username;
    final avatarUrl = profile?['avatar_url'] ?? 'https://ui-avatars.com/api/?name=$username&background=random';
    final content = post['content'] ?? '';
    final imageUrl = post['image_url'];
    final visibility = post['visibility'] ?? 'public';
    final createdAt = DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();
    final userId = profile?['id'] ?? post['user_id'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Avatar + Name + Time + Options)
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () => Get.to(() => UserProfileScreen(userId: userId)),
                child: Stack(
                  children: [
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.grey[800]),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.person, color: Colors.white54, size: 24),
                        ),
                      ),
                    ),
                    // Online dot
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Name & Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Get.to(() => UserProfileScreen(userId: userId)),
                          child: Text(
                            displayName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          visibility == 'public' ? LucideIcons.globe : LucideIcons.users,
                          size: 14,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeago.format(createdAt, locale: 'tr'),
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              // More Options
              if (isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 24),
                  color: AppColors.backgroundLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'delete' && onDelete != null) {
                      onDelete!();
                    } else if (value == 'visibility' && onVisibilityChange != null) {
                      onVisibilityChange!();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'visibility',
                      child: Row(
                        children: [
                          Icon(
                            visibility == 'public' ? LucideIcons.users : LucideIcons.globe,
                            size: 18,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            visibility == 'public' ? "Arkadaşlara Özel Yap" : "Herkese Açık Yap",
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Text("Sil", style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 24),
                  color: AppColors.backgroundLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'report') {
                      Get.snackbar(
                        'Rapor Gönderildi',
                        'Bu gönderi incelenmek üzere bildirildi',
                        backgroundColor: Colors.orange,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          const Icon(LucideIcons.flag, size: 18, color: Colors.orangeAccent),
                          const SizedBox(width: 10),
                          Text(
                            "Rapor Et",
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Content Text
          if (content.isNotEmpty)
            Text(
              content,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          
          // Image Thumbnail (Görüntüdeki gibi küçük kare)
          if (imageUrl != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Get.to(() => FullImageViewer(imageUrl: imageUrl)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 150, // Küçük thumbnail
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 150,
                    height: 150,
                    color: Colors.grey[900],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 150,
                    height: 150,
                    color: Colors.grey[900],
                    child: const Icon(LucideIcons.imageOff, color: Colors.white38, size: 32),
                  ),
                ),
              ),
            ),
          ],
          
          // Divider
          const SizedBox(height: 24), // Daha da aşağı
          // ACTIONS ROW (Etkileşimler)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // LIKE BUTONU
                GestureDetector(
                  onTap: () {
                    Get.find<PostsController>().toggleLike(post['id']);
                  },
                  child: Container( // Tıklama alanı genişletme için
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            (post['is_liked'] ?? false) ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey((post['is_liked'] ?? false)),
                            color: (post['is_liked'] ?? false) ? Colors.redAccent : Colors.white70,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${post['likes_count'] ?? 0}",
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // COMMENT BUTONU
                GestureDetector(
                  onTap: () {
                    Get.bottomSheet(
                       CommentsSheet(postId: post['id']),
                       isScrollControlled: true,
                    );
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.messageCircle, color: Colors.white70, size: 24),
                        const SizedBox(width: 6),
                        Text(
                          "${post['comments_count'] ?? 0}",
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
        ],
      ),
    );
  }
}
