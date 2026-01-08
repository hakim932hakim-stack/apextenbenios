import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/core/widgets/custom_close_icon.dart';
import 'package:yeniapex/features/room/controllers/room_controller.dart';
import 'package:yeniapex/features/room/screens/youtube_search_screen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
// 🔥 REMOVED: video_player (Native ExoPlayer kullanılıyor, Flutter widget olarak render edilmiyor)
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/features/room/widgets/user_profile_sheet.dart';
import 'package:yeniapex/features/room/widgets/share_room_sheet.dart'; 
import 'package:yeniapex/features/room/widgets/in_room_messages_sheet.dart';
import 'package:yeniapex/features/messages/controllers/messages_controller.dart';
import 'package:yeniapex/services/video_service.dart';
import 'package:yeniapex/core/widgets/user_name_text.dart';

class RoomScreen extends StatelessWidget {
  final String roomId;
  const RoomScreen({super.key, required this.roomId});

  void _showOnlineUsersSheet(BuildContext context, RoomController controller) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Row(
              children: [
                const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Obx(() => Text(
                  "Çevrimiçi (${controller.participants.length})",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            // Participants List
            Expanded(
              child: Obx(() {
                final ownerId = controller.room['created_by'];
                final parts = controller.participants.toList();
                
                // Sort: Owner > Admin > Others
                parts.sort((a, b) {
                  final pA = a['profile'] as Map<String, dynamic>?;
                  final pB = b['profile'] as Map<String, dynamic>?;
                  
                  // Owner check
                  if (a['user_id'] == ownerId) return -1;
                  if (b['user_id'] == ownerId) return 1;
                  
                  // Admin check
                  final isAdminA = pA?['is_admin'] == true;
                  final isAdminB = pB?['is_admin'] == true;
                  if (isAdminA && !isAdminB) return -1;
                  if (!isAdminA && isAdminB) return 1;
                  
                  return 0;
                });
                
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: parts.length,
                  itemBuilder: (context, index) {
                    final p = parts[index];
                    final profile = p['profile'] as Map<String, dynamic>?;
                    final isOwner = p['user_id'] == ownerId;
                    final isAdmin = profile?['is_admin'] == true;
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: GestureDetector(
                        onTap: () {
                          final userId = p['user_id'];
                          if (userId != null) {
                            Get.back(); // Sheet'i kapat
                            _showUserProfileSheet(context, controller, userId);
                          }
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: profile?['avatar_url'] != null
                              ? CachedNetworkImageProvider(profile!['avatar_url'])
                              : null,
                          child: profile?['avatar_url'] == null
                              ? Text(
                                  (profile?['display_name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                      title: Row(
                        children: [
                          if (isOwner) ...[
                            Transform.translate(
                              offset: const Offset(0, -2), // 🔥 1 tık yukarı
                              child: Image.asset(
                                "assets/images/crown_badge.png",
                                width: 16,
                                height: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          UserNameText(
                            displayName: profile?['display_name'] ?? profile?['username'] ?? 'Kullanıcı',
                            isAdmin: isAdmin,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Old Admin Badge removed (Now handled inside UserNameText)
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RoomController(roomId), tag: roomId);
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = topPadding + 60; // Header için ayrılan alan
    final videoAreaHeight = screenHeight * 0.35; // 35vh

    return WillPopScope(
      onWillPop: () async {
        // 1. Herhangi bir bottom sheet açık mı?
        if (Get.isBottomSheetOpen ?? false) {
          Get.back(); // Sheet'i kapat
          return false;
        }
        
        // 2. Odadan çıkma onayı iste (leaveRoom zaten dialog gösterecek)
        controller.leaveRoom();
        return false; // Otomatik geri gitmeyi engelle
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Obx(() {
          // 🔄 LOADING: Data yüklenirken göster
          if (controller.isLoading.value) {
            return Stack(
              children: [
                const StarBackground(),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Odaya bağlanılıyor...',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          
          // ✅ LOADED: Normal oda UI'ı
          return Stack(
          children: [
          // 1. Arka Plan (Yıldızlar)
          const StarBackground(),

          // 2. VIDEO ALANI (Header'ın Altında)
          Positioned(
            top: headerHeight,
            left: 0,
            right: 0,
            height: videoAreaHeight,
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              final hasVideo = controller.videoState['video_url'] != null;
              final coverUrl = controller.room['cover_image_url'];
              final isOwner = controller.room['created_by'] == controller.authController.currentUser.value?.id;
              
              // 1. Extraction (Yükleniyor) Durumu
              // 1. Extraction (Yükleniyor) Durumu - ARTIK BUTON ÜZERİNDE GÖSTERİLİYOR
              // if (controller.isExtracting.value) ... kaldırıldı
              
              // 2. 🔥 Native ExoPlayer (Direkt Android layer'da render ediliyor - Flutter widget olarak görünmez)
              // Native player A ct ivity'nin root view'ine eklenmiş durumda, burada sadece placeholder gösteriyoruz.
              if (controller.extractedUrl.value.isNotEmpty) {
                 return Container(color: Colors.transparent);
              }

              // 3. YouTube Player (Fallback)
              if (hasVideo && controller.youtubeController != null) {
                return YoutubePlayer(
                  controller: controller.youtubeController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.red,
                  progressColors: const ProgressBarColors(
                    playedColor: Colors.red,
                    handleColor: Colors.redAccent,
                  ),
                );
              } else {
                // 4. Kapak Fotoğrafı
                if (coverUrl != null && coverUrl.isNotEmpty) {
                   return CachedNetworkImage(
                     imageUrl: coverUrl,
                     fit: BoxFit.cover,
                     placeholder: (context, url) => Container(
                       color: Colors.black,
                       child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                     ),
                     errorWidget: (context, url, error) => Container(
                       color: Colors.black,
                       child: const Center(child: Icon(Icons.error, color: Colors.white)),
                     ),
                   );
                }

                // Video yok - APEX Logo + Video Ekle
                return Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // APEX Logo (Büyük Text)
                        Text(
                          "APEX",
                          style: GoogleFonts.inter(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Video Ekle Butonu (Sadece Owner)
                        // Video Ekle Butonu (Sadece Owner)
                        if (isOwner)
                          GestureDetector(
                            onTap: controller.isExtracting.value 
                                ? null 
                                : () {
                                    Get.to(() => YouTubeSearchScreen(
                                      onVideoSelected: (videoId, title, thumb) {
                                        controller.updateVideo(videoId, title, thumb);
                                      },
                                    ));
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (controller.isExtracting.value)
                                    const SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                    )
                                  else 
                                    const Text("🎬", style: TextStyle(fontSize: 20)),
                                    
                                  const SizedBox(width: 8),
                                  Text(
                                    controller.isExtracting.value ? "Video Ekleniyor..." : "Video Ekle",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }
            }),
          ),

          // 3. HEADER (TAŞINDI -> EN ALTTA)


          // 4. VIDEO HEADER (DİNAMİK - Video Yoksa Gizle)
          // 4. VIDEO HEADER (GİZLİ - LAYOUT İÇİN VAR AMA 0 YÜKSEKLİK)
          Positioned(
            top: headerHeight + videoAreaHeight,
            left: 0, 
            right: 0,
            height: 0, 
            child: const SizedBox.shrink(),
          ),

          // 5. CHAT MESAJLARI
          Positioned(
            top: headerHeight + videoAreaHeight, // Header + Video altına
            left: 0,
            right: 0,
            bottom: 80 + MediaQuery.of(context).viewInsets.bottom, 
            child: GestureDetector(
              behavior: HitTestBehavior.translucent, 
              // 🔥 Chat'e tıklanınca input'a focus ver
              onTap: () {
                if (controller.messageFocusNode.canRequestFocus) {
                   controller.messageFocusNode.requestFocus();
                }
                // Input alanına scroll
                Future.delayed(const Duration(milliseconds: 100), () {
                  controller.messageTextController.selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.messageTextController.text.length),
                  );
                });
              },
              child: Obx(() => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: controller.messages.length,
              itemBuilder: (context, index) {
                final msg = controller.messages[index];
                final isSystemMessage = msg['message_type'] == 'system';
                
                if (isSystemMessage) {
                  // React/Native Tasarımı: Soldan hizalı, avatar + bubble
                  return Padding(
                    key: ValueKey(msg['id'] ?? 'system_$index'), // 🔥 KEY EKLE!
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar (Kullanıcının avatarı veya sistem ikonu)
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: msg['username'] == 'Sistem' 
                              ? Colors.transparent 
                              : Colors.grey[800],
                          backgroundImage: (msg['username'] != 'Sistem' && msg['avatar_url'] != null)
                              ? CachedNetworkImageProvider(msg['avatar_url'])
                              : null,
                          child: msg['username'] == 'Sistem'
                              ? const Icon(Icons.settings_applications_rounded, color: Colors.white, size: 28)
                              : (msg['avatar_url'] == null
                                  ? Text(
                                      (msg['username'] ?? 'S')[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    )
                                  : null),
                        ),
                        const SizedBox(width: 8),
                        // İçerik
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kullanıcı Adı
                              Text(
                                msg['username'] ?? 'Sistem',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Sistem Mesaj Balonu
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  msg['content'] ?? '',
                                  style: GoogleFonts.inter(
                                    color: Color(0xFFCCCCCC),
                                    fontSize: 14,
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

                return Padding(
                  key: ValueKey(msg['id'] ?? 'msg_$index'), // 🔥 KEY EKLE!
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar (Online Badge ile)
                      GestureDetector(
                        onTap: () {
                          final userId = msg['user_id'];
                          if (userId != null) {
                            _showUserProfileSheet(context, controller, userId);
                          }
                        },
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: msg['avatar_url'] != null
                              ? CachedNetworkImageProvider(msg['avatar_url'])
                              : null,
                          child: msg['avatar_url'] == null
                              ? Text(
                                  (msg['username'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Mesaj İçeriği
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kullanıcı Adı
                            Builder(
                              builder: (context) {
                                final msgUserId = msg['user_id']?.toString();
                                final currentUserId = controller.authController.currentUser.value?.id?.toString();
                                final isRoomOwner = msgUserId == controller.room['created_by']?.toString();
                                final isMe = msgUserId == currentUserId;
                                
                                // 🔥 SELF-VIEW FIX: Kendi mesajımızsa doğrudan AuthController'dan kontrol et
                                final profileIsAdmin = controller.authController.currentProfile.value?['is_admin'] == true;
                                final msgIsAdmin = msg['is_admin'] == true;
                                final bool isAdmin = isMe ? profileIsAdmin : msgIsAdmin;

                                // 🔍 DEBUG LOG
                                print('📨 [CHAT RENDER] User: ${msg['username']}, msgUserId: $msgUserId, currentUserId: $currentUserId, isMe: $isMe, profileIsAdmin: $profileIsAdmin, msgIsAdmin: $msgIsAdmin, FINAL isAdmin: $isAdmin');

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                     // ODA SAHİBİ ROZETİ (CROWN)
                                     if (isRoomOwner) ...[
                                        Transform.translate(
                                          offset: const Offset(0, -2), // 🔥 1 tık yukarı
                                          child: Image.asset(
                                              "assets/images/crown_badge.png",
                                              width: 14,
                                              height: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                     ],
                                     
                                     // İSİM & ADMİN ROZETİ (UserNameText içinde)
                                     UserNameText(
                                      displayName: msg['username'] ?? 'Kullanıcı',
                                      isAdmin: isAdmin,
                                      style: GoogleFonts.inter(
                                        color:Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                );
                              }
                            ),
                            const SizedBox(height: 2),
                            // Mesaj Balonu veya Görsel
                            Builder(
                              builder: (context) {
                                final content = msg['content'] ?? '';
                                final isImage = content.startsWith('http') && 
                                    (content.contains('room_images') || 
                                     content.endsWith('.jpg') || 
                                     content.endsWith('.png') || 
                                     content.endsWith('.jpeg') ||
                                     content.endsWith('.webp'));
                                
                                if (isImage) {
                                  // 📸 GÖRSEL MESAJ
                                  return GestureDetector(
                                    onTap: () async {
                                      // Native player'ı gizle
                                      try { await VideoService.hidePlayer(); } catch (_) {}
                                      
                                      // Tam ekran görüntüle
                                      await Get.to(
                                        () => Scaffold(
                                          backgroundColor: Colors.black,
                                          appBar: AppBar(
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            leading: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.white),
                                              onPressed: () => Get.back(),
                                            ),
                                          ),
                                          extendBodyBehindAppBar: true,
                                          body: Center(
                                            child: InteractiveViewer(
                                              child: CachedNetworkImage(
                                                imageUrl: content,
                                                fit: BoxFit.contain,
                                                placeholder: (_, __) => const CircularProgressIndicator(color: Colors.cyanAccent),
                                                errorWidget: (_, __, ___) => const Icon(Icons.error, color: Colors.red),
                                              ),
                                            ),
                                          ),
                                        ),
                                        transition: Transition.fade,
                                      );
                                      
                                      // Native player'ı tekrar göster
                                      try { await VideoService.showPlayer(); } catch (_) {}
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: content,
                                        width: 150,
                                        height: 150,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          width: 150, height: 100,
                                          color: Colors.white10,
                                          child: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2)),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          width: 150, height: 100,
                                          color: Colors.white10,
                                          child: const Icon(Icons.broken_image, color: Colors.white38),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                
                                // 💬 NORMAL MESAJ
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    content,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            )), // ListView.builder ve Obx kapanış
            ), // GestureDetector kapanış
          ),

          // 5. BOTTOM CONTROLS - REACT/NATIVE TASARIMI (Keyboard Aware)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom, // 🔥 Klavye kadar YUKARI ÇIK
            child: Container(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : MediaQuery.of(context).padding.bottom + 8,
              ),
              child: Row(
                children: [
                  // SOL - BÜYÜK MİKROFON BUTONU (56dp)
                  GestureDetector(
                    onTap: controller.toggleMicrophone,
                    child: Obx(() => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: controller.isMicEnabled.value
                            ? Colors.white
                            : const Color(0xFF2A2A2A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        controller.isMicEnabled.value ? Icons.mic : Icons.mic_off,
                        color: controller.isMicEnabled.value ? Colors.black : Colors.white,
                        size: 26,
                      ),
                    )),
                  ),
                  const SizedBox(width: 8),

                  // SAĞ - CHAT BOX (44dp yükseklik)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Focus input (Doğru yöntem)
                        controller.messageFocusNode.requestFocus();
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Chat Input
                            Expanded(
                              child: Obx(() {
                                final user = controller.authController.currentUser.value;
                                final isOwner = controller.room['created_by'] == user?.id;
                                final canSendMessage = controller.isRoomChatEnabled.value || isOwner;
                                
                                return TextField(
                                  controller: controller.messageTextController,
                                  focusNode: controller.messageFocusNode, // 🔥 FOCUS NODE EKLENDİ
                                  enabled: canSendMessage,
                                  style: GoogleFonts.inter(
                                    color: canSendMessage ? Colors.white : Colors.white38,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: canSendMessage ? 'Chat' : 'Chat kapalı',
                                    hintStyle: GoogleFonts.inter(
                                      color: canSendMessage ? Colors.white70 : Colors.white38,
                                      fontSize: 14,
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: canSendMessage ? (_) => controller.sendMessage(null) : null,
                                );
                              }),
                            ),
                            
                            // Sağ Butonlar
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 📸 GÖRSEL GÖNDER BUTONU
                                GestureDetector(
                                  onTap: () => controller.pickAndSendImage(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.image_outlined, color: Colors.white70, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 🔥 MESAJLAR BUTONU (YENİ)
                                GestureDetector(
                                  onTap: () {
                                    Get.find<MessagesController>().clearUnreadNotification(); // 🔥 Badge temizle
                                    FocusScope.of(context).unfocus(); // 🔥 Klavye açıksa kapat
                                    Get.bottomSheet(const InRoomMessagesSheet(), isScrollControlled: true);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        const Icon(Icons.mail_outline, color: Colors.white70, size: 20),
                                        // Kırmızı Badge
                                        Obx(() {
                                          final hasUnread = Get.find<MessagesController>().hasUnreadMessages.value;
                                          if (!hasUnread) return const SizedBox.shrink();
                                          return Positioned(
                                            right: -4,
                                            top: -4,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Paylaş
                                  GestureDetector(
                                    onTap: () {
                                      // Eskisi: Link Kopyala
                                      // Clipboard.setData(ClipboardData(text: "https://apex.app/room/${controller.roomId}"));
                                      
                                      // Yenisi: Şık Paylaşım Ekranı
                                      Get.bottomSheet(ShareRoomSheet(controller: controller), isScrollControlled: true);
                                    },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.share, color: Colors.white70, size: 20),
                                  ),
                                ),
                                
                                // Video Varsa: Info ve Kapat butonları
                                Obx(() {
                                  final hasVideo = controller.videoState['video_url'] != null;
                                  final isOwner = controller.room['created_by'] == 
                                      controller.authController.currentUser.value?.id;
                                  
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isOwner && hasVideo) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: controller.closeVideo,
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.close, color: Colors.white70, size: 20),
                                          ),
                                        ),
                                      ],
                                      if (isOwner) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _showSettingsSheet(context, controller),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.settings, color: Colors.white70, size: 20),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ), // Bottom Controls Positioned End

                // --- Header (Exit, Mic Users, Count) ---
                Positioned(
                  top: MediaQuery.of(context).padding.top + 4,
                  left: 0,
                  right: 0,
                  child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Vertical padding azaltıldı
              child: Row(
                children: [
                  // SOL: Çıkış (X) Butonu
                        GestureDetector(
                          onTap: () {
                             // Sadece odadan çık (Video kapatma yetkisi burada değil)
                             controller.leaveRoom();
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(top: 10, left: 8, right: 8, bottom: 8),
                            child: CustomCloseIcon(size: 22, color: Colors.white70),
                          ),
                        ),
                  
                  const SizedBox(width: 8),
                  
                  // ORTA: MİKROFON AÇAN KULLANICILAR
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(top: 8), // 🔥 Avatar 1 tık aşağı
                      height: 50,
                      child: Obx(() {
                        final micUsers = controller.participants
                            .where((p) => controller.micEnabledUsers.contains(p['user_id']))
                            .toList();
                        
                        if (micUsers.isEmpty) return const SizedBox.shrink();
                        
                        return Stack(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: micUsers.map((p) {
                                  final profile = p['profile'] as Map<String, dynamic>?;
                                  final isSpeaking = controller.activeSpeakers.contains(p['user_id']);
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSpeaking ? Colors.greenAccent : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey[850],
                                      backgroundImage: profile?['avatar_url'] != null
                                          ? CachedNetworkImageProvider(profile!['avatar_url'])
                                          : null,
                                      child: profile?['avatar_url'] == null
                                          ? Text(
                                              (profile?['display_name'] ?? 'U')[0].toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // SAĞ: Online Sayısı
                  GestureDetector(
                    onTap: () => _showOnlineUsersSheet(context, controller),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 18),
                        const SizedBox(width: 4),
                        Obx(() {
                           final count = controller.activeRoomProfiles.isNotEmpty 
                              ? controller.activeRoomProfiles.length 
                              : controller.participants.length;
                           return Text(
                              "$count",
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ],
        ); // Stack - Normal UI
        }), // Obx - Loading wrapper kapanışı
      ), // Scaffold
    ); // WillPopScope
  }
}

// --- Action Sheets ---

void _showVideoInfoSheet(BuildContext context, RoomController controller) {
  Get.bottomSheet(
    Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.videoState['thumbnail_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                controller.videoState['thumbnail_url'],
                width: 120, height: 70, 
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            controller.videoState['video_title'] ?? 'Video',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
    backgroundColor: Colors.transparent,
    elevation: 0,
  ).whenComplete(() {
    FocusManager.instance.primaryFocus?.unfocus();
  });
}

void _showSettingsSheet(BuildContext context, RoomController controller) {
  Get.bottomSheet(
    Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Obx(() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4, 
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 24),
            ),
          ),
          Text("Oda Ayarları", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // 1. Sesli Sohbet
          _buildSettingTile(
            icon: Icons.mic, 
            title: "Sesli Sohbet", 
            subtitle: controller.isRoomVoiceEnabled.value ? "Açık" : "Kapalı",
            value: controller.isRoomVoiceEnabled.value,
            onChanged: (val) => controller.toggleRoomVoice(val),
          ),
          
          // 2. Chat
          _buildSettingTile(
            icon: Icons.chat_bubble, 
            title: "Sohbet", 
            subtitle: controller.isRoomChatEnabled.value ? "Açık" : "Kapalı",
            value: controller.isRoomChatEnabled.value,
            onChanged: (val) => controller.toggleRoomChat(val),
          ),
          
          // 3. Kilit (Custom widget - shows password inline)
          Obx(() => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    controller.isRoomLocked.value ? Icons.lock : Icons.lock_open,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Oda Kilidi",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (controller.isRoomLocked.value && controller.room['lock_password'] != null)
                        Row(
                          children: [
                            Text(
                              "Şifre: ${controller.room['lock_password']}",
                              style: GoogleFonts.spaceMono(
                                color: const Color(0xFFEF4444),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: controller.room['lock_password']),
                                );
                                // Toast removed
                              },
                              child: Icon(
                                LucideIcons.copy,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          controller.isRoomLocked.value ? "Kilitli" : "Açık",
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: controller.isRoomLocked.value,
                  onChanged: (val) => controller.toggleRoomLock(val),
                  activeColor: Colors.white,
                  activeTrackColor: Colors.green,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                ),
              ],
            ),
          )),
          
          
          const Divider(color: Colors.white10, height: 32),
          
          // 4. Chat Temizle
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.white70),
            title: Text("Sohbeti Temizle", style: GoogleFonts.inter(color: Colors.white)),
            onTap: controller.clearChat,
            contentPadding: EdgeInsets.zero,
          ),
          
          // 5. Kapak Resmi (Placeholder)
          ListTile(
            leading: const Icon(Icons.image, color: Colors.white70),
            title: Text(controller.room['cover_image_url'] != null ? "Kapağı Kaldır" : "Kapak Resmi Ekle", style: GoogleFonts.inter(color: Colors.white)),
            onTap: () {
               if (controller.room['cover_image_url'] != null) {
                  controller.removeCoverImage();
               } else {
                  controller.pickCoverImage();
               }
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ))),
    ),
    isScrollControlled: true,
  ).whenComplete(() {
    FocusManager.instance.primaryFocus?.unfocus();
  });
}

Widget _buildSettingTile({required IconData icon, required String title, required String subtitle, required bool value, required Function(bool) onChanged}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              Text(subtitle, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
        Switch(
          value: value, 
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: Colors.green,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.white24,
        ),
      ],
    ),
  );
}

void _showUserProfileSheet(BuildContext context, RoomController controller, String userId) {
  final user = controller.authController.currentUser.value;
  final isRoomOwner = controller.room['created_by'] == user?.id;

  Get.bottomSheet(
    UserProfileSheet(
      userId: userId,
      roomId: controller.roomId,
      isRoomOwner: isRoomOwner,
    ),
    isScrollControlled: true,
    elevation: 100,
    // Barrier'ı kaldır - oda gözüksün (settings gibi)
  ).whenComplete(() {
    FocusManager.instance.primaryFocus?.unfocus();
  });
}

// --- CustomVideoControls (Owner Only) ---
class CustomVideoControls extends StatefulWidget {
  final RoomController controller;
  final bool isFullscreen;
  const CustomVideoControls({
    Key? key, 
    required this.controller,
    this.isFullscreen = false,
  }) : super(key: key);

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  bool _isVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }
  
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.isPlaying.value) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _isVisible = !_isVisible);
    if (_isVisible) _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.translucent, 
      child: Stack(
        children: [
          // 1. Center Play/Pause (Animated Opacity) - Sadece Owner
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: _isVisible ? Colors.black.withOpacity(0.4) : Colors.transparent,
                child: Obx(() {
                  final user = widget.controller.authController.currentUser.value;
                  final isOwner = widget.controller.room['created_by'] == user?.id;
                  
                  if (!isOwner) return const SizedBox.shrink();
                  
                  return Center(
                    child: IconButton(
                      iconSize: 64,
                      icon: Obx(() => Icon(
                        widget.controller.isPlaying.value 
                            ? Icons.pause_circle_filled 
                            : Icons.play_circle_filled,
                        color: Colors.white,
                      )),
                      onPressed: () {
                        widget.controller.toggleNativePlayPause();
                        _startHideTimer();
                      },
                    ),
                  );
                }),
              ),
            ),
          ),

          // 2. Bottom Controls (Animated Opacity) - HERKES
          Positioned(
            left: 20,
            right: 20,
            bottom: 20, // 1 tık aşağı (40 -> 20)
            child: AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_isVisible, // Görünmezken tıklamayı engelle
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  // Arkaplan YOK (Transparent)
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Current Time
                          Obx(() => Text(
                                _formatDuration(widget.controller.currentPosition.value),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              )),
                          
                          const SizedBox(width: 12),
                          
                          // Seek Slider
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: Colors.redAccent,
                                inactiveTrackColor: Colors.white38,
                                thumbColor: Colors.redAccent,
                              ),
                              child: Obx(() {
                                  final current = widget.controller.currentPosition.value.toDouble();
                                  final total = widget.controller.totalDuration.value.toDouble();
                                  final user = widget.controller.authController.currentUser.value;
                                  final isOwner = widget.controller.room['created_by'] == user?.id;
                                  
                                  return Slider(
                                    value: current.clamp(0.0, total < 1 ? 1 : total),
                                    max: total < 1 ? 1 : total,
                                    onChanged: (val) {
                                       if (isOwner) {
                                         widget.controller.seekNativeVideo(val);
                                         _startHideTimer();
                                       }
                                    },
                                  );
                              }),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Total Duration
                          Obx(() => Text(
                            _formatDuration(widget.controller.totalDuration.value),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          )),
                          
                          const SizedBox(width: 8),

                          // Fullscreen Button
                          IconButton(
                            icon: Icon(
                              widget.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, 
                              color: Colors.white, 
                              size: 28
                            ),
                            onPressed: () {
                               if (widget.isFullscreen) {
                                 Get.back();
                               } else {
                                 Get.to(
                                   () => FullscreenVideoPage(controller: widget.controller),
                                   transition: Transition.fadeIn,
                                   duration: const Duration(milliseconds: 300),
                                 );
                               }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Volume Slider (Animated Opacity) - HERKES
          if (!widget.isFullscreen)
          Positioned(
             right: 10,
             top: 40,
             bottom: 100,
             child: AnimatedOpacity(
               opacity: _isVisible ? 1.0 : 0.0,
               duration: const Duration(milliseconds: 300),
               child: IgnorePointer(
                 ignoring: !_isVisible,
                 child: RotatedBox(
                   quarterTurns: 3,
                   child: Obx(() => SliderTheme(
                     data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                     ),
                     child: Slider(
                       value: widget.controller.videoVolume.value,
                       min: 0.0,
                       max: 1.0,
                       onChanged: (val) {
                          widget.controller.setVolume(val);
                          _startHideTimer();
                       },
                     ),
                   )),
                 ),
               ),
             ),
          ),
        ],
      ),
    );
  }
}

class FullscreenVideoPage extends StatelessWidget {
  final RoomController controller;
  const FullscreenVideoPage({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔥 Native ExoPlayer renders on Android layer - No Flutter widget needed
    // Just show controls overlay
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Native player zaten Android layer'da render ediliyor
              const Center(
                child: Text(
                  '🎥 Fullscreen Video (Native)',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
              Positioned.fill(
                child: CustomVideoControls(
                  controller: controller, 
                  isFullscreen: true,
                ),
              ),
                // Back Button (Top Left)
                Positioned(
                  top: 20,
                  left: 20,
                  child: GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ), // Stack
          ), // Center
        ), // SafeArea
    ); // Scaffold
  }
}
