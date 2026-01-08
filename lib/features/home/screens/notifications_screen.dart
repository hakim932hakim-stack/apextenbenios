import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/notifications/controllers/notifications_controller.dart';
import 'package:yeniapex/features/notifications/widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NotificationsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(NotificationsController());
    _tabController = TabController(length: 2, vsync: this);
    
    // Sayfa açılınca okundu işaretle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.markAllAsRead();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "BİLDİRİMLER",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          const StarBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                
                // TABS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.5),
                            AppColors.primary.withOpacity(0.3)
                          ],
                        ),
                      ),
                      dividerColor: Colors.transparent,
                      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
                      tabs: const [
                        Tab(text: "KİŞİSEL"),
                        Tab(text: "SİSTEM"),
                      ],
                    ),
                  ),
                ),
                
                // TAB CONTENT
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPersonalTab(),
                      _buildSystemTab(),
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

  Widget _buildPersonalTab() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      if (controller.personalNotifications.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.bell, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                "Henüz kişisel bildirim yok",
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Birileri postunuzu beğendiğinde\nveya yorum yaptığında burada göreceksiniz",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.fetchNotifications,
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: controller.personalNotifications.length,
          itemBuilder: (context, index) {
            final notification = controller.personalNotifications[index];
            return NotificationCard(notification: notification);
          },
        ),
      );
    });
  }

  Widget _buildSystemTab() {
    return Obx(() {
      if (controller.systemNotifications.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.megaphone, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                "Henüz sistem bildirimi yok",
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Yönetici duyuruları ve\nsistem bildirimleri burada görünecek",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: controller.systemNotifications.length,
        itemBuilder: (context, index) {
          final notification = controller.systemNotifications[index];
          return NotificationCard(notification: notification);
        },
      );
    });
  }
}
