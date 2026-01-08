import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

class DeviceUtils {
  
  // IP Adresini Al
  static Future<String?> getPublicIP() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (e) {
      print('IP alma hatası: $e');
    }
    return null;
  }

  // Cihaz Bilgisini Al
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'version': iosInfo.systemVersion,
          'identifier': iosInfo.identifierForVendor,
        };
      }
    } catch (e) {
      print('Cihaz bilgisi alma hatası: $e');
    }
    
    return {'platform': 'Unknown'};
  }
}
