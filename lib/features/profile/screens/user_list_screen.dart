import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/profile/screens/user_profile_screen.dart';
import 'package:yeniapex/core/widgets/user_name_text.dart'; // 🌈 Admin Styling

class UserListScreen extends StatelessWidget {
  final String title;
  final Future<List<Map<String, dynamic>>> Function() fetchFunction;

  const UserListScreen({
    super.key, 
    required this.title, 
    required this.fetchFunction
  });

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _buildCircleButton(icon: Icons.arrow_back, onTap: () => Get.back()),
                      const SizedBox(width: 16),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: fetchFunction(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                      }
                      
                      if (snapshot.hasError) {
                        return Center(child: Text('Hata oluştu', style: GoogleFonts.inter(color: Colors.red)));
                      }

                      final users = snapshot.data ?? [];

                      if (users.isEmpty) {
                         return Center(
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Icon(Icons.people_outline, size: 60, color: Colors.white.withOpacity(0.3)),
                               const SizedBox(height: 10),
                               Text("Kimse yok...", style: GoogleFonts.inter(color: Colors.white38)),
                             ],
                           ),
                         );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final avatarUrl = user['avatar_url'] ?? 'https://ui-avatars.com/api/?name=${user['username']}&background=random';
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                            ),
                            child: ListTile(
                                leading: Container(
                                  width: 44, height: 44,
                                  decoration: const BoxDecoration(shape: BoxShape.circle),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: avatarUrl, fit: BoxFit.cover,
                                      placeholder: (c,u) => Container(color: Colors.grey[800]),
                                      errorWidget: (c,u,e) => Container(color: Colors.grey[800], child: const Icon(Icons.person, color: Colors.white)),
                                    ),
                                  ),
                                ),
                                title: UserNameText(
                                  displayName: user['display_name'] ?? 'Kullanıcı',
                                  isAdmin: user['is_admin'] == true,
                                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  "@${user['username']}",
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                ),
                                trailing: title == "Ziyaretçiler" 
                                  ? Text(
                                      _formatDate(user['visited_at']),
                                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
                                    )
                                  : null, 
                                onTap: () {
                                   if (user['id'] != null) {
                                      Get.to(() => UserProfileScreen(userId: user['id']));
                                   }
                                },
                            ),
                          );

                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "";
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes.abs() < 1) return "Şimdi";
    if (diff.inMinutes.abs() < 60) return "${diff.inMinutes.abs()}dk önce";
    if (diff.inHours.abs() < 24) return "${diff.inHours.abs()}s önce";
    return "${diff.inDays.abs()}g önce";
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        width: 40, height: 40, borderRadius: 20, blur: 10, alignment: Alignment.center, border: 1,
        linearGradient: LinearGradient(colors: [Colors.white10, Colors.white12]),
        borderGradient: LinearGradient(colors: [Colors.white24, Colors.white10]),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
