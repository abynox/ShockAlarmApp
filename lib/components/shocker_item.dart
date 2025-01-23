import 'dart:math';

import 'package:flutter/material.dart';
import '../screens/logs.dart';
import '../screens/shares.dart';
import '../stores/alarm_store.dart';
import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class ShockerAction {
  String name;
  Function(AlarmListManager, Shocker, BuildContext, Function) onClick;
  Icon icon;

  ShockerAction({this.name = "Action", required this.onClick, required this.icon});
}

class ShockerItem extends StatefulWidget {
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;
  static List<ShockerAction> ownShockerActions = [
    ShockerAction(name: "Rename", icon: Icon(Icons.edit), onClick: (AlarmListManager manager, Shocker shocker, BuildContext context, Function onRebuild) {
      TextEditingController controller = TextEditingController();
      controller.text = shocker.name;
      showDialog(context: context, builder: (context) => AlertDialog(
        title: Text("Rename shocker"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: "Name"
          ),
        ),
        actions: [
          TextButton(onPressed: () {
            Navigator.of(context).pop();
          }, child: Text("Cancel")),
          TextButton(onPressed: () async {
            showDialog(context: context, builder: (context) => LoadingDialog(title: "Renaming shocker"));
            String? errorMessage = await manager.renameShocker(shocker, controller.text);
            Navigator.of(context).pop();
            if(errorMessage != null) {
              showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to rename shocker"), content: Text(errorMessage), actions: [TextButton(onPressed: () {
                Navigator.of(context).pop();
              }, child: Text("Ok"))],));
              return;
            }
            Navigator.of(context).pop();
            onRebuild();
          
          }, child: Text("Rename"))
        ],
      ));
    }),

    ShockerAction(name: "Logs", icon: Icon(Icons.list), onClick: (AlarmListManager manager, Shocker shocker, BuildContext context, Function onRebuild) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => LogScreen(shocker: shocker, manager: manager)));
    }),

    ShockerAction(name: "Shares", icon: Icon(Icons.share), onClick: (AlarmListManager manager, Shocker shocker, BuildContext context, Function onRebuild) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => SharesScreen(shocker: shocker, manager: manager)));
    }),

    ShockerAction(name: "Delete", icon: Icon(Icons.delete), onClick: (AlarmListManager manager, Shocker shocker, BuildContext context, Function onRebuild) {
      showDialog(context: context, builder: (context) => AlertDialog(title: Text("Delete shocker"), content: Text("Are you sure you want to delete the shocker ${shocker.name}?\n\n(You can add it again later)"), actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Cancel")),
        TextButton(onPressed: () async {
          String? errorMessage = await manager.deleteShocker(shocker);
          if(errorMessage != null) {
            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to delete shocker"), content: Text(errorMessage), actions: [TextButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: Text("Ok"))],));
            return;
          }
          Navigator.of(context).pop();
          onRebuild();
        }, child: Text("Delete"))
      ],));   
    }),
  ];

  static List<ShockerAction> foreignShockerActions = [
    ShockerAction(onClick: (AlarmListManager manager, Shocker shocker, BuildContext context, Function onRebuild) {
      showDialog(context: context, builder: (context) => AlertDialog(title: Text("Unlink shocker"), content: Text("Are you sure you want to unlink the shocker ${shocker.name} from your account? After that you cannot control the shocker anymore unless you redeem another share code."), actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Cancel")),
        TextButton(onPressed: () async {
          showDialog(context: context, builder: (context) {
            return LoadingDialog(title: "Unlinking shocker");
          });
          String? errorMessage;
          Token? token = manager.getToken(shocker.apiTokenId);
          if(token == null) errorMessage = "Token not found";
          else {
            OpenShockShare share = OpenShockShare()
                                  ..sharedWith = (OpenShockUser()..id = token.userId)
                                  ..shockerReference = shocker;
            errorMessage = await manager.deleteShare(share);
          }
          if(errorMessage != null) {
            Navigator.of(context).pop();
            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to delete share"), content: Text(errorMessage ?? "Unknown error"), actions: [TextButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: Text("Ok"))],));
            return;
          }
          await manager.updateShockerStore();
          Navigator.of(context).pop();
          Navigator.of(context).pop();
          onRebuild();
        }, child: Text("Unlink"))
      ],));
    }, icon: Icon(Icons.delete), name: "Unlink"),
  ];

  const ShockerItem({Key? key, required this.shocker, required this.manager, required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerItemState(shocker, manager, onRebuild);
}

class ShockerItemState extends State<ShockerItem> with TickerProviderStateMixin {
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;
  bool delayVibrationEnabled = false;

  DateTime actionDoneTime = DateTime.now();
  DateTime delayDoneTime = DateTime.now();
  double delayDuration = 0;
  AnimationController? progressCircularController;
  AnimationController? delayVibrationController;
  bool loadingPause = false;


  int currentIntensity = 25;
  int currentDuration = 1000;
  RangeValues rangeValues = RangeValues(0, 0);

  @override
  void initState() {
    super.initState();
    currentIntensity = min(shocker.intensityLimit, currentIntensity);
    currentDuration = min(shocker.durationLimit, currentDuration);
  }

  @override
  void dispose() {
    progressCircularController?.dispose();
    super.dispose();
  }

  void setPauseState(bool pause) async {
    setState(() {
      loadingPause = true;
    });
    String? error = await OpenShockClient().setPauseStateOfShocker(shocker, manager, pause);
    setState(() {
      loadingPause = false;
    });
    if(error != null) {
      showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to pause shocker"), content: Text(error), actions: [TextButton(onPressed: () {
        Navigator.of(context).pop();
      }, child: Text("Ok"))],));
      return;
    }
  }
  
  ShockerItemState(this.shocker, this.manager, this.onRebuild);
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<ShockerAction> actions = shocker.isOwn ? ShockerItem.ownShockerActions : ShockerItem.foreignShockerActions;
    return GestureDetector(
      /*
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  EditAlarm(alarm: this.alarm, manager: manager))),
                  */
      child: GestureDetector(
        onTap: () => {
          setState(() {
            if(shocker.paused) return;
            expanded = !expanded;
          })
        },
        child:
          Card(
            color: t.colorScheme.onInverseSurface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                            Expanded(child: 
                              Text(
                              shocker.name,
                                style: t.textTheme.headlineSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ),
                      
                      Row(
                        spacing: 5,
                        children: [
                          PopupMenuButton(iconColor: t.colorScheme.onSurfaceVariant, itemBuilder: (context) {
                            return [
                              for(ShockerAction a in actions) PopupMenuItem(value: a.name, child: Row(
                                spacing: 10,
                                children: [
                                a.icon,
                                Text(a.name)
                              ],)),
                          ];
                        }, onSelected: (String value) {
                          for(ShockerAction a in actions) {
                            if(a.name == value) {
                              a.onClick(manager, shocker, context, onRebuild);
                              return;
                            }
                          }
                        },),
                        if(loadingPause)
                          CircularProgressIndicator(),
                        if(shocker.isOwn && shocker.paused && !loadingPause)
                          IconButton(onPressed: () {
                            setPauseState(false);
                          }, icon: Icon(Icons.play_arrow)),
                        if(shocker.isOwn && !shocker.paused && !loadingPause)
                          IconButton(onPressed: () {
                            expanded = false;
                            setPauseState(true);
                          }, icon: Icon(Icons.pause)),

                        if (shocker.paused && !shocker.isOwn)
                        GestureDetector( child: Chip(
                            label: Text("paused"),
                            backgroundColor: t.colorScheme.errorContainer,
                            side: BorderSide.none,
                            avatar: Icon(Icons.info, color: t.colorScheme.error,)
                          ),
                          onTap: () {
                            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Shocker is paused"), content: Text(shocker.isOwn ?
                            "This shocker was pause by you. While it's paused you cannot control it. You can unpause it by pressing the play button." 
                            : "This shocker was paused by the owner. While it's paused you cannot control it. You can ask the owner to unpause it."),
                            actions: [TextButton(onPressed: () {
                              Navigator.of(context).pop();
                            }, child: Text("Ok"))],));
                          },),
                        if (!shocker.paused)
                          IconButton(onPressed: () {setState(() {
                            expanded = !expanded;
                          });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)),
                      ],)
                    ],
                  ),
                  if(expanded)
                    ShockingControls(manager: manager, currentDuration: currentDuration, currentIntensity: currentIntensity,
                      durationLimit: shocker.durationLimit, intensityLimit: shocker.intensityLimit,
                      shockAllowed: shocker.shockAllowed, vibrateAllowed: shocker.vibrateAllowed, soundAllowed: shocker.soundAllowed,
                      onDelayAction: (type, intensity, duration) {
                        manager.sendShock(type, shocker, intensity, duration).then((errorMessage) {
                          if(errorMessage == null) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(errorMessage),
                            duration: Duration(seconds: 3),
                          ));
                        });
                      },
                      onProcessAction: (type, intensity, duration) {

                        manager.sendShock(type, shocker, intensity, duration).then((errorMessage) {
                          if(errorMessage == null) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(errorMessage),
                            duration: Duration(seconds: 3),
                          ));
                        });
                      },
                      onSet: (intensity, duration) {
                          setState(() {
                            currentDuration = duration;
                            currentIntensity = intensity;
                          });
                        },
                    )
                ],
              )
            ),
          ),
        ),
    );
  }
}

