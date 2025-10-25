import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/dialogs/yes_cancel_dialog.dart';
import 'package:shock_alarm_app/screens/shockers/grouped/grouped_shocker_selector.dart';
import 'package:shock_alarm_app/screens/shockers/live/live_controls.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/screens/logs/logs.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/limits.dart';
import 'package:shock_alarm_app/services/openshockws.dart';
import 'package:shock_alarm_app/services/vibrations.dart';

import '../../../services/alarm_list_manager.dart';
import '../../../services/openshock.dart';
import '../shocking_controls.dart';

class GroupedShockerScreen extends StatefulWidget {
  final AlarmListManager manager;

  int confirmedNumber = -1;
  bool dialogShowing = false;

  GroupedShockerScreen({Key? key, required this.manager})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _GroupedShockerScreenState();
}

class _GroupedShockerScreenState extends State<GroupedShockerScreen> {
  LiveControlSettings liveControlSettings = LiveControlSettings();

  bool liveEnabled = false;

  @override
  void initState() {
    super.initState();
    if (!AlarmListManager.supportsWs())
      AlarmListManager.getInstance().updateHubStatusViaHttp();
  }

  void onRebuild() {
    setState(() {});
  }

  int? executeAll(ControlType type, int intensity, int duration) {
    ShockAlarmVibrations.onAction(type);
    List<Control> controls = [];
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      controls.add(s.getLimitedControls(type, intensity, duration));
    }
    AlarmListManager.getInstance().sendControls(controls);
    return duration;
  }

  void executeAllLive(ControlType type, int intensity) {
    // Enforce the limit of the confirm ui 
    // If the hard limit is on we do not need to show the dialog. redundancy is the limit function of the Controls themselves
    
    // The cofirm limits check is now performed in the call to this method so it applies to everything that uses the live controls ui instead of just this view
    List<Control> controls = [];
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      controls.add(s.getLimitedControls(type, intensity, 300));
    }
    AlarmListManager.getInstance().sendLiveControls(controls);
  }

  liveEventDone(ControlType type, int durationInMs, int maxIntensity) {
    List<Control> controls = [];
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      controls.add(
          s.getLimitedControls(ControlType.stop, maxIntensity, durationInMs)..duration = min(durationInMs, OpenShockLimits.maxDuration));
    }
    // we create a log entry for transparency with the other user
    if (AlarmListManager.getInstance().settings.liveControlsLogWorkaround) {
      AlarmListManager.getInstance().sendControls(controls,
          customName: "{live}{${LiveControlWS.getControl(type)}}");
    }
  }

  bool loadingPause = false;
  bool loadingResume = false;

  void pauseAll(bool pause) async {
    setState(() {
      if (pause) {
        loadingPause = true;
      } else {
        loadingResume = true;
      }
    });
    ShockAlarmVibrations.pause(pause);

    int shockerCount = 0;
    int completedShockers = 0;
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      if (!s.isOwn) continue;
      shockerCount++;
      OpenShockClient().setPauseStateOfShocker(s, AlarmListManager.getInstance(), pause).then((error) {
        completedShockers++;
        if (error != null) {
          ErrorDialog.show("Failed to pause shocker", error);
          return;
        }
      });
    }

    int i = 0;
    // wait until all shockers are paused
    while (completedShockers < shockerCount) {
      await Future.delayed(Duration(milliseconds: 20));
      i++;
      if (i > 1000) {
        break;
      }
    }
    setState(() {
      if (pause) {
        loadingPause = false;
      } else {
        loadingResume = false;
      }
    });
  }

  bool canPause() {
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      if (s.isOwn && !s.paused) {
        return true;
      }
    }
    return false;
  }

  bool canViewLogs() {
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      if (s.isOwn) {
        return true;
      }
    }
    return false;
  }

  bool canResume() {
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      if (s.isOwn && s.paused) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    AlarmListManager.getInstance().reloadAllMethod = () {
      if(!mounted) return;
      setState(() {});
    };
    ThemeData t = Theme.of(context);
    bool isOwnShocker = canResume() || canPause();
    List<ShockerAction> actions = isOwnShocker
        ? ShockerItem.ownShockerActions
        : ShockerItem.foreignShockerActions;
    Shocker limitedShocker = AlarmListManager.getInstance().getSelectedShockerLimits();

    return DesktopMobileRefreshIndicator(
        onRefresh: () async {
          await AlarmListManager.getInstance().updateShockerStore();
          setState(() {});
        },
        child: Flex(
          direction: Axis.vertical,
          children: [
            GroupedShockerSelector(onChanged: onRebuild, onlyLive: liveEnabled),
            if (AlarmListManager.getInstance().selectedShockers.isNotEmpty)
              ConstrainedContainer(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (loadingPause) CircularProgressIndicator(),
                        if (!loadingPause && canPause())
                          IconButton(
                              onPressed: () {
                                pauseAll(true);
                              },
                              icon: Icon(Icons.pause)),
                        if (loadingResume) CircularProgressIndicator(),
                        if (!loadingResume && canResume())
                          IconButton(
                              onPressed: () {
                                pauseAll(false);
                              },
                              icon: Icon(Icons.play_arrow)),
                        if (canViewLogs())
                          FilledButton(
                            onPressed: () {
                              List<Shocker> shockers = [];
                              for (String shockerId
                                  in AlarmListManager.getInstance().selectedShockers) {
                                Shocker s = AlarmListManager.getInstance().shockers
                                    .firstWhere((x) => x.id == shockerId);
                                if (!s.isOwn) continue;
                                shockers.add(s);
                              }
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => LogScreen(
                                          shockers: shockers,
                                          manager: AlarmListManager.getInstance())));
                            },
                            child: Text("View logs"),
                          ),
                        PopupMenuButton<String>(
                          iconColor: t.colorScheme.onSurfaceVariant,
                          itemBuilder: (context) {
                            return [
                              for (ShockerAction a in actions)
                                if (AlarmListManager.getInstance().selectedShockers.length == 1 || a.allowMultipleShockers) PopupMenuItem(
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
                                          "${liveEnabled ? "Disable" : "Enable"} live controls")
                                    ],
                                  )),
                            ];
                          },
                          onSelected: (String value) {
                            List<Shocker> shockers = [];
                            for(String id in AlarmListManager.getInstance().selectedShockers) {
                              shockers.add(AlarmListManager.getInstance().shockers.firstWhere(
                                (x) => x.id == id));
                            }
                            for (ShockerAction a in actions) {
                              if (a.name == value) {
                                a.onClick(AlarmListManager.getInstance(), shockers, context, onRebuild);
                                return;
                              }
                            }
                            if (value == "live") {
                              context
                                  .findAncestorStateOfType<
                                      ScreenSelectorScreenState>()
                                  ?.setPageSwipeEnabled(liveEnabled);
                              setState(() {
                                ShockerItem.ensureSafety();
                                liveEnabled = !liveEnabled;
                                if (!liveEnabled) {
                                  AlarmListManager.getInstance().disconnectAllFromLiveControlGateway();
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    liveEnabled
                        ? LiveControls(
                            ensureConnection: () async {
                              ErrorContainer<
                                  bool> error = await AlarmListManager
                                      .getInstance()
                                  .connectToLiveControlGatewayOfSelectedShockers();
                              if (error.error != null) {
                                ErrorDialog.show(
                                    "Error connecting to hubs", error.error!);
                              }
                              setState(() {
                                
                              });
                            },
                            hubConnected: AlarmListManager.getInstance().areSelectedShockersConnected(),
                            onSendLive: executeAllLive,
                            soundAllowed: limitedShocker.soundAllowed,
                            vibrateAllowed: limitedShocker.vibrateAllowed,
                            shockAllowed: limitedShocker.shockAllowed,
                            intensityLimit: limitedShocker.intensityLimit,
                            liveEventDone: liveEventDone,
                            showLatency: true,
                          )
                        : ShockingControls(
                            manager: AlarmListManager.getInstance(),
                            controlsContainer: AlarmListManager.getInstance().controls,
                            durationLimit: limitedShocker.durationLimit,
                            intensityLimit: limitedShocker.intensityLimit,
                            soundAllowed: limitedShocker.soundAllowed,
                            vibrateAllowed: limitedShocker.vibrateAllowed,
                            shockAllowed: limitedShocker.shockAllowed,
                            onDelayAction: executeAll,
                            onProcessAction: executeAll,
                            onSet: (container) {},
                            key: ValueKey(
                                DateTime.now().millisecondsSinceEpoch)),
                  ],
                ),
              )
            else
              Text("No shockers selected", style: t.textTheme.headlineMedium)
          ],
        ));
  }
}
