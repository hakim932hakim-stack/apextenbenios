import 'package:flutter/services.dart';

/// Video Playback Service Helper
/// Android Foreground Service ile iletişim kurar
class VideoService {
  static const _platform = MethodChannel('com.apex/video_service');
  
  // 🔥 NEW: Native Video Player MethodChannel
  static const _nativePlayer = MethodChannel('com.apex/native_video_player');
  
  /// Callback for when notification play button is pressed
  static Function()? onPlayFromNotification;
  
  /// Callback for when notification pause button is pressed  
  static Function()? onPauseFromNotification;
  
  // 🔥 NEW: Callbacks for native player events
  static Function(int duration)? onVideoReady;
  static Function()? onVideoEnded;
  static Function(bool isPlaying)? onPlaybackStateChanged;
  static Function()? onToggleFullscreen;
  
  static VideoService? _instance;
  
  factory VideoService() {
    _instance ??= VideoService._internal();
    return _instance!;
  }
  
  VideoService._internal() {
    _setupMethodCallHandler();
    _setupNativePlayerHandler();
  }
  
  /// Listen to callbacks from native side
  void _setupMethodCallHandler() {
    _platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlay':
          onPlayFromNotification?.call();
          break;
        case 'onPause':
          onPauseFromNotification?.call();
          break;
      }
    });
  }
  
  /// Listen to native player events
  void _setupNativePlayerHandler() {
    _nativePlayer.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onReady':
          final duration = call.arguments['duration'] as int? ?? 0;
          onVideoReady?.call(duration);
          break;
        case 'onEnded':
          onVideoEnded?.call();
          break;
        case 'onPlaybackState':
          final isPlaying = call.arguments['playing'] as bool? ?? false;
          onPlaybackStateChanged?.call(isPlaying);
          break;
        case 'toggleFullscreen':
          print('📽️ [VideoService] Toggle fullscreen requested');
          onToggleFullscreen?.call();
          break;
      }
    });
  }
  
  // ============================================
  // 🔥 NATIVE VIDEO PLAYER METHODS (NEW)
  // ============================================
  
  /// Load and play video with native ExoPlayer
  static Future<void> loadVideo({
    required String url,
    required String title,
    required bool isOwner,
    int startPosition = 0,
    int topMargin = 0, // 🔥 Header yüksekliği (px)
  }) async {
    try {
      print('🔥 [VideoService] Loading native video - $title');
      await _nativePlayer.invokeMethod('loadVideo', {
        'url': url,
        'title': title,
        'isOwner': isOwner,
        'startPosition': startPosition,
        'topMargin': topMargin, // 🔥 Pozisyon parametresi
      });
      print('✅ [VideoService] Native video loaded!');
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] loadVideo error: ${e.message}');
      rethrow;
    }
  }
  
  /// Play video
  static Future<void> play() async {
    try {
      await _nativePlayer.invokeMethod('play');
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] play error: ${e.message}');
    }
  }
  
  /// Pause video
  static Future<void> pause() async {
    try {
      await _nativePlayer.invokeMethod('pause');
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] pause error: ${e.message}');
    }
  }
  
  /// Seek to position (milliseconds)
  static Future<void> seekTo(int position) async {
    try {
      await _nativePlayer.invokeMethod('seekTo', {'position': position});
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] seekTo error: ${e.message}');
    }
  }
  
  /// Stop video and release player
  static Future<void> stopVideo() async {
    try {
      await _nativePlayer.invokeMethod('stop');
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] stopVideo error: ${e.message}');
    }
  }
  
  /// Get current playback position (milliseconds)
  static Future<int> getCurrentPosition() async {
    try {
      final pos = await _nativePlayer.invokeMethod<int>('getCurrentPosition');
      return pos ?? 0;
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] getCurrentPosition error: ${e.message}');
      return 0;
    }
  }
  
  /// Get video duration (milliseconds)
  static Future<int> getDuration() async {
    try {
      final duration = await _nativePlayer.invokeMethod<int>('getDuration');
      return duration ?? 0;
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] getDuration error: ${e.message}');
      return 0;
    }
  }
  
  /// Check if video is playing
  static Future<bool> isPlaying() async {
    try {
      final playing = await _nativePlayer.invokeMethod<bool>('isPlaying');
      return playing ?? false;
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] isPlaying error: ${e.message}');
      return false;
    }
  }
  
  /// Set volume (0.0 to 1.0)
  static Future<void> setVolume(double volume) async {
    try {
      await _nativePlayer.invokeMethod('setVolume', {'volume': volume});
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] setVolume error: ${e.message}');
    }
  }
  
  // ============================================
  // 🔥 FOREGROUND SERVICE METHODS (EXISTING)
  // ============================================
  
  /// Start foreground service with video info
  static Future<void> startService({
    required String title,
    required bool isOwner,
    bool isPlaying = false,
  }) async {
    try {
      print('🔥 [VideoService] Starting service - title: $title, isOwner: $isOwner, isPlaying: $isPlaying');
      await _platform.invokeMethod('startVideoService', {
        'title': title,
        'isOwner': isOwner,
        'isPlaying': isPlaying,
      });
      print('✅ [VideoService] Service started successfully!');
    } on PlatformException catch (e) {
      print('⚠️ [VideoService] startService error: ${e.message}');
      print('⚠️ [VideoService] Error code: ${e.code}');
      print('⚠️ [VideoService] Error details: ${e.details}');
    } catch (e) {
      print('❌ [VideoService] Unexpected error: $e');
    }
  }
  
  /// Stop foreground service
  static Future<void> stopService() async {
    try {
      await _platform.invokeMethod('stopVideoService');
    } on PlatformException catch (e) {
      print('⚠️ VideoService.stopService error: ${e.message}');
    }
  }
  
  /// Update playback state (play/pause)
  static Future<void> updatePlaybackState({
    required bool isPlaying,
    String? title,
  }) async {
    try {
      await _platform.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        if (title != null) 'title': title,
      });
    } on PlatformException catch (e) {
      print('⚠️ VideoService.updatePlaybackState error: ${e.message}');
    }
  }
  
  /// Check if service is running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _platform.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      print('⚠️ VideoService.isServiceRunning error: ${e.message}');
      return false;
    }
  }
  
  /// 🙈 Hide native player (for bottom sheets)
  static Future<void> hidePlayer() async {
    try {
      await _nativePlayer.invokeMethod('hidePlayer');
      print('🙈 [VideoService] Player hidden');
    } on PlatformException catch (e) {
      print('⚠️ VideoService.hidePlayer error: ${e.message}');
    }
  }
  
  /// 👀 Show native player
  static Future<void> showPlayer() async {
    try {
      await _nativePlayer.invokeMethod('showPlayer');
      print('👀 [VideoService] Player shown');
    } on PlatformException catch (e) {
      print('⚠️ VideoService.showPlayer error: ${e.message}');
    }
  }
}
