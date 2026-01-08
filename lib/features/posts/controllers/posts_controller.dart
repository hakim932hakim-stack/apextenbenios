import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class PostsController extends GetxController {
  final supabase = Supabase.instance.client;
  
  // State
  final RxList<Map<String, dynamic>> publicPosts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> myPosts = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCreating = false.obs;
  
  // Create Post Form
  final TextEditingController contentController = TextEditingController();
  final Rx<File?> selectedImage = Rx<File?>(null);
  final RxString visibility = 'public'.obs; // 'public' or 'friends'
  
  // Pagination (basit)
  final RxInt publicPage = 0.obs;
  final RxInt myPage = 0.obs;
  static const int pageSize = 20;
  
  // Infinite Scroll Flags
  final RxBool hasMorePublic = true.obs;
  final RxBool hasMoreMy = true.obs;
  final RxBool isLoadingMore = false.obs;
  
  // Profile Cache (Profil bilgilerini cache'le)
  final Map<String, Map<String, dynamic>> _profileCache = {};
  
  @override
  void onInit() {
    super.onInit();
    fetchPublicPosts();
    fetchMyPosts();
  }
  
  @override
  void onClose() {
    contentController.dispose();
    super.onClose();
  }
  
  // ==========================================
  // HELPER: Profil bilgisi çek
  // ==========================================
  
  Future<Map<String, dynamic>?> _getProfile(String userId) async {
    // Cache'de varsa döndür
    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId];
    }
    
    try {
      final response = await supabase
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        _profileCache[userId] = response;
      }
      return response;
    } catch (e) {
      debugPrint('Profile fetch error: $e');
      return null;
    }
  }
  
  
  // ==========================================
  // FETCH POSTS
  // ==========================================
  
  Future<void> fetchPublicPosts({bool refresh = false}) async {
    if (refresh) {
      publicPage.value = 0;
      publicPosts.clear();
      hasMorePublic.value = true;
    }
    
    if (!hasMorePublic.value) return; // Daha fazla yok
    
    isLoading.value = publicPosts.isEmpty;
    isLoadingMore.value = publicPosts.isNotEmpty;
    
    try {
      final response = await supabase
          .from('posts')
          .select('*')
          .order('created_at', ascending: false)
          .range(publicPage.value * pageSize, (publicPage.value + 1) * pageSize - 1);
      
      final enrichedPosts = await _enrichPostsWithProfiles(response);
      
      // Daha az post geldiyse, daha fazla yok demektir
      if (enrichedPosts.length < pageSize) {
        hasMorePublic.value = false;
      }
      
      if (refresh) {
        publicPosts.value = enrichedPosts;
      } else {
        publicPosts.addAll(enrichedPosts);
      }
      
      publicPage.value++;
    } catch (e) {
      debugPrint('❌ Fetch public posts error: $e');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }
  
  Future<void> fetchMyPosts({bool refresh = false}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    if (refresh) {
      myPage.value = 0;
      myPosts.clear();
      hasMoreMy.value = true;
    }
    
    if (!hasMoreMy.value) return; // Daha fazla yok
    
    try {
      final response = await supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(myPage.value * pageSize, (myPage.value + 1) * pageSize - 1);
      
      final enrichedPosts = await _enrichPostsWithProfiles(response);
      
      // Daha az post geldiyse, daha fazla yok demektir
      if (enrichedPosts.length < pageSize) {
        hasMoreMy.value = false;
      }
      
      if (refresh) {
        myPosts.value = enrichedPosts;
      } else {
        myPosts.addAll(enrichedPosts);
      }
      
      myPage.value++;
    } catch (e) {
      debugPrint('❌ Fetch my posts error: $e');
    }
  }
  
  // Fetch posts for a specific user (profile page)
  Future<List<Map<String, dynamic>>> fetchUserPosts(String userId) async {
    try {
      final response = await supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return await _enrichPostsWithProfiles(response);
    } catch (e) {
      debugPrint('❌ Fetch user posts error: $e');
      return [];
    }
  }
  
  // ==========================================
  // CREATE POST
  // ==========================================
  
  Future<void> pickImage() async {
    // İzin Kontrolü (Android 13+ Photos, Eski Storage)
    if (Platform.isAndroid) {
       PermissionStatus status;
       // Android sürümüne göre doğru izni iste
       // Basit yaklaşım: Önce Photos'u dene (Android 13+), olmazsa Storage (Eski)
       // Ancak permission_handler dokümantasyonuna göre Android 13+ photos ister.
       
       // SDK kontrolü yapamıyoruz (device_info_plus lazım), o yüzden sırayla deniyoruz
       status = await Permission.photos.status;
       if (status.isDenied) {
           status = await Permission.photos.request();
       }
       
       // Eğer photos desteklenmiyorsa veya reddedildiyse Storage dene
       if (!status.isGranted) {
           var storageStatus = await Permission.storage.status;
           if (storageStatus.isDenied) {
              storageStatus = await Permission.storage.request();
           }
           if (storageStatus.isGranted) status = storageStatus;
       }

       if (status.isPermanentlyDenied) {
         Get.snackbar('İzin Gerekli', 'Galeriye erişim için izin vermelisiniz', 
            backgroundColor: Colors.red, colorText: Colors.white,
            mainButton: TextButton(onPressed: openAppSettings, child: const Text('Ayarlar', style: TextStyle(color: Colors.white)))
         );
         return;
       }
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (image != null) {
      selectedImage.value = File(image.path);
    }
  }
  
  void removeImage() {
    selectedImage.value = null;
  }
  
  void toggleVisibility() {
    visibility.value = visibility.value == 'public' ? 'friends' : 'public';
  }
  
  void setVisibility(String value) {
    visibility.value = value;
  }
  
  Future<bool> createPost() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    
    final content = contentController.text.trim();
    final hasImage = selectedImage.value != null;
    
    // Eğer hem yazı yok hem resim yoksa -> Hata
    if (content.isEmpty && !hasImage) {
      Get.snackbar('Uyarı', 'Lütfen bir şeyler yazın veya görsel ekleyin', backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }
    
    if (content.length > 100) {
      Get.snackbar('Hata', 'Maksimum 100 karakter', backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    
    isCreating.value = true;
    
    try {
      String? imageUrl;
      
      // Upload image if selected
      if (selectedImage.value != null) {
        final file = selectedImage.value!;
        final fileExt = file.path.split('.').last;
        final fileName = '${const Uuid().v4()}.$fileExt';
        final filePath = '$userId/$fileName';
        
        await supabase.storage
            .from('post-images')
            .upload(filePath, file);
        
        imageUrl = supabase.storage
            .from('post-images')
            .getPublicUrl(filePath);
      }
      
      // Insert post
      await supabase.from('posts').insert({
        'user_id': userId,
        'content': content,
        'image_url': imageUrl,
        'visibility': visibility.value,
      });
      
      // Clear form
      contentController.clear();
      selectedImage.value = null;
      visibility.value = 'public';
      
      // Refresh lists
      await fetchPublicPosts(refresh: true);
      await fetchMyPosts(refresh: true);
      
      // Toast kaldırıldı - sessiz başarı
      return true;
    } catch (e) {
      debugPrint('❌ Create post error: $e');
      Get.snackbar('Hata', 'Post paylaşılamadı: $e', backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    } finally {
      isCreating.value = false;
    }
  }
  
  // ==========================================
  // DELETE POST
  // ==========================================
  
  Future<bool> deletePost(String postId, String? imageUrl) async {
    try {
      // Delete post from DB (cascades to storage via trigger or manual)
      await supabase.from('posts').delete().eq('id', postId);
      
      // Delete image from storage if exists
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          // Extract path from URL
          final uri = Uri.parse(imageUrl);
          final pathSegments = uri.pathSegments;
          // Format: /storage/v1/object/public/post-images/userId/filename.ext
          if (pathSegments.length >= 5) {
            final storagePath = '${pathSegments[pathSegments.length - 2]}/${pathSegments.last}';
            await supabase.storage.from('post-images').remove([storagePath]);
          }
        } catch (e) {
          debugPrint('Storage delete error: $e');
        }
      }
      
      // Remove from local lists
      publicPosts.removeWhere((p) => p['id'] == postId);
      myPosts.removeWhere((p) => p['id'] == postId);
      
      // Toast kaldırıldı - sessiz başarı
      return true;
    } catch (e) {
      debugPrint('❌ Delete post error: $e');
      Get.snackbar('Hata', 'Post silinemedi', backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }
  
  // ==========================================
  // UPDATE VISIBILITY
  // ==========================================
  
  Future<bool> updatePostVisibility(String postId, String newVisibility) async {
    try {
      await supabase
          .from('posts')
          .update({'visibility': newVisibility, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', postId);
      
      // Update local lists
      final publicIndex = publicPosts.indexWhere((p) => p['id'] == postId);
      if (publicIndex != -1) {
        publicPosts[publicIndex]['visibility'] = newVisibility;
        publicPosts.refresh();
      }
      
      final myIndex = myPosts.indexWhere((p) => p['id'] == postId);
      if (myIndex != -1) {
        myPosts[myIndex]['visibility'] = newVisibility;
        myPosts.refresh();
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Update visibility error: $e');
      Get.snackbar('Hata', 'Ayar güncellenemedi', backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }
  
  // ==========================================
  // GET MY POST COUNT
  // ==========================================
  
  Future<int> getPostCount(String userId) async {
    try {
      final response = await supabase
          .from('posts')
          .select('id')
          .eq('user_id', userId);
      
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // ==========================================
  // ❤️ LIKES & COMMENTS LOGIC
  // ==========================================

  // Postları zenginleştirirken Like/Comment sayılarını da al
  @override
  Future<List<Map<String, dynamic>>> _enrichPostsWithProfiles(List<dynamic> posts) async {
    final enrichedPosts = <Map<String, dynamic>>[];
    final currentUserId = supabase.auth.currentUser?.id;

    for (var post in posts) {
      final postMap = Map<String, dynamic>.from(post);
      final userId = postMap['user_id'] as String?;
      final postId = postMap['id'] as String;
      
      // 1. Profil Bilgisi
      if (userId != null) {
        final profile = await _getProfile(userId);
        postMap['profile'] = profile;
      }

      // 2. Beğeni Sayısı
      final likesCount = await supabase
          .from('post_likes')
          .count(CountOption.exact)
          .eq('post_id', postId);
      postMap['likes_count'] = likesCount;

      // 3. Yorum Sayısı
      final commentsCount = await supabase
          .from('post_comments')
          .count(CountOption.exact)
          .eq('post_id', postId);
      postMap['comments_count'] = commentsCount;

      // 4. Ben Beğendim mi?
      bool isLikedByMe = false;
      if (currentUserId != null) {
        final myLike = await supabase
            .from('post_likes')
            .select('post_id')
            .eq('post_id', postId)
            .eq('user_id', currentUserId)
            .maybeSingle();
        isLikedByMe = myLike != null;
      }
      postMap['is_liked'] = isLikedByMe;
      
      enrichedPosts.add(postMap);
    }
    
    return enrichedPosts;
  }

  // Beğeni Yap/Geri Al
  Future<void> toggleLike(String postId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Local Update (Anında Tepki)
    final postIndex = publicPosts.indexWhere((p) => p['id'] == postId);
    final myPostIndex = myPosts.indexWhere((p) => p['id'] == postId);

    bool isLiked = false;
    
    // Public List Update
    if (postIndex != -1) {
      isLiked = publicPosts[postIndex]['is_liked'] ?? false;
      publicPosts[postIndex]['is_liked'] = !isLiked;
      publicPosts[postIndex]['likes_count'] = (publicPosts[postIndex]['likes_count'] ?? 0) + (isLiked ? -1 : 1);
      publicPosts.refresh();
    }
    
    // My List Update (Eğer aynı postsa)
    if (myPostIndex != -1) {
      // isLiked already toggle status from logic above if it was in public, but let's be safe
      // Logic: if not found in public, use simple toggle. If found, sync.
      if (postIndex == -1) isLiked = myPosts[myPostIndex]['is_liked'] ?? false;
      
      myPosts[myPostIndex]['is_liked'] = !isLiked;
      myPosts[myPostIndex]['likes_count'] = (myPosts[myPostIndex]['likes_count'] ?? 0) + (isLiked ? -1 : 1);
      myPosts.refresh();
    }

    try {
      if (isLiked) {
        // Zaten beğenilmişti -> SİL (Unlike)
        await supabase.from('post_likes').delete().eq('post_id', postId).eq('user_id', userId);
      } else {
        // Beğenilmemişti -> EKLE (Like)
        await supabase.from('post_likes').insert({'post_id': postId, 'user_id': userId});
        
        // (Opsiyonel) Bildirim gönderme eklenebilir
      }
    } catch (e) {
      debugPrint("Like toggle error: $e");
      // Hata olursa geri al (Revert)
       if (postIndex != -1) {
          publicPosts[postIndex]['is_liked'] = isLiked;
          publicPosts[postIndex]['likes_count'] = (publicPosts[postIndex]['likes_count'] ?? 0) + (isLiked ? 1 : -1);
          publicPosts.refresh();
       }
    }
  }

  // Yorumları Getir (Manuel Join)
  Future<List<Map<String, dynamic>>> fetchComments(String postId) async {
     try {
       // 1. Yorumları çek
       final commentsData = await supabase
           .from('post_comments')
           .select('*')
           .eq('post_id', postId)
           .order('created_at', ascending: true);
       
       final comments = List<Map<String, dynamic>>.from(commentsData);
       if (comments.isEmpty) return [];

       // 2. User ID'leri topla
       final userIds = comments.map((c) => c['user_id'] as String).toSet().toList();

       // 3. Profilleri çek
       final profilesData = await supabase
           .from('profiles')
           .select('id, username, display_name, avatar_url')
           .inFilter('id', userIds);
        
       final profilesMap = {
         for (var p in profilesData) p['id'] as String: p
       };

       // 4. Birleştir
       for (var comment in comments) {
         final uid = comment['user_id'] as String;
         if (profilesMap.containsKey(uid)) {
           comment['profile'] = profilesMap[uid];
         }
       }
       
       return comments;
     } catch (e) {
       debugPrint("Fetch comments error: $e");
       return [];
     }
  }

  // Yorum Yap
  Future<void> addComment(String postId, String content) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase.from('post_comments').insert({
        'post_id': postId,
        'user_id': userId,
        'content': content
      });

      // Local Comment Count Update
      final postIndex = publicPosts.indexWhere((p) => p['id'] == postId);
      if (postIndex != -1) {
         publicPosts[postIndex]['comments_count'] = (publicPosts[postIndex]['comments_count'] ?? 0) + 1;
         publicPosts.refresh();
      }
      
      final myPostIndex = myPosts.indexWhere((p) => p['id'] == postId);
      if (myPostIndex != -1) {
         myPosts[myPostIndex]['comments_count'] = (myPosts[myPostIndex]['comments_count'] ?? 0) + 1;
         myPosts.refresh();
      }

    } catch (e) {
      debugPrint("Add comment error: $e");
      Get.snackbar("Hata", "Yorum gönderilemedi", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
