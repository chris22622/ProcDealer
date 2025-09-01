import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:vibration/vibration.dart';
import 'save_service.dart';

class AudioService {
  static bool get _soundOn {
    try {
      if (!Hive.isBoxOpen(SaveService.metaBox)) return true;
      return Hive.box(SaveService.metaBox).get('sound', defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }

  static bool get _hapticsOn {
    try {
      if (!Hive.isBoxOpen(SaveService.metaBox)) return false;
      return Hive.box(SaveService.metaBox).get('haptics', defaultValue: true) as bool;
    } catch (_) {
      return false;
    }
  }

  static Future<void> click() async {
    if (_soundOn) {
      // Use system click sound to avoid asset requirements
      await SystemSound.play(SystemSoundType.click);
    }
    if (_hapticsOn) {
      try {
        final has = await Vibration.hasVibrator() ?? false;
        if (has) {
          await Vibration.vibrate(duration: 20);
        }
      } catch (_) {
        // ignore on unsupported platforms
      }
    }
  }

  static Future<void> confirm() async {
    if (_soundOn) {
      await SystemSound.play(SystemSoundType.click);
    }
    if (_hapticsOn) {
      try {
        final has = await Vibration.hasVibrator() ?? false;
        if (has) {
          await Vibration.vibrate(duration: 35);
        }
      } catch (_) {}
    }
  }

  static Future<void> alert() async {
    if (_soundOn) {
      await SystemSound.play(SystemSoundType.click);
    }
    if (_hapticsOn) {
      try {
        final has = await Vibration.hasVibrator() ?? false;
        if (has) {
          await Vibration.vibrate(pattern: [0, 60, 30, 60]);
        }
      } catch (_) {}
    }
  }
}
