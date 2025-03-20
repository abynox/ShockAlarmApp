import 'dart:async';
import 'dart:ffi';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/dialogs/ErrorDialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class LiveControlSettings {
  bool loop = false;
  bool float = false;
}

class LiveControls extends StatefulWidget {
  ControlsContainer controlsContainer;
  void Function(ControlType type, int intensity) onSendLive;
  bool soundAllowed;
  bool vibrateAllowed;
  bool shockAllowed;
  int intensityLimit;
  LiveControlSettings settings;
  bool snapToZeroAfterDone;

  LiveControls(
      {super.key,
      required this.controlsContainer,
      required this.onSendLive,
      required this.soundAllowed,
      required this.vibrateAllowed,
      required this.shockAllowed,
      required this.intensityLimit,
      required this.settings,
      this.snapToZeroAfterDone = false});

  @override
  State<StatefulWidget> createState() => _LiveControlsState();
}

class _LiveControlsState extends State<LiveControls> {
  double posX = 100; // Initial X position
  double posY = 100; // Initial Y position
  ControlType type = ControlType.vibrate;
  bool connecting = false;

  void onLatency() {
    setState(() {});
  }

  void ensureConnection() async {
    setState(() {
      connecting = true;
    });
    ErrorContainer<bool> error = await AlarmListManager.getInstance()
        .connectToLiveControlGatewayOfSelectedShockers();
    if (error.error != null) {
      ErrorDialog.show("Error connecting to hubs", error.error!);
    }
    AlarmListManager.getInstance().liveControlGatewayConnections.values
        .forEach((element) {
      element.onLatency = onLatency;
    });
    setState(() {
      connecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(spacing: 10, children: [
      SegmentedButton<ControlType>(
        segments: [
          if (widget.shockAllowed)
            ButtonSegment(
                value: ControlType.shock,
                label:
                    OpenShockClient.getIconForControlType(ControlType.shock)),
          if (widget.vibrateAllowed)
            ButtonSegment(
                value: ControlType.vibrate,
                label:
                    OpenShockClient.getIconForControlType(ControlType.vibrate)),
          if (widget.soundAllowed)
            ButtonSegment(
                value: ControlType.sound,
                label:
                    OpenShockClient.getIconForControlType(ControlType.sound)),
        ],
        selected: {type},
        onSelectionChanged: (Set<ControlType> newSelection) {
          if (newSelection.isNotEmpty) {
            setState(() {
              type = newSelection.first;
            });
          }
        },
      ),
      !AlarmListManager.getInstance().areSelectedShockersConnected()
          ? Column(
              children: [
                connecting
                    ? CircularProgressIndicator()
                    : FilledButton(
                        onPressed: ensureConnection,
                        child: Text("Connect to hubs")),
              ],
            )
          : Column(
              children: [
                Row(children: [
                  Text("Latency: "),
                  ...AlarmListManager.getInstance().liveControlGatewayConnections.entries
                      .map((e) => Text("${AlarmListManager.getInstance().getHub(e.key)?.name}: ${e.value.getLatency()} ms, "))
                      .toList()
                ],),
                Row(
                  spacing: 10,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Switch(
                        value: widget.settings.loop,
                        onChanged: (value) {
                          setState(() {
                            widget.settings.loop = value;
                          });
                        }),
                    Text("Loop"),
                    Switch(
                        value: widget.settings.float,
                        onChanged: (value) {
                          setState(() {
                            widget.settings.float = value;
                          });
                        }),
                    Text("Float")
                  ],
                ),
                DraggableCircle(
                  loop: widget.settings.loop,
                  float: widget.settings.float,
                  onSendLive: (intensity) {
                    widget.onSendLive(type, intensity);
                  },
                  respondInterval: 50,
                  intensityLimit: widget.intensityLimit,
                )
              ],
            )
    ]);
  }
}

class DraggableCircle extends StatefulWidget {
  double height = 300;
  double width = 300;
  Color graphColor = Colors.blue;
  double circleDiameter = 50;
  double respondInterval = 100;
  bool loop = true;
  bool float = false;
  int intensityLimit = 100;
  void Function(int intensity) onSendLive;

  DraggableCircle(
      {super.key,
      this.height = 300,
      this.width = 300,
      this.graphColor = Colors.blue,
      this.circleDiameter = 50,
      this.respondInterval = 100,
      required this.onSendLive,
      this.intensityLimit = 100,
      this.loop = true,
      this.float = false});

  @override
  _DraggableCircleState createState() => _DraggableCircleState();
}

class _DraggableCircleState extends State<DraggableCircle> {
  double posX = 100; // Initial X position
  double posY = 100; // Initial Y position
  double value = 0;

  int startMs = 0;
  late Timer timer;

  Map<int, double> lastStroke = {};
  List<FlSpot> samples = [];
  List<FlSpot> verticalLines = [];
  int sampleLimitCount = 100;
  double xValue = 0;
  double step = 1;
  int lastResponse = 0;
  bool sentZero = false;

