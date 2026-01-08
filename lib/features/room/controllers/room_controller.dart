import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 🔥 REMOVED: video_player (Artık native ExoPlayer kullanıyoruz)
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:yeniapex/core/services/livekit_service.dart';
import 'package:yeniapex/core/services/audio_manager_service.dart';
import 'package:yeniapex/features/room/services/youtube_extractor_service.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:yeniapex/features/messages/services/pie_socket_service.dart';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // 🔥 Import for Permission check
import 'package:flutter_background_service/flutter_background_service.dart'; // 🔥 Import
import 'dart:convert'; // jsonDecode için gerekli olabilir
import 'package:yeniapex/services/video_service.dart'; // 🔥 Native Video Player + Background Service
import 'package:yeniapex/core/utils/password_generator.dart'; // 🔐 Password Generator
import 'package:yeniapex/features/home/controllers/home_controller.dart'; // 🔥 Fix Import
import 'package:yeniapex/features/room/widgets/password_display_dialog.dart'; // 📋 Password Dialog
import 'package:image_picker/image_picker.dart'; // 📸 Image Picker
import 'dart:io'; // File için
import 'package:connectivity_plus/connectivity_plus.dart'; // 📶 İnternet Kontrolü
import 'package:yeniapex/core/utils/permission_helper.dart'; // 🔐 Permission Helper
import 'package:yeniapex/features/auth/screens/auth_wrapper.dart'; // 🔄 Auth Wrapper (Home yönlendirmesi için)


class RoomController extends GetxController with WidgetsBindingObserver {
  final String roomId;
  RoomController(this.roomId);

  final supabase = Supabase.instance.client;
  final authController = Get.find<AuthController>();
  final liveKitService = Get.put(LiveKitService());
  final pieSocket = Get.find<PieSocketService>();

  // Observables
  // State
  final RxMap<String, dynamic> room = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> videoState = <String, dynamic>{}.obs; // {video_url, is_playing, current_time, ...}
  final RxList<Map<String, dynamic>> participants = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  
  // Video Player Key (Widget Rebuild için)
  final playerKey = UniqueKey().obs;

  // Loading States
  final isLoading = true.obs;
  // 🔥 Real-time Active Users (ID -> Profile Map) - PieSocket Presence
  final RxMap<String, Map<String, dynamic>> activeRoomProfiles = <String, Map<String, dynamic>>{}.obs;
  
  // Players & States
  YoutubePlayerController? youtubeController;
  // 🔥 REMOVED: VideoPlayerController (Artık native ExoPlayer kullanıyoruz)
  final RxBool isPlaying = false.obs;
  final RxBool isChatVisible = true.obs;
  final RxBool isMicEnabled = false.obs;
  
  // Video Extraction States
  final RxBool isExtracting = false.obs;
  final RxString extractedUrl = ''.obs;
  final RxString extractionError = ''.obs;
  
  // 🔥 Native Player Progress (Real-time süre takibi)
  final RxInt currentPosition = 0.obs; // Saniye cinsinden
  final RxInt totalDuration = 0.obs; // Saniye cinsinden
  Timer? _positionTimer;
  
  // Settings & Volume
  final RxDouble videoVolume = 1.0.obs;
  final RxBool isRoomChatEnabled = true.obs;
  final RxBool isRoomVoiceEnabled = true.obs;
  final RxBool isRoomLocked = false.obs;
  
  // LiveKit Tracking (React benzeri)
  final RxList<String> micEnabledUsers = <String>[].obs;
  final RxList<String> activeSpeakers = <String>[].obs;
  
  // Message Input Controller
  final TextEditingController messageTextController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();

  // ... (Geri kalan değişkenler değişmedi)

  // Connectivity Variables
  StreamSubscription? _connectivitySubscription; // 📶 İnternet dinleyicisi
  Timer? _connectionTimeoutTimer; // ⏱️ Kopma zamanlayıcısı

  // Share & Friends
  final RxList<Map<String, dynamic>> friendsList = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredFriendsList = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingFriends = false.obs;

  
  // --- ARKADAŞLARI GETİR (Karşılıklı Takip) ---
  Future<void> fetchMutualFriends() async {
    final user = authController.currentUser.value;
    if (user == null) return;

    isLoadingFriends.value = true;
    try {
      // 1. Benim takip ettiklerim
      final following = await supabase.from('follows').select('following_id').eq('follower_id', user.id);
      final followingIds = (following as List).map((e) => e['following_id']).toSet();

      // 2. Beni takip edenler
      final followers = await supabase.from('follows').select('follower_id').eq('following_id', user.id);
      final followerIds = (followers as List).map((e) => e['follower_id']).toSet();

      // 3. Kesişim (Karşılıklı)
      final mutualIds = followingIds.intersection(followerIds).toList();

      if (mutualIds.isEmpty) {
        friendsList.clear();
        filteredFriendsList.clear();
        return;
      }

      // 4. Profilleri Çek
      final profiles = await supabase
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .filter('id', 'in', mutualIds)
          .order('username'); // İstersen updated_at vs.

      friendsList.value = List<Map<String, dynamic>>.from(profiles);
      filteredFriendsList.value = List<Map<String, dynamic>>.from(profiles);

    } catch (e) {
      print("Friends fetch error: $e");
    } finally {
      isLoadingFriends.value = false;
    }
  }

  void filterFriends(String query) {
    if (query.isEmpty) {
      filteredFriendsList.value = friendsList;
    } else {
      filteredFriendsList.value = friendsList.where((friend) {
        final name = (friend['display_name'] ?? '').toString().toLowerCase();
        final username = (friend['username'] ?? '').toString().toLowerCase();
        final q = query.toLowerCase();
        return name.contains(q) || username.contains(q);
      }).toList();
    }
  }

  // --- DAVET GÖNDER ---
  Future<void> sendRoomInvite(String targetUserId) async {
    final user = authController.currentUser.value;
    if (user == null) return;

    // Oda Bilgileri
    final roomTitle = room['title'] ?? 'Sohbet Odası';
    String? thumbnail = room['cover_image_url'];
    
    // Eğer video çalıyorsa onun thumb'ını alabiliriz (Opsiyonel)
    if (videoState.containsKey('thumbnail_url')) {
       // Video varsa video kapağını kullanmak daha çekici olabilir
       thumbnail = videoState['thumbnail_url'];
    }

    // JSON Formatlı Mesaj (Özel Prefix ile)
    // [INVITE] prefix'i ile ChatScreen bunun bir davetiye olduğunu anlayacak.
    final inviteData = {
      'type': 'room_invite',
      'roomId': roomId,
      'title': roomTitle,
      'thumbnail': thumbnail ?? '',
      'inviterName': user.userMetadata?['display_name'] ?? 'Bir Kullanıcı',
    };
    
    // Mesaj içeriği: [ROOM_INVITE] {"..."}
    final messageContent = "[ROOM_INVITE] ${jsonEncode(inviteData)}"; 
    // Not: Dart map'i string'e çevirir ama jsonEncode kullanmak daha güvenli. 
    // Basitlik için string interpolasyon yapıyorum ama aşağıda düzelteceğim.

    try {
      await supabase.from('direct_messages').insert({
        'sender_id': user.id,
        'receiver_id': targetUserId,
        'content': messageContent, // Özel format
        'is_read': false
      });
       // Toast kaldırıldı
    } catch (e) {
      Get.snackbar("Hata", "Davetiye gönderilemedi");
    }
  }

  Future<void> sendInviteToAll() async {
    // Toplu gönderimde spam'a takılmamak için biraz gecikmeli atabiliriz veya direkt döngüyle.
    if (filteredFriendsList.isEmpty) return;
    
    Get.back(); // Popup'ı kapat
    Get.back(); // Popup'ı kapat

    for (var friend in filteredFriendsList) {
       await sendRoomInvite(friend['id']);
       await Future.delayed(const Duration(milliseconds: 100)); // Rate limit koruması
    }
  }

