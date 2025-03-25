import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/dialogs/delete_dialog.dart';
import 'package:shock_alarm_app/screens/shockers/live/live_controls.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_details.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/services/PatternGenerator.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshockws.dart';
import '../logs/logs.dart';
import '../shares/shares.dart';
import '../../stores/alarm_store.dart';
import '../../services/alarm_list_manager.dart';
import '../../services/openshock.dart';

class ShockerAction {
  String name;
  Function(AlarmListManager, Shocker, BuildContext, Function) onClick;
  Icon icon;

  ShockerAction(
      {this.name = "Action", required this.onClick, required this.icon});
}

class ShockerItem extends StatefulWidget {
  LiveControlSettings liveControlSettings = LiveControlSettings();
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;
  static List<ShockerAction> ownShockerActions = [
    ShockerAction(
        name: "Edit",
        icon: Icon(Icons.edit),
        onClick: (AlarmListManager manager, Shocker shocker,
            BuildContext context, Function onRebuild) async {
          LoadingDialog.show("Loading details");
          List<OpenShockDevice> devices = await manager.getDevices();
          OpenShockShocker? s =
              await OpenShockClient().getShockerDetails(shocker);
          Navigator.of(context).pop();
          if (s == null) {
            ErrorDialog.show("Failed to get shocker details",
                "Failed to get shocker details");
            return;
          }
          TextEditingController controller = TextEditingController();
          controller.text = shocker.name;
          showDialog(
              context: context,
              builder: (context) => AlertDialog.adaptive(
                    title: Text("Edit shocker"),
                    content: ShockerDetails(
                      shocker: s,
                      devices: devices,
                      apiTokenId: shocker.apiTokenId,
                    ),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("Cancel")),
                      TextButton(
                          onPressed: () async {
                            LoadingDialog.show("Saving shocker");
                            String? errorMessage =
                                await manager.editShocker(shocker, s);
                            Navigator.of(context).pop();
                            if (errorMessage != null) {
                              ErrorDialog.show(
                                  "Failed to save shocker", errorMessage);
                              return;
                            }
                            Navigator.of(context).pop();
                            await AlarmListManager.getInstance()
                                .updateShockerStore();
                            onRebuild();
                          },
                          child: Text("Save"))
                    ],
                  ));
        }),
    ShockerAction(
        name: "Logs",
        icon: Icon(Icons.list),
        onClick: (AlarmListManager manager, Shocker shocker,
            BuildContext context, Function onRebuild) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      LogScreen(shockers: [shocker], manager: manager)));
        }),
    ShockerAction(
        name: "Shares",
        icon: Icon(Icons.share),
        onClick: (AlarmListManager manager, Shocker shocker,
            BuildContext context, Function onRebuild) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      SharesScreen(shocker: shocker, manager: manager)));
        }),
    ShockerAction(
        name: "Delete",
        icon: Icon(Icons.delete),
        onClick: (AlarmListManager manager, Shocker shocker,
            BuildContext context, Function onRebuild) {
          showDialog(
              context: context,
              builder: (context) => DeleteDialog(
                  onDelete: () async {
                    LoadingDialog.show("Deleting shocker");
                    String? errorMessage = await manager.deleteShocker(shocker);
                    Navigator.of(context).pop();
                    if (errorMessage != null) {
                      ErrorDialog.show(
                          "Failed to delete shocker", errorMessage);
                      return;
                    }
                    Navigator.of(context).pop();
                    await AlarmListManager.getInstance().updateShockerStore();
                    onRebuild();
                  },
                  title: "Delete shocker",
                  body:
                      "Are you sure you want to delete the shocker ${shocker.name}?\n\n(You can add it again later. However shares will be lost until you manually recreate them all)"));
        }),
  ];

  static List<ShockerAction> foreignShockerActions = [
    ShockerAction(
        onClick: (AlarmListManager manager, Shocker shocker,
            BuildContext context, Function onRebuild) {
          showDialog(
              context: context,
              builder: (context) => AlertDialog.adaptive(
                    title: Text("Unlink shocker"),
                    content: Text(
                        "Are you sure you want to unlink the shocker ${shocker.name} from your account? After that you cannot control the shocker anymore unless you redeem another share code."),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("Cancel")),
                      TextButton(
                          onPressed: () async {
                            LoadingDialog.show("Unlinking shocker");
                            String? errorMessage;
                            Token? token = manager.getToken(shocker.apiTokenId);
                            if (token == null)
                              errorMessage = "Token not found";
                            else {
                              OpenShockShare share = OpenShockShare()
                                ..sharedWith =
                                    (OpenShockUser()..id = token.userId)
                                ..shockerReference = shocker;
                              errorMessage = await manager.deleteShare(share);
                            }
                            if (errorMessage != null) {
                              Navigator.of(context).pop();
                              ErrorDialog.show(
                                  "Failed to delete share", errorMessage);
                              return;
                            }
                            await manager.updateShockerStore();
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                            onRebuild();
                          },
                          child: Text("Unlink"))
                    ],
                  ));
        },
        icon: Icon(Icons.delete),
        name: "Unlink"),
  ];

  ShockerItem({
    Key? key,
    required this.shocker,
    required this.manager,
    required this.onRebuild,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      ShockerItemState(shocker, manager, onRebuild);
}

class ShockerItemState extends State<ShockerItem>
    with TickerProviderStateMixin {
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;
  bool delayVibrationEnabled = false;

  DateTime actionDoneTime = DateTime.now();
  DateTime delayDoneTime = DateTime.now();
  double delayDuration = 0;
  bool loadingPause = false;

  @override
  void initState() {
    super.initState();
    shocker.controls.limitTo(shocker.durationLimit, shocker.intensityLimit);
  }

  void setPauseState(bool pause) async {
    setState(() {
      loadingPause = true;
    });
    String? error =
        await OpenShockClient().setPauseStateOfShocker(shocker, manager, pause);
    setState(() {
      loadingPause = false;
    });
    if (error != null) {
      ErrorDialog.show("Failed to pause shocker", error);
      return;
    }
  }

  ShockerItemState(this.shocker, this.manager, this.onRebuild);
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<ShockerAction> actions = shocker.isOwn
        ? ShockerItem.ownShockerActions
        : ShockerItem.foreignShockerActions;
    return PaddedCard(
        child: Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (shocker.paused) return;
              expanded = !expanded;
            });
            onRebuild();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  shocker.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                spacing: 5,
                children: [
                  PopupMenuButton(
                    iconColor: t.colorScheme.onSurfaceVariant,
                    itemBuilder: (context) {
                      return [
                        for (ShockerAction a in actions)
                          PopupMenuItem(
                              value: a.name,
                              child: Row(
                                spacing: 10,
                                children: [a.icon, Text(a.name)],
                              )),
                        PopupMenuItem(
                            value: "live",
                            child: Row(
                              spacing: 10,
                              children: [
                                OpenShockClient.getIconForControlType(
                                    ControlType.live),
                                Text(
                                    "${AlarmListManager.getInstance().liveActiveForShockers.contains(shocker.id) ? "Disable" : "Enable"} live controls (beta)")
                              ],
                            ))
                      ];
                    },
                    onSelected: (String value) {
                      for (ShockerAction a in actions) {
                        if (a.name == value) {
                          a.onClick(manager, shocker, context, onRebuild);
                          return;
                        }
                      }
                      if (value == "live") {
                        setState(() {
                          if (AlarmListManager.getInstance()
                              .liveActiveForShockers
                              .contains(shocker.id)) {
                            AlarmListManager.getInstance()
                                .liveActiveForShockers
                                .remove(shocker.id);
                          } else {
                            AlarmListManager.getInstance()
                                .liveActiveForShockers
                                .add(shocker.id);
                          }
                        });
                        context
                            .findAncestorStateOfType<
                                ScreenSelectorScreenState>()
                            ?.setPageSwipeEnabled(AlarmListManager.getInstance()
                                .liveActiveForShockers
                                .isEmpty);
                      }
                    },
                  ),
                  if (loadingPause) CircularProgressIndicator(),
                  if (shocker.isOwn && shocker.paused && !loadingPause)
                    IconButton(
                        onPressed: () {
                          setPauseState(false);
                        },
                        icon: Icon(Icons.play_arrow)),
                  if (shocker.isOwn && !shocker.paused && !loadingPause)
                    IconButton(
                        onPressed: () {
                          expanded = false;
                          setPauseState(true);
                        },
                        icon: Icon(Icons.pause)),
                  if (shocker.paused)
                    GestureDetector(
                      child: Chip(
                          label: Text("paused"),
                          backgroundColor: t.colorScheme.errorContainer,
                          side: BorderSide.none,
                          avatar: Icon(
                            Icons.info,
                            color: t.colorScheme.error,
                          )),
                      onTap: () {
                        InfoDialog.show(
                            "Shocker is paused",
                            shocker.isOwn
                                ? "This shocker was pause by you. While it's paused you cannot control it. You can unpause it by pressing the play button."
                                : "This shocker was paused by the owner. While it's paused you cannot control it. You can ask the owner to unpause it.");
                      },
                    ),
                  if (!shocker.paused)
                    IconButton(
                        onPressed: () {
                          setState(() {
                            expanded = !expanded;
                          });
                          onRebuild();
                        },
                        icon: Icon(expanded
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded)),
                ],
              )
            ],
          ),
        ),
        if (expanded)
          AlarmListManager.getInstance()
                  .liveActiveForShockers
                  .contains(shocker.id)
              ? LiveControls(
                  showLatency: false,
                  onSendLive: onSendLive,
                  soundAllowed: shocker.soundAllowed,
                  vibrateAllowed: shocker.vibrateAllowed,
                  shockAllowed: shocker.shockAllowed,
                  intensityLimit: shocker.intensityLimit,
                  saveId: shocker.id,
                  ensureConnection: ensureConnection,
                  hubConnected: AlarmListManager.getInstance()
                      .liveControlGatewayConnections
                      .containsKey(shocker.hubId))
              : ShockingControls(
                  manager: manager,
                  controlsContainer: shocker.controls,
                  key: ValueKey(shocker.getIdentifier() + "-shocking-controls"),
                  durationLimit: shocker.durationLimit,
                  intensityLimit: shocker.intensityLimit,
                  shockAllowed: shocker.shockAllowed,
                  vibrateAllowed: shocker.vibrateAllowed,
                  soundAllowed: shocker.soundAllowed,
                  onDelayAction: (type, intensity, duration) {
                    manager
                        .sendShock(type, shocker, intensity, duration)
                        .then((errorMessage) {
                      if (errorMessage == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(errorMessage),
                        duration: Duration(seconds: 3),
                      ));
                    });
                  },
                  onProcessAction: (type, intensity, duration) {
                    manager
                        .sendShock(type, shocker, intensity, duration)
                        .then((errorMessage) {
                      if (errorMessage == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(errorMessage),
                        duration: Duration(seconds: 3),
                      ));
                    });
                  },
                  onSet: (container) {
                    setState(() {});
                  },
                )
      ],
    ));
  }

  Future ensureConnection() async {
    ErrorContainer<bool> error = await AlarmListManager.getInstance()
        .connectToLiveControlGateway(shocker.hubReference!);
    if (error.error != null) {
      ErrorDialog.show("Failed to connect to hub", error.error!);
      return;
    }
    setState(() {});
  }

  void onSendLive(ControlType type, int intensity) {
    List<Control> controls = [shocker.getLimitedControls(type, intensity, 300)];
    if (type == ControlType.stop) {
      // Temporary workaround until OpenShock fixed the issue with stop. So for now we send them individually
      for (Control c in controls) {
        manager.sendControls([c]);
      }
      return;
    }
    manager.sendLiveControls(controls);
  }
}

