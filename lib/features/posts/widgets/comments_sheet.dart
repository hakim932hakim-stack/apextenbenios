import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/features/posts/controllers/posts_controller.dart';
import 'package:yeniapex/features/profile/screens/user_profile_screen.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final controller = Get.find<PostsController>();
  final TextEditingController commentController = TextEditingController();
  final RxList<Map<String, dynamic>> comments = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSending = false.obs;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    isLoading.value = true;
    final data = await controller.fetchComments(widget.postId);
    comments.value = data;
    isLoading.value = false;
  }

  Future<void> _sendComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;

    isSending.value = true;
    await controller.addComment(widget.postId, text);
    commentController.clear();
    // Yorumları yenile
    await _loadComments();
    isSending.value = false;
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Text(
            "Yorumlar",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),

          // Comment List
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (comments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.messageCircle, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        "Henüz yorum yok.\nİlk yorumu sen yap!",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white54),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  final profile = comment['profile'] ?? {};
                  final username = profile['username'] ?? 'User';
                  final displayName = profile['display_name'] ?? username;
                  final avatarUrl = profile['avatar_url'] ?? "https://ui-avatars.com/api/?name=$username&background=random";
                  final content = comment['content'] ?? '';
                  // created_at parse logic already in _formatTime
                  final userId = comment['user_id'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: () => Get.to(() => UserProfileScreen(userId: userId)),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundImage: CachedNetworkImageProvider(avatarUrl),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // İçerik
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTime(comment['created_at']),
                                    style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                content,
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          
          // Input Area (Sabit Pozisyon)
          Column(
            children: [
              const SizedBox(height: 10),
              Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: TextField(
                          controller: commentController,
                          style: GoogleFonts.inter(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Yorum yaz...",
                            hintStyle: GoogleFonts.inter(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Obx(() => GestureDetector(
                      onTap: isSending.value ? null : _sendComment,
                      child: isSending.value 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
                          ),
                    )),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final localDate = date.toLocal();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }
}
