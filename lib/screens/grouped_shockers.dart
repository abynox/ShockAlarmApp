import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/components/grouped_shocker_selector.dart';
import 'package:shock_alarm_app/components/hub_item.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/screens/logs.dart';
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
          showDialog(
              context: context,
              builder: (context) => AlertDialog(
                    title: Text("Failed to pause shocker"),
                    content: Text(error),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("Ok"))
                    ],
                  ));
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
    ThemeData t = Theme.of(context);
    Shocker limitedShocker = manager.getSelectedShockerLimits();
    
    return PagePadding(
        child: DesktopMobileRefreshIndicator(
            onRefresh: () async {
              await manager.updateShockerStore();
              setState(() {});
            },
            child: Column(
              children: [
                GroupedShockerSelector(onChanged: onRebuild,),
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
                              ElevatedButton(
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
                              )
                          ],
                        ),
                        ShockingControls(
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
                  Text("No shockers selected",
                      style: t.textTheme.headlineMedium)
              ],
            )));
  }
}