class IntensityDurationSelector extends StatefulWidget {
  ControlsContainer controlsContainer;
  int maxDuration;
  int maxIntensity;
  bool showIntensity = true;
  bool allowRandom = false;
  ControlType type = ControlType.shock;
  final Function(ControlsContainer) onSet;

  IntensityDurationSelector(
      {Key? key,
      this.showIntensity = true,
      this.type = ControlType.shock,
      required this.controlsContainer,
      required this.onSet,
      required this.maxDuration,
      required this.maxIntensity,
      this.allowRandom = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => IntensityDurationSelectorState(
      controlsContainer,
      onSet,
      this.maxDuration,
      this.maxIntensity,
      this.showIntensity,
      this.type,
      this.allowRandom);
}

class IntensityDurationSelectorState extends State<IntensityDurationSelector> {
  ControlsContainer controlsContainer;
  int maxDuration;
  int maxIntensity;
  bool showIntensity;
  ControlType type = ControlType.shock;
  bool allowRandom = false;
  Function(ControlsContainer) onSet;

  IntensityDurationSelectorState(
      this.controlsContainer,
      this.onSet,
      this.maxDuration,
      this.maxIntensity,
      this.showIntensity,
      this.type,
      this.allowRandom);

  double cubicToLinear(double value) {
    return pow(value, 6 / 3).toDouble();
  }

  double linearToCubic(double value) {
    return pow(value, 3 / 6).toDouble();
  }

  double reverseMapDuration(double value) {
    if (maxDuration <= 300) return 0;
    return linearToCubic((value - 300) / (maxDuration - 300));
  }

  int mapDuration(double value) {
    return 300 +
        (cubicToLinear(value) * (maxDuration - 300) / 100).toInt() * 100;
  }

  @override
  Widget build(BuildContext context) {
    controlsContainer.limitTo(maxDuration, maxIntensity);
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        if (showIntensity)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10,
            children: [
              OpenShockClient.getIconForControlType(type),
              Text(
                "Intensity: " +
                    controlsContainer.getStringRepresentation(
                        controlsContainer.intensityRange, true),
                style: t.textTheme.headlineSmall,
              ),
            ],
          ),
        if (showIntensity)
          AlarmListManager.getInstance().settings.useRangeSliderForIntensity &&
                  allowRandom
              ? RangeSlider(
                  values: controlsContainer.intensityRange,
                  divisions: maxIntensity,
                  max: maxIntensity.toDouble(),
                  min: 0,
                  onChanged: (RangeValues values) {
                    setState(() {
                      controlsContainer.intensityRange = values;
                    });
                  })
              : Slider(
                  value: controlsContainer.intensityRange.start.toDouble(),
                  max: maxIntensity.toDouble(),
                  onChanged: (double value) {
                    setState(() {
                      controlsContainer.setIntensity(value);
                      onSet(controlsContainer);
                    });
                  }),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            Icon(Icons.timer),
            Text(
              "Duration: ${controlsContainer.getDurationString()}",
              style: t.textTheme.headlineSmall,
            ),
          ],
        ),
        AlarmListManager.getInstance().settings.useRangeSliderForDuration &&
                allowRandom
            ? RangeSlider(
                values: RangeValues(
                    reverseMapDuration(controlsContainer.durationRange.start),
                    reverseMapDuration(controlsContainer.durationRange.end)),
                max: 1,
                min: 0,
                divisions: maxDuration,
                onChanged: (RangeValues values) {
                  setState(() {
                    controlsContainer.durationRange = RangeValues(
                        mapDuration(values.start).toDouble(),
                        mapDuration(values.end).toDouble());
                  });
                })
            : Slider(
                value:
                    reverseMapDuration(controlsContainer.durationRange.start),
                max: 1,
                onChanged: (double value) {
                  setState(() {
                    controlsContainer.setDuration(mapDuration(value));
                    // ToDO: send intensity 1 if not show intensity

                    onSet(controlsContainer);
                  });
                }),
      ],
    );
  }
}

