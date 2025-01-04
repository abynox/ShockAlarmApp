import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../stores/alarm_store.dart';
import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class ShockerItem extends StatefulWidget {
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;

  const ShockerItem({Key? key, required this.shocker, required this.manager, required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerItemState(shocker, manager, onRebuild);
}

class ShockerItemState extends State<ShockerItem> {
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;

  int currentIntensity = 25;
  int currentDuration = 1000;

  void action(ControlType type) {
    manager.sendShock(type, shocker, currentIntensity, currentDuration).then((errorMessage) {
      if(errorMessage == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        duration: Duration(seconds: 3),
      ));
    });
  }
  
  ShockerItemState(this.shocker, this.manager, this.onRebuild);
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return GestureDetector(
      /*
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  EditAlarm(alarm: this.alarm, manager: manager))),
                  */
      child: Observer(
        builder: (context) => GestureDetector(
          onTap: () => {
            setState(() {
              if(shocker.paused) return;
              expanded = !expanded;
            })
          },
          child:
            Card(
              color: t.colorScheme.onInverseSurface,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 10,
                          children: <Widget>[
                            Text(
                              shocker.name,
                              style: TextStyle(fontSize: 24),
                            ),
                             Chip(label: Text(shocker.hub)),
                          ],
                          
                        ),
                        Row(children: [

                          if(shocker.isOwn && shocker.paused)
                            IconButton(onPressed: () {
                              OpenShockClient().setPauseStateOfShocker(shocker, manager, false);
                            }, icon: Icon(Icons.play_arrow)),
                          if(shocker.isOwn && !shocker.paused)
                            IconButton(onPressed: () {
                              OpenShockClient().setPauseStateOfShocker(shocker, manager, true);
                            }, icon: Icon(Icons.pause)),

                          if (shocker.paused)
                          GestureDetector( child: Chip(
                              label: Text("paused"),
                              backgroundColor: t.colorScheme.errorContainer,
                              side: BorderSide.none,
                              avatar: Icon(Icons.info, color: t.colorScheme.error,)
                            ),
                            onTap: () {
                              showDialog(context: context, builder: (context) => AlertDialog(title: Text("Shocker is paused"), content: Text(shocker.isOwn ?
                              "This shocker was pause by you. While it's paused you cannot control it. You can unpause it by pressing the play button." 
                              : "This shocker was paused by the owner. While it's paused you cannot control it. You can ask the owner to unpause it."),
                              actions: [TextButton(onPressed: () {
                                Navigator.of(context).pop();
                              }, child: Text("Ok"))],));
                            },),
                          if (!shocker.paused)
                            IconButton(onPressed: () {setState(() {
                              expanded = !expanded;
                            });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)),
                        ],)
                      ],
                    ),
                    if (expanded) Column(
                      children: [
                        IntensityDurationSelector(duration: currentDuration, intensity: currentIntensity, maxDuration: shocker.durationLimit, maxIntensity: shocker.intensityLimit, onSet: (intensity, duration) {
                          setState(() {
                            currentDuration = duration;
                            currentIntensity = intensity;
                          });
                        }),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            if(shocker.soundAllowed)
                              IconButton(
                                icon: OpenShockClient.getIconForControlType(ControlType.sound),
                                onPressed: () {action(ControlType.sound);},
                              ),
                            if(shocker.vibrateAllowed)
                              IconButton(
                                icon: OpenShockClient.getIconForControlType(ControlType.vibrate),
                                onPressed: () {action(ControlType.vibrate);},
                              ),
                            if(shocker.shockAllowed)
                              IconButton(
                                icon: OpenShockClient.getIconForControlType(ControlType.shock),
                                onPressed: () {action(ControlType.shock);},
                              ),
                          ],
                        ),
                        SizedBox.fromSize(size: Size.fromHeight(50),child: 
                        IconButton(onPressed: () {action(ControlType.stop);}, icon: Icon(Icons.stop),)
                        ,)
                        
                      ],
                    ),
                  ],
                )
              ),
            ),
          ),
      ),
    );
  }
}

class IntensityDurationSelector extends StatefulWidget {
  final int duration;
  final int intensity;
  int maxDuration;
  int maxIntensity;
  bool showIntensity = true;
  ControlType type = ControlType.shock;
  final Function(int, int) onSet;

  IntensityDurationSelector({Key? key, this.showIntensity = true, this.type = ControlType.shock, required this.duration, required this.intensity, required this.onSet, required this.maxDuration, required this.maxIntensity}) : super(key: key);

  @override
  State<StatefulWidget> createState() => IntensityDurationSelectorState(duration, intensity, onSet, this.maxDuration, this.maxIntensity, this.showIntensity, this.type);
}

class IntensityDurationSelectorState extends State<IntensityDurationSelector> {
  int maxDuration;
  int maxIntensity;
  int duration;
  int intensity;
  bool showIntensity;
  ControlType type = ControlType.shock;
  Function(int, int) onSet;


  IntensityDurationSelectorState(this.duration, this.intensity, this.onSet, this.maxDuration, this.maxIntensity, this.showIntensity, this.type);

  double cubicToLinear(double value) {
    return pow(value, 6/3).toDouble();
  }

  double linearToCubic(double value) {
    return pow(value,  3/6).toDouble();
  }

  double reverseMapDuration(double value) {

    return linearToCubic((value - 300) / maxDuration);
  }

  int mapDuration(double value) {
    return 300 + (cubicToLinear(value) * (maxDuration - 300) / 100).toInt() * 100;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    print(showIntensity);
    return Column(
      children: [
        if(showIntensity)
          Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10,children: [
            OpenShockClient.getIconForControlType(type),
            Text("Intensity: $intensity", style: TextStyle(fontSize: 24),),
          ],),
        if(showIntensity)
          Slider(value: intensity.toDouble(), max: maxIntensity.toDouble(), onChanged: (double value) {
            setState(() {
              intensity = value.toInt();
              onSet(intensity, duration);
            });
          }),
        Row(
          mainAxisAlignment: MainAxisAlignment.center, spacing: 10,
          children: [
            Icon(Icons.timer),
            Text("Duration: ${duration / 1000.0}", style: TextStyle(fontSize: 24),),
          ],),
        Slider(value: reverseMapDuration(duration.toDouble()), max: 1, onChanged: (double value) {
          setState(() {
            duration = mapDuration(value);
            onSet(showIntensity ? intensity : 1, duration);
          });
        }),
      ],
    );
  }

}