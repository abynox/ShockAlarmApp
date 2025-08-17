import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/screens/logs/shocker_log_entry.dart';
import 'package:shock_alarm_app/screens/logs/log_stats/log_stats.dart';
import 'package:shock_alarm_app/stores/shocker_log_stats.dart';

import '../../services/alarm_list_manager.dart';
import '../../services/openshock.dart';

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
      for (var shocker in shockers) {
        newLogs.addAll(manager.shockerLog[shocker.id] ?? []);
      }
      newLogs.sort((a, b) => b.createdOn.compareTo(a.createdOn));
    if(!mounted) return;
      setState(() {
        initialLoading = false;
        logs = newLogs;
      });
      if(reloadShockerLogs != null) {
        reloadShockerLogs!();
      }
    };
    if(needsToLoadLogsOnStart()) {
      loadLogs();
    } else {
      manager.reloadShockerLogs?.call();
    }
  }


  
  bool needsToLoadLogsOnStart() {
    if(!AlarmListManager.supportsWs()) {
      return true;
    }
    for (var shocker in shockers) {
      if(manager.shockerLog[shocker.id] == null) {
        return true;
      }
    }
    return false;
  }

  Future<void> loadLogs() async {
    List<ShockerLog> newLogs = [];
    for (var shocker in shockers) {
      newLogs.addAll(await manager.getShockerLogs(shocker));
    }
    newLogs.sort((a, b) => b.createdOn.compareTo(a.createdOn));
    if(!mounted) return;
    setState(() {
      logs = newLogs;
      initialLoading = false;
    });
  }

  ShockerLogStats showStats() {
    ShockerLogStats s = ShockerLogStats(themeData: Theme.of(context));
    s.addLogs(logs);
    s.doStats();
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