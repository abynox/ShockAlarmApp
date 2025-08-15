import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/screens/shockers/grouped/grouped_shocker_selector.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/screens/tones/tone_item.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/tools/random_shocks/bottle_spin.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../../../services/openshock.dart';
import '../../shockers/shocking_controls.dart';

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

  ControlType getRandomControlType() {
    if (validControlTypes.isEmpty) {
      return ControlType.shock;
    }
    return validControlTypes[Random().nextInt(validControlTypes.length)];
  }

  int getRandomIntensity(ControlType type) {
    return AlarmListManager.getInstance().settings.useSeperateSliders &&
            type == ControlType.vibrate
        ? controlsContainer.getRandomVibrateIntensity()
        : controlsContainer.getRandomIntensity();
  }

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
      ControlType type = getRandomControlType();
      executeAll(type, getRandomIntensity(type),
          controlsContainer.getRandomDuration());
    }
  }

  void executeAll(ControlType type, int intensity, int duration) {
    List<Control> controls = [];
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      controls.add(s.getLimitedControls(type, intensity, duration));
    }
    AlarmListManager.getInstance().sendControls(controls);
  }

  @override
  void initState() {
    validControlTypes = availableControls.values.first;
    super.initState();
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

  Map<String, List<ControlType>> availableControls = {
    "Shock": [ControlType.shock],
    "Vibrate": [ControlType.vibrate],
    "Sound": [ControlType.sound],
    "Shock & Vibrate": [ControlType.shock, ControlType.vibrate],
    "Shock & Sound": [ControlType.shock, ControlType.sound],
    "Vibrate & Sound": [ControlType.vibrate, ControlType.sound],
    "All": [ControlType.shock, ControlType.vibrate, ControlType.sound],
  };

  @override
  Widget build(BuildContext context) {
    Shocker limitedShocker =
        AlarmListManager.getInstance().getSelectedShockerLimits();
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
                        "This tool will do random shocks with the selected shockers. You can set the intensity and duration range, the delay between the shocks and the type of control to use randomly.\n\nNote: This feature might only work while the app is open in the background. Closing it on android or changing to another window on web may stop this feature temporarily.\n\nYou can also spin a bottle by pressing the random button next to the play button");
                  },
                  icon: Icon(Icons.info)),
              IntensityDurationSelector(
                  controlsContainer: controlsContainer,
                  onSet: (ControlsContainer c) {
                    setState(() {});
                  },
                  showSeperateIntensities: AlarmListManager.getInstance()
                      .settings
                      .useSeperateSliders,
                  maxDuration: limitedShocker.durationLimit,
                  maxIntensity: limitedShocker.intensityLimit,
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
                initialSelection: validControlTypes,
                dropdownMenuEntries: availableControls.entries
                    .map((entry) => DropdownMenuEntry<List<ControlType>>(
                        value: entry.value, label: entry.key))
                    .toList(),
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
                  IconButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => BottleSpinScreen(
                                      controlsContainer: controlsContainer,
                                      getRandomControlType:
                                          getRandomControlType,
                                    )));
                      },
                      icon: Icon(Icons.casino))
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
