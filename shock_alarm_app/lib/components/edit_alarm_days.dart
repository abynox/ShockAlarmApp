import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../stores/alarm_store.dart';

class EditAlarmDays extends StatefulWidget {
  final ObservableAlarmBase alarm;
  final Function onRebuild;

  const EditAlarmDays({Key? key, required this.alarm, required this.onRebuild}) : super(key: key);
  @override
  State<StatefulWidget> createState() => EditAlarmDaysState(alarm, onRebuild);
  
}
class EditAlarmDaysState extends State<EditAlarmDays> {

  final ObservableAlarmBase alarm;
  final Function onRebuild;

  EditAlarmDaysState(this.alarm, this.onRebuild);


  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          WeekDayToggle(
            text: 'Mo',
            current: alarm.monday,
            onToggle: (monday) => setState(()=> {alarm.monday = monday,onRebuild()}),
          ),
          WeekDayToggle(
            text: 'Tu',
            current: alarm.tuesday,
            onToggle: (tuesday) => setState(()=> {alarm.tuesday = tuesday,onRebuild()}),
          ),
          WeekDayToggle(
            text: 'We',
            current: alarm.wednesday,
            onToggle: (wednesday) => setState(()=> {alarm.wednesday = wednesday,onRebuild()}),
          ),
          WeekDayToggle(
            text: 'Th',
            current: alarm.thursday,
            onToggle: (thursday) => setState(()=> {alarm.thursday = thursday,onRebuild()}),
          ),
          WeekDayToggle(
            text: 'Fr',
            current: alarm.friday,
            onToggle: (friday) => setState(()=> {alarm.friday = friday,onRebuild()}),
          ),
          WeekDayToggle(
            text: 'Sa',
            current: alarm.saturday,
            onToggle: (saturday) => setState(()=> {alarm.saturday = saturday,onRebuild()}),
          ),
          WeekDayToggle(
            text: 'Su',
            current: alarm.sunday,
            onToggle: (sunday) => setState(()=> {alarm.sunday = sunday,onRebuild()}),
          ),
        ],
      ),
    );
  }
}

class WeekDayToggle extends StatelessWidget {
  final void Function(bool) onToggle;
  final bool current;
  final String text;

  const WeekDayToggle({Key? key, required this.onToggle, required this.current, required this.text})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    final textColor = this.current ? Colors.white : Colors.deepPurple;
    final blobColor = this.current ? Colors.deepPurple : Colors.white;

    return GestureDetector(
      child: SizedBox.fromSize(
        size: Size.fromRadius(size),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: new BorderRadius.circular(size), color: blobColor),
          child: Center(
              child: Text(
            this.text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          )),
        ),
      ),
      onTap: () => this.onToggle(!this.current),
    );
  }
}