  @override
  void onInit() {
    super.onInit();
    
    // 📶 İNTERNET KONTROLÜ (KILL SWITCH - V2)
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
       print("📶 Connectivity Changed: $results"); // Debug Log
       
       // Sadece 'none' içeriyorsa koptu sayalım.
       final isDisconnected = results.contains(ConnectivityResult.none);
       
       if (isDisconnected) {
          print("⚠️ [Room] Internet Lost! Starting countdown (4s)...");
          
          if (!Get.isSnackbarOpen) {
             Get.showSnackbar(GetSnackBar(
                title: "Bağlantı Sorunu",
                message: "İnternet bağlantınız koptu. 4 saniye içinde bağlanamazsanız odadan çıkarılacaksınız.",
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 3),
             ));
          }
          
          _connectionTimeoutTimer?.cancel();
          _connectionTimeoutTimer = Timer(const Duration(seconds: 4), () {
             print("🚨 [Room] No Internet for 4s. KICKING USER NOW!");
             
             // Önce Timer'ı ve Subscription'ı durdur (Memory Leak önlemi)
             _connectionTimeoutTimer?.cancel();
             _connectivitySubscription?.cancel();
             
             // 🔥 ÖNCE NAVİGASYON (Hemen at, bekleme yapma)
             print("🚨 Navigating to Home (AuthWrapper)...");
             Get.offAll(() => const AuthWrapper());
             
             // Sonra arkada temizlemeye çalış (Internet yoksa fail olur, sorun değil)
             Future.microtask(() => leaveRoom(isKicked: true));

             // Sonra arkada temizlemeye çalış (Internet yoksa fail olur, sorun değil)
             Future.microtask(() => leaveRoom(isKicked: true));
             
             // Kullanıcıya bilgi ver (Dialog yerine Snackbar - Daha güvenli)
             if (Get.context != null) {
                 Get.snackbar("Bağlantı Hatası", "İnternet bağlantınız koptuğu için ana sayfaya yönlendirildiniz.",
                    backgroundColor: Colors.red, colorText: Colors.white, duration: const Duration(seconds: 5),
                    snackPosition: SnackPosition.BOTTOM
                 );
             }

             // 3 saniye sonra dialogu kapat logic'ini de siliyoruz.
          });
       } else {
          // İnternet var!
          if (_connectionTimeoutTimer != null && _connectionTimeoutTimer!.isActive) {
             print("✅ [Room] Internet Restored! Cancelled auto-leave.");
             _connectionTimeoutTimer!.cancel();
             if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
             Get.snackbar("Bağlantı", "İnternet bağlantısı tekrar sağlandı.", backgroundColor: Colors.green, colorText: Colors.white);
          }
       }
    });
    
    // 🔥 Background Service Başlat (Sadece odada)
    FlutterBackgroundService().startService();
    
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this); // 🔥 Lifecycle Takibi (Background Video için)
    _initializeRoom();

    // 🔥 Real-time Presence Sync: activeRoomProfiles değişince participants'ı güncelle (Format Fix)
    ever(activeRoomProfiles, (profiles) {
       if (profiles.isNotEmpty) {
         print("PieSocket: Syncing ${profiles.length} active users to UI");
         // Profile Map'i Participant Map formatına çevir: {user_id: ..., profile: ...}
         participants.value = profiles.values.map((profile) => {
            'user_id': profile['id'],
            'room_id': roomId,
            'profile': profile,
         }).toList();
       }
    });
    
    // 🔥 BACKGROUND PLAYBACK: Notification kontrollerini dinle
    VideoService.onPlayFromNotification = () async {
      await VideoService.play();
      isPlaying.value = true;
    };
    
    VideoService.onPauseFromNotification = () async {
      await VideoService.pause();
      isPlaying.value = false;
    };
  }
  
  @override
  void onClose() async {
    debugPrint('🧹 RoomController.onClose() START');
    
    _connectivitySubscription?.cancel(); // 🛑 Dinleyiciyi durdur
    _connectionTimeoutTimer?.cancel();
    
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    
    // 🔥 Mikrofonu Kapat (Notification'ın gitmesi için ÖNEMLİ!)
    debugPrint('🧹 Disabling microphone...');
    try {
      await liveKitService.toggleMic(false);
    } catch (_) {}
    
    // 🔥 Background Service Durdur
    debugPrint('🧹 Stopping background service...');
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    await Future.delayed(const Duration(milliseconds: 200)); // Service'in durmasını bekle
    
    _positionTimer?.cancel();
    // _syncTimer is not defined in the original code, so it's omitted.
    
    // 🔥 Native player durdur
    debugPrint('🧹 Stopping native video player...');
    VideoService.stopVideo();
    youtubeController?.dispose();
    
    messageTextController.dispose();
    messageFocusNode.dispose();
    
    // 🔥 LiveKit disconnect (mikrofon kapatılacak) - AWAIT!
    debugPrint('🧹 Disconnecting from LiveKit...');
    await liveKitService.disconnect();
    debugPrint('✅ LiveKit disconnected!');
    
    // 🔥 PieSocket unsubscribe
    debugPrint('🧹 Unsubscribing from PieSocket...');
    pieSocket.unsubscribeFromRoom(roomId);
    
    // 🔥 BACKGROUND SERVICE: Service'i durdur
    debugPrint('🧹 Stopping video service...');
    await VideoService.stopService();
    debugPrint('✅ Video service stopped!');
    
    debugPrint('🧹 RoomController.onClose() COMPLETE');
    super.onClose();
  }
  
  Future<void> _initializeRoom() async {
    // 🔥 CRITICAL: Singleton'ı başlat ki listener'lar aktif olsun
    VideoService(); 
    
    // 🔥 12. Video State - Playback Listener (Admin Sync)
    VideoService.onPlaybackStateChanged = (isPlaying) async {
      // Sadece Owner yayın yapar
      if (room['created_by'] == authController.currentUser.value?.id) {
         final currentPos = await VideoService.getCurrentPosition();
         final currentTimeSec = (currentPos / 1000).round();
         
         // Socket yayını
         pieSocket.publishToRoom(roomId, 'video-sync', {
             'action': isPlaying ? 'play' : 'pause',
             'current_time': currentTimeSec,
             'is_playing': isPlaying,
         });

         // DB Güncelleme (Persistence)
         try {
             await supabase.from('video_state').update({
                 'is_playing': isPlaying,
                 'playback_time': currentTimeSec,
                 'updated_at': DateTime.now().toIso8601String()
             }).eq('room_id', roomId);
         } catch(e) {}
      }
    };

    // 🔥 ÖNCELİK 1: Listener'ları KUR (broadcast'leri alabilmek için)
    _setupRealtimeSubscriptions();
    _setupPieSocketListeners();
    _setupLiveKitListeners(); // 🔥 Anti-Ghost (Hayalet Önleyici)
    
    // 🔥 ÖNCELİK 2: PARALEL YÜKLEME (Listener'lar hazır, şimdi data yükle)
    await Future.wait([
      _fetchRoomDetails(),
      _joinRoom(), // Broadcast yapacak, listener'lar hazır!
    ]);
    
    // ✅ Yükleme tamamlandı
    isLoading.value = false;
    debugPrint('✅ Room initialization complete!');
  }

  Future<void> _joinRoom() async {
    final user = authController.currentUser.value;
    if (user == null) return;
    
    try {
      // 👻 GHOST MODE CHECK
      final isGhost = authController.currentProfile.value?['is_ghost_mode'] == true;
      if (isGhost) {
        print('👻 Ghost Mode Activated: Entering room silently...');
        
        // 🔥 GÜVENLİK TEMİZLİĞİ:
        // Eğer yanlışlıkla DB'de kaldıysak veya önceki oturumdan kaldıysa SİL.
        try {
           await supabase.from('room_participants').delete()
             .eq('room_id', roomId)
             .eq('user_id', user.id);
             
           // 🔥 CANLI TEMİZLİK (HEADER & POPUP DÜZELTME):
           // Halihazırda odada olanların ekranından düşmek için "Çıktı" sinyali gönder.
           // Biz aslında odadayız ama onlar bizi "Çıktı" sanıp listeden silecek.
           pieSocket.publishToRoom(roomId, 'system:member_left', {
              'member': user.id
           });

           // 🔥 LOCAL UI TEMİZLİĞİ (Race Condition Fix):
           // Eğer liste biz silmeden önce yüklendiyse (paralel çalıştığı için),
           // kendimizi yerel listeden manuel olarak çıkaralım.
           participants.removeWhere((p) => p['user_id'] == user.id);
           activeRoomProfiles.remove(user.id);
           
        } catch (_) {}
        
        return; 
      }

      // Önce zaten odada mı kontrol et
      final existing = await supabase
          .from('room_participants')
          .select('room_id')
          .eq('room_id', roomId)
          .eq('user_id', user.id)
          .maybeSingle();
      
      final isNewJoin = existing == null;
      print('🚀 _joinRoom: isNewJoin=$isNewJoin, userId=${user.id}');
      
      // Upsert yap (varsa güncelle, yoksa ekle)
      await supabase.from('room_participants').upsert({
         'room_id': roomId,
         'user_id': user.id,
         'profile_id': user.id, 
      });

      // Sistem mesajı gönder
      // NOT: Oda sahibi için de göster (ilk girişte messages boşsa)
      final shouldSendMessage = isNewJoin || messages.isEmpty;
      
      if (shouldSendMessage) {
        final profile = authController.currentProfile.value;
        final name = profile?['display_name'] ?? profile?['username'] ?? 'Bir kullanıcı';
        
        // DB'ye kaydet ve Yayına Çık
        if (isNewJoin) {
          // 🔥 ÖNCELİK 1: PieSocket ile HEMEN broadcast et (gecikme yok!)
          pieSocket.publishToRoom(roomId, 'join', {
            'userId': user.id,
            'username': name,
          });
          
          // 🔥 ÖNCELİK 2: DB insert'i fire-and-forget (async, bekleme!)
          supabase.from('messages').insert({
            'room_id': roomId,
            'user_id': user.id,
            'content': 'Odaya katıldı',
            'message_type': 'system',
            'username': name,
            'avatar_url': profile?['avatar_url'],
          }).then((_) {
            print('✅ System message saved to DB');
          }).catchError((e) {
            print('❌ System message DB error: $e');
          });
        }
      }
    } catch (e) {
      print('Join room error: $e');
    }
  }

  // Veri Çekme
  Future<void> _fetchRoomDetails() async {
    try {
      // Oda Bilgisi
    final roomData = await supabase.from('rooms').select().eq('id', roomId).single();
    room.value = roomData;
    
    // 🛑 YASAKLI ODA KONTROLÜ
    if (roomData['is_banned'] == true || roomData['is_active'] == false) {
      Get.offAllNamed('/home'); // Ana sayfaya at
      Get.snackbar(
        "Oda Erişilemez", 
        "Bu oda yönetici tarafından kapatılmıştır.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      return; // Metodu sonlandır
    }
      
      // Settings Sync
      isRoomChatEnabled.value = roomData['chat_enabled'] ?? true;
      isRoomVoiceEnabled.value = roomData['voice_enabled'] ?? true;
      isRoomLocked.value = roomData['is_locked'] ?? false;

      // Video State
      final vState = await supabase.from('video_state').select().eq('room_id', roomId).maybeSingle();
      if (vState != null) videoState.value = vState;
      
      // 🔥 UI HIZLANDIRMA: Video durumu belli olunca aç (Participants'ı bekleme)
      isLoading.value = false;

      // Katılımcılar ve Cache Doldurma
      await _fetchParticipants();

      // Mesajlar (TEMİZ BAŞLANGIÇ)
    // 🔥 YENİ GİRENLER ESKİ MESAJLARI GÖRMESİN
    messages.clear(); 
    // await _fetchMessages(); // Disable fetch history

      // Video Varsa Player Başlat
      if (videoState['video_url'] != null) {
        _initializePlayer(videoState['video_url']);
      }

      // LiveKit Bağlantısı
      final user = authController.currentUser.value;
      final profile = authController.currentProfile.value;
      if (user != null) {
        final code = room['code'];
        final username = profile?['username'] ?? profile?['display_name'] ?? 'Misafir';
        
        // Hata yakalama ile bağla, oda açılışını engellemesin
        try {
           await liveKitService.connectToRoom(code, roomId, user.id, username);
           
           // 🎵 CRITICAL FIX: LiveKit kendi AudioManager'ı ile arama moduna geçti
           // Tekrar MEDYA MODUNA GEÇİRELİM (LiveKit'i override ediyoruz)
           await Future.delayed(const Duration(milliseconds: 500)); // LiveKit'in init'i bitmesi için bekle
           await AudioManagerService.setMediaMode();
           await AudioManagerService.setMediaMode();
           await AudioManagerService.setSpeakerOn(true);
           print('🎵 [OVERRIDE] LiveKit sonrası medya modu tekrar aktif');
           
           // 🎤 FOREGROUND SERVICE BAŞLAT (React Projesi gibi Odaya girişte)
           // Manifest'te foregroundServiceType="microphone" olduğu için arka planda mikrofona erişebilir.
           // CRASH FIX: Önce izni kontrol et!
           if (await Permission.microphone.request().isGranted) {
               await AudioManagerService.startAudioService();
               print('🎤 [AudioManager] Foreground audio service başlatıldı (Odaya girişte)');
           } else {
               print('⚠️ [AudioManager] Mikrofon izni yok, foreground service BAŞLATILAMADI');
           }
           
           // LiveKit eventlerini dinle (React gibi)
           _setupLiveKitListeners();
        } catch (e) {
           Get.snackbar("Ses Hatası", "Ses sunucusuna bağlanılamadı");
        }
      }

      // isLoading.value = false; ← Kaldırıldı! _initializeRoom() zaten yapıyor
    } catch (e) {
      print("Error fetching room data: $e");
    }
  }
  
  // Helper method: Fetch messages only (used by PieSocket force-refetch)
  Future<void> _fetchMessages() async {
    try {
      // 🌈 JOIN profiles tablosu ile is_admin bilgisini çek
      final msgs = await supabase
          .from('messages')
          .select('*, profile:profiles!messages_user_id_fkey(is_admin)')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(50);
      
      // is_admin bilgisini message nesnesine kopyala
      final processedMsgs = msgs.map((msg) {
        final profile = msg['profile'];
        final userId = msg['user_id']?.toString();
        
        // 1. DB'den gelen profil (RLS yüzünden null gelebilir)
        bool isAdmin = profile?['is_admin'] == true;
        
        // 2. Eğer DB'den alamadıysak Cache'e bak (room_participants üzerinden gelmiş olabilir)
        if (!isAdmin && userId != null && activeRoomProfiles.containsKey(userId)) {
           isAdmin = activeRoomProfiles[userId]?['is_admin'] == true;
           // if (isAdmin) debugPrint('🔎 Recovered isAdmin from cache for $userId in history');
        }
        
        return {
          ...msg,
          'is_admin': isAdmin,
        };
      }).toList();
      
      messages.value = List<Map<String, dynamic>>.from(processedMsgs.reversed);
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }
  
  // Helper method: Fetch participants only (used by PieSocket join event)
  Future<void> _fetchParticipants() async {
    try {
      final parts = await supabase.from('room_participants').select('*, profile:profiles!room_participants_user_id_fkey(*)').eq('room_id', roomId);
      participants.value = List<Map<String, dynamic>>.from(parts);
      
      // 🔥 CACHE SYNC: Katılımcı listesini activeRoomProfiles map'ine de at
      // Böylece chat mesajları geldiğinde is_admin bilgisini buradan alabiliriz.
      for (var p in parts) {
         final profile = p['profile'];
         final userId = p['user_id'];
         if (profile != null && userId != null) {
            activeRoomProfiles[userId.toString()] = profile;
         }
      }
    } catch (e) {
      debugPrint('Error fetching participants: $e');
    }
  }

  void _initializePlayer(String urlOrId) {
  // 🔥 1. ADIM: Native Stream Kontrolü (MP4, M3U8 veya Direct HTTP)
  // Eğer link HTTP ise ve Youtube değilse, direkt Native Player'a ver.
  if ((urlOrId.startsWith('http') || urlOrId.startsWith('https')) && 
      !urlOrId.contains('youtube.com') && 
      !urlOrId.contains('youtu.be')) {
      
      print('[RoomController] 🎥 Direct Native Stream detected: $urlOrId');
      _initializeNativePlayer(urlOrId);
      return;
  }

  // YouTube ID Ayıklama (Eğer URL geldiyse)
  String videoId = urlOrId;
  if (urlOrId.contains('youtube') || urlOrId.contains('youtu.be')) {
     final regExp = RegExp(r'.*(?:(?:youtu\.be\/|v\/|vi\/|u\/\w\/|embed\/)|(?:(?:watch)?\?v(?:i)?=|\&v(?:i)?=))([^#\&\?]*).*');
     final match = regExp.firstMatch(urlOrId)?.group(1);
     if (match != null) videoId = match;
     print('[RoomController] 📺 YouTube ID extracted: $videoId');
  }

  // 🔥 2. ADIM: DB'de hazır extracted stream var mı? (React Logic)
  final existingStreamUrl = videoState['extracted_stream_url'];
  final extractionTimestamp = videoState['extraction_timestamp'];
  final existingVideoId = videoState['video_url'];

  // DB'deki extracted link şu anki video için mi?
  final isSameVideo = existingVideoId != null && existingVideoId.toString().contains(videoId);
  
  if (isSameVideo && existingStreamUrl != null && existingStreamUrl.toString().isNotEmpty) {
    // Süre kontrolü (6 saat = 21600 saniye)
    bool isExpired = false;
    if (extractionTimestamp != null) {
      final extTime = DateTime.tryParse(extractionTimestamp);
      if (extTime != null) {
        final diff = DateTime.now().difference(extTime);
        if (diff.inHours >= 6) isExpired = true;
      }
    }
    
    if (!isExpired) {
      print('[RoomController] ✨ Using pre-extracted stream from DB');
      extractedUrl.value = existingStreamUrl;
      _initializeNativePlayer(existingStreamUrl);
      return;
    } else {
      print('[RoomController] ⏰ Pre-extracted stream expired');
    }
  }
  
  // 🔥 3. ADIM: Yoksa veya süresi dolduysa extraction dene
  _extractAndPlayVideo(videoId);
}

  // LiveKit event listeners (React benzeri)
  void _setupLiveKitListeners() {
    // Participants değişince mic enabled users'ı güncelle
    ever(liveKitService.participants, (participants) {
      final micUsers = <String>[];
      
      for (var p in participants) {
        // Check if mic is enabled (trackPublications check)
        final hasMicTrack = p.trackPublications.values.any(
          (pub) => pub.kind == TrackType.AUDIO && !pub.muted
        );
        
        if (hasMicTrack) {
          // Extract user_id from identity (format: userId_timestamp)
          final userId = p.identity.split('_').first;
          micUsers.add(userId);
        }
      }
      
      micEnabledUsers.value = micUsers;
    });
    
    // Active speakers değişince güncelle
    ever(liveKitService.activeSpeakers, (speakers) {
      final speakerIds = speakers.map((s) => s.identity.split('_').first).toList();
      activeSpeakers.value = speakerIds;
    });

    // 🔥 ANTI-GHOST (Hayalet Temizliği)
    liveKitService.listener?.on<ParticipantDisconnectedEvent>((event) {
        final identity = event.participant.identity;
        if (identity != null) {
            debugPrint("🔥 [Anti-Ghost] User disconnected: $identity");
            // Ekrandan sil
            activeRoomProfiles.remove(identity);
            
            // Eğer bizsek
            if (identity == authController.currentUser.value?.id) {
               isMicEnabled.value = false;
            }

            // 🔥 3. HOME & DB TEMİZLİĞİ (HERKES DENEYECEK)
            // Kim odadaysa ve bunu fark ettiyse, veritabanından silmeyi denesin.
            // RLS izin verirse (Owner veya Admin ise) silinir.
             print("🧹 [Anti-Ghost] Attempting cleanup for: $identity");
                
             // 1. DB'den sil (Temiz UUID kullanarak)
             final cleanId = identity.split('_').first;
             supabase.from('room_participants')
                .delete()
                .eq('room_id', roomId)
                .eq('user_id', cleanId)
                .then((_) => print("✅ DB Cleaned"))
                .catchError((e) => print("❌ DB Clean Error: $e"));
                   
             // 2. 🔥 PieSocket GLOBAL ve ROOM Broadcast
             print("📢 [Anti-Ghost] Broadcasting disconnect for: $identity");
                
             pieSocket.publishToRoom(roomId, 'system:member_left', {'member': identity});
             
             pieSocket.publishToGlobal('force_disconnect', {
                 'member': identity,
                 'room_id': roomId 
             });
             
             // 🔥 LOCAL FIX: Kendi Home Controller'ıma da haber ver!
             // Socket'i beklemeden anında sil.
             try {
                if (Get.isRegistered<HomeController>()) {
                    final homeController = Get.find<HomeController>();
                    homeController.handleGhostUser(roomId, identity);
                }
             } catch(e) {
                print("Home Controller call error: $e");
             }
        }
    });

    // 🎵 CRITICAL FIX: Remote participant track eklendiğinde medya moduna geri dön
    // Başka biri mikrofonu açınca onun sesi AudioTrack (playback) oluşturuyor
    // Bu da Android'i arama moduna geçiriyor, bunu engellemek için override
    liveKitService.listener?.on<TrackPublishedEvent>((event) {
      // İlk override
      Future.delayed(const Duration(milliseconds: 300), () async {
        await AudioManagerService.setMediaMode();
        await AudioManagerService.setSpeakerOn(true);
        print('🎵 [REMOTE TRACK OVERRIDE 1] Remote track published - medya modu aktif');
      });
      
      // İkinci override (LiveKit geri dönebilir)
      Future.delayed(const Duration(milliseconds: 800), () async {
        await AudioManagerService.setMediaMode();
        await AudioManagerService.setSpeakerOn(true);
        print('🎵 [REMOTE TRACK OVERRIDE 2] Tekrar medya modu');
      });
      
      // Üçüncü override (Agresif)
      Future.delayed(const Duration(milliseconds: 1500), () async {
        await AudioManagerService.setMediaMode();
        await AudioManagerService.setSpeakerOn(true);
        print('🎵 [REMOTE TRACK OVERRIDE 3] Final medya modu');
      });
    });


    // 🔥 Initial Check: Eğer zaten katılımcı varsa state'i güncelle
    if (liveKitService.participants.isNotEmpty) {
       final micUsers = <String>[];
       for (var p in liveKitService.participants) {
         final hasMicTrack = p.trackPublications.values.any((pub) => pub.kind == TrackType.AUDIO && !pub.muted);
         if (hasMicTrack) {
           final userId = p.identity.split('_').first;
           micUsers.add(userId);
         }
       }
       micEnabledUsers.value = micUsers;
    }
  }

  // PieSocket event listeners (React benzeri - REAL-TIME!)
  void _setupPieSocketListeners() {
    // 🔥 GHOST MODE CHECK
    final isGhost = authController.currentProfile.value?['is_ghost_mode'] == true;
    
    // Connect to room channel
    pieSocket.subscribeToRoom(roomId, isGhost: isGhost);
    
    // 🔥 1. SYSTEM:MEMBER_JOINED - PieSocket Presence ile yeni kullanıcı katıldı
    pieSocket.onRoomEvent(roomId, 'system:member_joined', (data) async {
      print("PieSocket: User joined event received for ${data['username'] ?? 'unknown'} (${data['userId']})");
      
       final joinedUserId = data['userId'];
       final currentUserId = authController.currentUser.value?.id;
       final isGhost = authController.currentProfile.value?['is_ghost_mode'] == true;
      
       // 👻 GHOST KORUMASI:
       // Eğer gelen "katıldı" sinyali bize aitse VE ghost modundaysak -> İŞLEME ALMA!
       // Bu sayede listeye yanlışlıkla eklenmeyiz.
       if (joinedUserId == currentUserId && isGhost) {
          print("👻 [RoomController] Ignoring self-join event (Ghost Mode)");
          return;
       }

      final member = data['member'] ?? {};
      final userId = member['user']?.toString() ?? member['id']?.toString() ?? data['userId']?.toString();
      
      if (userId != null) {
         // Profil bilgisini çek (eğer yoksa)
         if (!activeRoomProfiles.containsKey(userId)) {
            final profile = await supabase.from('profiles').select().eq('id', userId).maybeSingle();
            if (profile != null) {
               activeRoomProfiles[userId] = profile;
            }
         }
         
         // UI güncellemesi
         _fetchParticipants(); 

         // 🔥 SİSTEM MESAJI EKLEMİYORUZ (DB'den veya _joinRoom'dan zaten geliyor)
         // Sadece bildirim veya log amaçlı bırakabiliriz
         final profile = activeRoomProfiles[userId];
         final name = profile?['display_name'] ?? profile?['username'] ?? 'Yeni kullanıcı';
         debugPrint('PieSocket: User joined event received for $name ($userId)');
         
         // 🔥 SYNC: Oda sahibi bizsek yeni gelene senkronizasyon gönder
         final isOwner = room['created_by'] == authController.currentUser.value?.id;
         if (isOwner) {
            final posMs = await VideoService.getCurrentPosition();
            final pos = (posMs / 1000).round();
            final isPlaying = await VideoService.isPlaying();
            
            pieSocket.publishToRoom(roomId, 'video-sync', {
               'action': 'sync',
               'current_time': pos,
               'is_playing': isPlaying,
               'video_url': videoState['video_url'],
            });
         }
      }
    });
    
    // 🔥 2. SYSTEM:MEMBER_LEFT - Kullanıcı ayrıldı
    pieSocket.onRoomEvent(roomId, 'system:member_left', (data) {
      final member = data['member'] ?? {};
      final userId = member['user']?.toString() ?? member['id']?.toString() ?? data['userId']?.toString();
      
      if (userId != null) {
        print('PieSocket: 🔴 User left: $userId');
        activeRoomProfiles.remove(userId);
        
        // 🔥 ANTI-GHOST (PieSocket Tarafından Tetiklenen)
        // Eğer LiveKit'ten yakalayamazsak buradan yakalayıp temizleyelim.
        print("🧹 [Anti-Ghost] Cleaning up from PieSocket event: $userId");
        
        // 1. DB temizle
        final cleanId = userId.split('_').first;
        supabase.from('room_participants')
           .delete()
           .eq('room_id', roomId)
           .eq('user_id', cleanId)
           .then((_) => print("✅ DB Cleaned (PieSocket Trigger)"))
           .catchError((e) => print("Note: DB Clean skipped or failed: $e"));

        // Ayrıca local map'ten de sil (Temiz ID ile)
        activeRoomProfiles.remove(cleanId);
           
        // 2. Local Home Update
        try {
            if (Get.isRegistered<HomeController>()) {
                Get.find<HomeController>().handleGhostUser(roomId, userId);
            }
        } catch(e) {}
        
        // 3. Global Broadcast (Eğer bizden başkası varsa duysun)
        // Kendi kendimize sonsuz döngü yaratmamak için kontrol edebiliriz ama force_disconnect farklı kanal.
        // Yine de gerekirse atalım.
         pieSocket.publishToGlobal('force_disconnect', {
             'member': userId,
             'room_id': roomId 
         });
      }
    });
    
    // 🔥 3. SYSTEM:MEMBER_LIST - İlk bağlantıda mevcut üyeler
    pieSocket.onRoomEvent(roomId, 'system:member_list', (data) async {
      print('PieSocket: 📋 Member list received');
      final members = data['members'] ?? [];
      final userIds = <String>[];
      
      for (var m in members) {
          final uid = m is String ? m : (m['user'] ?? m['id']);
          if (uid != null) userIds.add(uid.toString());
      }

      // 👻 GHOST KORUMASI: Gelen listeden kendimizi siliyoruz
      final currentUserId = authController.currentUser.value?.id;
      final isGhost = authController.currentProfile.value?['is_ghost_mode'] == true;
      if (isGhost && currentUserId != null) {
          userIds.remove(currentUserId);
          print("👻 [RoomController] Removed self from member list (Ghost Mode)");
      }
      
      if (userIds.isNotEmpty) {
          final profiles = await supabase.from('profiles').select().inFilter('id', userIds);
          for (var p in profiles) {
             activeRoomProfiles[p['id']] = p;
          }
      }
    });
    pieSocket.onRoomEvent(roomId, 'system:member_list', (data) {
      debugPrint('PieSocket: PRESENCE - Member list received');
      // roomMembers zaten PieSocketService'te güncelleniyor
    });
    
    // 4. CUSTOM JOIN EVENT - Manuel gönderilen katılma mesajı (opsiyonel, geriye uyumluluk)
    pieSocket.onRoomEvent(roomId, 'join', (data) {
      debugPrint('PieSocket: Custom join event - ${data['username']}');
      _fetchParticipants();
    });
    
    // 2. MESSAGE EVENT - Yeni mesaj geldi (REAL-TIME!)
    pieSocket.onRoomEvent(roomId, 'message', (data) async {
      debugPrint('PieSocket: New message received');
      
      // 🔥 KENDİ MESAJIMIZI EKLEME (Zaten sendMessage'de ekledik)
      final isOwnMessage = data['user_id'] == authController.currentUser.value?.id;
      if (isOwnMessage) {
        debugPrint('PieSocket: Skipping own message (already added in sendMessage)');
        return;
      }
      
      // 🌈 GELEN MESAJA is_admin BİLGİSİ EKLE
      final userId = data['user_id']?.toString(); // 🔥 toString() garantisi
      if (userId != null) {
        // Önce cache'den kontrol et
        if (activeRoomProfiles.containsKey(userId)) {
          final senderProfile = activeRoomProfiles[userId];
          data['is_admin'] = senderProfile?['is_admin'] == true;
          debugPrint('🔍 [CHAT] Using cached is_admin for $userId: ${data['is_admin']}');
        } else {
          // Cache'de yoksa Supabase'den çek
          try {
            debugPrint('🔍 [CHAT] Fetching is_admin from DB for user: $userId');
            final profile = await supabase
                .from('profiles')
                .select('is_admin')
                .eq('id', userId)
                .maybeSingle();
            
            data['is_admin'] = profile?['is_admin'] == true;
            debugPrint('🔍 [CHAT] DB result - is_admin raw: ${profile?['is_admin']}, evaluated: ${data['is_admin']}');
            
            // Profilin tamamını çekip cache'e eklemek daha iyi olurdu ama şimdilik sadece is_admin lazım
          } catch (e) {
            debugPrint('Error fetching is_admin for user $userId: $e');
            data['is_admin'] = false;
          }
        }
      } else {
        data['is_admin'] = false;
      }
      
      // Başkasının mesajını ekle
      final existingIndex = messages.indexWhere((m) => m['id'] == data['id']);
      if (existingIndex == -1) {
        messages.insert(0, data);
      }
    });

    
    // 3. ROOM SETTINGS UPDATE - Chat/Voice kapatıldı (REAL-TIME!)
    pieSocket.onRoomEvent(roomId, 'room-settings-update', (data) {
      debugPrint('PieSocket: Room settings updated');
      if (data.containsKey('chatEnabled')) {
        isRoomChatEnabled.value = data['chatEnabled'];
      }
      if (data.containsKey('voiceEnabled')) {
        isRoomVoiceEnabled.value = data['voiceEnabled'];
        
        // Eğer voice kapatıldıysa ve owner değilsen mikrofonu kapat
        if (!data['voiceEnabled']) {
          final user = authController.currentUser.value;
          final isOwner = room['created_by'] == user?.id;
          if (!isOwner && isMicEnabled.value) {
            toggleMicrophone();
          }
        }
      }
    });
    
    // 🔥 4. VIDEO SYNC - Owner video oynatıyor/duraklatıyor/değiştiriyor (REAL-TIME!)
    pieSocket.onRoomEvent(roomId, 'video-sync', (data) async {
      debugPrint('PieSocket: Video sync received - ${data['action']}');
      final user = authController.currentUser.value;
      final isOwner = room['created_by'] == user?.id;
      
      // Owner değilse senkronize et
      if (!isOwner) {
        
        // Video Kaldırıldı
        if (data['action'] == 'video-removed') {
           print("PieSocket: VIDEO REMOVED");
           _stopAllPlayers();
           videoState.value = {};
           return;
        }

        // Video Başlatıldı
        if (data['action'] == 'video-started') {
          print("PieSocket: VIDEO STARTED Signal Received!");
          videoState.value = Map<String, dynamic>.from(data);
          final videoUrl = data['video_url']?.toString();
          if (videoUrl != null) {
              // Önceki videoyu temizle ve yenisini başlat
              _extractAndPlayVideo(videoUrl);
          }
        } 
        
        // Play / Pause / Seek / Sync Actions
        else {
           // 🔥 UNIFIED SYNC LOGIC (Play/Pause/Seek/Sync)
           // Her aksiyonda (Play/Pause dahil) zaman kontrolü yap
           final time = (data['current_time'] as num?)?.toInt() ?? 0;
           final shouldPlay = data['is_playing'] ?? false;
           
           // 1. Zaman Kontrolü (>2 sn fark varsa seek yap)
           final currentMs = await VideoService.getCurrentPosition();
           final current = (currentMs / 1000).round();
           
           if ((time - current).abs() > 2) {
               print('[RoomController] 🔄 Sync Drift: Seeking to $time (Local: $current)');
               await VideoService.seekTo(time * 1000);
           }
           
           // 2. Oynatma Durumu Kontrolü
           final isPlayingLocal = await VideoService.isPlaying();
           
           if (shouldPlay && !isPlayingLocal) {
               print('[RoomController] 🔄 Sync: Play');
               await VideoService.play();
               isPlaying.value = true;
           } else if (!shouldPlay && isPlayingLocal) {
               print('[RoomController] 🔄 Sync: Pause');
               await VideoService.pause();
               isPlaying.value = false;
           }
        }
      }
    });
    
    // 7. COVER IMAGE UPDATE
    pieSocket.onRoomEvent(roomId, 'room-cover-update', (data) {
        print("PieSocket: Room cover updated -> ${data['cover_image_url']}");
        room.value = {...room.value, 'cover_image_url': data['cover_image_url']};
        room.refresh(); 
    });

    // 5. FORCE REFETCH - Chat temizlendi (REAL-TIME!)
    pieSocket.onRoomEvent(roomId, 'force-refetch', (data) {
      debugPrint('PieSocket: Force refetch triggered');
      _fetchMessages();
      if (data['type'] == 'participants') {
        _fetchParticipants();
      }
    });
    
    // 6. CLOSE ROOM - Oda sahibi odayı kapattı (REAL-TIME!)
    pieSocket.onRoomEvent(roomId, 'close', (data) {
      debugPrint('PieSocket: Room closed by owner');
      Get.back();
      // Toast kaldırıldı
    });

    // 7. USER BANNED - Kullanıcı yasaklandı (REAL-TIME KICK!)
    pieSocket.onRoomEvent(roomId, 'user-banned', (data) {
      final bannedUserId = data['user_id'];
      final myId = authController.currentUser.value?.id;


      // Eğer yasaklanan ben isem odadan çık
      if (bannedUserId == myId) {
        debugPrint('PieSocket: I was banned from this room');
        Get.back(); // Odadan çık (toast YOK!)
      } else {
        // Başka biri yasaklandı, katılımcı listesini güncelle
        _fetchParticipants();
      }
    });
    
    // 8. ACTIVE SPEAKERS - Konuşan kullanıcılar (REAL-TIME!)
    pieSocket.onRoomEvent(roomId, 'active-speakers', (data) {
      if (data.containsKey('speakers')) {
        activeSpeakers.value = List<String>.from(data['speakers']);
      }
    });
    
    // 🔥 8. MUTE EVENT - Kullanıcı mikrofonu kapattı
    pieSocket.onRoomEvent(roomId, 'mute', (data) {
      final userId = data['userId'];
      if (userId != null) {
        micEnabledUsers.remove(userId.toString());
        debugPrint('PieSocket: User muted - $userId');
      }
    });
    
    // 🔥 9. UNMUTE EVENT - Kullanıcı mikrofonu açtı
    pieSocket.onRoomEvent(roomId, 'unmute', (data) {
      final userId = data['userId'];
      if (userId != null && !micEnabledUsers.contains(userId.toString())) {
        micEnabledUsers.add(userId.toString());
        debugPrint('PieSocket: User unmuted - $userId');
      }
    });
  }

  // Actions
  Future<void> updateVideo(String? videoId, String? title, String? thumbnail) async {
    // Video kaldırılıyorsa
    if (videoId == null) {
      _stopAllPlayers();
      
      try {
        await supabase.from('video_state').upsert({
          'room_id': roomId,
          'video_url': null,
          'video_title': null,
          'thumbnail_url': null,
          'is_playing': false,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'room_id');
      } catch (e) {
        print("DB Clear Error: $e");
      }
      
      // 🔥 GLOBAL ALERT: Video bitti (Home güncelle)
      try {
        pieSocket.publishToGlobal('room_list_update', {
            'type': 'video_update',
            'roomId': roomId,
            'hasVideo': false
        });
        // 🔥 ROOM ALERT: Video kalktı (Kullanıcılar için)
        pieSocket.publishToRoom(roomId, 'video-sync', {'action': 'video-removed'});
      } catch (_) {}
      
      videoState.value = {};
      extractedUrl.value = '';
      return;
    }
    
    try {
      // 1. Önce video bilgisini kaydet (video_type alanı yok)
      final updates = {
        'room_id': roomId,
        'video_url': videoId,
        'video_title': title,
        'thumbnail_url': thumbnail,
        'is_playing': true,
        'updated_at': DateTime.now().toIso8601String(),
        // 'video_type': 'youtube', // DB'de yok
      };
      
      await supabase.from('video_state').upsert(updates, onConflict: 'room_id');
      videoState.value = updates;
      
      // 🔥 GLOBAL ALERT: Video başladı (Home güncelle)
      try {
         pieSocket.publishToGlobal('room_list_update', {
            'type': 'video_update',
            'roomId': roomId,
            'hasVideo': true,
            'thumbnail': thumbnail
         });
      } catch (_) {}
      
      // 🔥 REAL-TIME: Video değiştiğini herkese bildir
      pieSocket.publishToRoom(roomId, 'video-sync', {
        'video_url': videoId,
        'video_title': title,
        'thumbnail_url': thumbnail,
        'is_playing': true,
        'action': 'video-started',
      });
      
      // 2. YouTube stream çıkar
      await _extractAndPlayVideo(videoId);
    } catch (e) {
      print('Update video error: $e');
      Get.snackbar('Hata', 'Video güncellenemedi: $e');
    }
  }
  
  /// YouTube video stream çıkarıp native player'da oynatır
  Future<void> _extractAndPlayVideo(String videoId) async {
    try {
      isExtracting.value = true;
      extractionError.value = '';
      
      print('[RoomController] 📡 Extracting YouTube stream: $videoId');
      
      // 🔥 OPTIMIZATION: Eğer DB'de zaten çıkarılmış link varsa ve yeni ise, tekrar extract etme!
      final savedExtractedUrl = videoState['extracted_stream_url'];
      final savedVideoId = videoState['video_url']; // YouTube URL or ID
      
      // Basit kontrol: Eğer videoState'deki video şu an istenen video ise ve link varsa
      if (savedExtractedUrl != null && savedVideoId != null && savedVideoId.toString().contains(videoId)) {
          print('[RoomController] ⚡ FAST LOAD: Using cached extracted URL from Supabase');
          extractedUrl.value = savedExtractedUrl;
          await _initializeNativePlayer(savedExtractedUrl);
          return;
      }
      
      // Supabase Edge Function'ı çağır
      final result = await YouTubeExtractorService.extractStream(videoId);
      
      print('[RoomController] ✅ Extraction SUCCESS: ${result.quality}');
      
      extractedUrl.value = result.videoUrl;
      
      // Native video player başlat
      await _initializeNativePlayer(result.videoUrl);
      
      // 🔥 UI Force Update (Herkes İçin)
      videoState.refresh();
      
      // Owner ise extracted URL'i kaydet (diğer kullanıcılar için)
      // 🔥 KOLONLAR EKLENDİ - ARTIK AKTİF!
      final isOwner = room['created_by'] == authController.currentUser.value?.id;
      if (isOwner) {
        if (result.videoUrl != null) {
          print('[RoomController] ✨ Extraction successful, updating state');
          extractedUrl.value = result.videoUrl;
          videoState['extracted_stream_url'] = result.videoUrl;
          videoState['extraction_timestamp'] = DateTime.now().toIso8601String();
          videoState.refresh(); // 🔥 UI Force Update
          
          // DB'ye kaydet
          try {
            await supabase.from('video_state').update({
              'extracted_stream_url': result.videoUrl,
              'extraction_source': result.source,
              'extraction_timestamp': DateTime.now().toIso8601String(),
            }).eq('room_id', roomId);
            
            print('[RoomController] 💾 Saved extracted stream for other users');
          } catch (dbError) {
             print('[RoomController] ⚠️ Failed to save extracted stream: $dbError');
          }
        }
      }
      
    } catch (e) {
      print('[RoomController] ❌ Extraction FAILED: $e');
      extractionError.value = 'Video çıkartılamadı: ${e.toString()}';
      
      // Fallback: Toast göster (iframe yerine)
      print('[RoomController] ⚠️ Video extraction failed - showing toast');
      Get.rawSnackbar(
        message: 'Video Yasaklı',
        backgroundColor: Colors.grey[800]!,
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
        snackPosition: SnackPosition.BOTTOM,
      );
      extractedUrl.value = '';
    } finally {
      isExtracting.value = false;
    }
  }
  
  /// 🔥 Native ExoPlayer başlat (MP4/M3U8)
  Future<void> _initializeNativePlayer(String url) async {
    try {
      _positionTimer?.cancel();
      
      final isOwner = room['created_by'] == authController.currentUser.value?.id;
      
      // 🔥 Header yüksekliğini hesapla (SafeArea + Avatar row + padding)
      // SafeArea top: ~44dp (status bar)
      // Header (avatarlar, çıkış butonu, vb): ~80dp
      // Total: ~124dp = ~186px (1.5x density)
      final context = Get.context;
      final density = context != null ? MediaQuery.of(context).devicePixelRatio : 1.5;
      final safeAreaTop = context != null ? MediaQuery.of(context).padding.top : 44.0;
      final headerHeight = 80.0; // Avatar row + padding
      final topMargin = ((safeAreaTop + headerHeight) * density).toInt();
      
      print('🔥 [RoomController] Calculated topMargin: $topMargin px (SafeArea: $safeAreaTop, Header: $headerHeight, Density: $density)');
      
      // 🔥 NATIVE EXOPLAYER - Load Video
      await VideoService.loadVideo(
        url: url,
        title: videoState['video_title'] ?? videoState['title'] ?? 'Apex Party',
        isOwner: isOwner,
        startPosition: 0,
        topMargin: topMargin, // 🔥 Header'ın altında başla
      );
      
      // Key'i yenile (Widget Rebuild)
      playerKey.value = UniqueKey();
      
      // 🔥 Position tracking başlat
      _startPositionTimer();
      
      // Owner ise sync timer başlat
      if (isOwner) {
        _startSyncTimer();
      }
      
      isPlaying.value = true;
      
      print('[RoomController] ✅ Native ExoPlayer started!');
    } catch (e) {
      print('[RoomController] ❌ Native player error: $e');
      rethrow;
    }
  }
  
  /// 🔥 Position tracking timer - real-time süre güncellemesi için
  void _startPositionTimer() async {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      // 🔥 Native player'dan pozisyon al
      final pos = await VideoService.getCurrentPosition();
      currentPosition.value = (pos / 1000).round(); // milliseconds -> seconds
      
      // Duration'ı da güncelle (ilk seferde set et)
      if (totalDuration.value == 0) {
        final duration = await VideoService.getDuration();
        totalDuration.value = (duration / 1000).round();
      }
    });
  }
  
  /// Tüm player'ları durdur
  void _stopAllPlayers() async {
    youtubeController?.pause();
    youtubeController = null;
    
    // 🔥 Native player durdur
    await VideoService.stopVideo();
    
    extractedUrl.value = '';
    isPlaying.value = false;
    _stopSyncTimer();
  }

  // --- Realtime Sync Logic ---
  Timer? _syncTimer;

  void _setupRealtimeSubscriptions() {
    print("🔌 [RoomController] Setup Realtime Channels (Unfiltered Mode)...");

    // 1. ODA DURUMU TAKİBİ (Yasaklama/Silme için)
    // Filtresiz dinle, ID kontrolünü içeride yap (Daha güvenilir)
    final roomChannel = supabase.channel('room_updates_any');
    
    roomChannel.onPostgresChanges(
      event: PostgresChangeEvent.all, // 🔥 Update veya DELETE
      schema: 'public',
      table: 'rooms',
      callback: (payload) {
        // DELETE EVENT?
        if (payload.eventType == PostgresChangeEvent.delete) {
            final oldRecord = payload.oldRecord;
            if (oldRecord['id'] == roomId) {
               print("🚨 [Realtime] ROOM DELETED! Kicking user immediately...");
               Get.offAll(() => const AuthWrapper()); 
               
               // 🔥 Minimal Toast Message
               Get.rawSnackbar(
                 messageText: const Center(
                   child: Text(
                     "Oda kapatıldı",
                     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                   ),
                 ),
                 backgroundColor: Colors.red.withOpacity(0.9),
                 snackPosition: SnackPosition.BOTTOM,
                 borderRadius: 30,
                 margin: const EdgeInsets.fromLTRB(60, 0, 60, 30), // Alttan ve yanlardan boşluk
                 padding: const EdgeInsets.symmetric(vertical: 12),
                 duration: const Duration(seconds: 1), // 1 saniyede kaybolur
                 animationDuration: const Duration(milliseconds: 300),
                 snackStyle: SnackStyle.FLOATING,
               );
            }
            return;
        }

        // UPDATE EVENT?
        final newRecord = payload.newRecord;
        if (newRecord != null && newRecord['id'] == roomId) {
           print("🛑 [Realtime] ROOM UPDATE INTERCEPTED: ${newRecord['is_banned']}");
           if (newRecord['is_banned'] == true || newRecord['is_active'] == false) {
             print("🚨 BANNED/CLOSED! Kicking user immediately...");
             Get.offAll(() => const AuthWrapper()); 
             
             Get.rawSnackbar(
                 messageText: const Center(
                   child: Text(
                     "Oda kapatıldı",
                     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                   ),
                 ),
                 backgroundColor: Colors.red.withOpacity(0.9),
                 snackPosition: SnackPosition.BOTTOM,
                 borderRadius: 30,
                 margin: const EdgeInsets.fromLTRB(60, 0, 60, 30),
                 padding: const EdgeInsets.symmetric(vertical: 12),
                 duration: const Duration(seconds: 1),
                 animationDuration: const Duration(milliseconds: 300),
                 snackStyle: SnackStyle.FLOATING,
               );
           }
        }
      }
    ).subscribe();

    // 2. Video State Realtime Takibi
    final videoChannel = supabase.channel('video_updates_any');
    
    videoChannel.onPostgresChanges(
      event: PostgresChangeEvent.all, // Insert, Update, Delete
      schema: 'public',
      table: 'video_state',
      callback: (payload) {
        final newRecord = payload.newRecord;
        
        // Bizim odaya mı ait?
        if (newRecord == null || newRecord['room_id'] != roomId) return;
        
        print("🎥 [Realtime] VIDEO UPDATE INTERCEPTED: $newRecord");

        // Old state'i sakla
        final oldUrl = videoState['video_url'];
        final newUrl = newRecord['video_url'];
        
        // State'i güncelle
        videoState.value = newRecord;

        // HERKES İÇİN (Owner dahil - çünkü Admin değiştiriyor olabilir)
        // URL boşaldı mı? (Video Kaldırıldı)
        if (newUrl == null || newUrl.toString().isEmpty) {
            print("⏹️ Video has been removed via Realtime.");
            closeVideo();
            return;
        }

        // URL değişti mi veya Video yeni mi başladı?
        // NOT: oldUrl güncelleme öncesi alınmıştı
        if (newUrl != oldUrl) {
            print("🔄 Video URL Changed Realtime: $newUrl");
            _initializePlayer(newUrl);
        } else {
            // URL Aynı, sadece Play/Pause/Seek
            // Eğer biz Ownersak, bu sync'i yapmamalıyız (loop olmasın diye)
            // Ama Admin değiştirdiyse yapmalıyız.
            // Şimdilik Owner isek Sync yapma (kendi player'ımız master), sadece URL değişirse yap.
            if (room['created_by'] != authController.currentUser.value?.id) {
                _syncPlayerWithState(newRecord);
            }
        }
      }
    ).subscribe();
    
    // Eski Chat Mesaj Dinleyicisi
    supabase.from('messages').stream(primaryKey: ['id']).eq('room_id', roomId).order('created_at', ascending: false).limit(1).listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty) {
        final rawMsg = data.first;
        if (!messages.any((m) => m['id'] == rawMsg['id'])) {
           // 🔥 Enrich with is_admin (Stream'den gelmez)
           final newMsg = Map<String, dynamic>.from(rawMsg);
           final userId = newMsg['user_id'];
           
           bool isAdmin = false;
           // 1. Check Cache
           if (userId != null && activeRoomProfiles.containsKey(userId)) {
             isAdmin = activeRoomProfiles[userId]?['is_admin'] == true;
           }
           // 2. Check Self
           if (userId == authController.currentUser.value?.id) {
             isAdmin = authController.currentProfile.value?['is_admin'] == true;
           }
           
           newMsg['is_admin'] = isAdmin;
           messages.insert(0, newMsg);
        }
      }
    });
  }


  void _syncPlayerWithState(Map<String, dynamic> state) async {
     // 🔥 Native ExoPlayer Sync
     final isPlayingDB = state['is_playing'] ?? false;
     final localPlaying = await VideoService.isPlaying();
     
     // Play/Pause
     if (isPlayingDB && !localPlaying) {
        print('[RoomController] 🔄 Sync: Auto-Play');
        await VideoService.play();
        isPlaying.value = true;
     } else if (!isPlayingDB && localPlaying) {
        print('[RoomController] 🔄 Sync: Auto-Pause');
        await VideoService.pause();
        isPlaying.value = false;
     }
     
     // Seek (Zaman Eşitleme)
     // Sadece fark 3 saniyeden büyükse seek yap (sürekli atlama yapmaması için)
     final dbTime = (state['playback_time'] as num?)?.toDouble() ?? 0.0;
     final currentPosMs = await VideoService.getCurrentPosition();
     final localTime = (currentPosMs / 1000).toDouble();
     
     if ((dbTime - localTime).abs() > 3.0) {
        print('[RoomController] 🔄 Sync: Seeking to $dbTime (Local was $localTime)');
        await VideoService.seekTo((dbTime * 1000).toInt());
     }
  }

  // --- Owner Controls ---

  void _startSyncTimer() {
    _syncTimer?.cancel();
    // Her 2 saniyede bir video zamanını DB'ye yaz
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
       final playing = await VideoService.isPlaying();
       if (playing) {
          final posMs = await VideoService.getCurrentPosition();
          final pos = (posMs / 1000).round();
          try {
            await supabase.from('video_state').update({
              'playback_time': pos,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('room_id', roomId);
          } catch (_) {} 
       }
    });
  }
  
  void _stopSyncTimer() {
    _syncTimer?.cancel();
  }
  
  Future<void> toggleNativePlayPause() async {
    // 🔥 Check if playing via native service
    final isPlayingNow = await VideoService.isPlaying();
    
    if (isPlayingNow) {
      // Durdur
      await VideoService.pause();
      isPlaying.value = false;
      _stopSyncTimer(); // Sync durdur
      
      // Get current position
      final currentPos = await VideoService.getCurrentPosition();
      final currentTimeSec = (currentPos / 1000).round();
      
      // 🔥 SOCKET EMIT: Pause
      pieSocket.publishToRoom(roomId, 'video-sync', {
         'action': 'pause',
         'current_time': currentTimeSec,
         'is_playing': false,
      });
      
      // DB Güncelle
      try {
        await supabase.from('video_state').update({
          'is_playing': false,
          'playback_time': currentTimeSec,
        }).eq('room_id', roomId);
      } catch (_) {}
    } else {
      // Başlat
      await VideoService.play();
      isPlaying.value = true;
      _startSyncTimer(); // Sync başlat
      
      // Get current position
      final currentPos = await VideoService.getCurrentPosition();
      final currentTimeSec = (currentPos / 1000).round();
      
      // 🔥 SOCKET EMIT: Play
      pieSocket.publishToRoom(roomId, 'video-sync', {
         'action': 'play',
         'current_time': currentTimeSec,
         'is_playing': true,
      });
      
      // DB Güncelle
      try {
        await supabase.from('video_state').update({
          'is_playing': true,
        }).eq('room_id', roomId);
      } catch (_) {}
    }
  }
  
  Future<void> seekNativeVideo(double seconds) async {
    // Seek öncesi durumu kaydet
    final wasPlaying = await VideoService.isPlaying();
    
    // 🔥 Seek (milliseconds cinsinden gönder)
    await VideoService.seekTo((seconds * 1000).toInt());
    
    // 🔥 SOCKET EMIT: Seek (isPlaying: wasPlaying gönder ki karşı taraf durmasın)
    pieSocket.publishToRoom(roomId, 'video-sync', {
       'action': 'seek',
       'current_time': seconds.toInt(),
       'is_playing': wasPlaying, // Seek yapılsa bile oynuyorsa oynamaya devam etmeli
    });
    
    // DB Update
    try {
      await supabase.from('video_state').update({
          'playback_time': seconds.toInt(),
      }).eq('room_id', roomId);
    } catch (_) {}
  }
  
  Future<void> closeVideo() async {
    await updateVideo(null, null, null);
  }

  // --- Volume Control ---
  void setVolume(double val) async {
    videoVolume.value = val;
    await VideoService.setVolume(val);
  }

  // --- Room Settings Actions ---
  Future<void> toggleRoomChat(bool enabled) async {
    isRoomChatEnabled.value = enabled;
    try {
      // 1. Update DB
      await supabase.from('rooms').update({'chat_enabled': enabled}).eq('id', roomId);
      
      // 2. System Message (Local & Realtime)
      final sysMsg = {
        'id': 'sys_chat_${DateTime.now().millisecondsSinceEpoch}',
        'room_id': roomId,
        'username': 'Sistem',
        'content': enabled ? 'Chat herkes için açıldı' : 'Chat kapatıldı',
        'message_type': 'system',
        'created_at': DateTime.now().toIso8601String(),
      };
      messages.insert(0, sysMsg);
      pieSocket.publishToRoom(roomId, 'message', sysMsg);

      await supabase.from('messages').insert({
        'room_id': roomId,
        'username': 'Sistem',
        'content': sysMsg['content'],
        'message_type': 'system'
      });
      
      // 3. 🔥 REAL-TIME: PieSocket Broadcast
      pieSocket.publishToRoom(roomId, 'room-settings-update', {
        'chatEnabled': enabled,
      });
    } catch (e) {
      debugPrint('toggleRoomChat error: $e');
    }
  }

  Future<void> toggleRoomVoice(bool enabled) async {
    isRoomVoiceEnabled.value = enabled;
    try {
      // 1. Update DB
      await supabase.from('rooms').update({'voice_enabled': enabled}).eq('id', roomId);
      
      // 2. System Message (Local & Realtime)
      final sysMsg = {
        'id': 'sys_voice_${DateTime.now().millisecondsSinceEpoch}',
        'room_id': roomId,
        'username': 'Sistem',
        'content': enabled ? 'Sesli sohbet herkes için açıldı' : 'Sesli sohbet kapatıldı',
        'message_type': 'system',
        'created_at': DateTime.now().toIso8601String(),
      };
      messages.insert(0, sysMsg);
      pieSocket.publishToRoom(roomId, 'message', sysMsg);

      await supabase.from('messages').insert({
        'room_id': roomId,
        'username': 'Sistem',
        'content': sysMsg['content'],
        'message_type': 'system'
      });
      
      // 3. 🔥 REAL-TIME: PieSocket Broadcast
      pieSocket.publishToRoom(roomId, 'room-settings-update', {
        'voiceEnabled': enabled,
      });
      
      // 4. Eğer kapatıldıysa ve owner değilse, mikrofonları kapat
      if (!enabled) {
        final user = authController.currentUser.value;
        final isOwner = room['created_by'] == user?.id;
        if (!isOwner && isMicEnabled.value) {
          toggleMicrophone();
        }
      }
    } catch (e) {
      debugPrint('toggleRoomVoice error: $e');
    }
  }

  Future<void> toggleRoomLock(bool locked) async {
    String? password;
    
    if (locked) {
      // 🔐 Generate random password
      password = generateRoomPassword();
    }
    
    isRoomLocked.value = locked;
    
    try {
      // 1. Update DB
      await supabase.from('rooms').update({
        'is_locked': locked,
        'lock_password': locked ? password : null,
      }).eq('id', roomId);
      
      // 2. Update local room data (for UI to show password immediately)
      room.value = {...room.value, 'lock_password': locked ? password : null, 'is_locked': locked};
      
      // 3. System Message (Local & Realtime)
      final sysMsg = {
        'id': 'sys_lock_${DateTime.now().millisecondsSinceEpoch}',
        'room_id': roomId,
        'username': 'Sistem',
        'content': locked ? 'Oda kilitlendi' : 'Oda kilidi kaldırıldı',
        'message_type': 'system',
        'created_at': DateTime.now().toIso8601String(),
      };
      messages.insert(0, sysMsg);
      pieSocket.publishToRoom(roomId, 'message', sysMsg);

      await supabase.from('messages').insert({
        'room_id': roomId,
        'username': 'Sistem',
        'content': sysMsg['content'],
        'message_type': 'system'
      });
      
      // 4. PieSocket Global Broadcast (for home screen)
      pieSocket.publishToGlobal('lock-update', {
        'room_id': roomId,
        'is_locked': locked,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('toggleRoomLock error: $e');
    }
  }
  
  Future<void> clearChat() async {
     try {
       await supabase.from('messages').delete().eq('room_id', roomId);
       messages.clear(); // Local clean
       
       // 🔥 REAL-TIME: Herkese chat temizlendiğini bildir
       pieSocket.publishToRoom(roomId, 'force-refetch', {'type': 'messages'});
       
       Get.back(); // Close sheet if open
       // Toast removed
     } catch(e) {
       Get.snackbar("Hata", "Sohbet temizlenemedi.");
     }
  }


  


  Future<void> sendMessage(String? text) async {
    final messageText = text ?? messageTextController.text;
    if (messageText.trim().isEmpty) return;
    
    final user = authController.currentUser.value;
    final profile = authController.currentProfile.value;
    
    
    // Clear input immediately
    messageTextController.clear();
    
    // 🔥 FORCE CHECK ADMIN STATUS (Stale Auth Protection)
    bool isRealAdmin = profile?['is_admin'] == true;
    try {
       // Kendi profilimizi tazeleyelim (Optimistic Update hatasını önlemek için)
       if (user != null) {
         final freshProfile = await supabase.from('profiles').select('is_admin').eq('id', user.id).maybeSingle();
         if (freshProfile != null) {
            isRealAdmin = freshProfile['is_admin'] == true;
            print("🔍 [Global Send] Fresh Admin Check: $isRealAdmin");
         }
       }
    } catch (_) {}

    // Send to server - NO optimistic update, directly to DB
    try {
      final insertedMessage = await supabase.from('messages').insert({
        'room_id': roomId,
        'user_id': user?.id,
        'content': messageText,
        'username': profile?['display_name'] ?? 'Kullanıcı',
        'avatar_url': profile?['avatar_url'],
      }).select().single();
      
      // 🔥 REALTIME: Sadece başarılı insert sonrası PieSocket'e publish et
      final messageToPublish = {
        ...insertedMessage,
        'is_admin': isRealAdmin, // 🔥 Taze Admin bilgisini kullan
      };
      
      // Kendi mesajımızı hemen ekle (optimistic)
      messages.insert(0, messageToPublish);
      
      // Başkalarına gönder
      pieSocket.publishToRoom(roomId, 'message', messageToPublish);
      
    } catch (e) {
      Get.snackbar('Hata', 'Mesaj gönderilemedi');
    }
  }

  // 📸 GÖRSEL SEÇ VE GÖNDER
  Future<void> pickAndSendImage() async {
    try {
      // 1. İzin Kontrolü
      final hasPermission = await PermissionHelper.requestStoragePermission();
      if (!hasPermission) {
        Get.snackbar("İzin Gerekli", "Galeri erişimi için izin verin");
        return;
      }

      // 2. Galeriyi Aç
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (image == null) return;

      // 3. Yükleniyor göster (REMOVED)

      // 4. Supabase Storage'a Yükle
      final user = authController.currentUser.value;
      final profile = authController.currentProfile.value;
      final fileName = '${roomId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await File(image.path).readAsBytes();
      
      await supabase.storage
          .from('room_images')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      
      final imageUrl = supabase.storage.from('room_images').getPublicUrl(fileName);

      // 5. Mesaj Olarak Gönder - ÖNCE DB'ye kaydet
      final insertedMessage = await supabase.from('messages').insert({
        'room_id': roomId,
        'user_id': user?.id,
        'content': imageUrl,
        'username': profile?['display_name'] ?? 'Kullanıcı',
        'avatar_url': profile?['avatar_url'],
      }).select().single();
      
      // Gerçek ID ile mesaj oluştur
      final messageToPublish = {
        ...insertedMessage,
        'is_admin': profile?['is_admin'] == true,
      };
      
      // Optimistic update
      messages.insert(0, messageToPublish);
      
      // PieSocket ile herkese gönder
      pieSocket.publishToRoom(roomId, 'message', messageToPublish);


      
    } catch (e) {
      // Silent fail
    }
  }

  void toggleMicrophone() async {
    // Check voice permission (React gibi)
    final user = authController.currentUser.value;
    final isOwner = room['created_by'] == user?.id;
    
    if (!isRoomVoiceEnabled.value && !isOwner) {
      Get.snackbar(
        "Sesli Sohbet Kapalı",
        "Oda sahibi sesli sohbeti kapattı",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    isMicEnabled.toggle();
    liveKitService.toggleMic(isMicEnabled.value);
    
    // 🎵 SES MODU KONTROLÜ (CRITICAL!)
    if (isMicEnabled.value) {
      // ÖNCE medya moduna geç
      await AudioManagerService.setMediaMode();
      await AudioManagerService.setSpeakerOn(true);
      await AudioManagerService.requestAudioFocus();
      
      // 🎤 FOREGROUND SERVICE BAŞLAT (Arka plan için)
      await AudioManagerService.startAudioService();
      
      // 🔥 CRITICAL FIX: WebRTC AudioRecord başladıktan SONRA tekrar override et
      // LiveKit mikrofonu VOICE_COMMUNICATION source ile açıyor, onu medyaya çeviriyoruz
      await Future.delayed(const Duration(milliseconds: 800));
      await AudioManagerService.setMediaMode();
      await AudioManagerService.setSpeakerOn(true); 
      print('🎵 [CRITICAL OVERRIDE] WebRTC AudioRecord sonrası medya modu aktif');
      // 🎵 [CRITICAL OVERRIDE] WebRTC AudioRecord sonrası medya modu aktif
    } else {
      // Mikrofon KAPALI → Normal moda dön
      // await AudioManagerService.abandonAudioFocus(); // Focus bırakma, dinlemeye devam et
      
      // 🎤 FOREGROUND SERVICE DURDURMA! Odadan çıkana kadar açık kalsın.
      // await AudioManagerService.stopAudioService(); 
    }
    
    // Update mic enabled users list
    if (user != null) {
      if (isMicEnabled.value) {
        if (!micEnabledUsers.contains(user.id)) {
          micEnabledUsers.add(user.id);
        }
        // 🔥 REAL-TIME: Unmute event gönder
      pieSocket.publishToRoom(roomId, 'unmute', {'userId': user.id});
      
      // 👻 GHOST: Mikrofon açılınca görünür ol
      final isGhost = authController.currentProfile.value?['is_ghost_mode'] == true;
      if (isGhost) {
           print("👻 [Ghost] Mic ON -> Revealing self");
           // Diğerlerine haber ver
           pieSocket.publishToRoom(roomId, 'system:member_joined', {'member': {'user': user.id}});
           // Kendimizi local listeye de ekleyelim (Listener engelliyor çünkü)
           if (!activeRoomProfiles.containsKey(user.id)) {
               activeRoomProfiles[user.id] = authController.currentProfile.value!;
           }
      }
    } else {
      micEnabledUsers.remove(user.id);
      // 🔥 REAL-TIME: Mute event gönder
      pieSocket.publishToRoom(roomId, 'mute', {'userId': user.id});
      
      // 👻 GHOST: Mikrofon kapanınca tekrar gizlen
      final isGhost = authController.currentProfile.value?['is_ghost_mode'] == true;
      if (isGhost) {
           print("👻 [Ghost] Mic OFF -> Hiding self");
           // Diğerlerine çıkış mesajı gönder
           pieSocket.publishToRoom(roomId, 'system:member_left', {'member': {'user': user.id}});
           // Local listeden sil
           activeRoomProfiles.remove(user.id);
      }
    }
    }
  }

  Future<void> leaveRoom({bool isKicked = false}) async {
    final user = authController.currentUser.value;
    if (user == null) {
      Get.back();
      return;
    }

    final isOwner = room['created_by'] == user.id;

    // 🔥 KILL SWITCH: Eğer atıldıysa (internet koptuysa) soru sormadan işlem yap
    if (isKicked) {
        if (isOwner) {
            try { await _deleteRoom(); } catch (_) {}
        } else {
            try {
                await supabase.from('room_participants').delete().eq('room_id', roomId).eq('user_id', user.id);
            } catch (_) {}
        }
        return;
    }

    if (isOwner) {
       // Odayı kapatmak ister misin? BottomSheet
       Get.bottomSheet(
         Container(
           padding: const EdgeInsets.all(24),
           decoration: const BoxDecoration(
             color: Colors.black,
             borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
             border: Border(top: BorderSide(color: Colors.white12, width: 1)),
           ),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Container(
                 width: 40, height: 4,
                 margin: const EdgeInsets.only(bottom: 20),
                 decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
               ),
               const Text("Odayı Sonlandır?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 12),
               const Text(
                 "Oda sahibi olduğunuz için odadan ayrıldığınızda oda tüm katılımcılar için kapatılacaktır.",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.white60, fontSize: 14),
               ),
               const SizedBox(height: 24),
               Row(
                 children: [
                   Expanded(
                     child: TextButton(
                       onPressed: () => Get.back(),
                       style: TextButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         backgroundColor: Colors.white.withOpacity(0.05),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       child: const Text("İptal", style: TextStyle(color: Colors.white)),
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: TextButton(
                       onPressed: () async {
                         Get.back(); // Popup kapa
                         await _deleteRoom();
                         Get.back(); // Odadan çık
                       },
                       style: TextButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         backgroundColor: Colors.redAccent.withOpacity(0.2),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       child: const Text("Odayı Kapat", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 16),
             ],
           ),
         ),
         isScrollControlled: true,
       ).whenComplete(() {
         FocusManager.instance.primaryFocus?.unfocus();
       });
    } else {
      // 🔥 Normal katılımcı için de onay dialogu göster (React gibi)
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Text("Odadan Ayrıl", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                "Odadan ayrılmak istediğinize emin misiniz?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("İptal", style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  // Sağ Buton: Ayrıl
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        Get.back(); // Close bottom sheet
                        try {
                          await supabase.from('room_participants').delete().eq('room_id', roomId).eq('user_id', user.id);
                          
                          // 🔥 GLOBAL ALERT: Home Sayfası Güncellensin (Kişi sayısı düşsün)
                          try {
                             pieSocket.publishToGlobal('room_list_update', {
                                'type': 'refresh', 
                                'roomId': roomId
                             });
                          } catch (_) {}
                        } catch (_) {}
                        Get.back(); // Exit room
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Ayrıl", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        isScrollControlled: true,
      ).whenComplete(() {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    }
  }

  Future<void> _deleteRoom() async {
     // 🔥 REAL-TIME: Önce herkese oda kapandığını bildir
     pieSocket.publishToRoom(roomId, 'close', {
       'closedBy': authController.currentUser.value?.id,
     });
     
     // 🔥 GLOBAL ALERT: Odanın kapandığını ana sayfaya bildir
     pieSocket.publishToGlobal('room_list_update', {
        'type': 'delete',
        'roomId': roomId
     });
     
     // Odayı sil (Cascade sayesinde mesajlar ve participantlar da silinmeli)
     // Ekstra güvenlik için önce video_state silebiliriz ama cascade varsa gerek yok
     try {
       await supabase.from('rooms').delete().eq('id', roomId);
     } catch (e) {
       print("Oda silme hatası: $e");
       Get.snackbar("Hata", "Oda silinemedi, ancak çıkılıyor.");
     }
  }



  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
       print("� APP BACKGROUND: Native ExoPlayer devam ediyor...");
    } else if (state == AppLifecycleState.resumed) {
       print("🚀 APP FOREGROUND: Geri gelindi.");
    }
  }

  // 📸 ODA KAPAĞI EKLEME
  Future<void> pickCoverImage() async {
    // 1. Depolama izni kontrolü
    final hasPermission = await PermissionHelper.requestStoragePermission();
    if (!hasPermission) {
      Get.snackbar(
        "İzin Gerekli",
        "Fotoğraf seçmek için galeri erişim izni gereklidir.",
        backgroundColor: Colors.orange.withOpacity(0.5),
        colorText: Colors.white,
      );
      return;
    }

    try {
      // 2. Galeri'den fotoğraf seç
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Boyutu küçült
      );

      if (image == null) return;

      // 3. Loading göster
      Get.dialog(
        const Center(child: CircularProgressIndicator(color: Colors.white)),
        barrierDismissible: false,
      );

      // 4. Supabase Storage'a upload
      final file = File(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$roomId/$fileName';

      await supabase.storage.from('room-covers').upload(path, file);

      // 5. Public URL al
      final coverUrl = supabase.storage.from('room-covers').getPublicUrl(path);

      // 6. DB güncelle
      await supabase.from('rooms').update({
        'cover_image_url': coverUrl,
      }).eq('id', roomId);

      // 7. Local state güncelle
      room.value = {...room.value, 'cover_image_url': coverUrl};

      // 8. PieSocket broadcast
      pieSocket.publishToRoom(roomId, 'room-cover-update', {
        'cover_image_url': coverUrl,
      });
      pieSocket.publishToGlobal('room-cover-update', {
        'room_id': roomId,
        'cover_image_url': coverUrl,
        'timestamp': DateTime.now().toIso8601String(),
      });

      Get.back(); // Loading kapat

    } catch (e) {
      Get.back(); // Loading kapat

      debugPrint('pickCoverImage error: $e');
    }
  }

  // �️ ODA KAPAĞI KALDIRMA
  Future<void> removeCoverImage() async {
    try {
      // 1. DB'de cover_image_url'yi NULL yap (Trigger otomatik storage'dan siler)
      await supabase.from('rooms').update({
        'cover_image_url': null,
      }).eq('id', roomId);

      // 2. Local state güncelle
      room.value = {...room.value, 'cover_image_url': null};

      // 3. PieSocket broadcast
      pieSocket.publishToRoom(roomId, 'room-cover-update', {
        'cover_image_url': null,
      });
      pieSocket.publishToGlobal('room-cover-update', {
        'room_id': roomId,
        'cover_image_url': null,
        'timestamp': DateTime.now().toIso8601String(),
      });


    } catch (e) {

      debugPrint('removeCoverImage error: $e');
    }
  }

  // 🚫 KULLANICI YASAKLAMA
  Future<void> banUser(String userId) async {
    try {
      final user = authController.currentUser.value;
      if (user == null) return;

      // Sadece oda sahibi yasaklayabilir
      if (room['created_by'] != user.id) {
        Get.snackbar(
          'Hata',
          'Sadece oda sahibi kullanıcı yasaklayabilir',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Kendini yasaklayamaz
      if (userId == user.id) {
        Get.snackbar(
          'Hata',
          'Kendinizi yasaklayamazsınız',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // 1. DB'ye yasaklı kullanıcı ekle
      await supabase.from('room_bans').insert({
        'room_id': roomId,
        'user_id': userId,
        'banned_by': user.id,
      });

      // 2. Kullanıcıyı odadan çıkar (participants tablosundan sil)
      await supabase
          .from('room_participants')
          .delete()
          .match({'room_id': roomId, 'user_id': userId});

      // 2.5. Yasaklanan kullanıcının adını al (sistem mesajı için)
      final bannedUserProfile = await supabase
          .from('profiles')
          .select('display_name, username')
          .eq('id', userId)
          .single();
      
      final bannedUserName = bannedUserProfile['display_name'] ?? 
                             bannedUserProfile['username'] ?? 
                             'Bir kullanıcı';

      // 3. PieSocket: Yasaklanan kullanıcıya bildir (Real-time kick)
      pieSocket.publishToRoom(roomId, 'user-banned', {
        'user_id': userId,
        'room_id': roomId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 4. Sistem mesajı gönder (chat'e)
      final systemMessage = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'room_id': roomId,
        'user_id': 'system',
        'content': '$bannedUserName odadan atıldı',
        'message_type': 'system',
        'username': 'Sistem',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // DB'ye kaydet (fire-and-forget)
      supabase.from('messages').insert({
        'room_id': roomId,
        'user_id': user.id,
        'content': '$bannedUserName odadan atıldı',
        'message_type': 'system',
        'username': 'Sistem',
      }).then((_) {
        print('✅ Ban system message saved to DB');
      }).catchError((e) {
        print('❌ Ban system message DB error: $e');
      });
      
      // PieSocket ile yay (real-time)
      pieSocket.publishToRoom(roomId, 'message', systemMessage);

      // 5. Home listesini güncelle (banned indicator için)
      pieSocket.publishToGlobal('room_list_update', {
        'type': 'refresh',
        'roomId': roomId,
      });

      // Toast kaldırıldı - sessiz yasaklama
    } catch (e) {
      debugPrint('banUser error: $e');
      Get.snackbar(
        'Hata',
        'Kullanıcı yasaklanamadı: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // 🔍 KULLANICI YASAKLI MI KONTROL ET
  Future<bool> isUserBanned(String userId) async {
    try {
      final ban = await supabase
          .from('room_bans')
          .select('id')
          .match({'room_id': roomId, 'user_id': userId})
          .maybeSingle();

      return ban != null;
    } catch (e) {
      debugPrint('isUserBanned error: $e');
      return false;
    }
  }
}
