import 'package:shock_alarm_app/services/openshock.dart';
import 'package:vibration/vibration.dart';

class ShockAlarmVibrations {
  static void vibrateLongTap() {
    Vibration.hasVibrator().then((res) {
      if(!res) return;
      Vibration.vibrate(duration: 50, amplitude: 128);
    });
  }

  static void onAction(ControlType type) {
    Vibration.hasVibrator().then((res) {
      if(!res) return;
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
    });
  }
}