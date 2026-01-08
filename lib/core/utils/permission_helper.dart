import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// İzin Yönetimi Helper
/// Google Play ve App Store gerekliliklerine uygun izin kontrolü
class PermissionHelper {
  
  /// Bildirim İzni İste (Android 13+)
  /// Uygulama başlangıcında çağrılabilir
  static Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      
      if (status.isDenied || status.isPermanentlyDenied) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      
      return status.isGranted;
    }
    
    // iOS için bildirim izni farklı şekilde istenir
    return true; // iOS'ta manuel kontrol gerekli
  }
  
  /// Depolama/Galeri İzni İste
  /// Fotoğraf/Video seçme butonuna basıldığında çağrılmalı
  static Future<bool> requestStoragePermission({
    bool needsVideo = false,
  }) async {
    if (Platform.isAndroid) {
      // Sürüm kontrolü yerine tüm olası izinleri deniyoruz
      // Android < 13: Storage
      // Android 13+: Photos, Videos
      
      List<Permission> permissionsToRequest = [
        Permission.storage,
        Permission.photos,
      ];
      
      if (needsVideo) {
        permissionsToRequest.add(Permission.videos);
      }
      
      // Hepsini iste
      Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();
      
      // Herhangi biri granted ise işlem tamam
      if (statuses[Permission.storage] == PermissionStatus.granted || 
          statuses[Permission.photos] == PermissionStatus.granted ||
          (needsVideo && statuses[Permission.videos] == PermissionStatus.granted)) {
        return true;
      }
      
      // Hiçbiri granted değilse, kalıcı ret kontrolü
      if (statuses[Permission.storage] == PermissionStatus.permanentlyDenied || 
          statuses[Permission.photos] == PermissionStatus.permanentlyDenied) {
        await openAppSettings();
        return false;
      }
      
      return false;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) return true;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return false;
    }
    
    return false;
  }
  
  /// Mikrofon İzni İste
  /// Mikrofon butonuna basıldığında çağrılmalı
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.status;
    
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      // Kullanıcıyı ayarlara yönlendir
      await openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }
  
  /// Kamera İzni İste
  /// Kamera kullanımı için (opsiyonel - şimdilik yok)
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    
    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }
  

}
