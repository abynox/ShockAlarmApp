import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
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
    ThemeData t = Theme.of(context);
    List<Shocker> filteredShockers = manager.shockers.where((shocker) {
    return manager.enabledHubs[shocker.hub] ?? false;
  }).toList();
    return Column(children: [
      Text(
        'All shockers',
        style: t.textTheme.headlineMedium,
      ),
      Wrap(spacing: 5,runAlignment: WrapAlignment.start,children: manager.enabledHubs.keys.map<FilterChip>((hub) {
        return FilterChip(label: Text(hub), onSelected: (bool value) {
          manager.enabledHubs[hub] = value;
          setState(() {
          }
        );}, selected: manager.enabledHubs[hub]!);
      }).toList(),),
      Flexible(
        child: RefreshIndicator(child: ListView(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children:
              filteredShockers.isEmpty ? [Text('No shockers found', style: t.textTheme.headlineSmall)] :
              filteredShockers.map((shocker) {
                return ShockerItem(shocker: shocker, manager: manager, onRebuild: rebuild, key: ValueKey(shocker.id));
              }).toList()
            )
          ],), onRefresh: () async {
            await manager.updateShockerStore();
            setState(() {});
          }
        )
      )
    ],);
    
  }
}