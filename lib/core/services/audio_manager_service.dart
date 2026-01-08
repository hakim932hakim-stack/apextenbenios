import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// 🎵 Audio Manager Service
/// Native AudioManager kontrolü (Android/iOS)
class AudioManagerService {
  static const _channel = MethodChannel('com.apex/audio_manager');
  
  /// 🎵 MEDYA MODU (Video + Hoparlör)
  /// - Hoparlör varsayılan
  /// - Yüksek ses
  /// - Yankı önleme YOK
  static Future<void> setMediaMode() async {
    try {
      await _channel.invokeMethod('setMediaMode');
      print('🎵 [AudioManager] MEDIA MODE aktif');
    } catch (e) {
      print('⚠️ [AudioManager] setMediaMode error: $e');
    }
  }
  
  /// 📞 İLETİŞİM MODU (LiveKit varsayılanı)
  /// - Kulaklık varsayılan
  /// - Düşük ses
  /// - Yankı önleme AÇIK
  static Future<void> setCommunicationMode() async {
    try {
      await _channel.invokeMethod('setCommunicationMode');
      print('📞 [AudioManager] COMMUNICATION MODE aktif');
    } catch (e) {
      print('⚠️ [AudioManager] setCommunicationMode error: $e');
    }
  }
  
  /// 🔊 Hoparlörü zorla aç/kapat
  static Future<void> setSpeakerOn(bool enable) async {
    try {
      await _channel.invokeMethod('setSpeakerOn', {'enable': enable});
      print('🔊 [AudioManager] Hoparlör: ${enable ? "AÇIK" : "KAPALI"}');
    } catch (e) {
      print('⚠️ [AudioManager] setSpeakerOn error: $e');
    }
  }
  
  /// 🎧 Audio Focus iste (Medya odaklı)
  static Future<void> requestAudioFocus() async {
    try {
      await _channel.invokeMethod('requestAudioFocus');
      print('🎧 [AudioManager] Audio Focus istendi');
    } catch (e) {
      print('⚠️ [AudioManager] requestAudioFocus error: $e');
    }
  }
  
  /// 🎧 Audio Focus bırak
  static Future<void> abandonAudioFocus() async {
    try {
      await _channel.invokeMethod('abandonAudioFocus');
      print('🎧 [AudioManager] Audio Focus bırakıldı');
    } catch (e) {
      print('⚠️ [AudioManager] abandonAudioFocus error: $e');
    }
  }

  /// 🎤 Foreground Audio Service Başlat (Arka plan mikrofon)
  static Future<void> startAudioService() async {
    try {
      // 🔥 CRASH FIX: Android 14+ için izin kontrolü ŞART!
      if (await Permission.microphone.isGranted) {
           await _channel.invokeMethod('startAudioService');
           print('🎤 [AudioManager] Foreground audio service başlatıldı');
      } else {
           // İzin yoksa istemeyi dene
           print('⚠️ [AudioManager] Mikrofon izni yok, istek gönderiliyor...');
           if (await Permission.microphone.request().isGranted) {
               await _channel.invokeMethod('startAudioService');
               print('🎤 [AudioManager] Foreground audio service başlatıldı (izin alındı)');
           } else {
               print('❌ [AudioManager] Mikrofon izni reddedildi, servis BAŞLATILAMADI.');
           }
      }
    } catch (e) {
      print('⚠️ [AudioManager] startAudioService error: $e');
    }
  }
  
  /// 🎤 Foreground Audio Service Durdur
  static Future<void> stopAudioService() async {
    try {
      await _channel.invokeMethod('stopAudioService');
      print('🎤 [AudioManager] Foreground audio service durduruldu');
    } catch (e) {
      print('⚠️ [AudioManager] stopAudioService error: $e');
    }
  }
}
