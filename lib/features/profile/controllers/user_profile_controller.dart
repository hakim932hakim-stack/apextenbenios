import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';

class UserProfileController extends GetxController {
  final SupabaseClient supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();

  // Profil Verileri
  final Rx<Map<String, dynamic>?> userProfile = Rx<Map<String, dynamic>?>(null);
  final RxBool isLoading = true.obs;
  
  // Takip Verileri
  final Rx<String> followStatus = 'none'.obs; // none, following, pending
  final RxInt followersCount = 0.obs;
  final RxInt followingCount = 0.obs;
  final RxInt postsCount = 0.obs; // 🔥 NEW
  final RxBool isFollowLoading = false.obs;
  final RxBool isMutual = false.obs;

  // 🛡️ ENGEL DURUMLARI & ENGELLENENLER
  final RxBool isBlockedByMe = false.obs;
  final RxBool isBlockedByThem = false.obs;
  final RxBool isBlockLoading = false.obs;
  
  // Engellenen Kullanıcılar Listesi
  final RxList<Map<String, dynamic>> blockedUsers = <Map<String, dynamic>>[].obs;

  // 🔴 RAHATSIZ ETME DURUMU
  final RxBool isDND = false.obs;

  // 1️⃣ KULLANICI PROFİLİNİ YÜKLE
  Future<void> loadUser(String userId) async {
    isLoading.value = true;
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      userProfile.value = response;

      if (response != null) {
        // İstatistikleri yükle
        final followers = await supabase.from('follows').count().eq('following_id', userId);
        final following = await supabase.from('follows').count().eq('follower_id', userId);
        final posts = await supabase.from('posts').count().eq('user_id', userId); // 🔥 NEW
        
        followersCount.value = followers;
        followingCount.value = following;
        postsCount.value = posts; // 🔥 NEW
        
        // 🔴 Rahatsız Etme durumunu al
        isDND.value = response['do_not_disturb'] ?? false;
        
        // Takip durumunu kontrol et
        await checkFollowStatus(userId);
        
        // Engel durumunu kontrol et
        await checkBlockStatus(userId);
        
        // Ziyareti kaydet
        logVisit(userId);

        // 🔥 YASAKLI KULLANICI KONTROLÜ
        if (response['is_banned'] == true) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
              Get.defaultDialog(
                title: "⚠️ Hesap Yasaklandı",
                middleText: "Bu kullanıcı topluluk kurallarını ihlal ettiği için yasaklanmıştır.",
                textConfirm: "Tamam",
                confirmTextColor: Colors.white,
                buttonColor: Colors.red,
                barrierDismissible: false, // Dışarı basınca kapanmasın
                onConfirm: () {
                   Get.back(); // Dialog kapat
                   Get.back(); // Sayfadan çık
                }
              );
           });
        }
      }
    } catch (e) {
      print("User load error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // 2️⃣ TAKİP DURUMUNU KONTROL ET
  Future<void> checkFollowStatus(String targetId) async {
    final myId = authController.currentUser.value?.id;
    if (myId == null || myId == targetId) return;

    try {
      // 1. Direkt Takip Var mı?
      final follow = await supabase
          .from('follows')
          .select('id')
          .match({'follower_id': myId, 'following_id': targetId})
          .maybeSingle();
      
      if (follow != null) {
        followStatus.value = 'following';

        // Karşılıklı takip mi?
        final mutual = await supabase
           .from('follows')
           .select('id')
           .match({'follower_id': targetId, 'following_id': myId})
           .maybeSingle();
        isMutual.value = mutual != null;
        
      } else {
        isMutual.value = false;
        // 2. Bekleyen İstek Var mı?
        final request = await supabase
           .from('follow_requests')
           .select('id')
           .match({'requester_id': myId, 'target_id': targetId, 'status': 'pending'})
           .maybeSingle();
           
        followStatus.value = request != null ? 'pending' : 'none';
      }
      
    } catch (e) {
      print("Follow check error: $e");
    }
  }

  // 3️⃣ TAKİP ET / TAKİPTEN ÇIK
  Future<void> toggleFollow(String targetId) async {
    final myId = authController.currentUser.value?.id;
    if (myId == null) return;
    
    // Eğer engelli ise işlem yapma
    if (isBlocked) {
       Get.snackbar("Hata", "Engelli kullanıcı ile etkileşime geçilemez.");
       return;
    }

    isFollowLoading.value = true;
    try {
      if (followStatus.value == 'following') {
        // Takipten Çık
        await supabase
            .from('follows')
            .delete()
            .match({'follower_id': myId, 'following_id': targetId});
            
        followStatus.value = 'none';
        isMutual.value = false;
        followersCount.value--; 
      } else if (followStatus.value == 'pending') {
        // İsteği Geri Çek
        await supabase
            .from('follow_requests')
            .delete()
            .match({'requester_id': myId, 'target_id': targetId});
            
        followStatus.value = 'none';
      } else { // status == 'none'
        // HER ZAMAN TAKİP İSTEĞİ GÖNDER (Kullanıcı talebi)
        await supabase.from('follow_requests').insert({
             'requester_id': myId,
             'target_id': targetId,
             'status': 'pending'
        });
        
        followStatus.value = 'pending';
      }
      
      // Tekrar kontrol et (Garantilemek için)
      await checkFollowStatus(targetId);
      
    } catch (e) {
      Get.snackbar("Hata", "İşlem başarısız: $e");
    } finally {
      isFollowLoading.value = false;
    }
  }

  // ============== ENGELLEME FONKSİYONLARI ==============

  // 1. Durumu Kontrol Et
  Future<void> checkBlockStatus(String targetId) async {
    final myId = authController.currentUser.value?.id;
    if (myId == null) return;

    try {
      // Ben engelledim mi?
      final myBlock = await supabase
          .from('user_blocks')
          .select('id')
          .match({'blocker_id': myId, 'blocked_id': targetId})
          .maybeSingle();
      isBlockedByMe.value = myBlock != null;

      // O beni engelledi mi?
      final theirBlock = await supabase
          .from('user_blocks')
          .select('id')
          .match({'blocker_id': targetId, 'blocked_id': myId})
          .maybeSingle();
      isBlockedByThem.value = theirBlock != null;
    } catch (e) {
      print("Block status error: $e");
    }
  }
  
  // Getter: Herhangi bir engel var mı?
  bool get isBlocked => isBlockedByMe.value || isBlockedByThem.value;

  // 2. Engelle
  Future<void> blockUser(String targetId) async {
    final myId = authController.currentUser.value?.id;
    if (myId == null) return;

    isBlockLoading.value = true;
    try {
      await supabase.from('user_blocks').insert({
        'blocker_id': myId,
        'blocked_id': targetId,
      });
      
      // Takipten çıkar (karşılıklı)
      try {
        await supabase.from('follows').delete().match({'follower_id': myId, 'following_id': targetId});
        await supabase.from('follows').delete().match({'follower_id': targetId, 'following_id': myId});
      } catch (_) {}

      isBlockedByMe.value = true;
      followStatus.value = 'none'; // Takip düştü
      isMutual.value = false;
      
      // Eğer ayarlar ekranındaysak listeyi yenile
      await fetchBlockedUsers();

      Get.snackbar("Başarılı", "Kullanıcı engellendi", 
        backgroundColor: Colors.black, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      
    } catch (e) {
      Get.snackbar("Hata", "Engelleme başarısız: $e");
    } finally {
      isBlockLoading.value = false;
    }
  }

  // 3. Engeli Kaldır
  Future<void> unblockUser(String targetId) async {
    final myId = authController.currentUser.value?.id;
    if (myId == null) return;

    isBlockLoading.value = true;
    try {
      await supabase
          .from('user_blocks')
          .delete()
          .match({'blocker_id': myId, 'blocked_id': targetId});

      isBlockedByMe.value = false;
      
      // Listeyi yenile
      await fetchBlockedUsers();

      Get.snackbar("Başarılı", "Engel kaldırıldı", 
         backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);

    } catch (e) {
      Get.snackbar("Hata", "Engel kaldırılamadı: $e");
    } finally {
      isBlockLoading.value = false;
    }
  }
  
  // 4. Engellenenler Listesini Çek (For Settings Screen)
  Future<void> fetchBlockedUsers() async {
    final myId = authController.currentUser.value?.id;
    if (myId == null) return;
    
    try {
      // Engellenen ID'leri al
      final blocks = await supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', myId);
          
      if (blocks.isEmpty) {
        blockedUsers.clear();
        return;
      }
      
      final List<dynamic> blockedIds = (blocks as List).map((e) => e['blocked_id']).toList();
      
      // Profilleri çek (in_ yerine filter kullanıyoruz)
      if (blockedIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, username, display_name, avatar_url')
            .inFilter('id', blockedIds); // Using inFilter for proper array filtering
            
        blockedUsers.value = List<Map<String, dynamic>>.from(profiles);
      } else {
        blockedUsers.clear();
      }
      
    } catch (e) {
      print("Engellenenler listesi hatası: $e");
    }
  }
  
  // ============== DİĞER ==============

  Future<void> logVisit(String targetId) async {
     final myId = authController.currentUser.value?.id;
     if (myId == null || myId == targetId) return;

     try {
       // Önceki kayıtları temizle (Hata alsa bile devam et)
       try {
          await supabase.from('profile_visitors').delete().match({
            'visitor_id': myId,
            'profile_id': targetId,
          });
       } catch (_) {}

       // Yeni ziyareti ekle veya güncelle
       await supabase.from('profile_visitors').upsert({
         'visitor_id': myId,
         'profile_id': targetId,
         'visited_at': DateTime.now().toUtc().toIso8601String(),
       }); 
     } catch (e) {
       print("Visit log error: $e");
     }
  }

  // 👻 GHOST MODE TOGGLE
  Future<void> toggleGhostMode(bool value) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;
    try {
      await supabase.from('profiles').update({'is_ghost_mode': value}).eq('id', userId);
    } catch(e) { 
      print("Ghost mode toggle error: $e");
    }
  }
}
