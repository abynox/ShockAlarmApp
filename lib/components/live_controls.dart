import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/dialogs/ErrorDialog.dart';
import 'package:shock_alarm_app/dialogs/InfoDialog.dart';
import 'package:shock_alarm_app/screens/pattern_chooser.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class LiveControlSettings {
  bool loop = false;
  bool float = false;
}

class LivePattern {
  int id = -1;
  Map<int, double> pattern = {};
  String name = "";

  LivePattern();

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "pattern": pattern.map((key, value) =>
          MapEntry(key.toString(), value)), // Convert int keys to String
      "name": name
    };
  }

  LivePattern.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    pattern = (json["pattern"] as Map<String, dynamic>).map((key, value) =>
        MapEntry(int.parse(key),
            (value as num).toDouble())); // Convert keys back to int
    name = json["name"];
  }

  double? maxTime;

  double getMaxTime() {
    if (maxTime != null) return maxTime!;
    maxTime = pattern.keys.reduce(max).toDouble();
    return maxTime!;
  }
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
  
  Function(ControlType, int, int)? liveEventDone;

  LiveControls(
      {super.key,
      required this.controlsContainer,
      required this.onSendLive,
      required this.soundAllowed,
      required this.vibrateAllowed,
      required this.shockAllowed,
      required this.intensityLimit,
      required this.settings,
      this.liveEventDone,
      this.snapToZeroAfterDone = false});

  @override
  State<StatefulWidget> createState() => _LiveControlsState();
}

class _LiveControlsState extends State<LiveControls> {
  double posX = 100; // Initial X position
  double posY = 100; // Initial Y position
  ControlType type = ControlType.vibrate;
  bool connecting = false;

  LivePattern pattern = LivePattern();

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
    AlarmListManager.getInstance()
        .liveControlGatewayConnections
        .values
        .forEach((element) {
      element.onLatency = onLatency;
    });
    setState(() {
      connecting = false;
    });
  }

  bool isSavedPattern() {
    return pattern.id != -1;
  }

  bool isPlaying = false;

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
                Row(
                  children: [
                    IconButton(
                        onPressed: () {
                          InfoDialog.show("Live controls",
                              "Live control offers low latency controlling of your shocker with many events per second.\n\nHere you simply swipe in the area to control shockers in real time.\n\nFurthermore you can record patterns: A pattern is automatically recorded from when you touch the area until you release it. You can then save the pattern and play it back. Enabling loop will infinitely repeat the pattern once your finger is lifet off. Enabling float will make the intensity remain where it is when you lift your finger off.\n\n\nTo load a saved pattern click the load icon and tap on it. You'll see a preview of the pattern in the control box then. Press play to play the pattern then.");
                        },
                        icon: Icon(Icons.info)),
                    Text("Latency: "),
                    ...AlarmListManager.getInstance()
                        .liveControlGatewayConnections
                        .entries
                        .map((e) => Text(
                            "${AlarmListManager.getInstance().getHub(e.key)?.name}: ${e.value.getLatency()} ms, "))
                        .toList()
                  ],
                ),
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
                    if (!isSavedPattern())
                      Switch(
                          value: widget.settings.float,
                          onChanged: (value) {
                            setState(() {
                              widget.settings.float = value;
                            });
                          }),
                    if (!isSavedPattern()) Text("Float"),
                    if (isSavedPattern())
                      IconButton(
                          onPressed: () {
                            setState(() {
                              isPlaying = !isPlaying;
                            });
                          },
                          icon:
                              Icon(isPlaying ? Icons.pause : Icons.play_arrow)),
                    if (!isSavedPattern())
                      IconButton(
                          onPressed: savePattern, icon: Icon(Icons.save)),
                    IconButton(
                        onPressed: loadPattern, icon: Icon(Icons.pattern))
                  ],
                ),
                DraggableCircle(
                  loop: widget.settings.loop,
                  float: widget.settings.float,
                  onSendLive: (intensity) {
                    widget.onSendLive(type, intensity);
                  },
                  onPlayDone: () {
                    setState(() {
                      isPlaying = false;
                    });
                  },
                  isPlaying: isPlaying,
                  pattern: pattern,
                  logEvent: (duration, intensity) => widget.liveEventDone?.call(type, duration, intensity),
                  respondInterval: 50,
                  intensityLimit: widget.intensityLimit,
                )
              ],
            )
    ]);
  }

  void loadPattern() {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return PatternChooser(onPatternSelected: (pattern) {
        setState(() {
          this.pattern = pattern;
        });
      });
    }));
  }

  void savePattern() {
    TextEditingController nameController = TextEditingController();
    if (pattern.pattern.isEmpty) {
      ErrorDialog.show("Pattern is empty",
          "A pattern is recorded from the moment you start dragging the circle. Please move the circle to record a pattern.");
      return;
    }
    showDialog(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Save pattern?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Do you want to save the current pattern?"),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: "Pattern name"),
                  ),
                  Container(
                    width: 200,
                    height: 200,
                    child: PatternPreview(pattern: pattern),
                  )
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("Close")),
                TextButton(
                    onPressed: () {
                      pattern.name = nameController.text;
                      pattern.id =
                          AlarmListManager.getInstance().getNewLivePatternId();
                      AlarmListManager.getInstance().saveLivePattern(pattern);
                      pattern = LivePattern();
                      Navigator.pop(context);
                    },
                    child: Text("Save pattern"))
              ],
            ));
  }
}

