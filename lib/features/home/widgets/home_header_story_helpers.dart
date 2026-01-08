import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:yeniapex/features/stories/controllers/story_controller.dart';
import 'package:yeniapex/features/stories/screens/story_view_screen.dart';

void showProfileOptions(BuildContext context, StoryController controller, VoidCallback onProfileTap) {
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
          Container(
            width: 40, height: 4, 
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))
          ),
          const SizedBox(height: 24),
          
          _buildOptionItem(
            icon: LucideIcons.user,
            text: "Profil Fotoğrafını Gör",
            onTap: () {
               Get.back();
               final authController = Get.find<AuthController>();
               final user = authController.currentUser.value;
               final profile = authController.currentProfile.value;
               final avatarUrl = profile?['avatar_url'] ?? user?.userMetadata?['avatar_url'] ?? 'https://ui-avatars.com/api/?name=User&background=random';
               showProfilePhoto(context, avatarUrl);
            }
          ),
          
          if (controller.hasActiveStory.value)
             _buildOptionItem(
              icon: LucideIcons.eye,
              text: "Hikayeyi Gör",
              onTap: () {
                 Get.back();
                 Get.to(() => StoryViewScreen(stories: controller.myStories, isOwner: true));
              },
            ),

          // Eğer hikaye varsa KALDIR, yoksa EKLE
          if (controller.hasActiveStory.value)
             _buildOptionItem(
                icon: LucideIcons.trash2, 
                text: "Hikayeyi Kaldır", 
                onTap: () {
                   Get.back();
                   // İlk hikayeyi sil (zaten 1 tane var kuralı)
                   final story = controller.myStories.first;
                   controller.deleteStory(story['id'], story['media_url']);
                }
             )
          else
            _buildOptionItem(
              icon: LucideIcons.plusCircle,
              text: "Hikaye Ekle",
              onTap: () {
                 Get.back();
                 _showAddStorySheet(context, controller);
              },
            ),
             
          // Profil Ayarları kaldırıldı
        ],
      ),
    ),
  );
}

Widget _buildOptionItem({required IconData icon, required String text, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            child: Icon(icon, color: Colors.white, size: 24)
          ),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

void _showAddStorySheet(BuildContext context, StoryController controller) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Hikaye Ekle", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMediaOption(
                icon: LucideIcons.image, 
                label: "Fotoğraf", 
                onTap: () { Get.back(); controller.pickAndUploadStory(isVideo: false); }
              ),
              _buildMediaOption(
                icon: LucideIcons.video, 
                label: "Video (20sn)", 
                onTap: () { Get.back(); controller.pickAndUploadStory(isVideo: true); }
              ),
            ],
          )
        ],
      ),
    ),
  );
}

Widget _buildMediaOption({required IconData icon, required String label, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
          child: Icon(icon, color: Colors.cyanAccent, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    ),
  );
}

void showProfilePhoto(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (context) => GestureDetector(
      onTap: () => Get.back(),
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: Center(
          child: Hero(
            tag: 'profile_photo_header',
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.cyanAccent),
                errorWidget: (context, url, err) => const Icon(Icons.person, size: 50, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
