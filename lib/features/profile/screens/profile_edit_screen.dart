import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:yeniapex/core/app_colors.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/core/utils/permission_helper.dart';
import 'package:yeniapex/core/widgets/animated_avatar.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final AuthController authController = Get.find<AuthController>();
  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController nameController;
  late TextEditingController bioController;
  
  bool _isLoading = false;
  File? _selectedImage;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    
    // ✅ currentProfile kullan (güncel DB verisi)
    final profile = authController.currentProfile.value;
    
    nameController = TextEditingController(text: profile?['display_name'] ?? '');
    bioController = TextEditingController(text: profile?['bio'] ?? '');
    _currentAvatarUrl = profile?['avatar_url'] ?? 'https://ui-avatars.com/api/?name=User&background=random';
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  // 📸 Galeri'den Fotoğraf Seçme
  Future<void> _pickImage() async {
    // ✅ Depolama izni kontrolü (Just-in-time)
    final hasPermission = await PermissionHelper.requestStoragePermission();
    if (!hasPermission) {
      Get.snackbar(
        "İzin Gerekli", 
        "Fotoğraf seçmek için galeri erişim izni gereklidir.", 
        backgroundColor: Colors.orange.withOpacity(0.5), 
        colorText: Colors.white
      );
      return;
    }
    
    try {
      // imageQuality KULLANMA! GIF animasyonunu bozar!
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        // imageQuality kaldırıldı - GIF için ZORUNLU!
      );
      
      if (image != null) {
        // 🎨 GIF/WebP Kontrolü
        final extension = image.path.toLowerCase().split('.').last;
        print('🎨 Selected file extension: $extension');
        
        if (extension == 'gif' || extension == 'webp') {
          print('🎨 GIF/WebP detected, checking permission...');
          // GIF/WebP yetkisi kontrolü
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('can_use_gif')
                .eq('id', user.id)
                .maybeSingle();
            
            print('🎨 Profile data: $profile');
            print('🎨 can_use_gif: ${profile?['can_use_gif']}');
            
            if (profile == null || profile['can_use_gif'] != true) {
              print('❌ GIF permission DENIED');
              Get.snackbar(
                "GIF Yetkisi Gerekli", 
                "Profil fotoğrafına GIF/WebP yüklemek için yetki gereklidir. PNG veya JPG formatında bir fotoğraf seçin.",
                backgroundColor: Colors.red.withOpacity(0.7), 
                colorText: Colors.white,
                duration: const Duration(seconds: 4)
              );
              return;
            }
            print('✅ GIF permission GRANTED');
          }
        }
        
        print('✅ Image accepted, setting state...');
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
       Get.snackbar("Hata", "Fotoğraf seçilemedi: $e", backgroundColor: Colors.red.withOpacity(0.5), colorText: Colors.white);
    }
  }

  // 💾 Profili Kaydetme
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      String? newAvatarUrl;
      
      // 1. Eğer yeni foto seçildiyse, upload et
      if (_selectedImage != null) {
        final userId = supabase.auth.currentUser!.id;
        final fileExt = _selectedImage!.path.split('.').last.toLowerCase();
        final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        print('📤 Uploading avatar: $fileName (type: $fileExt)');
        
        // Content type belirle
        String contentType;
        if (fileExt == 'gif') {
          contentType = 'image/gif';
        } else if (fileExt == 'webp') {
          contentType = 'image/webp';
        } else if (fileExt == 'png') {
          contentType = 'image/png';
        } else {
          contentType = 'image/jpeg';
        }
        
        print('📝 Content-Type: $contentType');
        
        // Storage'a yükle (upsert kullanma, animasyon kaybeder!)
        final bytes = await _selectedImage!.readAsBytes();
        
        // Önce eski dosyayı sil (varsa)
        try {
          final oldFiles = await supabase.storage.from('avatars').list(
            path: '',
            searchOptions: SearchOptions(search: userId),
          );
          for (final file in oldFiles) {
            await supabase.storage.from('avatars').remove([file.name]);
          }
        } catch (e) {
          print('⚠️ Old file cleanup skipped: $e');
        }
        
        // Yeni dosyayı yükle - upsert KULLANMA!
        await supabase.storage.from('avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false, // ÖNEMLI: false olmalı yoksa optimize eder!
          ),
        );
        
        // Public URL al
        newAvatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
        print('✅ Avatar uploaded: $newAvatarUrl');
      }

      // 2. Profili güncelle
      await supabase.from('profiles').update({
        'display_name': nameController.text.trim(),
        'bio': bioController.text.trim(),
        if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', supabase.auth.currentUser!.id);

      // 3. Controller'daki veriyi tazele
      authController.currentProfile.value = {
        ...authController.currentProfile.value ?? {},
        'display_name': nameController.text.trim(),
        'bio': bioController.text.trim(),
        if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
      };
      
      authController.currentProfile.refresh(); // UI Tetikle
      await authController.refreshUser(); // Arka planda DB'den çek
      
      Get.back(); // Geri dön
      // Toast mesajı kaldırıldı

    } catch (e) {
      Get.snackbar("Hata", "Profil güncellenemedi: $e", backgroundColor: Colors.red.withOpacity(0.5), colorText: Colors.white);
      print("SAVE ERROR: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const StarBackground(),
          
          SafeArea(
            child: Column(
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text("İptal", style: GoogleFonts.inter(color: Colors.white60, fontSize: 14)),
                      ),
                      Text(
                        "Profili Düzenle",
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                          : TextButton(
                              onPressed: _saveProfile,
                              child: Text("Kaydet", style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // --- AVATAR DÜZENLEME ---
                        GestureDetector(
                          onTap: _pickImage,
                          child: Column(
                            children: [
                               Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 2),
                                ),
                                child: ClipOval(
                                  child: _selectedImage != null
                                      ? Image.file(_selectedImage!, fit: BoxFit.cover) // Seçilen yeni resim
                                      : AnimatedAvatar( // Mevcut resim
                                          imageUrl: _currentAvatarUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Fotoğrafı Değiştir",
                                style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // --- AD SOYAD ---
                        _buildInputField(
                          label: "AD SOYAD",
                          controller: nameController,
                          maxLength: 20,
                          placeholder: "Adınız",
                        ),

                        const SizedBox(height: 20),

                        // --- BIO ---
                        _buildInputField(
                          label: "HAKKIMDA",
                          controller: bioController,
                          maxLength: 100,
                          placeholder: "Kendinden bahset...",
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    int maxLength = 20,
    String placeholder = "",
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        GlassmorphicContainer(
          width: double.infinity,
          height: maxLines == 1 ? 55 : 120,
          borderRadius: 16,
          blur: 10,
          alignment: maxLines == 1 ? Alignment.centerLeft : Alignment.topLeft,
          border: 1,
          linearGradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderGradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: controller,
              maxLength: maxLength,
              maxLines: maxLines,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: GoogleFonts.inter(color: Colors.white24),
                counterStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
                contentPadding: maxLines > 1 ? const EdgeInsets.only(top: 12) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
