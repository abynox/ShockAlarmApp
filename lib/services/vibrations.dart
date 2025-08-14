import 'package:shock_alarm_app/services/openshock.dart';
import 'package:vibration/vibration.dart';

class ShockAlarmVibrations {

  static Future<bool> skipVibration() async {
    return !await Vibration.hasVibrator();
  }
  static void vibrateLongTap() async {
    if(await skipVibration()) return;
    Vibration.vibrate(duration: 50, amplitude: 128);
  }

  static void onAction(ControlType type) async {
    if(await skipVibration()) return;
    switch(type) {
      case ControlType.shock:
        Vibration.vibrate(pattern: [0, 100, 50, 100], amplitude: 128);
        break;
      case ControlType.stop:
        Vibration.vibrate(pattern: [0, 50, 50, 50, 50, 50], amplitude: 128);
        break;
      default:
        Vibration.vibrate(duration: 100, amplitude: 128);
        break;
    }
  }

  static void important() async {
    if(await skipVibration()) return;
    Vibration.vibrate(pattern: [0, 100, 50, 100], amplitude: 128);
  }

  static void pause(bool paused) async {
    if(await skipVibration()) return;
    Vibration.vibrate(pattern: paused ? [0, 100] : [0, 50, 100, 50], amplitude: 128);
  }
}