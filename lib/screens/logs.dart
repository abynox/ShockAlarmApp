import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/screens/log_stats.dart';
import 'package:shock_alarm_app/stores/shocker_log_stats.dart';

import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class LogScreen extends StatefulWidget {
  AlarmListManager manager;
  List<Shocker> shockers;

  LogScreen({Key? key, required this.manager, required this.shockers})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => LogScreenState(manager, shockers);
}

class LogScreenState extends State<LogScreen> {
  AlarmListManager manager;
  List<Shocker> shockers;
  List<ShockerLog> logs = [];
  bool initialLoading = false;
  Function? reloadShockerLogs;

  LogScreenState(this.manager, this.shockers);

  @override
  void initState() {
    super.initState();
    initialLoading = true;
    manager.reloadShockerLogs = () {
      List<ShockerLog> newLogs = [];
      for (var shocker in shockers)
        newLogs.addAll(manager.shockerLog[shocker.id] ?? []);
      newLogs.sort((a, b) => b.createdOn.compareTo(a.createdOn));
      setState(() {
        logs = newLogs;
      });
      if(reloadShockerLogs != null) {
        reloadShockerLogs!();
      }
    };
    loadLogs();
  }

  Future<void> loadLogs() async {
    List<ShockerLog> newLogs = [];
    for (var shocker in shockers) {
      newLogs.addAll(await manager.getShockerLogs(shocker));
    }
    newLogs.sort((a, b) => b.createdOn.compareTo(a.createdOn));
    setState(() {
      logs = newLogs;
      initialLoading = false;
    });
  }

  ShockerLogStats showStats() {
    ShockerLogStats s = ShockerLogStats(themeData: Theme.of(context));
    s.addLogs(logs);
    s.doStats();
    // ToDo: Open stats page with the stats
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => LogStatScreen(shockers: shockers, stats: s, state: this,)));
    return s;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = [];
    widgets.add(FilledButton(
        onPressed: showStats,
        child: Text("Show stats"),
        key: ValueKey("stats")));
    for (ShockerLog log in logs.toList()) {
      widgets.add(ShockerLogEntry(
        log: log,
        key: ValueKey(
            log.id),
      ));
    }

    return Scaffold(
        appBar: AppBar(
          title: Row(
            spacing: 10,
            children: [
              Text('Logs for ${shockers.map((x) => x.name).join(", ")}'),
            ],
          ),
        ),
        body: Padding(
            padding: const EdgeInsets.only(
              bottom: 15,
              left: 15,
              right: 15,
              top: 50,
            ),
            child: initialLoading
                ? Center(child: CircularProgressIndicator())
                : ConstrainedContainer(
                    child: DesktopMobileRefreshIndicator(
                        onRefresh: () async {
                          return loadLogs();
                        },
                        child: ListView.builder(
                  itemCount: logs.length + 1, // +1 for the button
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return FilledButton(
                        onPressed: showStats,
                        child: Text("Show stats"),
                        key: ValueKey("stats"),
                      );
                    }

                    final log = logs[index - 1]; // Adjust index since 0 is the button
                    return ShockerLogEntry(
                      log: log,
                      key: ValueKey(log.id),
                    );
                  },
                ),))));
  }
}

class ShockerLogEntry extends StatelessWidget {
  final ShockerLog log;

  const ShockerLogEntry({Key? key, required this.log}) : super(key: key);

  static String formatDateTime(DateTime? dateTime, {bool alwaysShowDate = false, String fallback = "Unknown"}) {
    if(dateTime == null) {
      return fallback;
    }
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day && !alwaysShowDate;
    final timeString =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    final dateString =
        '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

    return isToday ? timeString : '$dateString $timeString';
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 10,
            children: [
              Row(
                spacing: 10,
                children: [
                  OpenShockClient.getIconForControlType(log.type),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: 10,
                          children: [
                            Text(
                              log.getName(),
                              style: t.textTheme.titleMedium,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 10,
                          children: [
                            Text(formatDateTime(log.createdOn.toLocal())),
                          ],
                        ),
                      ]),
                ],
              ),
              Row(
                children: [
                  Text("${(log.duration / 100).round() / 10} s"),
                  Text(" @ "),
                  Text("${log.intensity}"),
                ],
              ),
              Chip(label: Text(log.shockerReference?.name ?? "Unknown")),
            ]),
        Divider()
      ],
    );
  }
}
