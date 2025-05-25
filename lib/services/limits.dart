import 'package:shock_alarm_app/services/alarm_list_manager.dart';

class OpenShockLimits {
  static const int maxDuration = 65536;
  static const int maxRecommendedDuration = 30000;
  static const int maxIntensity = 100;

  // Returns the maximum duration based on user preferences. This is meant for the sliders so they are okay to adjust and not so fiddely
  static getMaxDuration() {
    return AlarmListManager.getInstance().settings.increaseMaxDuration
        ? maxDuration
        : maxRecommendedDuration;
  }
}