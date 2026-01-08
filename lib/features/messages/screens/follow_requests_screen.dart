import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/messages/controllers/messages_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  final MessagesController controller = Get.find<MessagesController>();
  final RxList<Map<String, dynamic>> requests = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    isLoading.value = true;
    try {
      final data = await controller.getPendingRequests();
      requests.value = data;
    } catch (e) {
      Get.snackbar("Hata", "İstekler alınamadı");
    } finally {
      isLoading.value = false;
    }
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Get.back()),
                      const Text("Takip İstekleri", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                Expanded(
                  child: Obx(() {
                    if (isLoading.value) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                    
                    if (requests.isEmpty) {
                      return Center(child: Text("Bekleyen istek yok", style: GoogleFonts.inter(color: Colors.white54)));
                    }

                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final user = req['requester']; // Relation ile gelen requester verisi
                        
                        // Eğer relation gelmediyse skip et
                        if (user == null) return const SizedBox.shrink();

                        return ListTile(
                          leading: CircleAvatar(
                             backgroundImage: NetworkImage(user['avatar_url'] ?? "https://ui-avatars.com/api/?name=${user['username']}&background=random"),
                          ),
                          title: Text(user['display_name'] ?? user['username'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text("@${user['username']}", style: const TextStyle(color: Colors.white54)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () async {
                                  await controller.acceptRequest(req['id'], user['id']);
                                  requests.removeAt(index);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () async {
                                   await controller.rejectRequest(req['id']);
                                   requests.removeAt(index);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
