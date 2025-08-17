import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/screens/logs/shocker_log_entry.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/logs/logs.dart';
import 'package:shock_alarm_app/screens/shares/shares.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/stores/shocker_log_stats.dart';

import '../../../components/constrained_container.dart';
import '../../../services/openshock.dart';

class LogStatScreen extends StatefulWidget {
  List<Shocker> shockers;
  LogScreenState state;
  ShockerLogStats stats;

  LogStatScreen(
      {Key? key,
      required this.shockers,
      required this.stats,
      required this.state})
      : super(key: key);
  @override
  _LogStatScreenState createState() => _LogStatScreenState();
}

class _LogStatScreenState extends State<LogStatScreen> {
  @override
  void initState() {
    widget.state.reloadShockerLogs = () {
      rebuildStats();
    };
    super.initState();
  }

  void rebuildStats() {
    widget.stats.clear();
    for (var shocker in widget.shockers) {
      widget.stats
          .addLogs(AlarmListManager.getInstance().shockerLog[shocker.id] ?? []);
    }
    widget.stats.doStats();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            spacing: 10,
            children: [
              Text(
                  'Stats for ${widget.shockers.map((x) => x.name).join(", ")}'),
            ],
          ),
        ),
        bottomNavigationBar: Container(
            child: Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 10,
            alignment: WrapAlignment.center,
            children: widget.stats.users.entries
                .map((user) {
                  return FilterChip(
                      selected: widget.stats.selectedUsers.contains(user.key),
                      onSelected: (selected) {
                        if (selected) {
                          widget.stats.selectedUsers.add(user.key);
                        } else {
                          widget.stats.selectedUsers.remove(user.key);
                        }
                        rebuildStats();
                      },
                      label: Text(user.value.name),
                      avatar: CircleAvatar(
                        backgroundColor: user.value.color,
                      ));
                })
                .toList()
                .reversed
                .toList(),
          ),
        )),
        body: Padding(
            padding: const EdgeInsets.only(
              bottom: 15,
              left: 15,
              right: 15,
              top: 50,
            ),
            child: ConstrainedContainer(
                child: ListView(children: [
              FilledButton(
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          TextEditingController controller =
                              TextEditingController();
                          controller.text = "200";

                          return AlertDialog.adaptive(
                            title: Text("Load more"),
                            content: SingleChildScrollView(
                                child: Column(children: [
                              Text(
                                  "How many logs do you want to load (up to 300)?"),
                              TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                              )
                            ])),
                            actions: [
                              TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text("Close")),
                              TextButton(
                                  onPressed: () async {
                                    if (int.tryParse(controller.text) != null) {
                                      int limit = int.parse(controller.text);
                                      if (limit > 300) {
                                        limit = 300;
                                      }
                                      widget.stats.clear();
                                      LoadingDialog.show("Loading logs");
                                      for (var shocker in widget.shockers) {
                                        widget.stats.addLogs(
                                            await AlarmListManager.getInstance()
                                                .getShockerLogs(shocker,
                                                    limit: limit));
                                      }
                                      widget.stats.doStats();
                                      setState(() {});
                                      Navigator.of(context).pop();
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: Text("Load"))
                            ],
                          );
                        });
                  },
                  child: Text("Load more")),
                  
          PredefinedSpacing(),
              Text(
                "Data based on ${widget.stats.logs.length} logs from ${ShockerLogEntry.formatDateTime(widget.stats.minDate, alwaysShowDate: true)} to ${ShockerLogEntry.formatDateTime(widget.stats.maxDate, alwaysShowDate: true)}",
                style: Theme.of(context).textTheme.headlineSmall,
              ),

          PredefinedSpacing(),              ...widget.stats.shockDistribution.entries.map((controlType) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [
                        Text("Total",
                            style: Theme.of(context).textTheme.headlineLarge),
                        OpenShockClient.getIconForControlType(controlType.key,
                            size: 30),
                      ],
                    ),
                    AspectRatio(
                        aspectRatio: 1 / 1,
                        child: Container(
                            child: BarChart(
                                key: ValueKey(
                                    DateTime.now().microsecondsSinceEpoch),
                                BarChartData(
                                  gridData: FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                      topTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                        showTitles: false,
                                      )),
                                      rightTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                        showTitles: false,
                                      )),
                                      leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 70,
                                        getTitlesWidget: (value, meta) => Text(
                                            value
                                                    .toStringAsFixed(1)
                                                    .toString() +
                                                "s"),
                                      ))),
                                  barGroups: controlType.value.total.entries
                                      .map((entry) {
                                    double runningTotal = 0;
                                    List<BarChartRodStackItem> rods = [];
                                    for (var user
                                        in entry.value.users.entries) {
                                      double value =
                                          user.value.toDouble() / 1000;
                                      rods.add(BarChartRodStackItem(
                                          runningTotal,
                                          runningTotal + value,
                                          widget.stats.users[user.key]!.color));
                                      runningTotal += value;
                                    }

                                    return BarChartGroupData(
                                        x: entry.key,
                                        barRods: [
                                          BarChartRodData(
                                              toY: runningTotal,
                                              rodStackItems: rods)
                                        ]);
                                  }).toList(),
                                )))),
                    Padding(padding: PredefinedSpacing.paddingExtraLarge()),
                  ],
                );
              }).toList(),
            ]))));
  }
}