class ShockingControls extends StatefulWidget {
  final AlarmListManager manager;
  ControlsContainer controlsContainer;
  int durationLimit;
  int intensityLimit;
  bool soundAllowed;
  bool vibrateAllowed;
  bool shockAllowed;
  Function(ControlType type, int intensity, int duration) onDelayAction;
  Function(ControlType type, int intensity, int duration) onProcessAction;
  Function(ControlsContainer container) onSet;

  ShockingControls(
      {Key? key,
      required this.manager,
      required this.controlsContainer,
      required this.durationLimit,
      required this.intensityLimit,
      required this.soundAllowed,
      required this.vibrateAllowed,
      required this.shockAllowed,
      required this.onDelayAction,
      required this.onProcessAction,
      required this.onSet})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockingControlsState();
}

class ShockingControlsState extends State<ShockingControls>
    with TickerProviderStateMixin {
  DateTime actionDoneTime = DateTime.now();
  DateTime delayDoneTime = DateTime.now();
  double delayDuration = 0;
  int actionDuration = 0;
  AnimationController? progressCircularController;
  AnimationController? delayVibrationController;
  bool loadingPause = false;

  ShockingControlsState();

  @override
  void dispose() {
    progressCircularController?.dispose();
    delayVibrationController?.dispose();
    super.dispose();
  }

  void realAction(ControlType type) async {
    if (type != ControlType.stop) {
      if (AlarmListManager.getInstance().selectedTone != null) {
        int timeTillNow = 0;
        int timeDiff = 0;
        ControlList controls = PatternGenerator.GenerateFromTone(
            AlarmListManager.getInstance().selectedTone!);

        setState(() {
          actionDuration = controls.duration;
          actionDoneTime =
              DateTime.now().add(Duration(milliseconds: controls.duration));
          progressCircularController = AnimationController(
            vsync: this,
            duration: Duration(milliseconds: controls.duration),
          )..addListener(() {
              setState(() {
                if (progressCircularController!.status ==
                    AnimationStatus.completed) {
                  progressCircularController!.stop();
                  progressCircularController = null;
                }
              });
            });
          progressCircularController!.forward();
        });
        for (var time in controls.controls.keys) {
          timeDiff = time - timeTillNow;
          if (timeDiff > 0)
            await Future.delayed(Duration(milliseconds: timeDiff));
          timeTillNow = time;

          if (progressCircularController == null) break;
          try {
            for (Control control in controls.controls[time]!) {
              widget.onProcessAction(
                  control.type, control.intensity, control.duration);
            }
          } catch (e) {
            print("Error while sending controls: $e");
          }
        }
        return;
      } else {
        setState(() {
          actionDuration = selectedDuration;
          actionDoneTime =
              DateTime.now().add(Duration(milliseconds: selectedDuration));
          progressCircularController = AnimationController(
            vsync: this,
            duration: Duration(milliseconds: selectedDuration),
          )..addListener(() {
              setState(() {
                if (progressCircularController!.status ==
                    AnimationStatus.completed) {
                  progressCircularController!.stop();
                  progressCircularController = null;
                }
              });
            });
          progressCircularController!.forward();
        });
      }
    }
    widget.onProcessAction(type, selectedIntensity, selectedDuration);
  }

  int selectedIntensity = 0;
  int selectedDuration = 0;

  void action(ControlType type) {
    if (type == ControlType.stop) {
      delayVibrationController?.stop();
      progressCircularController?.stop();
      setState(() {
        delayVibrationController = null;
        progressCircularController = null;
      });
      realAction(type);
      return;
    }
    selectedDuration = widget.controlsContainer.getRandomDuration();
    selectedIntensity = widget.controlsContainer.getRandomIntensity();
    // Get random delay based on range
    if (widget.manager.delayVibrationEnabled) {
      // ToDo: make this duration adjustable
      widget.onDelayAction(ControlType.vibrate, selectedIntensity, 500);
    }
    delayDuration = widget.controlsContainer.delayRange.start +
        Random().nextDouble() *
            (widget.controlsContainer.delayRange.end -
                widget.controlsContainer.delayRange.start);
    if (delayDuration == 0) {
      realAction(type);
      return;
    }
    delayDoneTime = DateTime.now()
        .add(Duration(milliseconds: (delayDuration * 1000).toInt()));
    delayVibrationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (delayDuration * 1000).toInt()),
    )..addListener(() {
        setState(() {
          if (delayVibrationController!.status == AnimationStatus.completed) {
            delayVibrationController!.stop();
            delayVibrationController = null;
            realAction(type);
          }
        });
      });
    delayVibrationController!.forward();
  }

  void onToneSelected(int? id) {
    AlarmListManager.getInstance().selectedTone = widget.manager.getTone(id);
  }

  @override
  Widget build(BuildContext context) {
    widget.intensityLimit = widget.intensityLimit;

    List<DropdownMenuEntry<int?>> dme = [
      DropdownMenuEntry(value: null, label: "Custom input")
    ];
    dme.addAll(widget.manager.alarmTones.map((tone) {
      return DropdownMenuEntry(label: tone.name, value: tone.id);
    }));
    if (!widget.manager.settings.allowTonesForControls)
      AlarmListManager.getInstance().selectedTone = null;
    return Column(
      children: [
        if (widget.manager.settings.allowTonesForControls)
          DropdownMenu<int?>(
            dropdownMenuEntries: dme,
            initialSelection: AlarmListManager.getInstance().selectedTone?.id,
            onSelected: (value) {
              setState(() {
                onToneSelected(value);
              });
            },
          ),
        if (AlarmListManager.getInstance().selectedTone == null)
          IntensityDurationSelector(
            controlsContainer: widget.controlsContainer,
            maxDuration: widget.durationLimit,
            maxIntensity: widget.intensityLimit,
            onSet: widget.onSet,
            allowRandom: true,
            key: ValueKey(widget.manager.settings.useRangeSliderForDuration
                    .toString() +
                widget.manager.settings.useRangeSliderForIntensity.toString()),
          ),
        // Delay options
        if (widget.manager.settings.showRandomDelay)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 5,
            children: [
              Switch(
                value: widget.manager.delayVibrationEnabled,
                onChanged: (bool value) {
                  setState(() {
                    widget.manager.delayVibrationEnabled = value;
                  });
                },
              ),
              Expanded(
                  child: widget.manager.settings.useRangeSliderForRandomDelay
                      ? RangeSlider(
                          values: widget.controlsContainer.delayRange,
                          max: 10,
                          min: 0,
                          divisions: 10 * 3,
                          labels: RangeLabels(
                            "${(widget.controlsContainer.delayRange.start * 10).round() / 10} s",
                            "${(widget.controlsContainer.delayRange.end * 10).round() / 10} s",
                          ),
                          onChanged: (RangeValues values) {
                            setState(() {
                              widget.controlsContainer.delayRange = values;
                            });
                          })
                      : Row(
                          children: [
                            Text(
                                "${(widget.controlsContainer.delayRange.start * 10).round() / 10} s"),
                            Expanded(
                              child: Slider(
                                  value:
                                      widget.controlsContainer.delayRange.start,
                                  min: 0,
                                  max: 10,
                                  onChanged: (double value) {
                                    setState(() {
                                      widget.controlsContainer.delayRange =
                                          RangeValues(
                                              value,
                                              widget.controlsContainer
                                                  .delayRange.end);
                                    });
                                  }),
                            )
                          ],
                        )),
              GestureDetector(
                child: Icon(
                  Icons.info,
                ),
                onTap: () {
                  InfoDialog.show("Delay options",
                      "Here you can add a random delay when pressing a button by selecting a range. If you enable the switch before the slider you can send a vibration before the actual action happens.");
                },
              ),
            ],
          ),

        if (progressCircularController == null &&
            delayVibrationController == null)
          AlarmListManager.getInstance().selectedTone == null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    if (widget.soundAllowed)
                      IconButton(
                        icon: OpenShockClient.getIconForControlType(
                            ControlType.sound),
                        onPressed: () {
                          action(ControlType.sound);
                        },
                      ),
                    if (widget.vibrateAllowed)
                      IconButton(
                        icon: OpenShockClient.getIconForControlType(
                            ControlType.vibrate),
                        onPressed: () {
                          action(ControlType.vibrate);
                        },
                      ),
                    if (widget.shockAllowed)
                      IconButton(
                        icon: OpenShockClient.getIconForControlType(
                            ControlType.shock),
                        onPressed: () {
                          action(ControlType.shock);
                        },
                      ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: () {
                        action(ControlType.vibrate);
                      },
                    ),
                  ],
                ),
        if (delayVibrationController != null)
          Row(
            spacing: 10,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  "Delaying action... ${(delayDoneTime.difference(DateTime.now()).inMilliseconds / 100).round() / 10} s"),
              CircularProgressIndicator(
                  value: delayVibrationController == null
                      ? 0
                      : (delayDoneTime
                              .difference(DateTime.now())
                              .inMilliseconds /
                          (delayDuration * 1000))),
            ],
          ),
        if (progressCircularController != null)
          Row(
              spacing: 10,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    "${AlarmListManager.getInstance().selectedTone == null ? "Executing @ $selectedIntensity" : "Playing Tone"}... ${(actionDoneTime.difference(DateTime.now()).inMilliseconds / 100).round() / 10} s"),
                CircularProgressIndicator(
                  value: progressCircularController == null
                      ? 0
                      : 1 -
                          (actionDoneTime
                                  .difference(DateTime.now())
                                  .inMilliseconds /
                              actionDuration),
                )
              ]),
        SizedBox.fromSize(
          size: Size.fromHeight(50),
          child: IconButton(
            onPressed: () {
              action(ControlType.stop);
            },
            icon: Icon(Icons.stop),
          ),
        )
      ],
    );
  }
}
