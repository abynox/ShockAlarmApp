import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:shock_alarm_app/components/grouped_shocker_selector.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:shock_alarm_app/components/tone_item.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../services/openshock.dart';
import 'home.dart';

class RandomShocks extends StatefulWidget {
  @override
  RandomShocksState createState() => RandomShocksState();
}

class RandomShocksState extends State<RandomShocks> {
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
    if(isAndroid()) {
      if(!await FlutterBackground.hasPermissions) {
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
    // TODO: implement dispose
    if(isAndroid() && await FlutterBackground.hasPermissions) {
      FlutterBackground.disableBackgroundExecution();
    }
    running = false;
    runningId += 1;
    super.dispose();
  }

  void stopRandom() async {
    if(isAndroid() && await FlutterBackground.hasPermissions)FlutterBackground.disableBackgroundExecution();
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
              IconButton(onPressed: () {
                showDialog(context: context, builder: (context) {
                  return AlertDialog(
                    title: Text("Random shocks"),
                    content: Text(
                        "This tool will do random shocks with the selected shockers. You can set the intensity and duration range, the delay between the shocks and the type of control to use randomly.\n\nNote: This feature might only work while the app is open in the background. Closing it on android may stop this feature."),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("Close"))
                    ],
                  );
                });
              }, icon: Icon(Icons.info)),
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
              Padding(padding: EdgeInsets.all(15))
            ],
          )
        ],
      )),
    );
  }
}
