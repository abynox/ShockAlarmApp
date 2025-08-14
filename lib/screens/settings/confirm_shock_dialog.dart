import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shock_alarm_app/components/haptic_switch.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
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
    double intensity = AlarmListManager.getInstance()
        .settings
        .confirmShockMinIntensity
        .toDouble();
    double duration = AlarmListManager.getInstance()
        .settings
        .confirmShockMinDuration
        .toDouble();
    controlsContainer.intensityRange = RangeValues(intensity, intensity);
    controlsContainer.durationRange = RangeValues(duration, duration);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text("Confirm/Restrict Shock"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              "These are the minimum duration and intensity settings for which a confirmation dialog will be shown. Either one needs to be met or both to trigger it."),
          IntensityDurationSelector(
              controlsContainer: controlsContainer,
              onSet: (c) {
                AlarmListManager.getInstance()
                    .settings
                    .confirmShockMinIntensity = c.intensityRange.start.toInt();
                AlarmListManager.getInstance()
                    .settings
                    .confirmShockMinDuration = c.durationRange.start.toInt();
              },
              maxDuration: OpenShockLimits.getMaxDuration(),
              showSeperateIntensities: false,
              allowRandom: false,
              maxIntensity: 100),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text("Enforce as global limit"),
                  IconButton(
                      onPressed: () {
                        InfoDialog.show("Global limit",
                            "A global limit will restrict the intensity and duration of all shockers in the app (even your own) to the specified amount. This setting will not be synced to the server and does only apply to you. Other people still have the limits set in their respective shares.");
                      },
                      icon: Icon(Icons.info)),
                ],
              ),
              HapticSwitch(
                  value: AlarmListManager.getInstance()
                      .settings
                      .enforceHardLimitInsteadOfShock,
                  key: ValueKey("enforceHardLimitInsteadOfShock"),
                  onChanged: (value) {
                    setState(() {
                      AlarmListManager.getInstance()
                          .settings
                          .enforceHardLimitInsteadOfShock = value;
                      AlarmListManager.getInstance().saveSettings();
                    });
                  })
            ],
          ),
        ],
      ),
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
