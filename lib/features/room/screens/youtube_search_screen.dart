import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:get/get.dart';

class YouTubeSearchScreen extends StatefulWidget {
  final Function(String videoId, String title, String thumbnailUrl) onVideoSelected;

  const YouTubeSearchScreen({super.key, required this.onVideoSelected});

  @override
  State<YouTubeSearchScreen> createState() => _YouTubeSearchScreenState();
}

class _YouTubeSearchScreenState extends State<YouTubeSearchScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => isLoading = false);
            _checkUrlForVideo(url);
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              _checkUrlForVideo(change.url!);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://m.youtube.com'));
  }

  void _checkUrlForVideo(String url) async {
    // URL'den Video ID'yi çıkar
    String? videoId;
    if (url.contains('watch?v=')) {
      videoId = url.split('watch?v=')[1].split('&')[0];
    } else if (url.contains('youtu.be/')) {
      videoId = url.split('youtu.be/')[1].split('?')[0];
    }

    if (videoId != null && videoId.isNotEmpty) {
      // Video bulundu! Bilgileri çekmeye çalışalım (Title vs. JS ile)
      String title = 'YouTube Video';
      try {
        // WebView title yerine oEmbed API ile kesin başlığı al
        final apiUrl = Uri.parse('https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json');
        final response = await http.get(apiUrl);
        
        if (response.statusCode == 200) {
           final data = jsonDecode(response.body);
           title = data['title'] ?? title;
        } else {
           // Fallback to document title
           final result = await controller.runJavaScriptReturningResult('document.title') as String;
           title = result.replaceAll('"', '').replaceAll(' - YouTube', '');
        }
      } catch (_) {}

      final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      
      // Callback'i tetikle ve geri dön
      widget.onVideoSelected(videoId, title, thumbnailUrl);
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('YouTube\'da Ara', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
        ],
      ),
    );
  }
}
