import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:yeniapex/features/posts/controllers/posts_controller.dart';
import 'package:yeniapex/features/posts/widgets/post_card.dart';

class UserPostsScreen extends StatefulWidget {
  final String userId;
  final String displayName;

  const UserPostsScreen({
    super.key,
    required this.userId,
    required this.displayName,
  });

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  late final PostsController postsController;
  final authController = Get.find<AuthController>();
  
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;
  bool isOwner = false;

  @override
  void initState() {
    super.initState();
    // Controller yoksa oluştur, varsa mevcut olanı kullan
    postsController = Get.put(PostsController());
    isOwner = authController.currentUser.value?.id == widget.userId;
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => isLoading = true);
    
    final result = await postsController.fetchUserPosts(widget.userId);
    
    setState(() {
      posts = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const StarBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
                // Posts List
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : posts.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadPosts,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: posts.length,
                                itemBuilder: (context, index) {
                                  final post = posts[index];
                                  return PostCard(
                                    post: post,
                                    isOwner: isOwner,
                                    onDelete: isOwner ? () => _showDeleteConfirm(post) : null,
                                    onVisibilityChange: isOwner ? () => _showVisibilitySheet(post) : null,
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: GlassmorphicContainer(
              width: 44,
              height: 44,
              borderRadius: 22,
              blur: 10,
              alignment: Alignment.center,
              border: 1,
              linearGradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.1)],
              ),
              borderGradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          Column(
            children: [
              Text(
                "${widget.displayName}",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "${posts.length} Paylaşım",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.fileText,
            size: 64,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            isOwner ? "Henüz paylaşım yapmadınız" : "Henüz paylaşım yok",
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(Map<String, dynamic> post) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Postu Sil", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Bu postu silmek istediğinize emin misiniz?", style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text("İptal", style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await postsController.deletePost(post['id'], post['image_url']);
              _loadPosts(); // Refresh
            },
            child: Text("Sil", style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showVisibilitySheet(Map<String, dynamic> post) {
    final currentVisibility = post['visibility'] ?? 'public';
    
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              "Gizlilik Ayarı",
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            _buildVisibilityOption(
              icon: LucideIcons.globe,
              title: "Herkese Açık",
              subtitle: "Herkes görebilir",
              isSelected: currentVisibility == 'public',
              onTap: () async {
                Get.back();
                await postsController.updatePostVisibility(post['id'], 'public');
                _loadPosts();
              },
            ),
            const SizedBox(height: 12),
            _buildVisibilityOption(
              icon: LucideIcons.users,
              title: "Sadece Arkadaşlar",
              subtitle: "Karşılıklı takipleşenler görebilir",
              isSelected: currentVisibility == 'friends',
              onTap: () async {
                Get.back();
                await postsController.updatePostVisibility(post['id'], 'friends');
                _loadPosts();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildVisibilityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : Colors.white54, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
