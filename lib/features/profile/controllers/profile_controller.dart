import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';

class ProfileController extends GetxController {
  final supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();

  final RxInt followersCount = 0.obs;
  final RxInt followingCount = 0.obs;
  final RxInt visitorsCount = 0.obs;
  final RxInt postsCount = 0.obs; // 🔥 NEW
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchStats();
  }
  
  // İstatistikleri Çek
  Future<void> fetchStats() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    isLoading.value = true;
    try {
      // 1. Takipçiler (Following ID = Benim ID'm)
      final followers = await supabase
          .from('follows')
          .count()
          .eq('following_id', userId);
      
      // 2. Takip Ettiklerim (Follower ID = Benim ID'm)
      final following = await supabase
          .from('follows')
          .count()
          .eq('follower_id', userId);

      // 3. Ziyaretçiler
      final visitors = await supabase
          .from('profile_visitors')
          .count()
          .eq('profile_id', userId);

      // 4. 🔥 Postlar
      final posts = await supabase
          .from('posts')
          .count()
          .eq('user_id', userId);

      followersCount.value = followers;
      followingCount.value = following;
      visitorsCount.value = visitors;
      postsCount.value = posts; // 🔥 NEW

    } catch (e) {
      print("İstatistik Hatası: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Listeleri Çekme Metodları
  
  // Takipçileri Getir
  Future<List<Map<String, dynamic>>> getFollowers() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('follows')
        .select('follower_id, profiles!follower_id(id, username, display_name, avatar_url, is_admin)')
        .eq('following_id', userId);
    
    // Veriyi düzeltip döndür (profile içindeki veriyi yukarı taşı)
    return List<Map<String, dynamic>>.from(response.map((e) => e['profiles']));
  }

  // Takip Ettiklerimi Getir
  Future<List<Map<String, dynamic>>> getFollowing() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('follows')
        .select('following_id, profiles!following_id(id, username, display_name, avatar_url, is_admin)')
        .eq('follower_id', userId);
    
    return List<Map<String, dynamic>>.from(response.map((e) => e['profiles']));
  }

  // Ziyaretçileri Getir
  Future<List<Map<String, dynamic>>> getVisitors() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('profile_visitors')
        .select('visitor_id, visited_at, profiles!visitor_id(id, username, display_name, avatar_url, is_admin)')
        .eq('profile_id', userId)
        .order('visited_at', ascending: false) // En son gelen en üstte
        .limit(50); // Son 50 ziyaretçi
    
    // Tekilleştirme mantığı
    final Map<String, dynamic> uniqueVisitors = {};
    
    for (var item in response) {
      final visitorId = item['visitor_id'];
      // Liste 'visited_at' DESC olduğu için ilk gelen en günceldir.
      // Eğer map'te yoksa ekle.
      if (!uniqueVisitors.containsKey(visitorId) && item['profiles'] != null) {
         final profile = item['profiles'] as Map<String, dynamic>;
         profile['visited_at'] = item['visited_at'];
         uniqueVisitors[visitorId] = profile;
      }
    }

    return List<Map<String, dynamic>>.from(uniqueVisitors.values);
  }

  // Profilimi ziyaret edenleri logla (İlerde kullanılır)
  Future<void> logVisit(String profileId) async {
    final currentId = authController.currentUser.value?.id;
    if (currentId == null || currentId == profileId) return; // Kendini ziyaret etme

    try {
        // Son 24 saatte ziyaret etmiş mi? (Spam engelleme mantığı eklenebilir)
        await supabase.from('profile_visitors').insert({
          'visitor_id': currentId,
          'profile_id': profileId,
        });
    } catch (_) {}
  }
}
