import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:yeniapex/core/widgets/star_background.dart';
import 'package:yeniapex/features/messages/controllers/messages_controller.dart';
import 'package:yeniapex/features/auth/controllers/auth_controller.dart';
import 'package:yeniapex/features/messages/services/pie_socket_service.dart';
import 'dart:convert';
import 'package:yeniapex/features/home/controllers/home_controller.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:yeniapex/core/utils/permission_helper.dart';
import 'package:yeniapex/features/profile/screens/user_profile_screen.dart';
import 'package:yeniapex/features/profile/controllers/user_profile_controller.dart';
import 'package:yeniapex/core/widgets/user_name_text.dart'; // 🌈 Admin Styling

class ChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;

  const ChatScreen({
    super.key, 
    required this.partnerId, 
    required this.partnerName, 
    this.partnerAvatar
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessagesController controller = Get.find<MessagesController>();
  final AuthController authController = Get.find<AuthController>();
  final PieSocketService pieSocket = Get.find<PieSocketService>();
  
  // 🔥 Profil Controller (Blok Durumu İçin) - Unique Tag ile
  late UserProfileController profileController;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker(); // Picker
  DateTime? _lastTypingTime;

  @override
  void initState() {
    super.initState();
    
    // 🛡️ BLOCK CHECK INIT (Aynı Tag!)
    // Eğer UserProfileSheet açıksa oradaki instance'ı bulur, değilse yeni oluşturur.
    profileController = Get.put(UserProfileController(), tag: 'user_profile_${widget.partnerId}');
    
    // UI build işlemi bittikten sonra yükle (Hata Çözümü)
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // 🔥 Tüm profili yükle (DND, Engel, Takip vb.)
       profileController.loadUser(widget.partnerId);
       controller.loadChat(widget.partnerId);
    });

    // Sohbet odasına bağlan (Typing için)
    pieSocket.subscribeToDM(widget.partnerId);
  }
  
  @override
  void dispose() {
    // Sohbet odasından çık
    pieSocket.unsubscribeFromDM(widget.partnerId);
    super.dispose();
  }

  
  // Resim Seç ve Gönder
  Future<void> _pickAndSendImage() async {
    // ✅ Depolama izni kontrolü (Just-in-time)
    final hasPermission = await PermissionHelper.requestStoragePermission();
    if (!hasPermission) {
      Get.snackbar(
        "İzin Gerekli", 
        "Fotoğraf göndermek için galeri erişim izni gereklidir.", 
        backgroundColor: Colors.orange.withOpacity(0.5), 
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        await controller.sendImageMessage(widget.partnerId, File(image.path));
      }
    } catch (e) {
      print("Pick image error: $e");
    }
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    controller.sendMessage(widget.partnerId, _textController.text.trim());
    _textController.clear();
  }

  void _onTextChanged(String text) {
    // Send typing event every 2 seconds max via PieSocket
    final now = DateTime.now();
    if (_lastTypingTime == null || now.difference(_lastTypingTime!) > const Duration(seconds: 2)) {
      pieSocket.sendTyping(widget.partnerId);
      _lastTypingTime = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      body: Stack(
        children: [
          const StarBackground(),

          Column(
            children: [
              // --- CUSTOM HEADER (Glass) ---
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10, 
                  bottom: 10, 
                  left: 10, 
                  right: 10
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2), // Hafif koyuluk
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Row(
                  children: [

                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                    const SizedBox(width: 5),
                    
                    // Profil Tıklanabilir Alan
                    GestureDetector(
                      onTap: () => Get.to(() => UserProfileScreen(userId: widget.partnerId)),
                      child: Row(
                        children: [
                            // Avatar
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(shape: BoxShape.circle),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: widget.partnerAvatar ?? 'https://ui-avatars.com/api/?name=${widget.partnerName}&background=random',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.grey[900]),
                                  errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // İsim & Durum
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Obx(() {
                                   final profile = profileController.userProfile.value;
                                   final bool isAdmin = profile?['is_admin'] == true;
                                   
                                   return UserNameText(
                                      displayName: widget.partnerName,
                                      isAdmin: isAdmin,
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                   );
                                }),
                                // Online Durumu (Obx ile Reaktif - PieSocket)
                                Obx(() {
                                    final isTyping = pieSocket.typingUsers[widget.partnerId] ?? false;
                                    final isOnline = pieSocket.onlineUsers.contains(widget.partnerId);
                                    
                                    if (isTyping) {
                                       return Text(
                                         "Yazıyor...", 
                                         style: GoogleFonts.inter(fontSize: 12, color: Colors.cyanAccent, fontStyle: FontStyle.italic)
                                       );
                                    }

                                    return Text(
                                      isOnline ? "Çevrimiçi" : "Çevrimdışı", 
                                      style: GoogleFonts.inter(
                                        fontSize: 12, 
                                        color: isOnline ? Colors.greenAccent : Colors.white38
                                      ),
                                    );
                                }),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

                  // --- MESAJ LİSTESİ ---
              Expanded(
                child: Obx(() {
                  if (controller.isLoadingChat.value && controller.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                  }
                  
                  // Scroll to bottom MANUEL çağrısına gerek yok artık.
                  // reverse: true sayesinde otomatik en altta başlar.

                  final isPartnerTyping = pieSocket.typingUsers[widget.partnerId] ?? false;

                    return ListView.builder(
                    reverse: true, // 🔥 TERS LİSTE (WhatsApp Gibi)
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.messages.length,
                    itemBuilder: (context, index) {
                      final msg = controller.messages[index];
                      final isMe = msg['sender_id'] == authController.currentUser.value?.id;
                      final content = msg['content'] as String;
                      final date = DateTime.parse(msg['created_at']);
                      final timeStr = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

                      // Emoji kontrolü (Basit)
                      final isEmojiOnly = RegExp(r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\s]+$', unicode: true).hasMatch(content);
                      
                       // Resim Kontrolü
                       final match = RegExp(r"(http(s?):)([/|.|\w|\s|-])*\.(?:jpg|gif|png|jpeg|webp)", caseSensitive: false).firstMatch(content);
                       final isImage = match != null || (content.startsWith('http') && content.contains('chat_images')); 
                       
                       // 🔥 DAVETİYE KONTROLÜ
                       final isInvite = content.startsWith("[ROOM_INVITE]");
                       Map<String, dynamic>? inviteData;
                       if (isInvite) {
                          try {
                            // "[ROOM_INVITE] " kısmını (14 karakter) atıp parçala
                            inviteData = jsonDecode(content.substring(13));
                          } catch (_) {}
                       }

                       return GestureDetector(
                         onLongPress: !isMe ? () {
                           // Karşı tarafın mesajına yanıtla
                           showModalBottomSheet(
                             context: context,
                             backgroundColor: Colors.black,
                             builder: (_) => SafeArea(
                               child: ListTile(
                                 leading: const Icon(Icons.reply, color: Colors.cyanAccent),
                                 title: const Text("Yanıtla", style: TextStyle(color: Colors.white)),
                                  onTap: () {
                                   Navigator.pop(context);
                                   // Input'a @mesaj ekle
                                   final msgContent = content.length > 50 ? "${content.substring(0, 50)}..." : content;
                                   _textController.text = "@$msgContent ";
                                   // Input'a focus ver
                                 },
                               ),
                             ),
                           );
                         } : null,
                         child: Align(
                           alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                           child: Container(
                           margin: const EdgeInsets.only(bottom: 12),
                           padding: (isEmojiOnly || isImage || isInvite)
                               ? EdgeInsets.zero 
                               : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           constraints: BoxConstraints(maxWidth: Get.width * 0.75),
                           decoration: (isEmojiOnly || isImage || isInvite)
                             ? null 
                             : BoxDecoration(
                                 color: isMe ? Colors.cyanAccent.withOpacity(0.8) : Colors.white.withOpacity(0.1),
                                 borderRadius: BorderRadius.only(
                                   topLeft: const Radius.circular(16),
                                   topRight: const Radius.circular(16),
                                   bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                   bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                 ),
                                 border: Border.all(
                                   color: isMe ? Colors.transparent : Colors.white.withOpacity(0.1),
                                 ),
                               ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.end,
                             children: [
                                if (isInvite && inviteData != null)
                                  GestureDetector(
                                    onTap: () {
                                      // Odaya Katıl
                                      final roomId = inviteData!['roomId'];
                                      final homeController = Get.put(HomeController());
                                      homeController.joinRoom(roomId);
                                    },
                                    child: Container(
                                      width: 250,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Thumbnail
                                          if (inviteData['thumbnail'] != null && inviteData['thumbnail'].toString().isNotEmpty)
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: CachedNetworkImage(
                                                imageUrl: inviteData['thumbnail'],
                                                height: 120,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                 errorWidget: (_,__,___) => Container(color: Colors.grey[900], height: 120, child: const Icon(Icons.meeting_room, color: Colors.white)),
                                              ),
                                            ),
                                          
                                          const SizedBox(height: 12),
                                          
                                          // Başlıklar
                                          Text(
                                            "Sohbet Odası Daveti",
                                            style: GoogleFonts.inter(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            inviteData['title'] ?? 'Oda',
                                            style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${inviteData['inviterName']} seni davet ediyor!",
                                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                                          ),
                                          
                                          const SizedBox(height: 12),
                                          
                                          // Buton
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.cyanAccent,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              "Odaya Katıl",
                                              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                else if (isImage)
                                  GestureDetector(
                                    onTap: () {
                                      Get.dialog(
                                        GestureDetector(
                                          onTap: () => Get.back(),
                                          child: Scaffold(
                                            backgroundColor: Colors.black.withOpacity(0.9),
                                            body: Center(
                                              child: InteractiveViewer(
                                                child: CachedNetworkImage(imageUrl: content),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: content,
                                        width: 250,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: 250, height: 250, 
                                          color: Colors.white10, 
                                          child: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                                        ),
                                        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                                      ),
                                    ),
                                  )
                                else if (isEmojiOnly)
                                  Text(content, style: const TextStyle(fontSize: 40))
                                else
                                  Text(
                                    content,
                                    style: GoogleFonts.inter(
                                      color: isMe ? Colors.black : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                if (!isEmojiOnly) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.inter(
                                      color: isMe ? Colors.black54 : Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ]
                             ],
                           ),
                         ),
                        ),
                       );
                    },
                  );
                }),
              ),

              // --- INPUT ALANI ---
              Obx(() {
                // Blok Kontrolü
                final isBlockedByMe = profileController.isBlockedByMe.value;
                final isBlockedByThem = profileController.isBlockedByThem.value;

                if (isBlockedByMe || isBlockedByThem) {
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: 10, 
                      right: 10, 
                      top: 10, 
                      bottom: MediaQuery.of(context).padding.bottom + 10
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: Center(
                      child: Text(
                        isBlockedByMe 
                          ? "BU KİŞİYİ ENGELLEDİNİZ MESAJ GÖNDEREMESSİNİZ"
                          : "BU KİŞİ SİZİ ENGELLEDİ",
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // 🔴 RAHATSIZ ETME KONTROLÜ
                final isDND = profileController.isDND.value;
                if (isDND) {
                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: 10, 
                      right: 10, 
                      top: 10, 
                      bottom: MediaQuery.of(context).padding.bottom + 10
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: Center(
                      child: Text(
                        "🔴 Rahatsız Etme modu açık, mesaj gönderemezsiniz",
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Container(
                  padding: EdgeInsets.only(
                    left: 10, 
                    right: 10, 
                    top: 10, 
                    bottom: MediaQuery.of(context).padding.bottom + 10
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Row(
                    children: [
                      // Resim Ekle butonu
                      IconButton(
                        icon: const Icon(LucideIcons.imagePlus, color: Colors.white54),
                        onPressed: _pickAndSendImage,
                      ),
                      
                      // Text Field
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: _onTextChanged, // Typing listener PieSocket
                            decoration: InputDecoration(
                              hintText: "Mesaj yaz...",
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),

                      // Gönder Butonu
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.cyanAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.send, color: Colors.black, size: 20),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
