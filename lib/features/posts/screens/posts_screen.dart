import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/posts/controllers/posts_controller.dart';
import 'package:yeniapex/features/posts/widgets/post_card.dart';
import 'package:yeniapex/features/posts/widgets/create_post_section.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:yeniapex/features/home/screens/home_screen.dart'; // 🔥 Global callback için

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PostsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(PostsController());
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                // --- HEADER ---
                _buildHeader(),
                
                // --- CREATE POST SECTION ---
                const CreatePostSection(),
                
                // --- TABS ---
                _buildTabs(),
                
                // --- CONTENT ---
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Popüler (Tüm Postlar)
                      _buildPostList(isMyPosts: false),
                      
                      // TAB 2: Benim
                      _buildPostList(isMyPosts: true),
                    ],
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
          Text(
            "PAYLAŞIMLAR",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 44), // Balance
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 50,
        borderRadius: 25,
        blur: 15,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
        ),
        borderGradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.5), AppColors.primary.withOpacity(0.3)],
            ),
          ),
          dividerColor: Colors.transparent,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: "POPÜLER"),
            Tab(text: "BENİM"),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList({required bool isMyPosts}) {
    return Obx(() {
      final posts = isMyPosts ? controller.myPosts : controller.publicPosts;
      final isLoading = controller.isLoading.value;
      final isLoadingMore = controller.isLoadingMore.value;
      final hasMore = isMyPosts ? controller.hasMoreMy.value : controller.hasMorePublic.value;

      if (isLoading && posts.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      if (posts.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMyPosts ? LucideIcons.fileText : LucideIcons.globe,
                size: 64,
                color: Colors.white24,
              ),
              const SizedBox(height: 16),
              Text(
                isMyPosts ? "Henüz paylaşımın yok" : "Henüz paylaşım yok",
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          // Liste sonuna yaklaştığında daha fazla yükle
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            if (!isLoadingMore && hasMore) {
              if (isMyPosts) {
                controller.fetchMyPosts();
              } else {
                controller.fetchPublicPosts();
              }
            }
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            if (isMyPosts) {
              await controller.fetchMyPosts(refresh: true);
            } else {
              await controller.fetchPublicPosts(refresh: true);
            }
          },
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: posts.length + (hasMore ? 1 : 0), // Alt yükleme göstergesi için +1
            itemBuilder: (context, index) {
              // Son item = loading indicator
              if (index == posts.length) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: isLoadingMore
                        ? const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)
                        : const SizedBox.shrink(),
                  ),
                );
              }
              
              final post = posts[index];
              // Postun sahibi mi kontrol et (Popüler'de de kendi postlarını yönetebilsin)
              final currentUserId = controller.supabase.auth.currentUser?.id;
              final postUserId = post['user_id'];
              final isPostOwner = currentUserId != null && currentUserId == postUserId;
              
              return PostCard(
                post: post,
                isOwner: isPostOwner,
                onDelete: isPostOwner ? () => _showDeleteConfirm(post) : null,
                onVisibilityChange: isPostOwner ? () => _showVisibilitySheet(post) : null,
              );
            },
          ),
        ),
      );
    });
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
            onPressed: () {
              Get.back();
              controller.deletePost(post['id'], post['image_url']);
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
              onTap: () {
                Get.back();
                controller.updatePostVisibility(post['id'], 'public');
              },
            ),
            const SizedBox(height: 12),
            _buildVisibilityOption(
              icon: LucideIcons.users,
              title: "Sadece Arkadaşlar",
              subtitle: "Karşılıklı takipleşenler görebilir",
              isSelected: currentVisibility == 'friends',
              onTap: () {
                Get.back();
                controller.updatePostVisibility(post['id'], 'friends');
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
