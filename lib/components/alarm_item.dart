import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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
  }

  void _save() {
    manager.saveAlarm(alarm);
    expanded = false;
    onRebuild();
  }

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
                            Text(alarm.name),
                            EditAlarmTime(alarm: this.alarm),
                            DateRow(alarm: alarm)
                          ],
                        ),
                        Column(children: [
                          IconButton(onPressed: () {setState(() {
                            expanded = !expanded;
                          });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)),
                          Switch(value: alarm.active, onChanged: (value) {
                            setState(() {
                              alarm.active = value;
                            });
                          }),
                        ],)
                      ],
                    ),
                    if (expanded) Column(
                      children: [

                        EditAlarmDays(alarm: this.alarm, onRebuild: onRebuild,),
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