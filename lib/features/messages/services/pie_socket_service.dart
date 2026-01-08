import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';

class PieSocketService extends GetxService {
  static const String CLUSTER_ID = "s15480.fra1";
  static const String API_KEY = "2KdZCOv8WEvDfj6aL9p1hWcO22gPTkqluzeAEqg6";
  static const String GLOBAL_CHANNEL = "online-users-global";
  
  AuthController get _authController => Get.find<AuthController>();
  
  
  // Global Connection
  WebSocketChannel? _globalChannel;
  final RxSet<String> onlineUsers = <String>{}.obs;
  
  // DM Connections (ChannelName -> WebSocket)
  final Map<String, WebSocketChannel> _dmChannels = {};
  
  // Custom Global Listeners
  final Map<String, List<Function(dynamic)>> _globalListeners = {};
  
  // Typing Status (UserId -> IsTyping)
  final RxMap<String, bool> typingUsers = <String, bool>{}.obs;
  
  // Custom Global Listeners

  
  Future<void> init({bool isGhost = false}) async {
    connectGlobal(isGhost: isGhost);
  }

  void connectGlobal({bool isGhost = false}) {
    final myId = _authController.currentUser.value?.id;
    if (myId == null) return;

    // 🔥 GHOST MODE: Eğer ghost ise presence=0 ve notify_self=0 yap
    final presence = isGhost ? 0 : 1;
    final notifySelf = isGhost ? 0 : 1;
    final url = "wss://$CLUSTER_ID.piesocket.com/v3/$GLOBAL_CHANNEL?api_key=$API_KEY&notify_self=$notifySelf&presence=$presence&user=$myId";
    
    print("PieSocket Connecting Global with presence=$presence: $url");
    
    try {
      _globalChannel = WebSocketChannel.connect(Uri.parse(url));
      
      _globalChannel!.stream.listen((message) {
        _handleGlobalMessage(message);
      }, onError: (e) {
        print("PieSocket Global Error: $e");
        // Reconnect logic could be added here
      }, onDone: () {
        print("PieSocket Global Disconnected");
      });
      
    } catch (e) {
      print("PieSocket Connection Failed: $e");
    }
  }


