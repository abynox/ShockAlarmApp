import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../stores/alarm_store.dart';
import '../services/alarm_list_manager.dart';
import '../components/edit_alarm_days.dart';
import '../components/edit_alarm_head.dart';
import '../components/edit_alarm_time.dart';

const dates = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

class AlarmItem extends StatefulWidget {
  final ObservableAlarmBase alarm;
  final AlarmListManager manager;
  final Function onRebuild;

  const AlarmItem({Key? key, required this.alarm, required this.manager, required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => AlarmItemState(alarm, manager, onRebuild);
}

class AlarmItemState extends State<AlarmItem> {
  final ObservableAlarmBase alarm;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;
  
  AlarmItemState(this.alarm, this.manager, this.onRebuild);

  void _delete() {
    manager.deleteAlarm(alarm);
    onRebuild();
  }

  void _save() {
    manager.saveAlarm(alarm);
    expanded = false;
    onRebuild();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return  GestureDetector(
          onTap: () => {
            setState(() {
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(alarm.name),
                            EditAlarmTime(alarm: this.alarm, manager: this.manager,),
                            DateRow(alarm: alarm)
                          ],
                        ),
                        Column(children: [
                          IconButton(onPressed: () {setState(() {
                            expanded = !expanded;
                          });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)),
                          Switch(value: alarm.active,
                            
                            onChanged: (value) {
                            setState(() {
                              alarm.active = value;
                              _save();
                            });
                          }),
                        ],)
                      ],
                    ),
                    if (expanded) Column(
                      children: [

                        EditAlarmDays(alarm: this.alarm, onRebuild: onRebuild,),
                        Text(alarm.shockers.length.toString() + " shockers"),
                        Column(children: alarm.shockers.map((alarmShocker) {
                          return AlarmShockerWidget(alarmShocker: alarmShocker, manager: manager, onRebuild: onRebuild);
                        }).toList()),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: _delete,
                              icon: Icon(Icons.delete),
                            ),
                            IconButton(
                              onPressed: _save,
                              icon: Icon(Icons.save),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              ),
            ),
          );
  }
}

class AlarmShockerWidget extends StatefulWidget {
  final AlarmShocker alarmShocker;
  final AlarmListManager manager;
  final Function onRebuild;

  const AlarmShockerWidget({Key? key, required this.alarmShocker, required this.manager, required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => AlarmShockerWidgetState(alarmShocker, manager, onRebuild);
}

class AlarmShockerWidgetState extends State<AlarmShockerWidget> {
  final AlarmShocker alarmShocker;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;
  
  AlarmShockerWidgetState(this.alarmShocker, this.manager, this.onRebuild);

  void enable(bool value) {
    setState(() {
      alarmShocker.enabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    bool isPaused = alarmShocker.shockerReference?.paused ?? false;
    return  GestureDetector(
          onTap: () => {
            setState(() {
              expanded = !expanded;
            })
          },
          child:
            Card(
              color: t.colorScheme.surface,
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
                          spacing: 10,
                          children: [
                            Text(
                              alarmShocker.shockerReference?.name ?? "Unknown",
                              style: TextStyle(fontSize: 24),
                            ),
                            Chip(label: Text(alarmShocker.shockerReference?.hub ?? "Unknown")),
                          ],
                        ),
                        Row(children: [
                          if (isPaused)
                          GestureDetector(child:
                            Chip(
                              label: Text("paused"),
                              backgroundColor: t.colorScheme.errorContainer,
                              side: BorderSide.none,
                              avatar: Icon(Icons.info, color: t.colorScheme.error,)
                            ),
                            onTap: () {
                              showDialog(context: context, builder: (context) => AlertDialog(title: Text("Shocker is paused"), content: Text(alarmShocker.shockerReference!.isOwn ?? false ?
                              "This shocker was pause by you. The alarm will not trigger this shocker when it's paused even when you enable it in this menu. Unpause it so it can be triggered." 
                              : "This shocker was paused by the owner. The alarm will not trigger this shocker when it's paused even when you enable it in this menu. It needs to be unpaused so it can be triggered."),
                              actions: [TextButton(onPressed: () {
                                Navigator.of(context).pop();
                              }, child: Text("Ok"))],));
                            },),
                            
                          Switch(value: alarmShocker.enabled, onChanged: enable,),

                        ],)
                      ],
                    ),
                    if (alarmShocker.enabled) Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 5,
                      children: [
                            DropdownMenu<ControlType?>(dropdownMenuEntries: [
                                DropdownMenuEntry(label: "Tone", value: null,),
                                if(alarmShocker.shockerReference?.shockAllowed ?? false) DropdownMenuEntry(label: "Shock", value: ControlType.shock,),
                                if(alarmShocker.shockerReference?.vibrateAllowed ?? false) DropdownMenuEntry(label: "Vibration", value: ControlType.vibrate,),
                                if(alarmShocker.shockerReference?.soundAllowed ?? false) DropdownMenuEntry(label: "Sound", value: ControlType.sound,),
                              ],
                              initialSelection: alarmShocker.type,
                              onSelected: (value) {
                                setState(() {
                                  alarmShocker.type = value;
                                });
                              },
                            ),
                            if(alarmShocker.type == null) Text("Alarm tones are not implemented yet", style: TextStyle(fontSize: 18),),/* DropdownMenu<String?>(dropdownMenuEntries: [
                                DropdownMenuEntry(label: "Example alarm tone", value: null,)
                              ],
                              initialSelection: alarmShocker.toneId,
                              onSelected: (value) {
                                setState(() {
                                  alarmShocker.toneId = value;
                                });
                              },
                            ),
                              */
                            if(alarmShocker.type != null)
                              IntensityDurationSelector(key: ValueKey(alarmShocker.type), duration: alarmShocker.duration, intensity: alarmShocker.intensity, onSet: (intensity, duration) {
                                setState(() {
                                  alarmShocker.duration = duration;
                                  alarmShocker.intensity = intensity;
                                });
                              }, maxDuration: alarmShocker.shockerReference?.durationLimit ?? 300,
                              maxIntensity: alarmShocker.shockerReference?.intensityLimit ?? 0,
                              showIntensity: alarmShocker.type != ControlType.sound,
                              type: alarmShocker.type ?? ControlType.shock,),
                          ],
                        ),
                  ],
                )
              ),
            ),
          );
  }
}

class DateRow extends StatelessWidget {
  final ObservableAlarmBase alarm;
  final List<bool> dayEnabled;

  DateRow({
    Key? key,
    required this.alarm,
  })  : dayEnabled = [
          alarm.monday,
          alarm.tuesday,
          alarm.wednesday,
          alarm.thursday,
          alarm.friday,
          alarm.saturday,
          alarm.sunday
        ],
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(dates.asMap().entries.where((x) => dayEnabled[x.key]).map((indexStringPair) {
          return indexStringPair.value;
        }).join(", "));
  }
}