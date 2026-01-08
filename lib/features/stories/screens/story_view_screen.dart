import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago; // timeago eklenmeli (pubspec gerekebilir ama manuel yazarız)
import 'package:yeniapex/features/stories/controllers/story_controller.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  final bool isOwner;
  final Map<String, dynamic>? userProfile; // Show this user's info

  const StoryViewScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    this.isOwner = false,
    this.userProfile,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  final StoryController _storyController = Get.find<StoryController>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadStory(widget.stories[_currentIndex]);
  }

  void _loadStory(Map<String, dynamic> story) {
    _videoController?.dispose();
    _videoController = null;

    if (story['media_type'] == 'video' && story['media_url'] != null) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(story['media_url']))
        ..initialize().then((_) {
          if (mounted) {
             setState(() {});
             _videoController!.play();
          }
        });
    }
    
    // 🔥 İzleme Takibi (View Tracking)
    if (!widget.isOwner) {
       _storyController.markStoryAsViewed(story['id']);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _loadStory(widget.stories[index]);
  }

  void _deleteCurrentStory() async {
    final story = widget.stories[_currentIndex];
    await _storyController.deleteStory(story['id'], story['media_url']);
    Get.back(); // Hikaye ekranını kapat
  }
  
  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    final dateTime = DateTime.parse(dateTimeStr).toLocal();
    final diff = DateTime.now().difference(dateTime);

    if (diff.inDays > 0) return '${diff.inDays}g';
    if (diff.inHours > 0) return '${diff.inHours}sa';
    if (diff.inMinutes > 0) return '${diff.inMinutes}dk';
    return 'Şimdi';
  }
  
  // İzleyenleri göster
  void _showViewersSheet(String storyId) async {
    // Verileri çek
    final viewers = await _storyController.getStoryViewers(storyId);
    
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             Text("${viewers.length} Görüntülenme", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
             const SizedBox(height: 16),
             Expanded(
               child: viewers.isEmpty 
               ? const Center(child: Text("Henüz kimse görmedi", style: TextStyle(color: Colors.white54)))
               : ListView.builder(
                   itemCount: viewers.length,
                   itemBuilder: (context, index) {
                      final v = viewers[index];
                      final viewerProfile = v['viewer'] ?? {};
                      final viewedAt = v['viewed_at']; // Formatlanabilir
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(viewerProfile['avatar_url'] ?? 'https://ui-avatars.com/api/?name=User'),
                        ),
                        title: Text(viewerProfile['display_name'] ?? 'Kullanıcı', style: const TextStyle(color: Colors.white)),
                        trailing: Text(
                          viewedAt != null ? _formatViewTime(viewedAt) : '', 
                          style: const TextStyle(color: Colors.white54, fontSize: 12)
                        ),
                      );
                   },
                 ),
             )
          ],
        ),
      ),
    );
  }

  // Saat Formatlayıcı (13:04 -> 16:04 gibi yerel saate çevirir)
  String _formatViewTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const SizedBox.shrink();

    final currentStory = widget.stories[_currentIndex];
    final isVideo = currentStory['media_type'] == 'video';
    final timeAgo = _getTimeAgo(currentStory['created_at']);
    
    // User Bilgileri (Parametreden veya Auth'dan)
    String avatarUrl = 'https://ui-avatars.com/api/?name=User';
    String username = 'Kullanıcı';
    
    if (widget.userProfile != null) {
       avatarUrl = widget.userProfile!['avatar_url'] ?? avatarUrl;
       username = widget.userProfile!['display_name'] ?? widget.userProfile!['username'] ?? username;
    } else if (widget.isOwner) {
       final currentUser = Get.find<AuthController>().currentProfile.value;
       if (currentUser != null) {
          avatarUrl = currentUser['avatar_url'] ?? avatarUrl;
          username = currentUser['display_name'] ?? currentUser['username'] ?? username;
       }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Medya
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              final isVideoItem = story['media_type'] == 'video';
              
              if (isVideoItem) {
                if (_videoController != null && _videoController!.value.isInitialized) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
              } else {
                 return CachedNetworkImage(
                   imageUrl: story['media_url'],
                   fit: BoxFit.contain,
                   placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                 );
              }
            },
          ),
          
          // --- HEADER (Avatar + İsim) ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   // Profil
                   Row(
                     children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(avatarUrl),
                          backgroundColor: Colors.grey[800],
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [BoxShadow(blurRadius: 2, color: Colors.black)])),
                            Text(timeAgo, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500, shadows: [BoxShadow(blurRadius: 2, color: Colors.black)])),
                          ],
                        ),
                     ],
                   ),
                   
                   // Kapat
                   IconButton(
                     icon: const Icon(Icons.close, color: Colors.white, size: 28),
                     onPressed: () => Get.back(),
                   ),
                ],
              ),
            ),
          ),
          
          // --- FOOTER (Owner: View Count / Delete) ---
          if (widget.isOwner)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 // 👁️ Görüntüleyenler
                 GestureDetector(
                   onTap: () => _showViewersSheet(currentStory['id']),
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                     child: const Row(
                       children: [
                          Icon(LucideIcons.eye, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text("Görüntüleyenler", style: TextStyle(color: Colors.white))
                       ],
                     ),
                   ),
                 ),

                 // 🗑️ Sil
                 IconButton(
                   onPressed: _deleteCurrentStory,
                   icon: const Icon(Icons.delete, color: Colors.white, size: 28),
                 ), 
              ],
            ),
          ),
        ],
      ),
    );
  }
}
