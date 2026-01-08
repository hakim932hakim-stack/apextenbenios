import 'dart:async';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeniapex/features/auth/screens/auth_wrapper.dart';
import 'package:yeniapex/features/auth/screens/login_screen.dart';
import 'package:yeniapex/core/utils/toast_utils.dart'; // Import this
import 'package:yeniapex/core/utils/device_utils.dart';
import 'package:yeniapex/features/messages/services/pie_socket_service.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();
  
  final Rx<User?> currentUser = Rx<User?>(null);
  final Rx<Map<String, dynamic>?> currentProfile = Rx<Map<String, dynamic>?>(null); // Profil verisi
  final RxBool isLoading = false.obs;
  final RxBool isProfileComplete = false.obs;
  final RxBool isProfileChecking = true.obs; // Profil kontrolü devam ediyor mu?

  RealtimeChannel? _banChannel;
  Timer? _banCheckTimer; // Periyodik ban kontrolü

  @override
  void onInit() {
    super.onInit();
    currentUser.value = Supabase.instance.client.auth.currentUser;
    _checkProfileCompletion();
    
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      currentUser.value = user;
      
      if (user != null) {
        // Login oldu, profil kontrolü başlayacak -> Loading göster
        isProfileChecking.value = true; 
        _checkProfileCompletion();
        _listenForBanStatus(); // Ban kontrolünü başlat
        _startBanCheckTimer(); // Periyodik ban kontrolü başlat
      } else {
        isProfileComplete.value = false;
        isProfileChecking.value = false; // Logout
        _banChannel?.unsubscribe(); // Logout olunca dinlemeyi durdur
        _banCheckTimer?.cancel(); // Timer durdur
      }
    });
  }

  // Real-time Ban Takibi
  void _listenForBanStatus() {
    final user = currentUser.value;
    if (user == null) return;
    
    _banChannel?.unsubscribe();
    
    // Anlık değişiklikleri dinle (Channel daha güvenilirdir)
    _banChannel = Supabase.instance.client.channel('public:profiles:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: user.id),
          callback: (payload) async {
             final newRecord = payload.newRecord;
             final isBanned = newRecord['is_banned'] ?? false;
            
             if (isBanned) {
                await signOut();
                ToastUtils.show(
                  "Giriş Engellendi", 
                  "Hesabınız yönetici tarafından askıya alınmıştır.", 
                  isError: true,
                );
             }
          }
        )
        .subscribe();
  }

  // Login
  Future<void> signIn(String email, String password) async {
    try {
      isLoading.value = true;
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if(response.session != null) {
          // Başarılı giriş
          await refreshUser();
      }
    } catch (e) {
      ToastUtils.show("Hata", "Giriş yapılamadı: ${e.toString()}", isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  // Register
  Future<void> signUp(String email, String password, String username) async {
    try {
      isLoading.value = true;
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'display_name': username},
      );
      
      if (response.user != null) {
        ToastUtils.show("Başarılı", "Kayıt olundu! Hoş geldiniz.", isSuccess: true);
        
        if (Supabase.instance.client.auth.currentUser != null) {
             await refreshUser();
             if(Get.isDialogOpen ?? false) Get.back(); 
             
             // Yönlendirme
             Get.offAll(() => const AuthWrapper()); 
        } else {
            ToastUtils.show("Bilgi", "Lütfen email kutunuzu kontrol edin.");
            Get.offAll(() => const LoginScreen());
        }
      }
    } catch (e) {
      ToastUtils.show("Hata", "Kayıt yapılamadı: ${e.toString()}", isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  // Kullanıcı bilgisini tazele
  Future<void> refreshUser() async {
    try {
      final response = await Supabase.instance.client.auth.getUser();
      if (response.user != null) {
        currentUser.value = response.user;
        await _checkProfileCompletion();
      }
    } catch (e) {
      print("User Refresh Error: $e");
    }
  }

  // Profil Tamamlanma Durumunu Kontrol Et
  Future<void> _checkProfileCompletion() async {
    final user = currentUser.value;
    if (user == null) {
        isProfileComplete.value = false;
        isProfileChecking.value = false; // Critical fix: Stop loading/black screen
        return;
    }

    try {
      // 🔥 ÖNCE CURRENT IP VE CİHAZI AL
      final currentIP = await DeviceUtils.getPublicIP();
      final currentDeviceInfo = await DeviceUtils.getDeviceInfo();
      final deviceFingerprint = '${currentDeviceInfo['platform']}-${currentDeviceInfo['brand']}-${currentDeviceInfo['model']}';

      // 🔥 1. IP BAN KONTROLÜ (CURRENT IP)
      if (currentIP != null) {
        final ipBanCheck = await Supabase.instance.client
            .from('banned_ips')
            .select('id')
            .eq('ip_address', currentIP)
            .maybeSingle();
        
        if (ipBanCheck != null) {
          await signOut();
          ToastUtils.show(
            "Giriş Engellendi", 
            "Bu IP adresi yasaklanmıştır. Destek ekibi ile iletişime geçin.", 
            isError: true,
          );
          return;
        }
      }

      // 🔥 2. CİHAZ BAN KONTROLÜ (CURRENT DEVICE)
      final deviceBanCheck = await Supabase.instance.client
          .from('banned_devices')
          .select('id')
          .eq('device_fingerprint', deviceFingerprint)
          .maybeSingle();
      
      if (deviceBanCheck != null) {
        await signOut();
        ToastUtils.show(
          "Giriş Engellendi", 
          "Bu cihaz yasaklanmıştır. Destek ekibi ile iletişime geçin.", 
          isError: true,
        );
        return;
      }

      // 🔥 3. PROFİL VERİSİNİ ÇEK
      final data = await Supabase.instance.client
          .from('profiles')
          .select('*') // Tüm veriyi çek
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        // 🔥 4. HESAP BAN KONTROLÜ
        if (data['is_banned'] == true) {
           await signOut();
           ToastUtils.show(
              "Giriş Engellendi", 
              "Hesabınız yönetici tarafından askıya alınmıştır.", 
              isError: true,
           );
           return;
        }

        currentProfile.value = data; // Profil verisini state'e at
        isProfileComplete.value = data['is_profile_complete'] ?? false;
        
        // 🔥 IP ve Cihaz Bilgisini Kaydet (Giriş Takibi)
        await _updateLoginTracking(user.id);
        
        // PieSocket Başlat (Ghost Mode Kontrolü ile)
        try {
          final isGhost = data['is_ghost_mode'] == true;
          Get.find<PieSocketService>().init(isGhost: isGhost);
        } catch (_) {}
      } else {
         isProfileComplete.value = false;
         currentProfile.value = null;
      }
    } catch (e) {
      print("Profile check error: $e");
    } finally {
      isProfileChecking.value = false; // Kontrol bitti
    }
  }

  // IP ve Cihaz Bilgisini Güncelle
  Future<void> _updateLoginTracking(String userId) async {
    print('🔍 Starting login tracking for user: $userId');
    try {
      // IP ve Cihaz Bilgisini Al
      print('🔍 Fetching IP address...');
      final ip = await DeviceUtils.getPublicIP();
      print('🔍 IP Address: $ip');
      
      print('🔍 Fetching device info...');
      final deviceInfo = await DeviceUtils.getDeviceInfo();
      print('🔍 Device Info: $deviceInfo');
      
      // Supabase'e Kaydet
      print('🔍 Updating profile in Supabase...');
      await Supabase.instance.client.from('profiles').update({
        'last_ip': ip,
        'last_device_info': deviceInfo,
        'last_login_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      print('📍 Login tracked successfully: IP=$ip, Device=${deviceInfo['platform']} ${deviceInfo['model']}');
    } catch (e) {
      print('❌ Login tracking error: $e');
    }
  }

  // Periyodik IP ve Cihaz Ban Kontrolü (Her 10 saniyede bir)
  void _startBanCheckTimer() {
    _banCheckTimer?.cancel(); // Varsa öncekini iptal et
    
    _banCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final user = currentUser.value;
      if (user == null) {
        timer.cancel();
        return;
      }

      try {
        final currentIP = await DeviceUtils.getPublicIP();
        final currentDeviceInfo = await DeviceUtils.getDeviceInfo();
        final deviceFingerprint = '${currentDeviceInfo['platform']}-${currentDeviceInfo['brand']}-${currentDeviceInfo['model']}';

        // IP Ban Kontrolü
        if (currentIP != null) {
          final ipBan = await Supabase.instance.client
              .from('banned_ips')
              .select('id')
              .eq('ip_address', currentIP)
              .maybeSingle();
          
          if (ipBan != null) {
            print('🚫 IP BAN DETECTED - Logging out...');
            await signOut();
            ToastUtils.show(
              "Giriş Engellendi",
              "Bu IP adresi yasaklanmıştır.",
              isError: true,
            );
            return;
          }
        }

        // Cihaz Ban Kontrolü
        final deviceBan = await Supabase.instance.client
            .from('banned_devices')
            .select('id')
            .eq('device_fingerprint', deviceFingerprint)
            .maybeSingle();
        
        if (deviceBan != null) {
          print('🚫 DEVICE BAN DETECTED - Logging out...');
          await signOut();
          ToastUtils.show(
            "Giriş Engellendi",
            "Bu cihaz yasaklanmıştır.",
            isError: true,
          );
          return;
        }
      } catch (e) {
        print('Ban check timer error: $e');
      }
    });
  }

  // Logout
  Future<void> signOut() async {
    _banChannel?.unsubscribe();
    _banCheckTimer?.cancel();
    await Supabase.instance.client.auth.signOut();
    currentUser.value = null;
    isProfileComplete.value = false;
  }
}
