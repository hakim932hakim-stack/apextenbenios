import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:yeniapex/features/messages/services/pie_socket_service.dart';
import '../widgets/room_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../room/screens/room_screen.dart';
import '../../room/widgets/room_loading_widget.dart';
import 'dart:math';
import '../widgets/password_input_dialog.dart';

class HomeController extends GetxController {
  final SupabaseClient supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();
  final PieSocketService pieSocket = Get.find<PieSocketService>();
  
  // Odaları tutacak liste
  final RxList<Map<String, dynamic>> rooms = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  // Realtime
  Timer? _debounceTimer;
  RealtimeChannel? _subscriptionChannel;

  @override
  void onInit() {
    super.onInit();
    fetchRooms();
    _setupRealtimeSubscriptions();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _subscriptionChannel?.unsubscribe();
    super.onClose();
  }

  // Odaları Çek
  Future<void> fetchRooms() async {
    try {
      final currentUserId = authController.currentUser.value?.id;

      // React'taki useRooms hook'unun aynısı
      final response = await supabase.from('rooms').select('''
        *,
        owner:profiles!rooms_created_by_fkey(*),
        participants:room_participants(
          *,
          profile:profiles!room_participants_user_id_fkey(*)
        ),
        video_state(*)
      ''').order('created_at', ascending: false);
      
      // Yasaklı odaları çek (eğer giriş yaptıysak)
      List<String> bannedRoomIds = [];
      if (currentUserId != null) {
        try {
          final bans = await supabase
              .from('room_bans')
              .select('room_id')
              .eq('user_id', currentUserId);
          
          bannedRoomIds = bans.map((ban) => ban['room_id'].toString()).toList();
        } catch (e) {
          print('Banned rooms fetch error: $e');
        }
      }

      // Her odaya is_banned flag'i ekle
      var roomsWithBanStatus = response.map((room) {
        return {
          ...room,
          'is_banned': bannedRoomIds.contains(room['id']),
        };
      }).toList();

      // 🔥 SIRALAMA: Admin odaları en üstte, sonra tarih sırasında
      roomsWithBanStatus.sort((a, b) {
        // 1. Admin Kontrolü
        final aIsAdmin = a['owner']?['is_admin'] == true;
        final bIsAdmin = b['owner']?['is_admin'] == true;

        if (aIsAdmin && !bIsAdmin) return -1; // a önce gelir (Admin en üstte)
        if (!aIsAdmin && bIsAdmin) return 1;  // b önce gelir

        // 2. Tarih Kontrolü (Yeniden eskiye)
        final DateTime aDate = DateTime.tryParse(a['created_at'].toString()) ?? DateTime(1970);
        final DateTime bDate = DateTime.tryParse(b['created_at'].toString()) ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      // Gelen veriyi listeye ata
      rooms.value = List<Map<String, dynamic>>.from(roomsWithBanStatus);
    } catch (e) {
      print('Odalar çekilirken hata: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Realtime Setup (Smart Update)
  void _setupRealtimeSubscriptions() {
     final channelName = 'public:home-changes-${DateTime.now().millisecondsSinceEpoch}';
     print("Home Realtime: Setting up subscription to $channelName");
     
     _subscriptionChannel = supabase.channel(channelName);
     
     // 1. ODA DEĞİŞİKLİKLERİ
     _subscriptionChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all, 
          schema: 'public', 
          table: 'rooms', 
          callback: (payload) async {
             final event = payload.eventType;
             final newRecord = payload.newRecord;
             final oldRecord = payload.oldRecord;

             if (event == PostgresChangeEvent.insert) {
               // YENİ ODA: En başa ekle (Pagination'ı bozmaz, anlık görünür)
               await _handleNewRoomInsert(newRecord['id']);
             } 
             else if (event == PostgresChangeEvent.update) {
               // GÜNCELLEME: Sadece ilgili odayı bul
               _updateRoomInList(newRecord);
             } 
             else if (event == PostgresChangeEvent.delete) {
               // SİLME: Listeden çıkart
               rooms.removeWhere((r) => r['id'] == oldRecord['id']);
             }
        })
        
        // 2. KATILIMCI DEĞİŞİKLİKLERİ
        .onPostgresChanges(
          event: PostgresChangeEvent.all, 
          schema: 'public', 
          table: 'room_participants', 
          callback: (payload) {
             final roomId = payload.newRecord['room_id'] ?? payload.oldRecord['room_id'];
             _refreshSingleRoom(roomId);
        })

        // 3. VİDEO DURUMU
        .onPostgresChanges(
          event: PostgresChangeEvent.all, 
          schema: 'public', 
          table: 'video_state', 
          callback: (payload) {
            final roomId = payload.newRecord['room_id'] ?? payload.oldRecord['room_id'];
             _refreshSingleRoom(roomId);
        })
        .subscribe((status, [error]) {
             print("Home Realtime Status: $status");
        });

     // 4. PIESOCKET YEDEK
     pieSocket.onGlobalEvent('room_list_update', (data) {
        if (data is Map) {
           final type = data['type'];
           // Hem camelCase hem snake_case kontrolü
           final roomId = data['roomId'] ?? data['room_id'];
           
           if (type == 'create') {
              _handleNewRoomInsert(roomId);
           } else if (type == 'delete') {
              rooms.removeWhere((r) => r['id'] == roomId);
           } else {
              _refreshSingleRoom(roomId);
           }
        } else {
           _triggerRefresh(); 
        }
     });
     
     pieSocket.onGlobalEvent('lock-update', (data) {
        if (data is Map) {
           final roomId = data['roomId'] ?? data['room_id'];
           if (roomId != null) _refreshSingleRoom(roomId);
        }
     });
     
     pieSocket.onGlobalEvent('room-cover-update', (data) {
         print("PieSocket Home: Cover update received -> $data");
         if (data is Map) {
           final roomId = data['roomId'] ?? data['room_id'];
           if (roomId != null) _refreshSingleRoom(roomId);
        }
     });

     // 🔥 Anti-Ghost Listener
     // Odadan biri hayalet olarak silinirse bunu yakala ve odayı yenile
     pieSocket.onGlobalEvent('system:member_left', (data) {
         print("🔥 [Home] Anti-Ghost event received -> $data");
         // Veri içinde roomId olmalı, yoksa tüm odaları yenile veya member'ın olduğu odayı bul
         // Biz RoomController'dan member bilgisini attık ama roomId yoksa bulamayız.
         // En iyisi tüm odaları yenilemek yerine, ilgili odayı bulmak.
         // Ancak RoomController'dan gönderirken 'roomId' ekleyelim.
         
         if (data is Map) {
            final roomId = data['roomId'] ?? data['room_id']; // RoomController'a bunu eklemeliyiz
            if (roomId != null) {
               _refreshSingleRoom(roomId);
            }
         }
     });

     pieSocket.onGlobalEvent('force_disconnect', (data) {
         if (data is Map) {
            final roomId = data['roomId'] ?? data['room_id'];
            final memberId = data['member'];
            handleGhostUser(roomId, memberId);
         }
     });
  }

  // 🔥 DIRECT ACCESS METHOD (Network beklemeden)
  void handleGhostUser(dynamic roomId, dynamic memberId) {
     if (roomId != null && memberId != null) {
        final mId = memberId.toString();
        print("🔥 [Home] Force Removing Ghost User via Direct/Socket: $mId");
        
        // 1. MANUEL (OPTIMISTIK) SİLME
        final index = rooms.indexWhere((r) => r['id'].toString() == roomId.toString());
        
        if (index != -1) {
            var room = Map<String, dynamic>.from(rooms[index]);
            List participants = List.from(room['participants'] ?? []);
            
            print("   👉 Before Remove: ${participants.length} participants");
            
            // Kullanıcıyı listeden at (String'e çevirerek karşılaştır)
            participants.removeWhere((p) {
               final pUserId = p['user_id']?.toString();
               final pProfileId = p['profile']?['id']?.toString();
               return pUserId == mId || pProfileId == mId;
            });
            
            print("   👉 After Remove: ${participants.length} participants");
            
            room['participants'] = participants;
            rooms[index] = room;
            rooms.refresh(); // GetX UI Update
            print("✅ [Home] UI Updated forcefully.");
        }
        
        // 2. Veritabanından Teyit Et (Biraz gecikmeli)
        Future.delayed(const Duration(milliseconds: 1500), () {
           // Sadece tek odayı değil, her şeyi yenile, garanti olsun.
           fetchRooms(); 
        });
     }
  }

  // TEK BİR ODAYI GÜNCELLE
  Future<void> _refreshSingleRoom(dynamic roomId) async {
    if (roomId == null) return;
    try {
      final response = await supabase.from('rooms').select('''
        *,
        owner:profiles!rooms_created_by_fkey(*),
        participants:room_participants(
          *,
          profile:profiles!room_participants_user_id_fkey(*)
        ),
        video_state(*)
      ''').eq('id', roomId).maybeSingle();

      if (response != null) {
        final index = rooms.indexWhere((r) => r['id'] == response['id']);
        if (index != -1) {
          print("🔄 Single Room Refreshed: ${response['title']}");
          
          final isBanned = rooms[index]['is_banned'] ?? false;
          
          // Yeni map oluştur
          final updatedRoom = Map<String, dynamic>.from(response);
          updatedRoom['is_banned'] = isBanned;
          
          // Listeyi güncelle
          rooms[index] = updatedRoom; 
        } else {
           // Listede yoksa ekle
           rooms.add(response);
        }
        
        // 🔥 SIRALAMAYI YENİLE
        _sortRooms();
      }
    } catch (e) {
      print("Single room refresh error: $e");
    }
  }

  void _sortRooms() {
      rooms.sort((a, b) {
        // 1. Admin Kontrolü
        final aIsAdmin = a['owner']?['is_admin'] == true;
        final bIsAdmin = b['owner']?['is_admin'] == true;

        if (aIsAdmin && !bIsAdmin) return -1;
        if (!aIsAdmin && bIsAdmin) return 1;

        // 2. Tarih Kontrolü
        final DateTime aDate = DateTime.tryParse(a['created_at'].toString()) ?? DateTime(1970);
        final DateTime bDate = DateTime.tryParse(b['created_at'].toString()) ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      rooms.refresh();
  }
  
  Future<void> _handleNewRoomInsert(dynamic roomId) async {
      await _refreshSingleRoom(roomId);
  }

  void _updateRoomInList(Map<String, dynamic> newRecord) {
     final index = rooms.indexWhere((r) => r['id'] == newRecord['id']);
     if (index != -1) {
        print("🔥 UPDATE ROOM GELDİ: ${newRecord['id']}");
        if (newRecord.containsKey('cover_image_url')) {
           print("🖼️ KAPAK RESMİ DEĞİŞTİ: ${newRecord['cover_image_url']}");
        }

        // Mevcut oda verisini al
        final currentRoom = rooms[index];
        
        // Komple yeni bir map oluştur (Referans değişsin diye)
        final Map<String, dynamic> updatedRoom = Map<String, dynamic>.from(currentRoom);
        
        // Yeni gelen verileri işle
        newRecord.forEach((key, value) {
           updatedRoom[key] = value;
        });

        // Listeye tekrar ata
        rooms[index] = updatedRoom;
        
        // Listeyi zorla tetikle
        rooms.refresh();
     }
  }

  // GLOBAL REFRESH (Fallback)
  void _triggerRefresh() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchRooms();
    });
  }

  // Odaya Gir
  Future<void> joinRoom(String roomId) async {
    try {
      final currentUserId = authController.currentUser.value?.id;

      // Yasak kontrolü
      if (currentUserId != null) {
        final ban = await supabase
            .from('room_bans')
            .select('id')
            .match({'room_id': roomId, 'user_id': currentUserId})
            .maybeSingle();

        if (ban != null) {
          Get.rawSnackbar(
            message: 'Yasaklandınız',
            backgroundColor: Colors.red.withOpacity(0.9),
            duration: const Duration(seconds: 1),
          );
          return;
        }
      }

      // Oda bilgisi (Kilit vs)
      final roomData = await supabase
          .from('rooms')
          .select('is_locked, lock_password')
          .eq('id', roomId)
          .single();

      if (roomData['is_locked'] == true) {
        await Get.dialog(
          PasswordInputDialog(
            correctPassword: roomData['lock_password'] ?? '',
            onSuccess: () {
              Get.to(() => RoomScreen(roomId: roomId));
            },
          ),
          barrierDismissible: true,
        );
      } else {
        Get.to(() => RoomScreen(roomId: roomId));
      }
    } catch (e) {
      print('joinRoom error: $e');
      Get.snackbar('Hata', 'Odaya girilemiyor');
    }
  }

  // Oda Oluştur
  Future<void> createRoom() async {
    final user = authController.currentUser.value;
    if (user == null) {
      Get.snackbar('Hata', 'Giriş yapmalısınız');
      return;
    }

    Get.to(() => const RoomLoadingWidget());

    try {
      // 1. Mevcut oda kontrolü
      final existingRoom = await supabase
          .from('rooms')
          .select()
          .eq('created_by', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (existingRoom != null) {
        await Future.delayed(const Duration(seconds: 1)); 
        Get.off(() => RoomScreen(roomId: existingRoom['id']));
        return;
      }

      // 2. Yeni Oda Oluştur
      final profile = authController.currentProfile.value;
      final displayName = profile?['display_name'] ?? profile?['username'] ?? 'Kullanıcı';
      
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final rnd = Random();
      final code = String.fromCharCodes(Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

      final room = await supabase.from('rooms').insert({
        'code': code,
        'title': "$displayName'ın Odası",
        'created_by': user.id,
      }).select().single();

      await supabase.from('video_state').insert({'room_id': room['id']});

      await supabase.from('room_participants').insert({
        'room_id': room['id'],
        'user_id': user.id
      });
      
      // Global Event (Opsiyonel, Supabase zaten yakalıyor ama hız için iyi)
      pieSocket.publishToGlobal('room_list_update', {
         'type': 'create',
         'roomId': room['id']
      });

      await Future.delayed(const Duration(milliseconds: 1500)); 
      
      Get.off(() => RoomScreen(roomId: room['id']));

    } catch (e) {
      Get.back();
      print("Oda oluşturma hatası: $e");
      Get.snackbar("Hata", "Oda oluşturulamadı");
    }
  }
}
