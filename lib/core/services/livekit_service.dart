import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class LiveKitService extends GetxService {
  Room? room;
  EventsListener<RoomEvent>? listener;

  // Reaktif durumlar
  final RxBool isConnected = false.obs;
  final RxList<Participant> participants = <Participant>[].obs;
  final RxList<Participant> activeSpeakers = <Participant>[].obs;



  Future<void> connectToRoom(String roomCode, String roomId, String userId, String username) async {
    try {
      print("LiveKit Token Alınıyor...");
      final supabase = Supabase.instance.client;
      
      // Edge Function Çağrısı
      final res = await supabase.functions.invoke('livekit-token', body: {
        'roomCode': roomCode,
        'roomId': roomId,
        'userId': userId,
        'username': username,
      });

      // Hata kontrolü: invoke metodu hata durumunda zaten exception fırlatır.
      final data = res.data;
      final token = data['token'];
      final url = data['url'];

      print("LiveKit URL: $url");
      
      // Oda Ayarları
      room = Room();
      listener = room!.createListener();

      final options = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: const AudioPublishOptions(
          name: 'microphone',
        ),
      );

      // Bağlan
      await room!.connect(url, token, roomOptions: options);
      isConnected.value = true;
      print("LiveKit Bağlandı!");

      // Event Listenerları Kur
      _setupListeners();
      
      // Mevcut katılımcıları listeye ekle
      _updateParticipants();

    } catch (e) {
      print("LiveKit Bağlantı Hatası: $e");
      isConnected.value = false;
      rethrow;
    }
  }

  void _setupListeners() {
    if (listener == null) return;

    listener!
      ..on<ParticipantConnectedEvent>((event) {
        print("Katılımcı Geldi: ${event.participant.identity}");
        _updateParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        print("Katılımcı Gitti: ${event.participant.identity}");
        _updateParticipants();
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        activeSpeakers.value = event.speakers;
      });
  }

  void _updateParticipants() {
    if (room == null) return;
    final list = <Participant>[];
    if (room!.localParticipant != null) list.add(room!.localParticipant!);
    list.addAll(room!.remoteParticipants.values);
    participants.value = list;
  }

  Future<void> toggleMic(bool enable) async {
    if (room?.localParticipant != null) {
      await room!.localParticipant!.setMicrophoneEnabled(enable);
    }
  }

  Future<void> disconnect() async {
    // 🔥 Önce Local Track'leri STOP et (Mikrofon bildirimini silmek için)
    if (room?.localParticipant != null) {
      await room!.localParticipant!.setMicrophoneEnabled(false);
      await room!.localParticipant!.setCameraEnabled(false);
      
      // Trackleri unpublish et ve stopla
      for (var publication in room!.localParticipant!.trackPublications.values) {
         if (publication.track != null) {
           await publication.track!.stop();
         }
      }
    }

    // Normal disconnect
    await room?.disconnect();
    await room?.dispose(); // 🔥 Room'u da dispose et
    
    listener?.dispose();
    room = null;
    isConnected.value = false;
    participants.clear();
    activeSpeakers.clear();
  }
}
