import 'package:flutter/src/material/slider_theme.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:vibration/vibration.dart';

class ShockAlarmVibrations {


  static Future<bool> skipVibration() async {
    return !await Vibration.hasVibrator() || !AlarmListManager.getInstance().settings.enableUiVibrations;
  }
  static void vibrateLongTap() async {
    if(await skipVibration()) return;
    Vibration.vibrate(duration: 50, amplitude: 20);
  }

  static void onAction(ControlType type) async {
    if(await skipVibration()) return;
    switch(type) {
      case ControlType.shock:
        Vibration.vibrate(pattern: [0, 100, 50, 100], intensities: [0, 20, 0, 20]);
        break;
      case ControlType.stop:
        Vibration.vibrate(pattern: [0, 50, 50, 50, 50, 50], intensities: [0, 20, 0, 20, 0, 20]);
        break;
      default:
        Vibration.vibrate(duration: 100, amplitude: 10);
        break;
    }
  }

  static void important() async {
    if(await skipVibration()) return;
    Vibration.vibrate(pattern: [0, 100, 50, 100], intensities: [0, 50, 0, 50]);
  }

  static void pause(bool paused) async {
    if(await skipVibration()) return;
    Vibration.vibrate(pattern: paused ? [0, 100] : [0, 50, 100, 50], intensities: paused ? [0, 20] : [0, 20, 0, 20]);
  }
  static void switchChanged(bool active) async {
    if(await skipVibration()) return;
    Vibration.vibrate(pattern: active ? [0, 50] : [0, 50, 100, 50], intensities: active ? [0, 20] : [0, 20, 0, 20]);
  }

  static Map<String, String> stored = {};
  static void rangeSlider(String key, String id) async {
    if(await skipVibration()) return;
    if(stored.containsKey(key) && stored[key] == id) return; 
    Vibration.vibrate(duration: 50, amplitude: 20);
    stored[key] = id;
  }
}