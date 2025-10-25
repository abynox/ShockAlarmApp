import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/haptic_switch.dart';
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
import 'package:shock_alarm_app/screens/shockers/shocking_controls.dart';
import 'package:shock_alarm_app/screens/user_shares/create_user_share_dialog.dart';
import 'package:shock_alarm_app/services/PatternGenerator.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/formatter.dart';
import 'package:shock_alarm_app/services/limits.dart';
import 'package:shock_alarm_app/services/openshockws.dart';
import 'package:shock_alarm_app/services/vibrations.dart';
import '../logs/logs.dart';
import '../shares/shares.dart';
import '../../stores/alarm_store.dart';
import '../../services/alarm_list_manager.dart';
import '../../services/openshock.dart';

class ShockerAction {
  String name;
  Function(AlarmListManager, List<Shocker>, BuildContext, Function) onClick;
  Icon icon;
  bool allowMultipleShockers = false;

  ShockerAction(
      {this.name = "Action", this.allowMultipleShockers = false, required this.onClick, required this.icon});
}

class ShockerItem extends StatefulWidget {
  LiveControlSettings liveControlSettings = LiveControlSettings();
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;
  int? Function(ControlType type, int intensity, int duration, Shocker shocker)
      onShock;
  static List<ShockerAction> ownShockerActions = [
    ShockerAction(
        name: "Edit",
        icon: Icon(Icons.edit),
        onClick: (AlarmListManager manager, List<Shocker> shocker,
            BuildContext context, Function onRebuild) async {
          LoadingDialog.show("Loading details");
          List<OpenShockDevice> devices = await manager.getDevices();
          OpenShockShocker? s =
              await OpenShockClient().getShockerDetails(shocker[0]);
          Navigator.of(context).pop();
          if (s == null) {
            ErrorDialog.show("Failed to get shocker details",
                "Failed to get shocker details");
            return;
          }
          TextEditingController controller = TextEditingController();
          controller.text = shocker[0].name;
          showDialog(
              context: context,
              builder: (context) => AlertDialog.adaptive(
                    title: Text("Edit shocker"),
                    content: ShockerDetails(
                      shocker: s,
                      devices: devices,
                      apiTokenId: shocker[0].apiTokenId,
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
                                await manager.editShocker(shocker[0], s);
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
        allowMultipleShockers: true,
        onClick: (AlarmListManager manager, List<Shocker> shocker,
            BuildContext context, Function onRebuild) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      LogScreen(shockers: shocker, manager: manager)));
        }),
    ShockerAction(name: "Create Share", icon: Icon(Icons.share), allowMultipleShockers: true, onClick: (AlarmListManager manager, List<Shocker> shockers,
            BuildContext context, Function onRebuild) {
          showDialog(context: context, builder: (context) => CreateUserShareDialog(shockersToShare: shockers));
        }),
    ShockerAction(
        name: "Edit Shares",
        icon: Icon(Icons.key),
        onClick: (AlarmListManager manager, List<Shocker> shocker,
            BuildContext context, Function onRebuild) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      SharesScreen(shocker: shocker[0], manager: manager)));
        }),
    ShockerAction(
        name: "Delete",
        icon: Icon(Icons.delete),
        onClick: (AlarmListManager manager, List<Shocker> shocker,
            BuildContext context, Function onRebuild) {
          showDialog(
              context: context,
              builder: (context) => DeleteDialog(
                  onDelete: () async {
                    LoadingDialog.show("Deleting shocker");
                    String? errorMessage = await manager.deleteShocker(shocker[0]);
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
                      "Are you sure you want to delete the shocker ${shocker[0].name}?\n\n(You can add it again later. However shares will be lost until you manually recreate them all)"));
        }),
  ];

  static List<ShockerAction> foreignShockerActions = [
    ShockerAction(
      allowMultipleShockers: true,
        onClick: (AlarmListManager manager, List<Shocker> shockers,
            BuildContext context, Function onRebuild) {
              for(Shocker shocker in shockers) {
                showDialog(
              context: context,
              builder: (context) => AlertDialog.adaptive(
                    title: Text("Unlink shocker '${shocker.name}'"),
                    content: Text(
                        "Are you sure you want to unlink the shocker '${shocker.name}' from your account? After that you cannot control the shocker anymore unless you redeem another share code."),
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
              }
        },
        icon: Icon(Icons.delete),
        name: "Unlink"),
  ];

  static int runningConfirmNumber = 0;

  ShockerItem(
      {Key? key,
      required this.shocker,
      required this.manager,
      required this.onRebuild,
      required this.onShock})
      : super(key: key);

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

  bool selected() => AlarmListManager.getInstance()
      .selectedShockers
      .contains(widget.shocker.id);

  bool liveEnabled() => AlarmListManager.getInstance()
      .liveActiveForShockers
      .contains(widget.shocker.id);

  @override
  void initState() {
    super.initState();
    widget.shocker.controls
        .limitTo(widget.shocker.durationLimit, widget.shocker.intensityLimit);
  }

  void setPauseState(bool pause) async {
    setState(() {
      loadingPause = true;
      if (pause) {
        AlarmListManager.getInstance()
            .selectedShockers
            .remove(widget.shocker.id);
      }
    });
    ShockAlarmVibrations.pause(pause);
    String? error = await OpenShockClient()
        .setPauseStateOfShocker(widget.shocker, widget.manager, pause);
    if (!mounted) return;
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
                        if (widget.shocker.paused) return;
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
                          a.onClick(widget.manager, [widget.shocker], context,
                              widget.onRebuild);
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
                                .selectedShockers
                                .remove(widget.shocker.id);
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
                  if (widget.shocker.isOwn &&
                      widget.shocker.paused &&
                      !loadingPause)
                    IconButton(
                        onPressed: () {
                          setPauseState(false);
                        },
                        icon: Icon(Icons.play_arrow)),
                  if (widget.shocker.isOwn &&
                      !widget.shocker.paused &&
                      !loadingPause)
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
          !liveEnabled()
              ? ShockingControls(
                  manager: widget.manager,
                  controlsContainer: widget.shocker.controls,
                  key: ValueKey(
                      "${widget.shocker.getIdentifier()}-shocking-controls"),
                  durationLimit: AlarmListManager.getInstance()
                          .settings
                          .increaseMaxDuration
                      ? widget.shocker.durationLimit
                      : min(widget.shocker.durationLimit,
                          OpenShockLimits.maxRecommendedDuration),
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
              : LiveControls(
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
    List<Control> controls = [
      widget.shocker.getLimitedControls(type, intensity, 300)
    ];
    widget.manager.sendLiveControls(controls);
  }
}
