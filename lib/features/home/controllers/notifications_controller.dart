import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? imageUrl;
  final DateTime createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
  });
}

class NotificationsController extends GetxController {
  final supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();

  final RxList<NotificationItem> notifications = <NotificationItem>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool hasUnread = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
    checkUnread();
  }

  // Bildirimleri Çek
  Future<void> fetchNotifications() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    isLoading.value = true;
    try {
      // 1. Tüm bildirimleri çek
      final notifResponse = await supabase
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false);
      
      // 2. Okunanları çek
      final readsResponse = await supabase
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', userId);
      
      final readIds = (readsResponse as List).map((r) => r['notification_id'] as String).toSet();

      final List<NotificationItem> loadedNotifications = [];
      
      for (var data in notifResponse) {
        loadedNotifications.add(NotificationItem(
          id: data['id'],
          title: data['title'],
          message: data['message'],
          type: data['type'],
          imageUrl: data['image_url'],
          createdAt: DateTime.parse(data['created_at']),
          isRead: readIds.contains(data['id']),
        ));
      }

      notifications.value = loadedNotifications;
      
    } catch (e) {
      print("Error fetching notifications: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Hepsini Okundu İşaretle
  Future<void> markAllAsRead() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;
    
    final unread = notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    try {
      final inserts = unread.map((n) => {
        'user_id': userId,
        'notification_id': n.id
      }).toList();

      await supabase.from('notification_reads').upsert(inserts, onConflict: 'user_id,notification_id'); // ignoreDuplicates yok ama upsert zaten halleder

      // Local update
      for (var n in notifications) {
        n.isRead = true;
      }
      notifications.refresh();
      hasUnread.value = false;

    } catch (e) {
      print("Error marking as read: $e");
    }
  }

  // Okunmamış Var mı Kontrolü (Badge için)
  Future<void> checkUnread() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    try {
       // Tüm bildirim ID'lerini çek (Sadece ID, veri tasarrufu için)
       final notifResponse = await supabase.from('notifications').select('id');
       final totalCount = (notifResponse as List).length;
       
       // Okunan bildirim ID'lerini çek
       final readResponse = await supabase
          .from('notification_reads')
          .select('id') // Sadece ID
          .eq('user_id', userId);
       
       final readCount = (readResponse as List).length;
       
       hasUnread.value = totalCount > readCount;
    } catch (e) {
      print("Check unread error: $e");
    }
  }
}
