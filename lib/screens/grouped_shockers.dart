import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/hub_item.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';

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
  int currentDuration = 1000;
  int currentIntensity = 25;

  GroupedShockerScreenState(this.manager);

  void onRebuild() {
    setState(() {});
  }

  Shocker getShockerLimits() {
    Shocker limitedShocker = Shocker();
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

  void executeAll(ControlType type, int intensity, int duration) {
    List<Control> controls = [];
    for(Shocker s in manager.shockers.where((x) {
      return manager.selectedShockers.contains(x.id);
    })) {
      Control c = Control();
      c.id = s.id;
      c.type = type;
      c.intensity = min(s.intensityLimit, intensity);
      c.duration = min(s.durationLimit, duration);
      c.apiTokenId = s.apiTokenId;
      controls.add(c);
    }
    manager.sendControls(controls);
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
    print(limitedShocker.intensityLimit);
    return Column(
      children: [
        Flexible(
          child: ListView(children: [
            for (MapEntry<Hub?, List<Shocker>> hubContainer in groupedShockers.entries)
              Column(children: [
                HubItem(hub: hubContainer.key!, manager: manager, onRebuild: onRebuild),
                Wrap(spacing: 5,children: [
                  for (Shocker s in hubContainer.value) 
                    FilterChip(label: Text(s.name), onSelected: (bool selected) {
                      setState(() {
                        if(selected) {
                          manager.selectedShockers.add(s.id);
                        } else {
                          manager.selectedShockers.remove(s.id);
                        }
                      });
                    }, selected: manager.selectedShockers.contains(s.id),)
                ],)
              ],
            )
          ],
        ),
        ),
        ShockingControls(manager: manager, currentDuration: currentDuration, currentIntensity: currentIntensity, durationLimit: limitedShocker.durationLimit, intensityLimit: limitedShocker.intensityLimit, soundAllowed: limitedShocker.soundAllowed, vibrateAllowed: limitedShocker.vibrateAllowed, shockAllowed: limitedShocker.shockAllowed, onDelayAction: executeAll, onProcessAction: executeAll)
      ],
    );
    
  }
}