class PatternPreview extends StatelessWidget {
  LivePattern pattern;
  double aspectRation;

  PatternPreview({required this.pattern, this.aspectRation = 4 / 3});

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return AspectRatio(
      aspectRatio: aspectRation,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: pattern.pattern.keys.last.toDouble(),
          lineTouchData: const LineTouchData(enabled: false),
          clipData: const FlClipData.all(),
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: pattern.pattern.entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value);
              }).toList(),
              dotData: const FlDotData(
                show: false,
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
    );
  }
}

class DraggableCircle extends StatefulWidget {
  double height = 300;
  double width = 300;
  Color graphColor = Colors.blue;
  Color graphPreviewColor = Colors.lightBlue;
  double circleDiameter = 50;
  double respondInterval = 100;
  bool loop = true;
  bool float = false;
  bool isPlaying = false;
  int intensityLimit = 100;
  LivePattern pattern;
  void Function(int intensity) onSendLive;
  Function()? onPlayDone;
  Function(int, int)? logEvent;

  DraggableCircle(
      {super.key,
      this.height = 300,
      this.width = 300,
      this.graphColor = Colors.blue,
      this.circleDiameter = 50,
      this.respondInterval = 100,
      required this.onSendLive,
      this.intensityLimit = 100,
      required this.pattern,
      this.loop = true,
      this.float = false,
      this.isPlaying = false,
      this.logEvent,
      this.onPlayDone});

  @override
  _DraggableCircleState createState() => _DraggableCircleState();
}

class _DraggableCircleState extends State<DraggableCircle> {
  double posX = 100; // Initial X position
  double posY = 100; // Initial Y position
  double value = 0;

  int startMs = 0;
  late Timer timer;

  List<FlSpot> samples = [];
  List<FlSpot> verticalLines = [];
  int sampleLimitCount = 100;
  int lastResponse = 0;
  bool sentZero = false;
  bool notifiedEnd = false;
  int maxIntensity = 0;
  int? logTimeStart;