  @override
  void dispose() {
    // TODO: implement dispose
    timer.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < sampleLimitCount; i++) {
      samples.add(FlSpot(i.toDouble(), 0));
    }
    setValue(0);
    timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (onTick != null) {
        onTick!();
      }
      setState(() {
        for (int i = 0; i < sampleLimitCount - 1; i++) {
          samples[i] = FlSpot(i.toDouble(), samples[i + 1].y);
        }
        for (int i = 0; i < verticalLines.length; i++) {
          verticalLines[i] =
              FlSpot(verticalLines[i].x - step, verticalLines[i].y);
          if (verticalLines[i].x < 0) {
            verticalLines.removeAt(i);
          }
        }
        samples[sampleLimitCount - 1] =
            FlSpot(sampleLimitCount.toDouble(), value.toDouble());
      });
      xValue += step;
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastResponse > widget.respondInterval) {
        lastResponse = now;

        if(sentZero && value.toInt() == 0) return; // don't spam the ws when not active
        widget.onSendLive(value.toInt());
        sentZero = value.toInt() == 0;
      }
    });
  }

  void spawnVerticalLine() {
    verticalLines.add(FlSpot(sampleLimitCount.toDouble(),
        DateTime.now().millisecondsSinceEpoch.toDouble()));
  }

  void checkBounds() {
    posX = max(0, min(widget.width - widget.circleDiameter, posX));
    posY = max(0, min(widget.height - widget.circleDiameter, posY));
    updateValue();
  }

  void updateValue() {
    value = ((1 - posY / (widget.height - widget.circleDiameter)) *
        widget.intensityLimit);
  }

  double getYForValue(int value) {
    return (1 - (value / widget.intensityLimit)) *
        (widget.height - widget.circleDiameter);
  }

  void setValue(int value) {
    setState(() {
      posY = getYForValue(value);
      checkBounds();
    });
  }

  @override
  void didUpdateWidget(covariant DraggableCircle oldWidget) {
    if(oldWidget.float && !widget.float) {
      setValue(0);
    }
    if(oldWidget.loop && !widget.loop) {
      onTick = null;
      setValue(0);
    }
    super.didUpdateWidget(oldWidget);
  }

  Function? onTick;

  int lookStrokeStart = 0;
  void loopStroke() {
    if (lastStroke.isEmpty) return;
    int now = DateTime.now().millisecondsSinceEpoch;
    int elapsed = now - lookStrokeStart;
    if (elapsed > lastStroke.keys.last) {
      lookStrokeStart = now;
      spawnVerticalLine();
      return;
    }
    int next = lastStroke.keys.firstWhere((element) => element > elapsed,
        orElse: () => lastStroke.keys.last);
    setValue(lastStroke[next]!.toInt());
  }

  void update(details, {bool end = false, bool start = false}) {
    if (end) {

      lastStroke[DateTime.now().millisecondsSinceEpoch - startMs] = value;
      if(!widget.float) setValue(0);
      lookStrokeStart = DateTime.now().millisecondsSinceEpoch;
      if (widget.loop) {
        spawnVerticalLine();
        onTick = loopStroke;
      }
      return;
    }
    onTick = null;
    if (details == null) return;
    if (start) {
      startMs = DateTime.now().millisecondsSinceEpoch;
      lastStroke.clear();
    }
    setState(() {
      posX = details.localPosition.dx -
          widget.circleDiameter / 2; // Adjust for center
      posY = details.localPosition.dy - widget.circleDiameter / 2;
      checkBounds();
    });

    // save stroke data point
    lastStroke[DateTime.now().millisecondsSinceEpoch - startMs] = value;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return GestureDetector(
        onPanStart: (details) => update(details, start: true),
        onPanEnd: (details) {
          update(details, end: true);
        },
        onPanCancel: () {
          update(null, end: true);
        },
        onPanUpdate: update,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
              border: Border.all(color: t.colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(15)),
          child: Stack(
            children: [
              Center(
                  child: Text("Intensity\n${value.toInt().toString()}",
                      textAlign: TextAlign.center,
                      style: t.textTheme.headlineLarge?.copyWith(
                          color: Color(0x22FFFFFF),
                          fontSize: widget.width / 5))),
              Positioned(
                left: posX,
                top: posY,
                child: Container(
                  width: widget.circleDiameter,
                  height: widget.circleDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.colorScheme.tertiary, width: 3),
                  ),
                  child: Center(child: Text(value.toInt().toString())),
                ),
              ),
              if (samples.isNotEmpty)
                LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: widget.intensityLimit.toDouble(),
                    minX: 0,
                    maxX: sampleLimitCount.toDouble(),
                    extraLinesData: ExtraLinesData(
                        verticalLines: verticalLines.map((element) {
                      return VerticalLine(
                        x: element.x,
                        color: t.colorScheme.secondary,
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      );
                    }).toList()),
                    lineTouchData: const LineTouchData(enabled: false),
                    clipData: const FlClipData.all(),
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: samples,
                        dotData: const FlDotData(
                          show: false,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            widget.graphColor.withValues(alpha: 0),
                            widget.graphColor
                          ],
                          stops: const [0.1, 0.5],
                        ),
                        barWidth: 4,
                        isCurved: false,
                      )
                    ],
                    titlesData: const FlTitlesData(
                      show: false,
                    ),
                  ),
                  key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                ),
            ],
          ),
        ));
  }
}
