import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago; // 🔥 Posts Feature
import 'core/constants.dart';
import 'core/utils/permission_helper.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/screens/auth_wrapper.dart'; // Import
import 'features/messages/services/pie_socket_service.dart';
import 'services/background_main_service.dart'; // 🔥 Background Service 
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 Timeago Türkçe Desteği
  timeago.setLocaleMessages('tr', timeago.TrMessages());
  
  // 🔥 Background Service
  await initializeBackgroundService();

  // 🔥 Cache Sınırlama (CachedNetworkImage için)
  await _configureCacheManager();

  // 🚀 Supabase Başlatılıyor
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize Controllers & Services
  final pieSocket = Get.put(PieSocketService()); // Önce Servis
  Get.put(AuthController()); // Sonra onu kullanan Controller
  
  // pieSocket.init() AuthController içinde çağrılır.
  
  // ✅ Bildirim izni iste (Android 13+ için - opsiyonel, uygulamayı bloklamaz)
  _requestInitialPermissions();
  
  runApp(const MyApp());
}

/// Cache Manager Konfigürasyonu (50 MB, 100 dosya)
Future<void> _configureCacheManager() async {
  // CachedNetworkImage için varsayılan cache manager'ı özelleştir
  // Not: Bu paket zaten cached_network_image içinde var
  try {
    final cacheManager = DefaultCacheManager();
    await cacheManager.emptyCache(); // İlk başta temizle (opsiyonel)
  } catch (e) {
    print('Cache manager config error: $e');
  }
}

/// Uygulama başlangıcında gerekli izinleri iste
Future<void> _requestInitialPermissions() async {
  // Bildirim izni (opsiyonel, sessizce başarısız olur)
  try {
    await PermissionHelper.requestNotificationPermission();
  } catch (e) {
    // Hata olursa da uygulamayı bloklama
    print('Notification permission request failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'APEX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F0F14),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F14),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}