class IntensityDurationSelector extends StatefulWidget {
  final int duration;
  final int intensity;
  int maxDuration;
  int maxIntensity;
  bool showIntensity = true;
  ControlType type = ControlType.shock;
  final Function(int, int) onSet;

  IntensityDurationSelector({Key? key, this.showIntensity = true, this.type = ControlType.shock, required this.duration, required this.intensity, required this.onSet, required this.maxDuration, required this.maxIntensity}) : super(key: key);

  @override
  State<StatefulWidget> createState() => IntensityDurationSelectorState(duration, intensity, onSet, this.maxDuration, this.maxIntensity, this.showIntensity, this.type);
}

class IntensityDurationSelectorState extends State<IntensityDurationSelector> {
  int maxDuration;
  int maxIntensity;
  int duration;
  int intensity;
  bool showIntensity;
  ControlType type = ControlType.shock;
  Function(int, int) onSet;


  IntensityDurationSelectorState(this.duration, this.intensity, this.onSet, this.maxDuration, this.maxIntensity, this.showIntensity, this.type);

  double cubicToLinear(double value) {
    return pow(value, 6/3).toDouble();
  }

  double linearToCubic(double value) {
    return pow(value,  3/6).toDouble();
  }

  double reverseMapDuration(double value) {
    if(maxDuration <= 300) return 0;
    return linearToCubic((value - 300) / (maxDuration - 300));
  }

