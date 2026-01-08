import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';

class SoundService extends GetxService {
  late AudioPlayer _audioPlayer;

  @override
  void onInit() {
    super.onInit();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.stop); // Çaldıktan sonra durur
  }

  // Tekil instance yerine her seferinde yeni çalma mantığı (Overlap sorunu olmasın)
  // Veya aynı instance üzerinden stop -> play yap.
  // Basitlik için static method veya her seferinde new AudioPlayer.
  
  Future<void> playClickSound() async {
    try {
      final player = AudioPlayer();
      await player.setVolume(0.5);
      // AssetSource 'assets/' prefixini otomatik ekler. 
      // Dosya: assets/sounds/enter.mp3 ise -> AssetSource('sounds/enter.mp3')
      await player.play(AssetSource('sounds/enter.mp3'));
      
      // Memory leak önlemek için çalma bitince dispose edilebilir ama 
      // fire-and-forget için garbage collector halleder genelde. 
      // Ancak release mode STOP ise player.dispose() çağırmak gerekebilir onCompletion.
      player.onPlayerComplete.listen((event) {
        player.dispose();
      });

      print("DEBUG: Ses çalınmaya çalışıldı: sounds/enter.mp3");
    } catch (e) {
      print("DEBUG: Ses çalma hatası: $e");
    }
  }
}
