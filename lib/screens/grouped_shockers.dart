import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/hub_item.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:shock_alarm_app/screens/logs.dart';

import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class GroupedShockerScreen extends StatefulWidget {
  
  final AlarmListManager manager;
  const GroupedShockerScreen({Key? key, required this.manager}) : super(key: key);


  @override
  State<StatefulWidget> createState() => GroupedShockerScreenState(manager);
}

class GroupedShockerScreenState extends State<GroupedShockerScreen> {
  AlarmListManager manager;
  final ControlsContainer controls = ControlsContainer();

  GroupedShockerScreenState(this.manager);

  void onRebuild() {
    setState(() {});
  }

  Shocker getShockerLimits() {
    Shocker limitedShocker = Shocker();
    limitedShocker.durationLimit = 300;
    limitedShocker.intensityLimit = 0;
    limitedShocker.shockAllowed = false;
    limitedShocker.soundAllowed = false;
    limitedShocker.vibrateAllowed = false;
    for(Shocker s in manager.shockers.where((x) {
      return manager.selectedShockers.contains(x.id);
    })) {
      if(s.durationLimit > limitedShocker.durationLimit) {
        limitedShocker.durationLimit = s.durationLimit;
      }
      if(s.intensityLimit > limitedShocker.intensityLimit) {
        limitedShocker.intensityLimit = s.intensityLimit;
      }
      if(s.shockAllowed) {
        limitedShocker.shockAllowed = true;
      }
      if(s.soundAllowed) {
        limitedShocker.soundAllowed = true;
      }
      if(s.vibrateAllowed) {
        limitedShocker.vibrateAllowed = true;
      }
    }
    return limitedShocker;
  }

  Iterable<Shocker> getSelectedShockers() {
    return manager.shockers.where((x) {
      return manager.selectedShockers.contains(x.id);
    });
  }

  void executeAll(ControlType type, int intensity, int duration) {
    List<Control> controls = [];
    for(Shocker s in getSelectedShockers()) {
      controls.add(s.getLimitedControls(type, intensity, duration));
    }
    manager.sendControls(controls);
  }

  bool loadingPause = false;
  bool loadingResume = false;

  void pauseAll(bool pause) async {
    setState(() {
      if(pause) {
        loadingPause = true;
      } else {
        loadingResume = true;
      }
    });

    int shockerCount = 0;
    int completedShockers = 0;
    for(Shocker s in getSelectedShockers()) {
      if(!s.isOwn) continue;
      shockerCount++;
      OpenShockClient().setPauseStateOfShocker(s, manager, pause).then((error) {
        completedShockers++;
        if(error != null) {
          showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to pause shocker"), content: Text(error), actions: [TextButton(onPressed: () {
            Navigator.of(context).pop();
          }, child: Text("Ok"))],));
          return;
        }
      });
    }

    int i = 0;
    // wait until all shockers are paused
    while(completedShockers < shockerCount) {
      await Future.delayed(Duration(milliseconds: 20));
      i++;
      if(i > 1000) {
        break;
      }
    }
    setState(() {
      if(pause) {
        loadingPause = false;
      } else {
        loadingResume = false;
      }
    });
  }

  bool canPause() {
    for(Shocker s in getSelectedShockers()) {
      if(s.isOwn && !s.paused) {
        return true;
      }
    }
    return false;
  }

  bool canViewLogs() {
    for(Shocker s in getSelectedShockers()) {
      if(s.isOwn) {
        return true;
      }
    }
    return false;
  }

  bool canResume() {
    for(Shocker s in getSelectedShockers()) {
      if(s.isOwn && s.paused) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    Shocker limitedShocker = getShockerLimits();
    List<Shocker> filteredShockers = manager.shockers.where((shocker) {
      return (manager.enabledHubs[shocker.hubReference?.id] ?? false) || true || (manager.settings.disableHubFiltering);
    }).toList();
    Map<Hub?, List<Shocker>> groupedShockers = {};
    for(Shocker shocker in filteredShockers) {
      if(!groupedShockers.containsKey(shocker.hubReference)) {
        groupedShockers[shocker.hubReference] = [];
      }
      groupedShockers[shocker.hubReference]!.add(shocker);
    }
    // now add all missing hubs
    for(Hub hub in manager.hubs) {
      if(!manager.settings.disableHubFiltering && manager.enabledHubs[hub.id] == false) {
        continue;
      }
      if(!groupedShockers.containsKey(hub)) {
        groupedShockers[hub] = [];
      }
    }
    return Column(
      children: [
        Flexible(
          child: ListView(children: [
            for (MapEntry<Hub?, List<Shocker>> hubContainer in groupedShockers.entries)
              Column(children: [
                HubItem(hub: hubContainer.key!, manager: manager, onRebuild: onRebuild, key: ValueKey(hubContainer.key?.getIdentifier(manager)),),
                Wrap(spacing: 5,children: [
                  for (Shocker s in hubContainer.value)
                    ShockerChip(shocker: s, manager: manager, onSelected: (bool b) {
                      setState(() {
                        if(b) {
                          manager.selectedShockers.add(s.id);
                        } else {
                          manager.selectedShockers.remove(s.id);
                        }
                      });
                    }, key: ValueKey(s.getIdentifier()),)
                ],)
              ],
            )
          ],
        ),
        ),
        if(manager.selectedShockers.length > 0)
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (loadingPause)
                    CircularProgressIndicator(),
                  if (!loadingPause && canPause())
                    ElevatedButton(onPressed: () {
                      pauseAll(true);
                    }, child: Text("Pause selected"),),
                  if(loadingResume)
                    CircularProgressIndicator(),
                  if(!loadingResume && canResume())
                  ElevatedButton(onPressed: () {
                    pauseAll(false);
                  }, child: Text("Resume selected"),),

                  if(canViewLogs())
                    ElevatedButton(onPressed: () {
                      List<Shocker> shockers = [];
                      for(String shockerId in manager.selectedShockers) {
                        Shocker s = manager.shockers.firstWhere((x) => x.id == shockerId);
                        if(!s.isOwn) continue;
                        shockers.add(s);
                      }
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LogScreen(shockers: shockers, manager: manager)));
                    }, child: Text("View logs"),)
                ],
              ),
              ShockingControls(manager: manager,
                controlsContainer: this.controls,
                durationLimit: limitedShocker.durationLimit, intensityLimit: limitedShocker.intensityLimit,
                soundAllowed: limitedShocker.soundAllowed, vibrateAllowed: limitedShocker.vibrateAllowed, shockAllowed: limitedShocker.shockAllowed,
                onDelayAction: executeAll, onProcessAction: executeAll,
                onSet: (intensity, duration) {
                  },
                key: ValueKey(DateTime.now().millisecondsSinceEpoch)
              ),
            ],
          )
        else
          Text("No shockers selected", style: t.textTheme.headlineMedium)
      ],
    );
    
  }
}

