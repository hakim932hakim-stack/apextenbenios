import 'dart:convert';
import 'package:http/http.dart' as http;

/// YouTube video stream çıkarma servisi
/// Supabase Edge Function üzerinden Render Backend'e istek atar
class YouTubeExtractorService {
  // Supabase Edge Function URL
  static const String _edgeFunctionUrl = 
      'https://hpskmctrceefhfaruqoa.supabase.co/functions/v1/extract-youtube-vps';
  
  // Supabase Anon Key (JWT verification kapalı olmalı Edge Function'da)
  static const String _supabaseAnonKey = 
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhwc2ttY3RyY2VlZmhmYXJ1cW9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU2NjI1NzcsImV4cCI6MjA1MTIzODU3N30.hqsLwLSZq-SYLHiQK1LWDcxQ4QA1t9lfhcSA-HQ8D6o';

  /// YouTube video ID'den MP4 stream URL'i çıkarır
  /// 
  /// [videoId] - YouTube video ID (örn: "dQw4w9WgXcQ")
  /// 
  /// Returns: Extracted stream bilgisi
  /// Throws: Exception eğer extraction başarısız olursa
  static Future<ExtractedStream> extractStream(String videoId) async {
    try {
      print('[YouTubeExtractor] 📡 Extracting video: $videoId');
      
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
        body: jsonEncode({'videoId': videoId}),
      ).timeout(
        const Duration(seconds: 60), // Render cold start için uzun timeout
        onTimeout: () {
          throw Exception('Video extraction timeout (sunucu başlatılıyor, tekrar deneyin)');
        },
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Extraction failed');
      }
      
      final data = jsonDecode(response.body);
      
      print('[YouTubeExtractor] ✅ Extraction SUCCESS: ${data['quality']}');
      
      return ExtractedStream(
        videoUrl: data['videoUrl'],
        quality: data['quality'] ?? '1080p',
        source: data['source'] ?? 'vps-backend',
      );
    } catch (e) {
      print('[YouTubeExtractor] ❌ Extraction FAILED: $e');
      rethrow;
    }
  }
}

/// Çıkarılmış video stream bilgisi
class ExtractedStream {
  final String videoUrl;
  final String quality;
  final String source;

  ExtractedStream({
    required this.videoUrl,
    required this.quality,
    required this.source,
  });
}
