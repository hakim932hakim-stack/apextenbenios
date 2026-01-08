import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'dart:async';

class MessagesController extends GetxController {
  final supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();

  // Inbox Data
  final RxList<Map<String, dynamic>> conversations = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingInbox = true.obs;

  // Chat Data
  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingChat = false.obs;
  final RxBool isPartnerTyping = false.obs; // Typing status
  final RxBool isPartnerOnline = false.obs; // Online status

  RealtimeChannel? _myChannel; // Inbox dinleyicisi
  RealtimeChannel? _chatChannel; // Chat dinleyicisi
  Timer? _typingTimer;

  // Live Search için
  final RxString searchText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchConversations();
    _subscribeToInbox();
    initExtras(); 
    
    // Her 500ms'de bir arama yap (Yazarken anlık arama)
    debounce(searchText, (query) {
      if(query.toString().isNotEmpty) {
        searchUsers(query.toString());
      } else {
        searchResults.clear();
      }
    }, time: const Duration(milliseconds: 500));
  }

  @override
  void onClose() {
    _myChannel?.unsubscribe();
    _chatChannel?.unsubscribe();
    super.onClose();
  }

  // --- INBOX (MESAJ KUTUSU) ---

  Future<void> fetchConversations() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    isLoadingInbox.value = true;
    try {
      final response = await supabase
          .from('direct_messages')
          .select('*')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> conversationMap = {};

      for (var msg in response) {
        final isMe = msg['sender_id'] == userId;
        final partnerId = isMe ? msg['receiver_id'] : msg['sender_id'];

        if (!conversationMap.containsKey(partnerId)) {
          // Partner bilgisini al (Cache'den veya DB'den)
          final userProfile = await _fetchUserProfile(partnerId);
          
          conversationMap[partnerId] = {
            'user': userProfile, 
            'last_message': msg['content'],
            'created_at': msg['created_at'],
            'unread_count': 0, // Sonra hesaplanır
            'messages': <Map<String, dynamic>>[] // Mesajları burada toplamıyoruz ama gerekirse
          };
        }
        
        // Unread Count
        if (!isMe && !(msg['is_read'] as bool)) {
           var current = conversationMap[partnerId]!['unread_count'] as int;
           conversationMap[partnerId]!['unread_count'] = current + 1;
        }
      }

      conversations.value = conversationMap.values.toList();
    } catch (e) {
      print("Conversations error: $e");
    } finally {
      isLoadingInbox.value = false;
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    try {
      final data = await supabase.from('profiles').select().eq('id', userId).single();
      return data;
    } catch (e) {
      return {'id': userId, 'username': 'Unknown', 'avatar_url': null};
    }
  }

  // Notification Dot
  final RxBool hasUnreadMessages = false.obs;

  void _subscribeToInbox() {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    _myChannel = supabase.channel('public:direct_messages:inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            // Yeni mesaj geldi!
            fetchConversations();
            
            // 🔥 Home ekranındaki kırmızı noktayı yak
            hasUnreadMessages.value = true;
            
            // İsteğe bağlı: Bildirim sesi çalabilirsin
            // SystemSound.play(SystemSoundType.click);
          },
        )
        .subscribe();
  }

  // Mesajlar ekranına girince çağıracağız
  void clearUnreadNotification() {
    hasUnreadMessages.value = false;
  }

  // --- CHAT (SOHBET) ---

  Future<void> loadChat(String partnerId) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    isLoadingChat.value = true;
    messages.clear();
    isPartnerTyping.value = false;
    isPartnerOnline.value = false;

    try {
      final response = await supabase
          .from('direct_messages')
          .select('*')
          .or('and(sender_id.eq.$userId,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$userId)')
          .order('created_at', ascending: false); // 🔥 AZALAN SIRA (En yeni en başta)
      
      messages.value = List<Map<String, dynamic>>.from(response);

      // Okundu işaretle
      markAsRead(partnerId);

      // Realtime Dinleme Başlat
      _subscribeToChat(partnerId);

    } catch (e) {
      print("Chat load error: $e");
    } finally {
      isLoadingChat.value = false;
    }
  }

  void _subscribeToChat(String partnerId) {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    // Önceki kanalı kapat
    _chatChannel?.unsubscribe();

    // Kanal Adı: dm-{sorted_ids} (React ile aynı formatı deneyelim)
    final ids = [userId, partnerId]..sort();
    final channelName = 'dm-${ids[0]}-${ids[1]}';

    _chatChannel = supabase.channel(channelName)
      // 1. Yazıyor (Typing) Göstergesi
      .onBroadcast(event: 'typing', callback: (payload) {
        if (payload['senderId'] == partnerId) {
          isPartnerTyping.value = true;
          // 3 saniye sonra typing'i kapat
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(milliseconds: 3000), () {
            isPartnerTyping.value = false;
          });
        }
      })
      // 2. Presence ve Diğerleri...
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'direct_messages',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, 
            column: 'sender_id', 
            value: partnerId
        ), 
        callback: (payload) {
          final newMsg = payload.newRecord;
          // Eğer bu sohbetin mesajıysa ekle
          if ((newMsg['sender_id'] == partnerId && newMsg['receiver_id'] == userId) || 
              (newMsg['sender_id'] == userId && newMsg['receiver_id'] == partnerId)) {
             
             // 🔥 TERS LİSTE OLDUĞU İÇİN EN BAŞA EKLE (UI'da en altta gözükür)
             messages.insert(0, newMsg);
             markAsRead(partnerId);
          }
        },
      )
      .subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          // Kanala katıldım, varlığımı bildir
           await _chatChannel?.track({'user_id': userId, 'online_at': DateTime.now().toIso8601String()});
        }
      });
  }

  // Mesaj Gönder
  Future<void> sendMessage(String partnerId, String content) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    // Geçici ("Optimistic") Ekleme
    final tempMsg = {
       'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
       'sender_id': userId,
       'receiver_id': partnerId,
       'content': content,
       'created_at': DateTime.now().toIso8601String(),
       'is_read': false
    };
    // TERS LİSTE: En başa ekle
    messages.insert(0, tempMsg); 

    try {
      final response = await supabase.from('direct_messages').insert({
        'sender_id': userId,
        'receiver_id': partnerId,
        'content': content
      }).select().single();

      // Temp mesajı gerçek olanla değiştir
      final index = messages.indexWhere((m) => m['id'] == tempMsg['id']);
      if (index != -1) {
        messages[index] = response;
      }
      
      // Inbox'ı güncelle (son mesaj değişti)
      fetchConversations();

    } catch (e) {
      print("Send message error: $e");
      messages.remove(tempMsg); // Hata varsa sil
      Get.snackbar("Hata", "Mesaj gönderilemedi");
    }
  }

  // Resim Gönder
  Future<void> sendImageMessage(String partnerId, dynamic imageFile) async {
      try {
        final userId = authController.currentUser.value?.id;
        if (userId == null) return;

        Get.snackbar("Yükleniyor", "Resim gönderiliyor...", showProgressIndicator: true);

        // 1. Storage'a Yükle
        final fileName = 'chat_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = 'chat_images/$fileName';
        
        // imageFile File tipindedir (dart:io)
        await supabase.storage.from('avatars').upload(path, imageFile);
        
        // 2. URL al
        final imageUrl = supabase.storage.from('avatars').getPublicUrl(path);
        
        // 3. Mesaj olarak gönder
        if (imageUrl.isNotEmpty) {
           await sendMessage(partnerId, imageUrl);
        }
      } catch (e) {
        print("Image upload error: $e");
        Get.snackbar("Hata", "Resim yüklenemedi: $e");
      }
  }

  // Yazıyor... Gönder
  Future<void> sendTyping(String partnerId) async {
    final userId = authController.currentUser.value?.id;
    if(userId == null || _chatChannel == null) return;

    await _chatChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'senderId': userId},
    );
  }

  Future<void> markAsRead(String partnerId) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    await supabase
        .from('direct_messages')
        .update({'is_read': true})
        .eq('sender_id', partnerId)
        .eq('receiver_id', userId)
        .eq('is_read', false);
    
    // Inbox sayısını güncelle
    final convIndex = conversations.indexWhere((c) => c['user']['id'] == partnerId);
    if (convIndex != -1) {
      var conv = Map<String, dynamic>.from(conversations[convIndex]);
      conv['unread_count'] = 0;
      conversations[convIndex] = conv;
    }
  }

  // --- EKSTRA ÖZELLİKLER (DND, SEARCH, FOLLOW) ---

  final RxBool doNotDisturb = false.obs;
  final RxInt pendingRequestsCount = 0.obs;
  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  final RxBool isSearching = false.obs;

  Future<void> initExtras() async {
    await checkDNDStatus();
    await fetchPendingRequestsCount();
    _subscribeToFollowRequests();
  }

  // DND (Rahatsız Etme)
  Future<void> checkDNDStatus() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;
    try {
      final data = await supabase.from('profiles').select('do_not_disturb').eq('id', userId).single();
      doNotDisturb.value = data['do_not_disturb'] ?? false;
    } catch (_) {}
  }

  Future<void> toggleDND() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;
    
    final newVal = !doNotDisturb.value;
    doNotDisturb.value = newVal; // Optimistic update

    try {
      await supabase.from('profiles').update({'do_not_disturb': newVal}).eq('id', userId);
      
      // AuthController'daki profil verisini de güncelle ki senkronize olsun
      await authController.refreshUser();
      
    } catch (e) {
      doNotDisturb.value = !newVal; // Revert
      Get.snackbar("Hata", "Ayarlar güncellenemedi");
    }
  }

  // Takip İstekleri Sayısı & Realtime
  Future<void> fetchPendingRequestsCount() async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('follow_requests')
          .select('id') 
          .eq('target_id', userId)
          .eq('status', 'pending');
          
      pendingRequestsCount.value = (response as List).length;
    } catch (_) {}
  }

  void _subscribeToFollowRequests() {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    supabase.channel('follow_requests_count')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'follow_requests',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'target_id', value: userId),
        callback: (payload) => fetchPendingRequestsCount(),
      )
      .subscribe();
  }

  // Kullanıcı Arama
  Future<void> searchUsers(String query) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null || query.trim().isEmpty) {
      searchResults.clear();
      return;
    }

    isSearching.value = true;
    print("DEBUG: Searching for $query"); // LOG
    try {
      final data = await supabase
          .from('profiles')
          .select('id, display_name, username, avatar_url, is_admin')
          .neq('id', userId)
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);
      
      print("DEBUG: Found ${data.length} results"); // LOG
      searchResults.value = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Search error: $e");
    } finally {
      isSearching.value = false;
    }
  }
  
  // Takip Et
  Future<void> followUser(String targetId) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    // Önce eski istekleri sil (temizlik)
    await supabase.from('follow_requests').delete().match({'requester_id': userId, 'target_id': targetId});

    // Yeni istek
    await supabase.from('follow_requests').insert({
       'requester_id': userId,
       'target_id': targetId,
       'status': 'pending'
    });
    
    Get.snackbar("Başarılı", "Takip isteği gönderildi");
  }

  // İstek Listesi (UI için)
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
     final userId = authController.currentUser.value?.id;
     if (userId == null) return [];

     final data = await supabase
       .from('follow_requests')
       .select('*, requester:profiles!requester_id(*)')
       .eq('target_id', userId)
       .eq('status', 'pending');
       
     return List<Map<String, dynamic>>.from(data);
  }

  Future<void> acceptRequest(String requestId, String requesterId) async {
      final userId = authController.currentUser.value?.id;
      if (userId == null) return;

      // 1. Follows'a ekle
      await supabase.from('follows').insert({
        'follower_id': requesterId,
        'following_id': userId
      });

      // 2. İsteği sil
      await supabase.from('follow_requests').delete().eq('id', requestId);
      
      // Listeyi güncelle (UI tarafında manuel çağrılacak veya realtime)
      fetchPendingRequestsCount();
  }
  
  Future<void> rejectRequest(String requestId) async {
      await supabase.from('follow_requests').delete().eq('id', requestId);
      fetchPendingRequestsCount();
  }

  // Sohbet Başlat (Karşılıklı Takip Kontrolü)
  Future<bool> checkMutualFollow(String targetId) async {
    final userId = authController.currentUser.value?.id;
    if (userId == null) return false;
    
    try {
        final iFollow = await supabase.from('follows').select('id').match({'follower_id': userId, 'following_id': targetId}).maybeSingle();
        final theyFollow = await supabase.from('follows').select('id').match({'follower_id': targetId, 'following_id': userId}).maybeSingle();
        
        return iFollow != null && theyFollow != null;
    } catch (e) {
      return false;
    }
  }
}
