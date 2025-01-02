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

  int currentIntensity = 0;
  int currentDuration = 0;

  void action(ControlType type) {
    manager.sendShock(type, shocker, currentIntensity, currentDuration);
  }
  
  ShockerItemState(this.shocker, this.manager, this.onRebuild);
  @override
  Widget build(BuildContext context) {
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
              expanded = !expanded;
            })
          },
          child:
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              shocker.name,
                              style: TextStyle(fontSize: 24),
                            )
                          ],
                        ),
                        Column(children: [
                          IconButton(onPressed: () {setState(() {
                            expanded = !expanded;
                          });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded))
                        ],)
                      ],
                    ),
                    if (expanded) Column(
                      children: [
                        Row(children: [
                          Column(
                            children: [
                              Slider(value: currentIntensity.toDouble(), max: shocker.intensityLimit.toDouble(), onChanged: (double value) {
                                setState(() {
                                  currentIntensity = value.toInt();
                                });
                              }),
                            ],
                          ),
                          Text(currentIntensity.toString())
                        ],),
                        Row(children: [
                          Column(
                            children: [
                              Slider(value: currentDuration.toDouble(), max: shocker.durationLimit.toDouble(), onChanged: (double value) {
                                setState(() {
                                  currentDuration = value.toInt();
                                });
                              }),
                            ],
                          ),
                          Text(currentDuration.toString())
                        ],),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            IconButton(
                              icon: Icon(Icons.sports_hockey),
                              onPressed: () {action(ControlType.shock);},
                            ),
                            IconButton(
                              icon: Icon(Icons.vibration),
                              onPressed: () {action(ControlType.vibrate);},
                            ),
                            IconButton(
                              icon: Icon(Icons.volume_down),
                              onPressed: () {action(ControlType.sound);},
                            ),
                          ],
                        ),
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