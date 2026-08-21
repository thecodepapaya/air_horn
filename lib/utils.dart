import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';

class VolumeNudge {
  static const _cooldown = Duration(seconds: 2);

  static bool _checkInProgress = false;
  static DateTime? _lastShownAt;

  static Future<void> showIfMuted() async {
    final lastShownAt = _lastShownAt;
    if (_checkInProgress ||
        (lastShownAt != null &&
            DateTime.now().difference(lastShownAt) < _cooldown)) {
      return;
    }

    _checkInProgress = true;
    try {
      if (await VolumeController.instance.isMuted()) {
        _lastShownAt = DateTime.now();
        await Fluttertoast.showToast(
          msg: 'Turn up your media volume to hear the horn.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on MissingPluginException {
      // Volume detection is unavailable in widget tests and unsupported hosts.
    } on PlatformException {
      // A volume check should never prevent the horn from playing.
    } finally {
      _checkInProgress = false;
    }
  }
}

class HoldNudge {
  static Future<void> show() async {
    await Future.wait([HornVibrator.attention(), _showToast()]);
  }

  static Future<void> _showToast() async {
    try {
      await Fluttertoast.showToast(
        msg: 'Press and hold the button to keep the horn sounding.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } on MissingPluginException {
      // Native toasts are unavailable in widget tests and unsupported hosts.
    } on PlatformException {
      // The hint must never interfere with the horn control.
    }
  }
}

class HornVibrator {
  static Future<void> start() async {
    try {
      await Vibration.vibrate(
        duration: Duration.millisecondsPerHour,
        amplitude: 255,
      );
    } on MissingPluginException {
      // Some devices and test hosts do not expose a vibrator.
    } on PlatformException {
      // Audio remains usable when vibration is unavailable.
    }
  }

  static Future<void> end() async {
    try {
      await Vibration.cancel();
    } on MissingPluginException {
      // Some devices and test hosts do not expose a vibrator.
    } on PlatformException {
      // Audio remains usable when vibration is unavailable.
    }
  }

  static Future<void> attention() async {
    await end();
    try {
      await HapticFeedback.heavyImpact();
    } on MissingPluginException {
      // Haptics are optional on unsupported devices.
    } on PlatformException {
      // The toast still provides a visual hint without haptics.
    }
  }
}

class Player {
  static final _player = AudioPlayer();
  static Future<void>? _initialization;
  static var _commandGeneration = 0;

  static Future<void> init() {
    final currentInitialization = _initialization;
    if (currentInitialization != null) {
      return currentInitialization;
    }

    final initialization = _initialize();
    _initialization = initialization;
    return initialization.catchError((Object error, StackTrace stackTrace) {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  static Future<void> _initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _player.setAsset('assets/horn.mp3', preload: true);
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(1);
  }

  static Future<void> prepare() async {
    try {
      await init();
    } catch (_) {
      // A later press retries initialization after transient device failures.
    }
  }

  static Future<void> play() async {
    final command = ++_commandGeneration;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await init();
        if (command != _commandGeneration) {
          return;
        }
        unawaited(_playIgnoringLateErrors());
        return;
      } catch (_) {
        if (command != _commandGeneration) {
          return;
        }
      }
    }
  }

  static Future<void> _playIgnoringLateErrors() async {
    try {
      await _player.play();
    } catch (_) {
      // Playback errors are retried on the next press.
    }
  }

  static Future<void> onEnd() async {
    final command = ++_commandGeneration;
    try {
      await init();
    } catch (_) {
      return;
    }
    if (command != _commandGeneration) {
      return;
    }
    try {
      await _player.pause();
    } catch (_) {
      return;
    }
    if (command != _commandGeneration) {
      return;
    }
    try {
      await _player.seek(Duration.zero);
    } catch (_) {
      // The next successful load starts the asset from the beginning.
    }
  }
}
