import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/delete_dialog.dart';
import 'package:shock_alarm_app/dialogs/yes_cancel_dialog.dart';
import 'package:shock_alarm_app/screens/shockers/live/live_controls.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_details.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/services/PatternGenerator.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/formatter.dart';
import 'package:shock_alarm_app/services/limits.dart';
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
  int? Function(ControlType type, int intensity, int duration, Shocker shocker) onShock;
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
  
  static int runningConfirmNumber = 0;

  ShockerItem({
    Key? key,
    required this.shocker,
    required this.manager,
    required this.onRebuild,
    required this.onShock
  }) : super(key: key);

  static void ensureSafety() {
    runningConfirmNumber++;
  }
  
  @override
  State<StatefulWidget> createState() => ShockerItemState();
}

class ShockerItemState extends State<ShockerItem>
    with TickerProviderStateMixin {
  bool expanded = false;
  bool delayVibrationEnabled = false;

  DateTime actionDoneTime = DateTime.now();
  DateTime delayDoneTime = DateTime.now();
  double delayDuration = 0;
  bool loadingPause = false;

  bool selected() =>
      AlarmListManager.getInstance().selectedShockers.contains(widget.shocker.id);

  bool liveEnabled() =>
      AlarmListManager.getInstance().liveActiveForShockers.contains(widget.shocker.id);

  @override
  void initState() {
    super.initState();
    widget.shocker.controls.limitTo(widget.shocker.durationLimit, widget.shocker.intensityLimit);
  }

  void setPauseState(bool pause) async {
    setState(() {
      loadingPause = true;
    });
    String? error =
        await OpenShockClient().setPauseStateOfShocker(widget.shocker, widget.manager, pause);
    setState(() {
      loadingPause = false;
    });
    if (error != null) {
      ErrorDialog.show("Failed to pause shocker", error);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<ShockerAction> actions = widget.shocker.isOwn
        ? ShockerItem.ownShockerActions
        : ShockerItem.foreignShockerActions;
        return PaddedCard(
        child: Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (widget.shocker.paused) return;
              expanded = !expanded;
            });
            widget.onRebuild();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                  child: Row(
                children: [
                  Checkbox(
                    value: selected(),
                    shape: CircleBorder(),
                    onChanged: (bool? value) {
                      print("Selected shocker ${widget.shocker.name}: $value");
                      if (value == null) return;
                      if (value) {
                        expanded = true;
                        AlarmListManager.getInstance()
                            .selectedShockers
                            .add(widget.shocker.id);
                      } else {
                        expanded = false;
                        AlarmListManager.getInstance()
                            .selectedShockers
                            .remove(widget.shocker.id);
                      }
                      setState(() {});
                      widget.onRebuild();
                    },
                  ),
                  Text(
                    widget.shocker.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )),
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
                                    "${AlarmListManager.getInstance().liveActiveForShockers.contains(widget.shocker.id) ? "Disable" : "Enable"} live controls")
                              ],
                            ))
                      ];
                    },
                    onSelected: (String value) {
                      for (ShockerAction a in actions) {
                        if (a.name == value) {
                          a.onClick(widget.manager, widget.shocker, context, widget.onRebuild);
                          return;
                        }
                      }
                      if (value == "live") {
                        ShockerItem.ensureSafety();
                        setState(() {
                          if (AlarmListManager.getInstance()
                              .liveActiveForShockers
                              .contains(widget.shocker.id)) {
                            AlarmListManager.getInstance()
                                .liveActiveForShockers
                                .remove(widget.shocker.id);
                          } else {
                            AlarmListManager.getInstance()
                                .liveActiveForShockers
                                .add(widget.shocker.id);
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
                  if (widget.shocker.isOwn && widget.shocker.paused && !loadingPause)
                    IconButton(
                        onPressed: () {
                          setPauseState(false);
                        },
                        icon: Icon(Icons.play_arrow)),
                  if (widget.shocker.isOwn && !widget.shocker.paused && !loadingPause)
                    IconButton(
                        onPressed: () {
                          expanded = false;
                          setPauseState(true);
                        },
                        icon: Icon(Icons.pause)),
                  if (widget.shocker.paused)
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
                            widget.shocker.isOwn
                                ? "This shocker was pause by you. While it's paused you cannot control it. You can unpause it by pressing the play button."
                                : "This shocker was paused by the owner. While it's paused you cannot control it. You can ask the owner to unpause it.");
                      },
                    ),
                  if (!widget.shocker.paused)
                    IconButton(
                        onPressed: () {
                          setState(() {
                            expanded = !expanded;
                          });
                          widget.onRebuild();
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
          liveEnabled()
              ? LiveControls(
                  showLatency: false,
                  onSendLive: onSendLive,
                  soundAllowed: widget.shocker.soundAllowed,
                  vibrateAllowed: widget.shocker.vibrateAllowed,
                  shockAllowed: widget.shocker.shockAllowed,
                  intensityLimit: widget.shocker.intensityLimit,
                  saveId: widget.shocker.id,
                  ensureConnection: ensureConnection,
                  hubConnected: AlarmListManager.getInstance()
                      .liveControlGatewayConnections
                      .containsKey(widget.shocker.hubId))
              : ShockingControls(
                  manager: widget.manager,
                  controlsContainer: widget.shocker.controls,
                  key: ValueKey("${widget.shocker.getIdentifier()}-shocking-controls"),
                  durationLimit: AlarmListManager.getInstance().settings.increaseMaxDuration ? widget.shocker.durationLimit : min(widget.shocker.durationLimit, OpenShockLimits.maxRecommendedDuration),
                  intensityLimit: widget.shocker.intensityLimit,
                  shockAllowed: widget.shocker.shockAllowed,
                  showActions: !selected(),
                  vibrateAllowed: widget.shocker.vibrateAllowed,
                  soundAllowed: widget.shocker.soundAllowed,
                  onDelayAction: (type, intensity, duration) {
                    widget.onShock(type, intensity, duration, widget.shocker);
                  },
                  onProcessAction: (type, intensity, duration) {
                    widget.onShock(type, intensity, duration, widget.shocker);
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
        .connectToLiveControlGateway(widget.shocker.hubReference!);
    if (error.error != null) {
      ErrorDialog.show("Failed to connect to hub", error.error!);
      return;
    }
    setState(() {});
  }

  void onSendLive(ControlType type, int intensity) {
    List<Control> controls = [widget.shocker.getLimitedControls(type, intensity, 300)];
    if (type == ControlType.stop) {
      // Temporary workaround until OpenShock fixed the issue with stop. So for now we send them individually
      for (Control c in controls) {
        widget.manager.sendControls([c]);
      }
      return;
    }
    widget.manager.sendLiveControls(controls);
  }
}

class IntensityDurationSelector extends StatefulWidget {
  ControlsContainer controlsContainer;
  int maxDuration;
  int maxIntensity;
  bool showIntensity = true;
  bool showSeperateIntensities = false;
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
      required this.showSeperateIntensities,
      required this.maxIntensity,
      this.allowRandom = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => IntensityDurationSelectorState();
}

class IntensityDurationSelectorState extends State<IntensityDurationSelector> {
  double cubicToLinear(double value) {
    return pow(value, 6 / 3).toDouble();
  }

  double linearToCubic(double value) {
    return pow(value, 3 / 6).toDouble();
  }

  double reverseMapDuration(double value) {
    if (widget.maxDuration <= 300) return 0;
    return linearToCubic((value - 300) / (widget.maxDuration - 300));
  }

  int mapDuration(double value) {
    return 300 +
        (cubicToLinear(value) * (widget.maxDuration - 300) / 100).toInt() * 100;
  }

  @override
  Widget build(BuildContext context) {
    widget.controlsContainer.limitTo(widget.maxDuration, widget.maxIntensity);
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        if (widget.showIntensity) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10,
            children: [
              widget.showSeperateIntensities
                  ? OpenShockClient.getIconForControlType(ControlType.shock)
                  : OpenShockClient.getIconForControlType(widget.type),
              Text(
                "Intensity: ${widget.controlsContainer.getIntensityString()}",
                style: t.textTheme.headlineSmall,
              ),
            ],
          ),
          AlarmListManager.getInstance().settings.useRangeSliderForIntensity &&
                  widget.allowRandom
              ? RangeSlider(
                  values: widget.controlsContainer.intensityRange,
                  divisions: widget.maxIntensity <= 0 ? 1 : widget.maxIntensity,
                  max: widget.maxIntensity.toDouble(),
                  min: 0,
                  onChanged: (RangeValues values) {
                    setState(() {
                      widget.controlsContainer.intensityRange = values;
                    });
                  })
              : Slider(
                  value:
                      widget.controlsContainer.intensityRange.start.toDouble(),
                  max: widget.maxIntensity.toDouble(),
                  onChanged: (double value) {
                    setState(() {
                      widget.controlsContainer.setIntensity(value);
                      widget.onSet(widget.controlsContainer);
                    });
                  }),
          if (widget.showSeperateIntensities) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                OpenShockClient.getIconForControlType(ControlType.vibrate),
                Text(
                  "Intensity: ${widget.controlsContainer.getStringRepresentation(widget.controlsContainer.vibrateIntensityRange, true)}",
                  style: t.textTheme.headlineSmall,
                ),
              ],
            ),
            AlarmListManager.getInstance()
                        .settings
                        .useRangeSliderForIntensity &&
                    widget.allowRandom
                ? RangeSlider(
                    values: widget.controlsContainer.vibrateIntensityRange,
                    divisions: widget.maxIntensity,
                    max: widget.maxIntensity.toDouble(),
                    min: 0,
                    onChanged: (RangeValues values) {
                      setState(() {
                        widget.controlsContainer.vibrateIntensityRange = values;
                      });
                    })
                : Slider(
                    value: widget.controlsContainer.vibrateIntensityRange.start
                        .toDouble(),
                    max: widget.maxIntensity.toDouble(),
                    onChanged: (double value) {
                      setState(() {
                        widget.controlsContainer.setVibrateIntensity(value);
                        widget.onSet(widget.controlsContainer);
                      });
                    }),
          ]
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            Icon(Icons.timer),
            Text(
              "Duration: ${widget.controlsContainer.getDurationString()}",
              style: t.textTheme.headlineSmall,
            ),
          ],
        ),
        AlarmListManager.getInstance().settings.useRangeSliderForDuration &&
                widget.allowRandom
            ? RangeSlider(
                values: RangeValues(
                    reverseMapDuration(
                        widget.controlsContainer.durationRange.start),
                    reverseMapDuration(
                        widget.controlsContainer.durationRange.end)),
                max: 1,
                min: 0,
                divisions: widget.maxDuration,
                onChanged: (RangeValues values) {
                  setState(() {
                    widget.controlsContainer.durationRange = RangeValues(
                        mapDuration(values.start).toDouble(),
                        mapDuration(values.end).toDouble());
                  });
                })
            : Slider(
                value: reverseMapDuration(
                    widget.controlsContainer.durationRange.start),
                max: 1,
                onChanged: (double value) {
                  setState(() {
                    widget.controlsContainer.setDuration(mapDuration(value));
                    // ToDO: send intensity 1 if not show intensity

                    widget.onSet(widget.controlsContainer);
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
  bool showSliders = true;
  bool showActions = true;
  int? Function(ControlType type, int intensity, int duration) onDelayAction;
  int? Function(ControlType type, int intensity, int duration) onProcessAction;
  int? Function(ControlsContainer container) onSet;

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
      required this.onSet,
      this.showSliders = true,
      this.showActions = true})
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
  AnimationController? delayVibrationController;
  bool loadingPause = false;
  ShockCountdownIndicatorController? countdownIndicatorController;

  ShockingControlsState();

  @override
  void dispose() {
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
          
        });
        countdownIndicatorController?.start(
            selectedIntensity, controls.duration, actionDoneTime);
        for (var time in controls.controls.keys) {
          timeDiff = time - timeTillNow;
          if (timeDiff > 0)
            await Future.delayed(Duration(milliseconds: timeDiff));
          timeTillNow = time;

          if (countdownIndicatorController?.stopped() ?? false) break;
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
        int? durationByHandler = widget.onProcessAction(type, selectedIntensity, selectedDuration);
        setState(() {
          actionDuration = durationByHandler ?? selectedDuration;
          actionDoneTime =
            DateTime.now().add(Duration(milliseconds: durationByHandler ?? selectedDuration));
          countdownIndicatorController?.start(selectedIntensity, durationByHandler ?? selectedDuration, actionDoneTime);
        });
      }
    } else {
      widget.onProcessAction(type, 1, 300);
      setState(() {
        actionDoneTime = DateTime.now();
        countdownIndicatorController?.reset();
      });
    }
    
  }

  int selectedIntensity = 0;
  int selectedDuration = 0;
  bool needConfirm = true;


  void action(ControlType type, {bool recalculateIntensityAndDuration = true}) {
    // Get intensity
    // do not adjust selected intensity and duration if recalculate is false as then the user confirmed the (sometimes randomly) determined shock values
    if(recalculateIntensityAndDuration) {
      selectedDuration = widget.controlsContainer.getRandomDuration();
      selectedIntensity =
          AlarmListManager.getInstance().settings.useSeperateSliders &&
                  type == ControlType.vibrate
              ? widget.controlsContainer.getRandomVibrateIntensity()
              : widget.controlsContainer.getRandomIntensity();

    }

    bool isRange = false;
    
    // If the sliders aren't shown we are (as of time of writing) in the og shockers view. It doesn't report anything back to this widget.
    // Therefore we have to extract the highest intensity and duration ourselves.
    // It's pain but works
    // Ideally all components would be rewritten so they can communicate with the confirm widget and don't do random stuff in them but let this widget handle it.
    // This component was never designed for multiple seperate output parameters tho, hence choosing the highest instead of just showing what's gonna happen 
    if(!widget.showSliders) {
      isRange = AlarmListManager.getInstance().settings.useRangeSliderForDuration || AlarmListManager.getInstance().settings.useRangeSliderForIntensity;
      selectedIntensity = 0;
      // In this case the intensity is coming from somewhere else and must thus be read from somewhere else
      for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
        int shockerIntensity = s.controls.intensityRange.end.toInt();
        if(shockerIntensity > selectedIntensity) selectedIntensity = shockerIntensity;
        int shockerDuration = s.controls.durationRange.end.toInt();
        if(shockerDuration > selectedDuration) selectedDuration = shockerDuration;
      }
    }

    // If the hard limit is on we do not need to show the dialog. redundancy is the limit function of the Controls themselves
    if(!AlarmListManager.getInstance().settings.enforceHardLimitInsteadOfShock && type == ControlType.shock
      && AlarmListManager.getInstance().settings.confirmShock
      && (selectedIntensity >= AlarmListManager.getInstance().settings.confirmShockMinIntensity || selectedDuration >= AlarmListManager.getInstance().settings.confirmShockMinDuration)) {
      if(needConfirm) {
        //
        YesCancelDialog.show("Shock Confirmation", "Are you sure you want to shock for${isRange ? " up to" : ""} ${selectedIntensity}@${Formatter.formatMillisToSeconds(selectedDuration)} s", () {
          needConfirm = false;
          action(type, recalculateIntensityAndDuration: false);
          Navigator.of(context).pop();
        });
        return;
      } else {
        needConfirm = true;
      }
    }
    if (type == ControlType.stop) {
      delayVibrationController?.stop();
      countdownIndicatorController?.reset();
      setState(() {
        delayVibrationController = null;
      });
      realAction(type);
      return;
    }
    // Get random delay based on range
    if (widget.manager.delayVibrationEnabled) {
      // ToDo: make this duration adjustable
      int vibrationIntensity = selectedIntensity;
      // Make sure to use the intensity from the vibrate slider if it's enabled
      if(type != ControlType.vibrate && AlarmListManager.getInstance().settings.useSeperateSliders) {
        vibrationIntensity = widget.controlsContainer.getRandomVibrateIntensity();
      }

      widget.onDelayAction(ControlType.vibrate, vibrationIntensity, 500);
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
  void initState() {
    countdownIndicatorController = ShockCountdownIndicatorController();
    super.initState();
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
        if (widget.manager.settings.allowTonesForControls && widget.showSliders) ...[
          DropdownMenu<int?>(
            dropdownMenuEntries: dme,
            initialSelection: AlarmListManager.getInstance().selectedTone?.id,
            onSelected: (value) {
              setState(() {
                onToneSelected(value);
              });
            },
          ),
          PredefinedSpacing(padding: PredefinedSpacing.paddingExtraSmall())
        ],
        if (widget.showSliders &&
            AlarmListManager.getInstance().selectedTone == null)
          IntensityDurationSelector(
            controlsContainer: widget.controlsContainer,
            maxDuration: widget.durationLimit,
            maxIntensity: widget.intensityLimit,
            onSet: widget.onSet,
            showSeperateIntensities:
                AlarmListManager.getInstance().settings.useSeperateSliders,
            allowRandom: true,
            key: ValueKey(widget.manager.settings.useRangeSliderForDuration
                    .toString() +
                widget.manager.settings.useRangeSliderForIntensity.toString()),
          ),
        // Delay options
        if (widget.manager.settings.showRandomDelay && widget.showActions)
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

        if (countdownIndicatorController?.stopped() ?? true &&
            delayVibrationController == null &&
            widget.showActions)
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
                        icon: OpenShockClient.getIconForControlType(ControlType.shock),
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
                  "Delaying action... ${Formatter.formatMillisToSeconds(delayDoneTime.difference(DateTime.now()).inMilliseconds)} s"),
              CircularProgressIndicator(
                  value: delayVibrationController == null
                      ? 0
                      : (delayDoneTime
                              .difference(DateTime.now())
                              .inMilliseconds /
                          (delayDuration * 1000))),
            ],
          ),
        ShockCountdownIndicator(controller: countdownIndicatorController!, onDone: () => setState(() {}),),
        if(widget.showActions) SizedBox.fromSize(
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

class ShockCountdownIndicatorController {
  Function()? onResetReceived;
  Function()? onStartReceived;
  Function()? getIsStopped;

  bool playingTone = false;
  int intensity = 0;
  DateTime actionDoneTime = DateTime.now();
  int duration = 0;

  void reset() {
    onResetReceived?.call();
  }

  void start(int intensity, int duration, DateTime actionDoneTime) {
    this.duration = duration;
    this.intensity = intensity;
    this.actionDoneTime = actionDoneTime;
    onStartReceived?.call();
  }

  bool stopped() {
    return getIsStopped?.call() ?? true;
  }
}

class ShockCountdownIndicator extends StatefulWidget {
  ShockCountdownIndicatorController controller;
  Function() onDone;
  

  ShockCountdownIndicator(
      {Key? key,
      required this.controller,
      required this.onDone})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockCountdownIndicatorState();
}

class ShockCountdownIndicatorState extends State<ShockCountdownIndicator> 
    with TickerProviderStateMixin {
  AnimationController? progressCircularController;

  @override void initState() {
    widget.controller.onResetReceived = () {
      if(!mounted) return;
      setState(() {
        progressCircularController?.stop();
        progressCircularController = null;
      });
    };
    widget.controller.onStartReceived = () {
      if(!mounted) return;
      progressCircularController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.controller.duration),
      )..addListener(() {
          setState(() {
            if (progressCircularController!.status ==
                AnimationStatus.completed) {
              widget.onDone();
              progressCircularController!.stop();
              progressCircularController = null;
            }
          });
        });
      setState(() {
        progressCircularController!.forward();
      });
    };
    widget.controller.getIsStopped = () {
      if(!mounted) return true;
      return progressCircularController == null;
    };
    super.initState();
  }

  @override
  void dispose() {
    progressCircularController?.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    if(progressCircularController == null) {
      return SizedBox.shrink();
    }
    return Row(
              spacing: 10,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    "${!widget.controller.playingTone ? "Executing @ ${widget.controller.intensity}" : "Playing Tone"}... ${(widget.controller.actionDoneTime.difference(DateTime.now()).inMilliseconds / 100).round() / 10} s"),
                CircularProgressIndicator(
                  value: progressCircularController == null
                      ? 0
                      : 1 -
                          (widget.controller.actionDoneTime
                                  .difference(DateTime.now())
                                  .inMilliseconds /
                              widget.controller.duration),
                )
              ]);
  }
}