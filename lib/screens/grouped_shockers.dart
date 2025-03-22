import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/components/grouped_shocker_selector.dart';
import 'package:shock_alarm_app/components/hub_item.dart';
import 'package:shock_alarm_app/components/live_controls.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:shock_alarm_app/dialogs/ErrorDialog.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/screens/logs.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshockws.dart';
import 'package:sticky_headers/sticky_headers.dart';

import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class GroupedShockerScreen extends StatefulWidget {
  final AlarmListManager manager;
  const GroupedShockerScreen({Key? key, required this.manager})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupedShockerScreenState(manager);
}

class GroupedShockerScreenState extends State<GroupedShockerScreen> {
  AlarmListManager manager;

  GroupedShockerScreenState(this.manager);
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

  void executeAll(ControlType type, int intensity, int duration) {
    List<Control> controls = [];
    for (Shocker s in manager.getSelectedShockers()) {
      controls.add(s.getLimitedControls(type, intensity, duration));
    }
    if (type == ControlType.stop) {
      // Temporary workaround until OpenShock fixed the issue with stop. So for now we send them individually
      for (Control c in controls) {
        manager.sendControls([c]);
      }
      return;
    }
    manager.sendControls(controls);
  }

  void executeAllLive(ControlType type, int intensity) {
    List<Control> controls = [];
    for (Shocker s in manager.getSelectedShockers()) {
      controls.add(s.getLimitedControls(type, intensity, 300));
    }
    if (type == ControlType.stop) {
      // Temporary workaround until OpenShock fixed the issue with stop. So for now we send them individually
      for (Control c in controls) {
        manager.sendControls([c]);
      }
      return;
    }
    manager.sendLiveControls(controls);
  }

  liveEventDone(ControlType type, int durationInMs, int maxIntensity) {
    List<Control> controls = [];
    for (Shocker s in manager.getSelectedShockers()) {
      controls.add(
          s.getLimitedControls(ControlType.stop, maxIntensity, durationInMs)..duration = max(durationInMs, 30000));
    }
    // we create a log entry for transparency with the other user
    if (manager.settings.liveControlsLogWorkaround)
      manager.sendControls(controls,
          customName: "{live}{${LiveControlWS.getControl(type)}}");
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

    int shockerCount = 0;
    int completedShockers = 0;
    for (Shocker s in manager.getSelectedShockers()) {
      if (!s.isOwn) continue;
      shockerCount++;
      OpenShockClient().setPauseStateOfShocker(s, manager, pause).then((error) {
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
    for (Shocker s in manager.getSelectedShockers()) {
      if (s.isOwn && !s.paused) {
        return true;
      }
    }
    return false;
  }

  bool canViewLogs() {
    for (Shocker s in manager.getSelectedShockers()) {
      if (s.isOwn) {
        return true;
      }
    }
    return false;
  }

  bool canResume() {
    for (Shocker s in manager.getSelectedShockers()) {
      if (s.isOwn && s.paused) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    AlarmListManager.getInstance().reloadAllMethod = () {
      setState(() {});
    };
    ThemeData t = Theme.of(context);
    bool isOwnShocker = canResume() || canPause();
    List<ShockerAction> actions = isOwnShocker
        ? ShockerItem.ownShockerActions
        : ShockerItem.foreignShockerActions;
    Shocker limitedShocker = manager.getSelectedShockerLimits();

    return DesktopMobileRefreshIndicator(
        onRefresh: () async {
          await manager.updateShockerStore();
          setState(() {});
        },
        child: Flex(
          direction: Axis.vertical,
          children: [
            GroupedShockerSelector(onChanged: onRebuild, onlyLive: liveEnabled),
            if (manager.selectedShockers.length > 0)
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
                                  in manager.selectedShockers) {
                                Shocker s = manager.shockers
                                    .firstWhere((x) => x.id == shockerId);
                                if (!s.isOwn) continue;
                                shockers.add(s);
                              }
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => LogScreen(
                                          shockers: shockers,
                                          manager: manager)));
                            },
                            child: Text("View logs"),
                          ),
                        PopupMenuButton<String>(
                          iconColor: t.colorScheme.onSurfaceVariant,
                          itemBuilder: (context) {
                            return [
                              if (manager.selectedShockers.length == 1)
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
                                          "${liveEnabled ? "Disable" : "Enable"} live controls (beta)")
                                    ],
                                  )),
                            ];
                          },
                          onSelected: (String value) {
                            Shocker shocker = manager.shockers.firstWhere(
                                (x) => x.id == manager.selectedShockers[0]);
                            for (ShockerAction a in actions) {
                              if (a.name == value) {
                                a.onClick(manager, shocker, context, onRebuild);
                                return;
                              }
                            }
                            if (value == "live") {
                              context
                                  .findAncestorStateOfType<
                                      ScreenSelectorState>()
                                  ?.setPageSwipeEnabled(liveEnabled);
                              setState(() {
                                liveEnabled = !liveEnabled;
                                if (!liveEnabled) {
                                  manager.disconnectAllFromLiveControlGateway();
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
                          )
                        : ShockingControls(
                            manager: manager,
                            controlsContainer: manager.controls,
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
