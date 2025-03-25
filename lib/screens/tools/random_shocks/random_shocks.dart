import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/screens/shockers/grouped/grouped_shocker_selector.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/screens/tones/tone_item.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../../../services/openshock.dart';

class RandomShocksScreen extends StatefulWidget {
  @override
  _RandomShocksScreenState createState() => _RandomShocksScreenState();
}

class _RandomShocksScreenState extends State<RandomShocksScreen> {
  ControlsContainer controlsContainer = ControlsContainer();

  int minTime = 1000;
  int maxTime = 30000;
  int runningId = 0;
  bool running = false;
  DateTime lastRandom = DateTime.now();
  DateTime nextRandom = DateTime.now();
  List<ControlType> validControlTypes = [];

  void startRandom() async {
    running = true;
    runningId += 1;
    int currentId = runningId;
    if (isAndroid()) {
      if (!await FlutterBackground.hasPermissions) {
        initBgService();
      } else {
        FlutterBackground.enableBackgroundExecution();
      }
    }
    setState(() {});
    lastRandom = DateTime.now();
    while (runningId == currentId) {
      int randomDelay = Random().nextInt((maxTime - minTime).toInt()) + minTime;
      nextRandom = lastRandom.add(Duration(milliseconds: randomDelay));
      await Future.delayed(Duration(milliseconds: randomDelay));
      if (runningId != currentId) {
        return;
      }
      ControlType type =
          validControlTypes[Random().nextInt(validControlTypes.length)];
      executeAll(type, controlsContainer.getRandomIntensity(),
          controlsContainer.getRandomDuration());
    }
  }

  void executeAll(ControlType type, int intensity, int duration) {
    List<Control> controls = [];
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      controls.add(s.getLimitedControls(type, intensity, duration));
    }
    if (type == ControlType.stop) {
      // Temporary workaround until OpenShock fixed the issue with stop. So for now we send them individually
      for (Control c in controls) {
        AlarmListManager.getInstance().sendControls([c]);
      }
      return;
    }
    AlarmListManager.getInstance().sendControls(controls);
  }

  @override
  void dispose() async {
    super.dispose();
    if (isAndroid() &&
        await FlutterBackground.hasPermissions &&
        FlutterBackground.isBackgroundExecutionEnabled) {
      FlutterBackground.disableBackgroundExecution();
    }
    running = false;
    runningId += 1;
  }

  void stopRandom() async {
    if (isAndroid() &&
        await FlutterBackground.hasPermissions &&
        FlutterBackground.isBackgroundExecutionEnabled)
      FlutterBackground.disableBackgroundExecution();
    runningId += 1;
    running = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Random shocks'),
      ),
      body: PagePadding(
          child: ConstrainedContainer(
              child: Column(
        children: <Widget>[
          GroupedShockerSelector(
            onChanged: () {
              setState(() {});
            },
          ),
          Column(
            spacing: 10,
            children: [
              IconButton(
                  onPressed: () {
                    InfoDialog.show("Random shocks",
                        "This tool will do random shocks with the selected shockers. You can set the intensity and duration range, the delay between the shocks and the type of control to use randomly.\n\nNote: This feature might only work while the app is open in the background. Closing it on android or changing to another window on web may stop this feature temporarely.");
                  },
                  icon: Icon(Icons.info)),
              IntensityDurationSelector(
                  controlsContainer: controlsContainer,
                  onSet: (ControlsContainer c) {
                    setState(() {});
                  },
                  maxDuration: 30000,
                  maxIntensity: 100,
                  allowRandom: true,
                  key: ValueKey(AlarmListManager.getInstance()
                          .settings
                          .useRangeSliderForDuration
                          .toString() +
                      AlarmListManager.getInstance()
                          .settings
                          .useRangeSliderForIntensity
                          .toString())),
              Row(
                spacing: 10,
                children: [
                  SecondTextField(
                      timeMs: minTime,
                      label: "min delay",
                      onSet: (time) {
                        setState(() {
                          minTime = time;
                        });
                      }),
                  SecondTextField(
                      timeMs: maxTime,
                      label: "max delay",
                      onSet: (time) {
                        setState(() {
                          maxTime = time;
                        });
                      })
                ],
              ),
              DropdownMenu<List<ControlType>>(
                initialSelection: [ControlType.shock],
                dropdownMenuEntries: [
                  DropdownMenuEntry(value: [ControlType.shock], label: "Shock"),
                  DropdownMenuEntry(
                      value: [ControlType.vibrate], label: "Vibrate"),
                  DropdownMenuEntry(value: [ControlType.sound], label: "Sound"),
                  DropdownMenuEntry(
                      value: [ControlType.shock, ControlType.vibrate],
                      label: "Shock & Vibrate"),
                  DropdownMenuEntry(
                      value: [ControlType.shock, ControlType.sound],
                      label: "Shock & Sound"),
                  DropdownMenuEntry(
                      value: [ControlType.vibrate, ControlType.sound],
                      label: "Vibrate & Sound"),
                  DropdownMenuEntry(value: [
                    ControlType.shock,
                    ControlType.vibrate,
                    ControlType.sound
                  ], label: "All"),
                ],
                onSelected: (value) {
                  validControlTypes = value ?? [];
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!running)
                    IconButton(
                        onPressed: startRandom, icon: Icon(Icons.play_arrow)),
                  if (running)
                    IconButton(onPressed: stopRandom, icon: Icon(Icons.stop)),
                ],
              ),
              PredefinedSpacing(),
            ],
          )
        ],
      ))),
    );
  }
}
