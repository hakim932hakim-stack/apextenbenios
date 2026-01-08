import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsController extends GetxController {
  final supabase = Supabase.instance.client;
  
  // State
  final RxList<Map<String, dynamic>> personalNotifications = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> systemNotifications = <Map<String, dynamic>>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  // Bildirimleri Çek
  Future<void> fetchNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    isLoading.value = true;

    try {
      // Bildirimleri çek (yeniden eskiye)
      final notificationsData = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = List<Map<String, dynamic>>.from(notificationsData);

      // Actor profil bilgilerini ekle (Manuel Join)
      final actorIds = notifications
          .where((n) => n['actor_id'] != null)
          .map((n) => n['actor_id'] as String)
          .toSet()
          .toList();

      if (actorIds.isNotEmpty) {
        final profilesData = await supabase
            .from('profiles')
            .select('id, username, display_name, avatar_url')
            .inFilter('id', actorIds);

        final profilesMap = {
          for (var p in profilesData) p['id'] as String: p
        };

        // Profil bilgilerini merge et
        for (var notification in notifications) {
          final actorId = notification['actor_id'] as String?;
          if (actorId != null && profilesMap.containsKey(actorId)) {
            notification['actor_profile'] = profilesMap[actorId];
          }
        }
      }

      // Kişisel ve Sistem olarak ayır
      personalNotifications.value = notifications
          .where((n) => n['type'] == 'post_like' || n['type'] == 'post_comment')
          .toList();

      systemNotifications.value = notifications
          .where((n) => n['type'] == 'system')
          .toList();

      // Okunmamış sayısını hesapla
      unreadCount.value = notifications.where((n) => n['is_read'] == false).length;
      
      debugPrint("✅ Bildirimleri çekildi: Toplam=${notifications.length}, Kişisel=${personalNotifications.length}, Sistem=${systemNotifications.length}, Okunmamış=${unreadCount.value}");
    } catch (e) {
      debugPrint("❌ Fetch notifications error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Tüm Bildirimleri Okundu İşaretle (Sayfaya girince)
  Future<void> markAllAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      // Local state güncellemesi
      for (var notification in personalNotifications) {
        notification['is_read'] = true;
      }
      for (var notification in systemNotifications) {
        notification['is_read'] = true;
      }
      personalNotifications.refresh();
      systemNotifications.refresh();
      unreadCount.value = 0;
    } catch (e) {
      debugPrint("❌ Mark all as read error: $e");
    }
  }

  // Tekil Bildirim Okundu
  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      // Local state güncellemesi
      final index = personalNotifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        personalNotifications[index]['is_read'] = true;
        personalNotifications.refresh();
        unreadCount.value = (unreadCount.value - 1).clamp(0, 999);
      }
    } catch (e) {
      debugPrint("Mark as read error: $e");
    }
  }
}
