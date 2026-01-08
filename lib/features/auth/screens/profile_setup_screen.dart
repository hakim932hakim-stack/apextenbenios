import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:yeniapex/features/home/screens/home_screen.dart';
import 'package:yeniapex/core/utils/toast_utils.dart';
import 'package:yeniapex/core/utils/permission_helper.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final AuthController authController = Get.find<AuthController>();
  final supabase = Supabase.instance.client;

  File? _imageFile;
  String? _avatarUrl;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  String _gender = ''; // 'male' or 'female'
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Mevcut username varsa doldur (eğer metadata'da varsa)
    final user = authController.currentUser.value;
    if (user != null) {
        _usernameController.text = user.userMetadata?['username'] ?? '';
    }
  }

  // Fotoğraf Seç
  Future<void> _pickImage() async {
    // ✅ Depolama izni kontrolü (Just-in-time)
    final hasPermission = await PermissionHelper.requestStoragePermission();
    if (!hasPermission) {
      ToastUtils.show("İzin Gerekli", "Fotoğraf seçmek için galeri erişim izni gereklidir.", isError: true);
      return;
    }
    
    final picker = ImagePicker();
    try {
      // imageQuality KULLANMA! GIF animasyonunu bozar.
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // 🎨 GIF/WebP Kontrolü
        final extension = pickedFile.path.toLowerCase().split('.').last;
        if (extension == 'gif' || extension == 'webp') {
          // GIF/WebP yetkisi kontrolü
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('can_use_gif')
                .eq('id', user.id)
                .maybeSingle();
            
            if (profile == null || profile['can_use_gif'] != true) {
              ToastUtils.show(
                "GIF Yetkisi Gerekli", 
                "Profil fotoğrafına GIF/WebP yüklemek için yetki gereklidir. PNG veya JPG formatında bir fotoğraf seçin.", 
                isError: true
              );
              return;
            }
          }
        }
        
        setState(() {
          _imageFile = File(pickedFile.path);
          _isUploading = true;
        });
        await _uploadAvatar();
      }
    } catch (e) {
      ToastUtils.show("Hata", "Fotoğraf seçilemedi: $e", isError: true);
      setState(() => _isUploading = false);
    }
  }

  // Fotoğraf Yükle
  Future<void> _uploadAvatar() async {
    if (_imageFile == null) return;
    
    try {
      final user = authController.currentUser.value;
      if (user == null) return;

      final fileExt = _imageFile!.path.split('.').last;
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await supabase.storage.from('avatars').upload(fileName, _imageFile!, fileOptions: const FileOptions(upsert: true));
      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      
      setState(() {
        _avatarUrl = imageUrl;
        _isUploading = false;
      });
    } catch (e) {
      ToastUtils.show("Hata", "Fotoğraf yüklenemedi: $e", isError: true);
      setState(() => _isUploading = false);
    }
  }

  // Kaydet
  Future<void> _submit() async {
    if (_usernameController.text.trim().isEmpty) {
      ToastUtils.show("Uyarı", "Kullanıcı adı gerekli", isError: true);
      return;
    }
    if (_gender.isEmpty) {
      ToastUtils.show("Uyarı", "Cinsiyet seçimi zorunlu", isError: true);
      return;
    }

    final username = _usernameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (username.isEmpty) return;

    setState(() => _isLoading = true);
    final user = authController.currentUser.value;
    
    try {
      // Username kontrolü
      final existingUser = await supabase.from('profiles').select('id').eq('username', username).neq('id', user!.id).maybeSingle();
      if (existingUser != null) {
        ToastUtils.show("Hata", "Bu kullanıcı adı zaten alınmış", isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Default avatar mantığı
      String finalAvatar = _avatarUrl ?? '';
      if (finalAvatar.isEmpty) {
         finalAvatar = _gender == 'male' 
            ? 'https://avatar.iran.liara.run/public/boy?username=$username' 
            : 'https://avatar.iran.liara.run/public/girl?username=$username';
      }

      // Update
      // Upsert (Insert or Update) - Trigger çalışmazsa diye garanti olsun
      await supabase.from('profiles').upsert({
        'id': user.id, // ID upsert için şart
        'username': username,
        'display_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatar_url': finalAvatar,
        'gender': _gender,
        'is_profile_complete': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id'); // ID çakışırsa güncelle

      // 🔥 MANUEL GÜNCELLEME: DB'yi beklemeden geçiş yap
      authController.isProfileComplete.value = true;
      authController.currentProfile.value = {
        ...authController.currentProfile.value ?? {},
        'username': username,
        'display_name': _nameController.text.trim(),
        'avatar_url': finalAvatar,
        'gender': _gender,
        'is_profile_complete': true,
      };

      await authController.refreshUser(); // Arka planda yine de tazele
      
      Get.offAll(() => const HomeScreen());
      ToastUtils.show("Başarılı", "Profilin oluşturuldu! 🎉", isSuccess: true);
      
    } catch (e) {
      ToastUtils.show("Hata", "Profil oluşturulamadı: $e", isError: true);
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
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Profil Oluştur", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("Kimliğini belirle ve maceraya katıl.", style: GoogleFonts.inter(fontSize: 14, color: Colors.white54)),
                  const SizedBox(height: 32),

                  // Avatar
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: _isUploading 
                             ? const CircularProgressIndicator(color: Colors.white)
                             : _imageFile != null 
                                ? ClipOval(child: Image.file(_imageFile!, fit: BoxFit.cover))
                                : (_avatarUrl != null 
                                    ? ClipOval(child: CachedNetworkImage(imageUrl: _avatarUrl!, fit: BoxFit.cover))
                                    : const Icon(LucideIcons.camera, color: Colors.white54, size: 32)),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white,
                            child: Icon(LucideIcons.edit2, size: 14, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Fotoğraf Seç", style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600)),

                  const SizedBox(height: 32),

                  // Form
                  GlassmorphicContainer(
                    width: double.infinity,
                    height: 380, // Yükseklik
                    borderRadius: 24,
                    blur: 10,
                    alignment: Alignment.center,
                    border: 1,
                    linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]),
                    borderGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // İsim & Kullanıcı Adı Row
                          Row(
                            children: [
                              Expanded(child: _buildInput("ADIN", _nameController)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildInput("KULLANICI ADI", _usernameController, prefix: "@")),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Bio
                          _buildInput("BİYOGRAFİ", _bioController, maxLines: 2),
                          const SizedBox(height: 16),

                          // Cinsiyet
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("CİNSİYET", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(child: _genderButton("Erkek", "male", LucideIcons.user)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _genderButton("Kadın", "female", LucideIcons.userCheck)), // Icon uydurdum
                                ],
                              ),
                            ],
                          ),

                          const Spacer(),
                          Text("⚠️ Kullanıcı adı ve cinsiyet daha sonra değiştirilemez.", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isUploading) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                        : Text("Kaydı Tamamla", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {int maxLines = 1, String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixText: prefix,
              prefixStyle: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderButton(String text, String val, IconData icon) {
    bool isSelected = _gender == val;
    return GestureDetector(
      onTap: () => setState(() => _gender = val),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.white : Colors.white24),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