  int mapDuration(double value) {
    return 300 + (cubicToLinear(value) * (maxDuration - 300) / 100).toInt() * 100;
  }

  @override
  Widget build(BuildContext context) {
    intensity = min(intensity, maxIntensity);
    duration = min(duration, maxDuration);
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        if(showIntensity)
          Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10,children: [
            OpenShockClient.getIconForControlType(type),
            Text("Intensity: $intensity", style: t.textTheme.headlineSmall,),
          ],),
        if(showIntensity)
          Slider(value: intensity.toDouble(), max: maxIntensity.toDouble(), onChanged: (double value) {
            setState(() {
              intensity = value.toInt();
              onSet(intensity, duration);
            });
          }),
        Row(
          mainAxisAlignment: MainAxisAlignment.center, spacing: 10,
          children: [
            Icon(Icons.timer),
            Text("Duration: ${duration / 1000.0}", style: t.textTheme.headlineSmall,),
          ],),
        Slider(value: reverseMapDuration(duration.toDouble()), max: 1, onChanged: (double value) {
          setState(() {
            duration = mapDuration(value);
            onSet(showIntensity ? intensity : 1, duration);
          });
        }),
      ],
    );
  }

}

class ShockingControls extends StatefulWidget {
  final AlarmListManager manager;
  int currentDuration;
  int currentIntensity;
  int durationLimit;
  int intensityLimit;
  bool soundAllowed;
  bool vibrateAllowed;
  bool shockAllowed;
  Function(ControlType type, int intensity, int duration) onDelayAction;
  Function(ControlType type, int intensity, int duration) onProcessAction;
  Function(int intensity, int duration) onSet;

  ShockingControls({Key? key, required this.manager, required this.currentDuration, required this.currentIntensity, required this.durationLimit, required this.intensityLimit, required this.soundAllowed, required this.vibrateAllowed, required this.shockAllowed, required this.onDelayAction, required this.onProcessAction, required this.onSet}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockingControlsState(this.manager, this.currentDuration, this.currentIntensity, this.durationLimit, this.intensityLimit, this.soundAllowed, this.vibrateAllowed, this.shockAllowed, this.onDelayAction, this.onProcessAction, this.onSet);
}

class ShockingControlsState extends State<ShockingControls> with TickerProviderStateMixin {
  AlarmListManager manager;
  int currentDuration;
  int currentIntensity;
  int durationLimit;
  int intensityLimit;
  bool soundAllowed;
  bool vibrateAllowed;
  bool shockAllowed;
  Function(ControlType type, int intensity, int duration) onDelayAction;
  Function(ControlType type, int intensity, int duration) onProcessAction;
  Function(int intensity, int duration) onSet;

  DateTime actionDoneTime = DateTime.now();
  DateTime delayDoneTime = DateTime.now();
  double delayDuration = 0;
  AnimationController? progressCircularController;
  AnimationController? delayVibrationController;
  bool loadingPause = false;


  ShockingControlsState(this.manager, this.currentDuration, this.currentIntensity, this.durationLimit, this.intensityLimit, this.soundAllowed, this.vibrateAllowed,this.shockAllowed, this.onDelayAction, this.onProcessAction, this.onSet);

  @override
  void dispose() {
    progressCircularController?.dispose();
    delayVibrationController?.dispose();
    super.dispose();
  }

