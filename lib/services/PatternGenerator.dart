import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

class PatternGenerator {
  static ControlList GenerateFromTone(AlarmTone tone, {AlarmShocker? shocker}) {
    ControlList controls = ControlList();
    for (AlarmToneComponent component in tone.components) {
      int executionTime = component.time + component.duration;
      if (executionTime > controls.duration) {
        controls.duration = executionTime;
      }
      if(!controls.controls.containsKey(component.time)) {
        controls.controls[component.time] = [];
      }
      Control control = Control();
      control.type = component.type!;
      control.intensity = component.intensity;
      control.duration = component.duration;
      if(shocker != null) {
        control.id = shocker.shockerId;
        control.apiTokenId = shocker.shockerReference!.apiTokenId;
      }
      controls.controls[component.time]!.add(control);
    }
    return controls;
  }
}

class ControlList {
  Map<int, List<Control>> controls = {};
  int duration = 0;
}