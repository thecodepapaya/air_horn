import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

class HornVibrator {
  static void start() {
    Vibration.vibrate(
      duration: Duration.millisecondsPerHour,
      amplitude: 255,
    );
  }

  static void end() {
    Vibration.cancel();
  }
}

class Player {
  static final _player = AudioPlayer();

  static void init() {
    _player.setAsset('assets/horn.mp3');
  }

  static Future<void> play() async {
    await _player.play();
  }

  static void onEnd() async {
    await _player.pause();
    _player.seek(Duration.zero);
  }
}
