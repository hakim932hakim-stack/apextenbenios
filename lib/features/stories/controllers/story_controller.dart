import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:video_player/video_player.dart';

class StoryController extends GetxController {
  final supabase = Supabase.instance.client;
  final authController = Get.find<AuthController>();
  
  // State
  var myStories = <Map<String, dynamic>>[].obs;
  var otherStories = <Map<String, dynamic>>[].obs; // Başkalarının hikayeleri (User ID keyli)
  var isUploading = false.obs;
  var isLoading = false.obs;
  
  // Hikaye var mı kontrolü için (UI'da kırmızı halka için)
  var hasActiveStory = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchMyStories();
  }

  // Başka kullanıcının hikayelerini çek
  Future<List<Map<String, dynamic>>> fetchOtherUserStories(String userId) async {
    try {
      final response = await supabase
          .from('stories')
          .select()
          .eq('user_id', userId)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("❌ Fetch other stories error: $e");
      return [];
    }
  }

  // Kendi hikayelerimi çek (Aktif olanlar)
  Future<void> fetchMyStories() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('stories')
          .select()
          .eq('user_id', userId)
          .gt('expires_at', DateTime.now().toIso8601String()) // Süresi geçmemiş olanlar
          .order('created_at', ascending: true);
      
      myStories.value = List<Map<String, dynamic>>.from(response);
      hasActiveStory.value = myStories.isNotEmpty;
    } catch (e) {
      debugPrint("❌ Fetch stories error: $e");
    }
  }

  // --- VIEW TRACKING ---

  // Hikayeyi Görüntülendi Olarak İşaretle
  Future<void> markStoryAsViewed(String storyId) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    try {
      await supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': userId,
      });
    } catch (_) {}
  }

  // Görüntüleyenleri Çek (Manuel Join - İlişki hatasını önlemek için)
  Future<List<Map<String, dynamic>>> getStoryViewers(String storyId) async {
    try {
      // 1. İzleyenleri çek (Sadece ID ve Tarih)
      final viewsResponse = await supabase
          .from('story_views')
          .select('viewer_id, viewed_at')
          .eq('story_id', storyId)
          .order('viewed_at', ascending: false);
      
      final List<dynamic> views = viewsResponse;
      if (views.isEmpty) return [];

      // 2. Viewer ID'leri topla
      final List<String> viewerIds = views.map((v) => v['viewer_id'] as String).toList();

      // 3. Profilleri çek
      final profilesResponse = await supabase
          .from('profiles')
          .select()
          .inFilter('id', viewerIds); // .in_ yerine .inFilter kullanıyoruz dart v2
      
      final List<dynamic> profiles = profilesResponse;
      
      // 4. Verileri birleştir
      // Sonuç: [{ 'viewed_at': ..., 'viewer': { ...profile... } }]
      final List<Map<String, dynamic>> result = [];
      
      for (var view in views) {
        // Profil eşleştirmesi - Güvenli yöntem
        final matchingProfiles = profiles.where((p) => p['id'] == view['viewer_id']).toList();
        final profile = matchingProfiles.isNotEmpty ? matchingProfiles.first : null;
        
        if (profile != null) {
          result.add({
            'viewed_at': view['viewed_at'],
            'viewer': profile,
          });
        } else {
           // Profil bulunamadıysa (silinmiş user vs) anonim göster veya gösterme
           // result.add({'viewed_at': view['viewed_at'], 'viewer': {'display_name': 'Bilinmeyen Kullanıcı', 'avatar_url': null}});
        }
      }
      
      return result;

    } catch (e) {
      debugPrint("Viewers Error: $e");
      return [];
    }
  }

  // --- ACTIONS ---

  // Medya seç ve yükle
  Future<void> pickAndUploadStory({bool isVideo = false}) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;
    
    // 1 Hikaye limiti: Eğer zaten hikaye varsa yükletme (UI yönetir ama burada da duralım)
    if (hasActiveStory.value) return; 

    final picker = ImagePicker();
    XFile? file;

    if (isVideo) {
      file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 20));
    } else {
      file = await picker.pickImage(source: ImageSource.gallery);
    }

    if (file == null) return;

    try {
      isLoading.value = true;
      // Get.snackbar siliyoruz

      final fileBytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last;
      final fileName = '${const Uuid().v4()}.$fileExt';
      final filePath = '$userId/$fileName';

      // 1. Storage
      await supabase.storage.from('stories').uploadBinary(
        filePath, 
        fileBytes,
        fileOptions: FileOptions(contentType: isVideo ? 'video/$fileExt' : 'image/$fileExt')
      );

      final mediaUrl = supabase.storage.from('stories').getPublicUrl(filePath);

      // 2. Database
      await supabase.from('stories').insert({
        'user_id': userId,
        'media_url': mediaUrl,
        'media_type': isVideo ? 'video' : 'image',
        'duration': isVideo ? 20 : 5,
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });

      await fetchMyStories(); // State güncelle
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Private _uploadStory silindi, logic yukarı taşındı.

  // Hikaye Sil
  Future<void> deleteStory(String storyId, String? mediaUrl) async {
    try {
      // 1. Storage
      if (mediaUrl != null) {
        try {
          final uri = Uri.parse(mediaUrl);
          final pathSegmentIndex = uri.pathSegments.indexOf('stories');
          if (pathSegmentIndex != -1) {
             final path = uri.pathSegments.sublist(pathSegmentIndex + 1).join('/');
             await supabase.storage.from('stories').remove([path]);
          }
        } catch (_) {}
      }

      // 2. DB
      await supabase.from('stories').delete().eq('id', storyId);

      // State
      myStories.removeWhere((e) => e['id'] == storyId);
      hasActiveStory.value = myStories.isNotEmpty;
      
      // Get.back(); // UI tarafında yönetilecek
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }
}