class ShockerChip extends StatefulWidget {
  final AlarmListManager manager;
  final Shocker shocker;
  final Function(bool) onSelected;
  const ShockerChip({Key? key, required this.shocker, required this.manager, required this.onSelected}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerChipState(manager, shocker, onSelected);
}

class ShockerChipState extends State<ShockerChip> {
  final AlarmListManager manager;
  final Shocker shocker;
  final Function(bool) onSelected;
  ShockerChipState(this.manager, this.shocker, this.onSelected);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<ShockerAction> shockerActions = shocker.isOwn ? ShockerItem.ownShockerActions : ShockerItem.foreignShockerActions;
    return 
      GestureDetector(
          child:
            Row(mainAxisSize: MainAxisSize.min, spacing: 5, children: [
              FilterChip(label: 
                Row(mainAxisSize: MainAxisSize.min,
                spacing: 5,children: [
                  Text(shocker.name + (shocker.paused ? " (paused)" : "")),
                ],
                )
              , onSelected: onSelected, selected: manager.selectedShockers.contains(shocker.id),
              backgroundColor: shocker.paused ? t.colorScheme.errorContainer : null,
              selectedColor: shocker.paused ? t.colorScheme.errorContainer : null,),
              if(shocker.paused)
                GestureDetector(child: Icon(Icons.info, color: t.colorScheme.error,), onTap: () {
                  showDialog(context: context, builder: (context) {
                    return AlertDialog(
                      title: Text("Shocker is paused"),
                      content: 
                          Text(shocker.isOwn ?
                        "This shocker was pause by you. While it's paused you cannot control it. You can unpause it by selecting the shocker and pressing unpause selected." 
                        : "This shocker was paused by the owner. While it's paused you cannot control it. You can ask the owner to unpause it."),
                      actions: [
                        TextButton(onPressed: () {
                          Navigator.of(context).pop();
                        }, child: Text("Close"))
                      ],
                    );
                  });
                },)
            ],
              
          ),
        onLongPress: () {
          List<Widget> actions = [];
          for(ShockerAction a in shockerActions) {
            actions.add(GestureDetector(onTap: () {
                Navigator.of(context).pop();
                a.onClick(manager, shocker, context, manager.reloadAllMethod!);
              }, child: Row(children: [
                a.icon,
                Text(a.name, style: t.textTheme.titleLarge,)
              ],spacing: 5, mainAxisSize: MainAxisSize.min,)
            ,));
          }
          showDialog(context: context, builder: (context) {
            return AlertDialog(
              title: Text(shocker.name),
              content: Column(
                spacing: 20,
                children: actions,
                mainAxisSize: MainAxisSize.min
                ,),
              actions: [
                TextButton(onPressed: () {
                  Navigator.of(context).pop();
                }, child: Text("Close"))
              ],
            );
          });
        }
      );
  }
}