  /// Subscribe to a room channel WITH PRESENCE
  void subscribeToRoom(String roomId, {bool isGhost = false}) {
    if (_roomChannels.containsKey(roomId)) return; // Already subscribed
    
    final myId = _authController.currentUser.value?.id;
    if (myId == null) return;
    
    final channelName = "room-$roomId";
    // 🔥 GHOST MODE: Eğer ghost ise presence=0 ve notify_self=0 yap
    final presence = isGhost ? 0 : 1;
    final notifySelf = isGhost ? 0 : 1;
    final url = "wss://$CLUSTER_ID.piesocket.com/v3/$channelName?api_key=$API_KEY&notify_self=$notifySelf&presence=$presence&user=$myId";
    
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _roomChannels[roomId] = channel;
      _roomEventCallbacks[roomId] = {};
      roomMembers[roomId] = <String>{}.obs; // Initialize room members set
      
      channel.stream.listen((message) {
        _handleRoomMessage(roomId, message);
      }, onError: (e) {
        print("PieSocket Room Error: $e");
      }, onDone: () {
        print("PieSocket Room Disconnected: $roomId");
      });
      
      print("PieSocket: Subscribed to Room $roomId with presence=$presence (user: $myId)");
    } catch (e) {
      print("PieSocket Room Connection Error: $e");
    }
  }
  
  void _handleGlobalMessage(dynamic message) {
    // print("PieSocket MSG: $message"); // Debug
    try {
      final data = jsonDecode(message);
      
      // PieSocket Event Formatı: { "event": "eventName", "data": { ... } } veya benzeri
      // Ancak v3 direkt JSON atıyor olabilir.
      
      // React tarafındaki event isimleri: system:member_joined, system:member_list
      // Bu eventler genelde bir 'event' field'ı ile gelir.
      
      final event = data['event'];
      
      if (event == 'system:member_list') {
         // Liste geldi
         final members = data['data']['members'] ?? [];
         onlineUsers.clear();
         for (var m in members) {
           if (m is String) {
              onlineUsers.add(m);
           } else if (m is Map) {
              final uid = m['user'] ?? m['id'] ?? m['uuid'];
              if (uid != null) onlineUsers.add(uid.toString());
           }
         }
         print("PieSocket: Online Users Count: ${onlineUsers.length}");
         
      } else if (event == 'system:member_joined') {
         final m = data['data']['member'];
         String? uid;
         if (m is String) uid = m;
         else if (m is Map) uid = m['user'] ?? m['id'] ?? m['uuid'];
         
         if (uid != null) {
           onlineUsers.add(uid.toString());
           print("PieSocket: User Joined $uid");
         }
         
      } else if (event == 'system:member_left') {
         final m = data['data']['member'];
         String? uid;
         if (m is String) uid = m;
         else if (m is Map) uid = m['user'] ?? m['id'] ?? m['uuid'];
         
         if (uid != null) {
           onlineUsers.remove(uid.toString());
           print("PieSocket: User Left $uid");
         }
      } else if (event == 'force_disconnect') {
         // 🔥 Custom Force Disconnect (Anti-Ghost)
         final m = data['data']['member'];
         String? uid;
         if (m is String) uid = m;
         else if (m is Map) uid = m['user'] ?? m['id'] ?? m['uuid'];
         
         if (uid != null) {
           onlineUsers.remove(uid.toString());
           print("🔥 PieSocket: Force Disconnect User $uid - List Updated");
         }
      } else {
         // Custom Events (örn: room_list_update)
         if (_globalListeners.containsKey(event)) {
             for (var cb in _globalListeners[event]!) {
                 try {
                   cb(data['data']);
                 } catch (e) {
                   print("Listener Error: $e");
                 }
             }
         }
      }
      
    } catch (e) {
      print("PieSocket Global Message Parse Error: $e");
    }

  }

  void publishToGlobal(String event, Map<String, dynamic> data) {
    if (_globalChannel == null) return;
    
    final payload = jsonEncode({
      "event": event,
      "data": data,
      "exclude_self": false
    });
    
    try {
       _globalChannel!.sink.add(payload);
    } catch(e) {
       print("PieSocket Publish Error: $e");
    }
  }
  
  void onGlobalEvent(String event, Function(dynamic) callback) {
    if (!_globalListeners.containsKey(event)) {
      _globalListeners[event] = [];
    }
    _globalListeners[event]!.add(callback);
  }

  // --- DM / Chat Kısmı ---
  
  // İki kişi arasındaki kanal adını oluştur (Alfabetik sıra)
  String getDMChannelName(String otherId) {
    final myId = _authController.currentUser.value?.id ?? "";
    final sorted = [myId, otherId]..sort();
    return "dm-${sorted[0]}-${sorted[1]}";
  }

  void subscribeToDM(String otherId) {
    final channelName = getDMChannelName(otherId);
    if (_dmChannels.containsKey(channelName)) return; // Zaten bağlı

    final url = "wss://$CLUSTER_ID.piesocket.com/v3/$channelName?api_key=$API_KEY&notify_self=1";
    
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _dmChannels[channelName] = channel;
      
      channel.stream.listen((message) {
        _handleDMMessage(message, otherId);
      });
      
      print("PieSocket: Subscribed to DM $channelName");
    } catch (e) {
      print("PieSocket DM Error: $e");
    }
  }
  
  void unsubscribeFromDM(String otherId) {
    final channelName = getDMChannelName(otherId);
    if (_dmChannels.containsKey(channelName)) {
      _dmChannels[channelName]!.sink.close();
      _dmChannels.remove(channelName);
    }
  }

  void _handleDMMessage(dynamic message, String partnerId) {
    try {
      final data = jsonDecode(message);
      final event = data['event'];
      
      if (event == 'typing') {
         // Karşı taraf yazıyor
         // Gelen veride senderId kontrolü yapılmalı
         final senderId = data['data']?['senderId'];
         if (senderId == partnerId) {
           typingUsers[partnerId] = true;
           
           // 3 saniye sonra sil (Debounce)
           Future.delayed(const Duration(seconds: 3), () {
             typingUsers[partnerId] = false;
           });
         }
      }
    } catch (_) {}
  }

  void sendTyping(String otherId) {
    final channelName = getDMChannelName(otherId);
    final channel = _dmChannels[channelName];
    
    if (channel != null) {
      final myId = _authController.currentUser.value?.id;
      // Event formatı: { "event": "typing", "data": { "senderId": "..." } }
      final msg = jsonEncode({
        "event": "typing",
        "data": { "senderId": myId }
      });
      channel.sink.add(msg);
    }
  }
  
  // ============================================
  // ROOM SUPPORT (React benzeri)
  // ============================================
  
  // Room Connections (RoomId -> WebSocket)
  final Map<String, WebSocketChannel> _roomChannels = {};
  
  // Room Event Callbacks (RoomId -> EventType -> Callbacks)
  final Map<String, Map<String, List<Function(Map<String, dynamic>)>>> _roomEventCallbacks = {};
  
  // 🔥 Room Members (RoomId -> Set<UserId>) - PRESENCE TRACKING
  final Map<String, RxSet<String>> roomMembers = {};
  
  
  /// Unsubscribe from a room channel
  void unsubscribeFromRoom(String roomId) {
    if (_roomChannels.containsKey(roomId)) {
      _roomChannels[roomId]!.sink.close();
      _roomChannels.remove(roomId);
      _roomEventCallbacks.remove(roomId);
      print("PieSocket: Unsubscribed from Room $roomId");
    }
  }
  
  /// Handle incoming room messages
  void _handleRoomMessage(String roomId, dynamic message) {
    try {
      final decoded = jsonDecode(message);
      final Map<String, dynamic> data = (decoded is Map<String, dynamic>) ? decoded : {'event': 'unknown', 'data': decoded};
      
      final event = data['event'];
      
      // Safely handle payload
      final rawPayload = data['data'];
      final Map<String, dynamic> payload = (rawPayload is Map<String, dynamic>) 
          ? rawPayload 
          : {'raw_content': rawPayload};
      
      // 🔥 PRESENCE EVENTS (React benzeri)
      if (event == 'system:member_list') {
        // İlk bağlantıda mevcut üye listesi gelir
        final members = payload['members'] ?? [];
        roomMembers[roomId]?.clear();
        for (var m in members) {
          if (m is String) {
             roomMembers[roomId]?.add(m);
          } else if (m is Map) {
             final uid = m['user'] ?? m['id'] ?? m['uuid'];
             if (uid != null) roomMembers[roomId]?.add(uid.toString());
          }
        }
        print("PieSocket Room $roomId: Member list received (${roomMembers[roomId]?.length ?? 0} users)");
        
        // member-list callback'lerini de çağır
        _triggerCallbacks(roomId, 'system:member_list', {'members': roomMembers[roomId]?.toList() ?? []});
        
      } else if (event == 'system:member_joined') {
        // Yeni üye katıldı
        final member = payload['member'] ?? payload;
        String? uid;
        if (member is String) {
           uid = member;
        } else if (member is Map) {
           uid = member['user'] ?? member['id'] ?? member['uuid'];
        }
        
        if (uid != null) {
          roomMembers[roomId]?.add(uid.toString());
          print("PieSocket Room $roomId: Member joined - $uid");
          
          // join callback'lerini çağır (RoomController'da dinleniyor)
          _triggerCallbacks(roomId, 'system:member_joined', {'userId': uid.toString()});
        }
        
      } else if (event == 'system:member_left') {
        // Üye ayrıldı
        final member = payload['member'] ?? payload;
        String? uid;
        if (member is String) {
           uid = member;
        } else if (member is Map) {
           uid = member['user'] ?? member['id'] ?? member['uuid'];
        }
        
        if (uid != null) {
          roomMembers[roomId]?.remove(uid.toString());
          print("PieSocket Room $roomId: Member left - $uid");
          
          // leave callback'lerini çağır
          _triggerCallbacks(roomId, 'system:member_left', {'userId': uid.toString()});
        }
        
      } else {
        // Normal custom eventler (message, video-sync, room-settings-update, etc.)
        _triggerCallbacks(roomId, event, payload is Map<String, dynamic> ? payload : {'data': payload});
      }
    } catch (e) {
      print("PieSocket Room Message Parse Error: $e");
    }
  }
  
  /// Helper: Trigger all registered callbacks for an event
  void _triggerCallbacks(String roomId, String event, Map<String, dynamic> payload) {
    if (_roomEventCallbacks[roomId]?.containsKey(event) == true) {
      for (var callback in _roomEventCallbacks[roomId]![event]!) {
        callback(payload);
      }
    }
  }
  
  /// Register a callback for a specific room event
  void onRoomEvent(String roomId, String eventType, Function(Map<String, dynamic>) callback) {
    if (!_roomEventCallbacks.containsKey(roomId)) {
      _roomEventCallbacks[roomId] = {};
    }
    if (!_roomEventCallbacks[roomId]!.containsKey(eventType)) {
      _roomEventCallbacks[roomId]![eventType] = [];
    }
    _roomEventCallbacks[roomId]![eventType]!.add(callback);
  }
  
  /// Publish an event to a room channel
  void publishToRoom(String roomId, String eventType, Map<String, dynamic> data) {
    final channel = _roomChannels[roomId];
    
    if (channel != null) {
      final myId = _authController.currentUser.value?.id;
      final profile = _authController.currentProfile.value;
      final username = profile?['display_name'] ?? profile?['username'] ?? 'User';
      
      final msg = jsonEncode({
        "event": eventType,
        "data": data,
        "sender": myId,
        "username": username,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });
      
      channel.sink.add(msg);
      print("PieSocket: Published $eventType to room-$roomId");
    } else {
      print("PieSocket: Room channel not found for $roomId");
    }
  }
  
  @override
  void onClose() {
    // Close all connections
    _globalChannel?.sink.close();
    for (var channel in _dmChannels.values) {
      channel.sink.close();
    }
    for (var channel in _roomChannels.values) {
      channel.sink.close();
    }
    super.onClose();
  }
}