  void realAction(ControlType type) {
    if(type != ControlType.stop) {
      setState(() {
        actionDoneTime = DateTime.now().add(Duration(milliseconds: currentDuration));
        progressCircularController = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: currentDuration),
        )..addListener(() {
          setState(() {
            if(progressCircularController!.status == AnimationStatus.completed) {
              progressCircularController!.stop();
              progressCircularController = null;
            }
          });
        });
        progressCircularController!.forward();
      });
    }
    onProcessAction(type, currentIntensity, currentDuration);
  }

  void action(ControlType type) {
    if(type == ControlType.stop) {
      delayVibrationController?.stop();
      progressCircularController?.stop();
      setState(() {
        delayVibrationController = null;
        progressCircularController = null;
      });
      realAction(type);
      return;
    }
    // Get random delay based on range
    if(manager.delayVibrationEnabled) {
      // ToDo: make this duration adjustable
      onDelayAction(ControlType.vibrate, currentIntensity, 500);
    }
    delayDuration = manager.rangeValues.start + Random().nextDouble() * (manager.rangeValues.end - manager.rangeValues.start);
    if(delayDuration == 0) {
      realAction(type);
      return;
    }
    delayDoneTime = DateTime.now().add(Duration(milliseconds: (delayDuration * 1000).toInt()));
    delayVibrationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (delayDuration * 1000).toInt()),
    )..addListener(() {
      setState(() {
        if(delayVibrationController!.status == AnimationStatus.completed) {
          delayVibrationController!.stop();
          delayVibrationController = null;
          realAction(type);
        }
      });
    });
    delayVibrationController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    intensityLimit = widget.intensityLimit;
    return Column(
      children: [
        IntensityDurationSelector(duration: currentDuration, intensity: currentIntensity, maxDuration: durationLimit, maxIntensity: intensityLimit, onSet: onSet),
        // Delay options
        if(manager.settings.showRandomDelay)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 5,
            children: [
              Switch(value: manager.delayVibrationEnabled, onChanged: (bool value) {
                setState(() {
                  manager.delayVibrationEnabled = value;
                });
              },),
              Expanded(child: manager.settings.useRangeSliderForRandomDelay ? RangeSlider(
                values: manager.rangeValues,
                max: 10,
                min: 0,
                divisions: 10 * 3,
                labels: RangeLabels(
                  "${(manager.rangeValues.start * 10).round() / 10} s",
                  "${(manager.rangeValues.end * 10).round() / 10} s",
                ),
                onChanged: (RangeValues values) {
                setState(() {
                  manager.rangeValues = values;
                });
              }) : 
              Row(children: [
                Text("${(manager.rangeValues.start * 10).round() / 10} s"),
                Expanded(child: 
                  Slider(value: manager.rangeValues.start, min: 0, max: 10, onChanged: (double value) {
                    setState(() {
                      manager.rangeValues = RangeValues(value, manager.rangeValues.end);
                    });
                  }),
                )
                
              ],)
            ),
            
            GestureDetector(child: Icon(Icons.info,),
              onTap: () {
                showDialog(context: context, builder: (context) => AlertDialog(title: Text("Delay options"), content: Text("Here you can add a random delay when pressing a button by selecting a range. If you enable the switch before the slider you can send a vibration before the actual action happens."),
                actions: [
                  TextButton(onPressed: () {
                    Navigator.of(context).pop();
                }, child: Text("Ok"))]
                ,));
              },),
          ],),
        
        if(progressCircularController == null && delayVibrationController == null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              if(soundAllowed)
                IconButton(
                  icon: OpenShockClient.getIconForControlType(ControlType.sound),
                  onPressed: () {action(ControlType.sound);},
                ),
              if(vibrateAllowed)
                IconButton(
                  icon: OpenShockClient.getIconForControlType(ControlType.vibrate),
                  onPressed: () {action(ControlType.vibrate);},
                ),
              if(shockAllowed)
                IconButton(
                  icon: OpenShockClient.getIconForControlType(ControlType.shock),
                  onPressed: () {action(ControlType.shock);},
                ),
            ],
          ),
        if(delayVibrationController != null)
        Row(spacing: 10, mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Text("Delaying action... ${(delayDoneTime.difference(DateTime.now()).inMilliseconds / 100).round() / 10} s"),
          CircularProgressIndicator(
              value: delayVibrationController == null ? 0 : (delayDoneTime.difference(DateTime.now()).inMilliseconds / (delayDuration*1000))
            ),
        ],),
        if(progressCircularController != null)
          Row(
            spacing: 10,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Executing... ${(actionDoneTime.difference(DateTime.now()).inMilliseconds / 100).round() / 10} s"),
              CircularProgressIndicator(
                value: progressCircularController == null ? 0 : 1 - (actionDoneTime.difference(DateTime.now()).inMilliseconds / currentDuration),
              )
            ]
          ),
        SizedBox.fromSize(size: Size.fromHeight(50),child: 
        IconButton(onPressed: () {action(ControlType.stop);}, icon: Icon(Icons.stop),)
        ,)
        
      ],
    );
  }
}