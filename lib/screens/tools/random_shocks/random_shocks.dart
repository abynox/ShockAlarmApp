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
  bool showBottleFlipUi = false;

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

  void doSpin() async {
    if (AlarmListManager.getInstance().getSelectedShockers().isEmpty) {
      ErrorDialog.show("No shockers selected",
          "Please select at least one shocker to spin the bottle.");
      return;
    }
    spinText = "";
    spinDone = false;
    showBottleFlipUi = true;
    randomlySelectedShocker = Random()
        .nextInt(AlarmListManager.getInstance().getSelectedShockers().length);
    angle %= 2 * pi;
    int spins = Random().nextInt(5) + 6;
    double spinAngle = 2 * pi * spins +
        2 *
            pi *
            (randomlySelectedShocker /
                AlarmListManager.getInstance().getSelectedShockers().length);
    spinAngle += 2 * pi - angle;
    print(spinAngle);

    //now spin it over time
    double spinDuration = 2000 + Random().nextDouble() * 200;
    double startTime = DateTime.now().millisecondsSinceEpoch.toDouble();
    double endTime = startTime + spinDuration;

    double startAngle = angle;
    double progress = 0;

    // now animate it
    while (progress < 1) {
      progress =
          (DateTime.now().millisecondsSinceEpoch.toDouble() - startTime) /
              (spinDuration);
      setState(() {
        angle = startAngle + spinAngle * sin(progress * pi / 2);
      });
      await Future.delayed(Duration(milliseconds: 10));
    }
    ControlType type = getRandomControlType(); // get the random control type
    int intensity = getRandomIntensity(type);
    Shocker s = AlarmListManager.getInstance()
        .getSelectedShockers()
        .elementAt(randomlySelectedShocker);
    String prefix =
        "${type.name} @ $intensity for ${(controlsContainer.getRandomDuration() / 1000).toStringAsFixed(1)} sec (${s.hubReference?.name}.${s.name})";
    setState(() {
      angle = startAngle + spinAngle;
      spinText = "$prefix in 3";
      spinDone = true;
    });
    await Future.delayed(Duration(milliseconds: 1000));
    setState(() {
      spinText = "$prefix in 2";
    });
    await Future.delayed(Duration(milliseconds: 1000));
    setState(() {
      spinText = "$prefix in 1";
    });
    await Future.delayed(Duration(milliseconds: 1000));
    setState(() {
      spinText = "$prefix now!";
    });
    AlarmListManager.getInstance().sendControls([
      s.getLimitedControls(
          type, intensity, controlsContainer.getRandomDuration())
    ]);
    await Future.delayed(Duration(milliseconds: 2000));
    //now stop it
    setState(() {
      showBottleFlipUi = false;
    });
  }

  int randomlySelectedShocker = 0;
  bool spinDone = false;
  String spinText = "";

  double angle = 0;

  Widget buildSpinningBottle() {
    List<Shocker> shockers =
        AlarmListManager.getInstance().getSelectedShockers().toList();

    ThemeData t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Random shocks'),
      ),
      body: PagePadding(
          child: ConstrainedContainer(
              child: Flex(
        direction: Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10,
        children: <Widget>[
          Flexible(
            flex: 1,
            child: Text(
              spinText,
              style: t.textTheme.headlineMedium,
            ),
          ),
          Flexible(
            flex: 5,
            child: LayoutBuilder(builder: (context, constraints) {
            double size = constraints.maxWidth;
            if (constraints.maxHeight < constraints.maxWidth) {
              size = constraints.maxHeight;
            }

            return Container(
              width: size,
              height: size,
              constraints: BoxConstraints(
                maxWidth: size,
                maxHeight: size,
              ),
              decoration: BoxDecoration(
                color: t.colorScheme.onSecondary,
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: size / 2,
                    left: size / 2,
                    child: Center(
                        child: Transform(
                            transform: Matrix4.identity()..rotateZ(angle),
                            child: FractionalTranslation(
                                translation: Offset(-0.5, -0.5),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "BOTTLE", // spin it
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: size / 10,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_right,
                                        size: size / 7,
                                      )
                                    ])))),
                  ),
                  ...shockers.map((shocker) => Positioned(
                        left: size / 2 +
                            cos(2 *
                                    pi /
                                    shockers.length *
                                    shockers.indexOf(shocker)) *
                                (size / 2 - 50),
                        top: size / 2 +
                            sin(2 *
                                    pi /
                                    shockers.length *
                                    shockers.indexOf(shocker)) *
                                (size / 2 - 50),
                        child: FractionalTranslation(
                            translation: Offset(-0.5, -0.5),
                            child: Chip(
                              label: Text(shocker.name),
                              backgroundColor: shockers.indexOf(shocker) ==
                                          randomlySelectedShocker &&
                                      spinDone
                                  ? t.colorScheme
                                      .onPrimary // ToDo: change this color
                                  : null,
                            )),
                      )),
                ],
              ),
            );
          })),
        ],
      ))),
    );
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
    if (showBottleFlipUi) {
      return buildSpinningBottle();
    }
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
                        setState(() {
                          doSpin();
                        });
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
