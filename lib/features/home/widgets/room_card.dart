import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lottie/lottie.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/core/widgets/user_name_text.dart';

class RoomCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final int userCount;
  final List<String> avatarUrls;
  final bool isLocked;
  final bool hasActiveVideo;
  final bool isBanned; // Yasaklı mı?
  final bool creatorIsAdmin; // 🌈 Oda sahibi admin mi?
  final VoidCallback onTap;

  const RoomCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.thumbnailUrl,
    required this.userCount,
    required this.avatarUrls,
    this.isLocked = false,
    this.hasActiveVideo = false,
    this.isBanned = false,
    this.creatorIsAdmin = false, // 🌈 Default false
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 96, // React: h-24 (96px)
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), // React: bg-white/3
        borderRadius: BorderRadius.circular(16), // React: rounded-2xl
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
            children: [
              Row(
                children: [
                  // 1. Thumbnail (Left - 16:9 Aspect Ratio)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: const BoxDecoration(
                         borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                         ),
                         color: Colors.black,
                      ),
                      clipBehavior: Clip.antiAlias, // Clip for rounded corners
                      child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.black12),
                              errorWidget: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  
                  // 2. Content (Right)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top: Owner Name & Video Title
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Owner Name
                              Row(
                                children: [
                                  Flexible(
                                    child: UserNameText(
                                      displayName: title,
                                      isAdmin: creatorIsAdmin,
                                      style: GoogleFonts.inter(
                                        color: Colors.white, 
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 2),
                              
                              // Subtitle / Video Title
                              if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: hasActiveVideo ? const Color(0xFFF87171) : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          
                          // Bottom: Avatars & Count
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Avatars Stack (Max 4 now)
                              if (avatarUrls.isNotEmpty)
                                SizedBox(
                                  height: 26,
                                  width: (avatarUrls.take(4).length * 18.0) + 12,
                                  child: Stack(
                                    children: List.generate(avatarUrls.take(4).length, (index) {
                                      return Positioned(
                                        left: index * 18.0,
                                        child: Container(
                                          width: 26, height: 26,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                          ),
                                          child: ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: avatarUrls[index],
                                              fit: BoxFit.cover,
                                              placeholder: (_,__) => Container(color: Colors.grey[800]),
                                              errorWidget: (_,__,___) => Container(color: Colors.grey[800]),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),

                                
                              const Spacer(),
                              
                              // User Count & Eye Icon
                              Row(
                                children: [
                                  Text(
                                    "$userCount",
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Lottie.asset(
                                      'assets/animations/live_indicator.json',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Lock Badge (Top Right)
              if (isLocked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5), // Siyah transparan arka plan
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                    ),
                    child: const Icon(LucideIcons.lock, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          "APEX",
          style: GoogleFonts.blackOpsOne(
            color: Colors.white54,
            fontSize: 20,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