  @override
  void dispose() {
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
          verticalLines[i] = FlSpot(verticalLines[i].x - 1, verticalLines[i].y);
          if (verticalLines[i].x < 0) {
            verticalLines.removeAt(i);
          }
        }
        samples[sampleLimitCount - 1] =
            FlSpot(sampleLimitCount.toDouble(), value.toDouble());
      });
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastResponse > widget.respondInterval) {
        lastResponse = now;
        if (sentZero && value.toInt() == 0) {
          if(!notifiedEnd) {
            notifiedEnd = true;
            int lengthInMs = logTimeStart == null ? 0 : now - logTimeStart!;
            if(maxIntensity != 0) widget.logEvent?.call(lengthInMs, maxIntensity);
            maxIntensity = 0;
            logTimeStart = null;
          }
          return; // don't spam the ws when not active
        }
        logTimeStart ??= now;
        notifiedEnd = false;
        if(value > maxIntensity) maxIntensity = value.toInt();
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
    if (oldWidget.float && !widget.float) {
      setValue(0);
    }
    if (oldWidget.loop && !widget.loop) {
      onTick = null;
      setValue(0);
    }
    if (!oldWidget.isPlaying && widget.isPlaying) {
      startPlay();
    }
    if (oldWidget.isPlaying && !widget.isPlaying) {
      onTick = null;
      setValue(0);
    }
    super.didUpdateWidget(oldWidget);
  }

  Function? onTick;

  int lookStrokeStart = 0;
  void loopStroke() {
    if (widget.pattern.pattern.isEmpty) return;
    int now = DateTime.now().millisecondsSinceEpoch;
    int elapsed = now - lookStrokeStart;
    if (elapsed > widget.pattern.pattern.keys.last) {
      if (!widget.loop) {
        onTick = null;
        setValue(0);
        widget.onPlayDone?.call();
        return;
      }
      lookStrokeStart = now;
      spawnVerticalLine();
      return;
    }
    int next = widget.pattern.pattern.keys.firstWhere(
        (element) => element > elapsed,
        orElse: () => widget.pattern.pattern.keys.last);
    setValue(widget.pattern.pattern[next]!.toInt());
  }

  void startPlay() {
    spawnVerticalLine();
    lookStrokeStart = DateTime.now().millisecondsSinceEpoch;
    onTick = loopStroke;
  }

  void update(details, {bool end = false, bool start = false}) {
    if (widget.pattern.id != -1) return;
    if (end) {
      widget.pattern.pattern[DateTime.now().millisecondsSinceEpoch - startMs] =
          value;
      if (!widget.float) setValue(0);
      if (widget.loop) {
        startPlay();
      }
      return;
    }
    onTick = null;
    if (details == null) return;
    if (start) {
      startMs = DateTime.now().millisecondsSinceEpoch;
      widget.pattern.pattern.clear();
    }
    setState(() {
      posX = details.localPosition.dx -
          widget.circleDiameter / 2; // Adjust for center
      posY = details.localPosition.dy - widget.circleDiameter / 2;
      checkBounds();
    });

    // save stroke data point
    widget.pattern.pattern[DateTime.now().millisecondsSinceEpoch - startMs] =
        value;
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
                    extraLinesData: ExtraLinesData(verticalLines: [
                      if (widget.pattern.id != -1)
                        VerticalLine(
                          x: (DateTime.now().millisecondsSinceEpoch -
                                      lookStrokeStart) / widget.pattern.getMaxTime() * 100,
                          color: t.colorScheme.tertiary,
                          strokeWidth: 1,
                          dashArray: [5, 15],
                        ),
                      ...verticalLines.map((element) {
                        return VerticalLine(
                          x: element.x,
                          color: t.colorScheme.secondary,
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        );
                      }).toList()
                    ]),
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
                      ),
                      if (widget.pattern.id != -1)
                        LineChartBarData(
                          spots: widget.pattern.pattern.entries.map((e) {
                            return FlSpot(
                                e.key.toDouble() /
                                    widget.pattern.getMaxTime() *
                                    100,
                                e.value);
                          }).toList(),
                          dotData: const FlDotData(
                            show: false,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              widget.graphPreviewColor.withValues(alpha: 0.2)
                            ],
                            stops: const [0.1],
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
