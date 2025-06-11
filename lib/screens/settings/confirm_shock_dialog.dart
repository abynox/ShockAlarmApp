import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/limits.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class ConfirmShockDialog extends StatefulWidget {
  const ConfirmShockDialog({Key? key}) : super(key: key);

  @override
  _ConfirmShockDialogState createState() => _ConfirmShockDialogState();
}

class _ConfirmShockDialogState extends State<ConfirmShockDialog> {
   ControlsContainer controlsContainer = ControlsContainer();

   @override
  void initState() {
    super.initState();
    double intensity = AlarmListManager.getInstance().settings.confirmShockMinIntensity.toDouble();
    double duration = AlarmListManager.getInstance().settings.confirmShockMinDuration.toDouble();
    controlsContainer.intensityRange = RangeValues(intensity, intensity);
    controlsContainer.durationRange = RangeValues(duration, duration);
  }
 
  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text("Confirm Shock"),
      content: Column(mainAxisSize: MainAxisSize.min,
      children: [
        Text("These are the minimum duration and intensity settings for which a confirmation dialog will be shown. Either one needs to be met or both to trigger it."),
        IntensityDurationSelector(controlsContainer: controlsContainer,
          onSet: (c) {
            AlarmListManager.getInstance().settings.confirmShockMinIntensity = c.intensityRange.start.toInt();
            AlarmListManager.getInstance().settings.confirmShockMinDuration = c.durationRange.start.toInt();
          },
          maxDuration: OpenShockLimits.getMaxDuration(),
          showSeperateIntensities: false,
          allowRandom: false,
          maxIntensity: 100)

      ],),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            AlarmListManager.getInstance().saveSettings();
          },
          child: Text("Ok"),
        ),
      ],
    );
  }
}