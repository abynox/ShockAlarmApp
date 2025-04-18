import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/screens/logs/shocker_log_entry.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/screens/tools/bottom/shocker_unpause_dialog.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/screens/logs/logs.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class BottomScreen extends StatefulWidget {
  const BottomScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _BottomScreenState();
}

class _BottomScreenState extends State<BottomScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _scaleAnimation;
  bool pausingShockers = false;
  List<ShockerLog> logs = [];

  @override
  void initState() {
    super.initState();
    if(!AlarmListManager.getInstance().hasValidAccount()) {
      ErrorDialog.show("Not logged in", "The Bottom screen requires being logged in to show useful information. Please log in to your account.");
      return;
    }
    AlarmListManager.getInstance().reloadShockerLogs = updateLogs;
    updateLogs();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true); // Makes it "breathe"

    _colorAnimation = ColorTween(
      begin: Colors.green,
      end: Colors.greenAccent,
    ).animate(_controller);
    _scaleAnimation = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    WakelockPlus.enable();
  }

  void updateLogs() async {
    List<ShockerLog> newLogs = [];
    for (var shockerId in AlarmListManager.getInstance().shockerLog.keys) {
      newLogs
          .addAll(AlarmListManager.getInstance().shockerLog[shockerId] ?? []);
    }
    newLogs.sort((a, b) => b.createdOn.compareTo(a.createdOn));
    setState(() {
      logs = newLogs;
    });
  }

  @override
  void deactivate() {
    // TODO: implement deactivate
    WakelockPlus.disable();

    _controller.dispose();
    super.deactivate();
  }

  int requiredShockers = 0;
  int doneShockers = 0;

  bool eStopActive() {
    for (var shocker in AlarmListManager.getInstance().shockers) {
      if (!shocker.isOwn) continue;
      if (!shocker.paused) return false;
    }
    return true;
  }

  void eStop() {
    // Pause all shockers
    requiredShockers = 0;
    doneShockers = 0;
    pausingShockers = true;
    for (var shocker in AlarmListManager.getInstance().shockers) {
      if (!shocker.isOwn) continue;
      requiredShockers++;
      OpenShockClient()
          .setPauseStateOfShocker(shocker, AlarmListManager.getInstance(), true)
          .then((error) {
        doneShockers++;
        if (error != null) {
          ErrorDialog.show("Error pausing shocker ${shocker.name}", error);
        } else if (doneShockers == requiredShockers) {
          setState(() {
            pausingShockers = false;
          });
        }
      });
    }
  }

  void unpause() async {
    List<Shocker> toUnpause = [];
    await showDialog(
        context: context, builder: (context) => ShockerUnpauseDialog());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    // This will allow for bottoms to see their logs as well as having a big stop button that pauses all their shockers.
    return Scaffold(
      appBar: AppBar(
        title: Text('Bottom Screen'),
      ),
      body: Center(
          child: PagePadding(
              child: ConstrainedContainer(
                  child: LayoutBuilder(
                      builder: (context, constraints) => ConstrainedBox(
                            constraints: constraints,
                            child: Column(
                              children: [
                                Expanded(
                                    flex: 0,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 15),
                                      child: Text("Live Logs",
                                          style: t.textTheme.headlineMedium),
                                    )),
                                Expanded(
                                    flex: 6,
                                    child: logs.length == 0
                                        ? Text(
                                            "No logs yet",
                                            style: t.textTheme.headlineSmall,
                                          )
                                        : ListView.builder(
                                            itemCount: logs
                                                .length, // +1 for the button
                                            itemBuilder: (context, index) {
                                              final log = logs[
                                                  index]; // Adjust index since 0 is the button
                                              return ShockerLogEntry(
                                                log: log,
                                                key: ValueKey(log.id),
                                              );
                                            })),
                                eStopActive()
                                    ? Expanded(
                                        flex: 0,
                                        child: Column(
                                          children: [
                                            ElevatedButton(
                                                onPressed: unpause,
                                                child:
                                                    Text("Unpause shockers")),
                                            Padding(
                                              padding: PredefinedSpacing.paddingMedium(),
                                              child: AnimatedBuilder(
                                                  animation: _scaleAnimation,
                                                  builder: (context, child) =>
                                                      Transform.scale(
                                                          scale: _scaleAnimation
                                                              .value,
                                                          child:
                                                              AnimatedBuilder(
                                                                  animation:
                                                                      _colorAnimation,
                                                                  builder:
                                                                      (context,
                                                                          child) {
                                                                    return Text(
                                                                      "All shockers are paused - you are safe",
                                                                      style: t
                                                                          .textTheme
                                                                          .headlineLarge
                                                                          ?.copyWith(
                                                                              color: _colorAnimation.value),
                                                                    );
                                                                  }))),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Expanded(
                                        flex: 4,
                                        child: FilledButton(
                                          onPressed: eStop,
                                          child: pausingShockers
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                      CircularProgressIndicator()
                                                    ])
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.stop,
                                                      size: 50,
                                                    ),
                                                    Text(
                                                      'Emergency Stop',
                                                      style: TextStyle(
                                                          fontSize: 30),
                                                    )
                                                  ],
                                                ),
                                        )),
                              ],
                            ),
                          ))))),
    );
  }
}
