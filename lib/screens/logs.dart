import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';

import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class LogScreen extends StatefulWidget {
  AlarmListManager manager;
  List<Shocker> shockers;
  
  LogScreen({Key? key, required this.manager, required this.shockers}) : super(key: key);

  @override
  State<StatefulWidget> createState() => LogScreenState(manager, shockers);
}

class LogScreenState extends State<LogScreen> {
  AlarmListManager manager;
  List<Shocker> shockers;
  List<ShockerLog> logs = [];
  bool initialLoading = false;

  LogScreenState(this.manager, this.shockers);

  @override
  void initState() {
    super.initState();
    initialLoading = true;
    manager.reloadShockerLogs = () {
      setState(() {
        for (var shocker in shockers) 
          logs.addAll(manager.availableShockerLogs[shocker.id] ?? []);
        logs.sort((a, b) => b.createdOn.compareTo(a.createdOn));
      });
    };
    loadLogs();
  }

  Future<void> loadLogs() async {
    List<ShockerLog> newLogs = [];
    for (var shocker in shockers) {
      final logs = await manager.getShockerLogs(shocker);
      newLogs.addAll(logs);
    }
    newLogs.sort((a, b) => b.createdOn.compareTo(a.createdOn));
    setState(() {
      logs = newLogs;
      initialLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          spacing: 10,
          children: [
            Text('Logs for ${shockers.map((x) => x.name).join(", ")}'),
          ],
        ),
      ),
      body:
      Padding(
        padding: const EdgeInsets.only(
          bottom: 15,
          left: 15,
          right: 15,
          top: 50,
        ),
        child:
        initialLoading ? Center(child: CircularProgressIndicator()) :
        DesktopMobileRefreshIndicator(
          onRefresh: () async {
            return loadLogs();
          },
          child: ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ShockerLogEntry(log: log, key: ValueKey("${log.createdOn}-${log.type}"),);
            }
          )
        )
      )
    );
  }
}

class ShockerLogEntry extends StatelessWidget {
  final ShockerLog log;

  const ShockerLogEntry({Key? key, required this.log}) : super(key: key);

  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day;
    final timeString = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    final dateString = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

    return isToday ? timeString : '$dateString $timeString';
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return 
    Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              spacing: 10,
              children: [OpenShockClient.getIconForControlType(log.type),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: 10,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          Text(log.getName(), style: t.textTheme.titleMedium,),
                        ],
                      ),
                      Text(formatDateTime(log.createdOn.toLocal())),
                  ],),
                  Row(
                    children: [
                      Text("${(log.duration / 100).round() / 10} s"),
                      Text(" @ "),
                      Text("${log.intensity}"),
                    ],
                  ),
                ]
              ),],),

            Chip(label: Text(log.shockerReference?.name ?? "Unknown")),
          ]),
          Divider()
      ],
    );
    
  }
}

