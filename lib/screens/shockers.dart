import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';
import '../components/bottom_add_button.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../components/shocker_item.dart';

class ShockerScreen extends StatefulWidget {
  final AlarmListManager manager;

  const ShockerScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerScreenState(manager);
}

class ShockerScreenState extends State<ShockerScreen> {
  final AlarmListManager manager;

  void rebuild() {
    setState(() {});
  } 

  ShockerScreenState(this.manager);
  @override
  Widget build(BuildContext context) {
    return Column(
        children: <Widget>[
          Text(
            'Your shockers',
            style: TextStyle(fontSize: 28, color: Theme.of(context).textTheme.headlineMedium?.color),
          ),
          Flexible(
            child: Observer(
              builder: (context) => ListView.builder(
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final shocker = manager.shockers[index];
                  
                  return ShockerItem(shocker: shocker, manager: manager, onRebuild: rebuild);
                },
                itemCount: manager.shockers.length,
              ),
            ),
          )
        ],
      );
  }
}