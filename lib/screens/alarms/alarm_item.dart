import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/haptic_switch.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../../stores/alarm_store.dart';
import '../../services/alarm_list_manager.dart';
import 'edit_alarm_days.dart';
import 'edit_alarm_time.dart';

const dates = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

class AlarmItem extends StatefulWidget {
  final Alarm alarm;
  final AlarmListManager manager;
  final Function onRebuild;

  const AlarmItem(
      {Key? key,
      required this.alarm,
      required this.manager,
      required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      AlarmItemState(alarm, manager, onRebuild);
}

class AlarmItemState extends State<AlarmItem> {
  final Alarm alarm;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;

  AlarmItemState(this.alarm, this.manager, this.onRebuild);

  void _delete() {
    manager.deleteAlarm(alarm);
    onRebuild();
  }

  void _save() async {
    manager.saveAlarm(alarm);
    if (manager.anyAlarmOn() && isAndroid()) {
      // The permission is only available on Android.
      // Web and Linux will use the alarm server for scheduling.
      // When adding a native linux alarming package this should be updated.
      await requestAlarmPermissions();
    }
    expanded = false;
    onRebuild();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
        child: Column(
      children: [
        GestureDetector(
          onTap: () => {
            setState(() {
              expanded = !expanded;
              if (!expanded) {
                _save();
              }
            })
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextButton(
                    onPressed: () async {
                      TextEditingController controller =
                          TextEditingController(text: alarm.name);
                      await showDialog(
                          context: context,
                          builder: (builder) {
                            return AlertDialog.adaptive(
                              title: Text("Rename alarm"),
                              content: TextField(controller: controller),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Cancel")),
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      alarm.name = controller.text;
                                      _save();
                                    },
                                    child: Text("Save"))
                              ],
                            );
                          });
                    },
                    child: Text(alarm.name),
                  ),
                  EditAlarmTime(
                    alarm: this.alarm,
                    manager: this.manager,
                  ),
                  DateRow(alarm: alarm)
                ],
              ),
              Column(
                children: [
                  IconButton(
                      onPressed: () {
                        setState(() {
                          expanded = !expanded;
                          if (!expanded) {
                            _save();
                          }
                        });
                      },
                      icon: Icon(expanded
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)),
                  HapticSwitch(
                      value: alarm.active,
                      onChanged: (value) {
                        setState(() {
                          alarm.active = value;
                          _save();
                        });
                      }),
                ],
              )
            ],
          ),
        ),
        if (expanded)
          Column(
            children: [
              EditAlarmDays(
                alarm: this.alarm,
                onRebuild: onRebuild,
              ),
              if (!manager.settings.useAlarmServer)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Repeat alarm tone"),
                    HapticSwitch(
                      value: alarm.repeatAlarmsTone,
                      onChanged: (value) {
                        setState(() {
                          alarm.repeatAlarmsTone = value;
                          _save();
                        });
                      },
                    )
                  ],
                ),
              Text("${alarm.shockers.where((x) {
                return x.enabled;
              }).length} shockers active"),
              Column(
                  children: alarm.shockers.map((alarmShocker) {
                return AlarmShockerWidget(
                    alarmShocker: alarmShocker,
                    manager: manager,
                    onRebuild: onRebuild);
              }).toList()),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _delete,
                    icon: Icon(Icons.delete),
                  ),
                  IconButton(
                    onPressed: () {
                      alarm.onAlarmStopped(manager, needStop: true);
                    },
                    icon: Icon(Icons.stop),
                  ),
                  IconButton(
                    onPressed: () {
                      alarm.trigger(manager, false);
                    },
                    icon: Icon(Icons.play_arrow),
                  )
                ],
              )
            ],
          ),
      ],
    ));
  }
}

class AlarmShockerWidget extends StatefulWidget {
  final AlarmShocker alarmShocker;
  final AlarmListManager manager;
  final Function onRebuild;

  const AlarmShockerWidget(
      {Key? key,
      required this.alarmShocker,
      required this.manager,
      required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      AlarmShockerWidgetState(alarmShocker, manager, onRebuild);
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
    return GestureDetector(
      onTap: () => {
        setState(() {
          expanded = !expanded;
        })
      },
      child: PaddedCard(
          color: t.colorScheme.surface,
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
                        style: t.textTheme.headlineSmall,
                      ),
                      Chip(
                          label: Text(alarmShocker
                                  .shockerReference?.hubReference?.name ??
                              "Unknown")),
                    ],
                  ),
                  Row(
                    children: [
                      if (isPaused)
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
                                alarmShocker.shockerReference?.isOwn ?? false
                                    ? "This shocker was pause by you. The alarm will not trigger this shocker when it's paused even when you enable it in this menu. Unpause it so it can be triggered."
                                    : "This shocker was paused by the owner. The alarm will not trigger this shocker when it's paused even when you enable it in this menu. It needs to be unpaused so it can be triggered.");
                          },
                        ),
                      HapticSwitch(
                        value: alarmShocker.enabled,
                        onChanged: enable,
                      ),
                    ],
                  )
                ],
              ),
              if (alarmShocker.enabled)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5,
                  children: [
                    DropdownMenu<ControlType?>(
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          label: "Tone",
                          value: null,
                        ),
                        if (alarmShocker.shockerReference?.shockAllowed ??
                            false)
                          DropdownMenuEntry(
                            label: "Shock",
                            value: ControlType.shock,
                          ),
                        if (alarmShocker.shockerReference?.vibrateAllowed ??
                            false)
                          DropdownMenuEntry(
                            label: "Vibration",
                            value: ControlType.vibrate,
                          ),
                        if (alarmShocker.shockerReference?.soundAllowed ??
                            false)
                          DropdownMenuEntry(
                            label: "Sound",
                            value: ControlType.sound,
                          ),
                      ],
                      initialSelection: alarmShocker.type,
                      onSelected: (value) {
                        setState(() {
                          alarmShocker.type = value;
                        });
                      },
                    ),
                    if (alarmShocker.type == null)
                      DropdownMenu<int?>(
                        dropdownMenuEntries: manager.alarmTones.map((tone) {
                          return DropdownMenuEntry(
                              label: tone.name, value: tone.id);
                        }).toList(),
                        initialSelection: alarmShocker.toneId,
                        onSelected: (value) {
                          setState(() {
                            alarmShocker.toneId = value;
                          });
                        },
                      ),
                    if (alarmShocker.type != null)
                      IntensityDurationSelector(
                        showSeperateIntensities: false,
                        key: ValueKey(alarmShocker.type),
                        controlsContainer: ControlsContainer.fromInts(
                            intensity: alarmShocker.intensity,
                            duration: alarmShocker.duration),
                        onSet: (ControlsContainer container) {
                          setState(() {
                            alarmShocker.duration =
                                container.durationRange.start.toInt();
                            alarmShocker.intensity =
                                container.intensityRange.start.toInt();
                          });
                        },
                        maxDuration:
                            alarmShocker.shockerReference?.durationLimit ?? 300,
                        maxIntensity:
                            alarmShocker.shockerReference?.intensityLimit ?? 0,
                        showIntensity: alarmShocker.type != ControlType.sound,
                        type: alarmShocker.type ?? ControlType.shock,
                      ),
                  ],
                ),
            ],
          )),
    );
  }
}

class DateRow extends StatelessWidget {
  final Alarm alarm;
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
    return Text(dates
        .asMap()
        .entries
        .where((x) => dayEnabled[x.key])
        .map((indexStringPair) {
      return indexStringPair.value;
    }).join(", "));
  }
}
