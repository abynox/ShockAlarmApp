import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:share_plus/share_plus.dart';

import '../components/bottom_add_button.dart';
import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class SharesScreen extends StatefulWidget {
  AlarmListManager manager;
  Shocker shocker;

  SharesScreen({Key? key, required this.manager, required this.shocker}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SharesScreenState(manager, shocker);
}

class SharesScreenState extends State<SharesScreen> {
  AlarmListManager manager;
  Shocker shocker;
  List<OpenShockShare> shares = [];
  List<OpenShockShareCode> shareCodes = [];
  bool initialLoading = false;
  Color activeColor = Colors.green;
  Color inactiveColor = Colors.red;
  SharesScreenState(this.manager, this.shocker);

  @override
  void initState() {
    super.initState();
    initialLoading = true;
    loadShares();
  }

  Future<void> loadShares() async {
    final newShares = await manager.getShockerShares(shocker);
    setState(() {
      shares = newShares;
      initialLoading = false;
    });

    final newShareCodes = await manager.getShockerShareCodes(shocker);
    setState(() {
      shareCodes = newShareCodes;
    });
  }

  Future addShare() async {
    OpenShockShareLimits limits = OpenShockShareLimits();
    OpenShockShare share = OpenShockShare();
    await showDialog(context: context, builder: (context) => AlertDialog(
      content: ShockerShareEntryEditor(share: share, manager: manager, limits: limits),
      actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Cancel")),
        TextButton(onPressed: () async {
          String? error = await OpenShockClient().addShare(shocker, limits, manager);
          if(error != null) {
            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Error"), content: Text(error), actions: [TextButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: Text("Ok"))],));
            return;
          }
          Navigator.of(context).pop();
        }, child: Text("Create share"))
      ],
    ));
    setState(() {
      loadShares();
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
      appBar: AppBar(
        title: Row(
          spacing: 10,
          children: [
            Text('Shares for ${shocker.name}'),
            Chip(label: Text(shocker.hub)),
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
        child: 
          initialLoading ? Center(child: CircularProgressIndicator()) :
            
            RefreshIndicator(child: 
              Flexible(child: 
                  ListView(children: [
                  for(OpenShockShare share in shares)
                    ShockerShareEntry(share: share, manager: manager),
                  for(OpenShockShareCode code in shareCodes)
                    ShockerShareCodeEntry(shareCode: code, manager: manager, onDeleted: () {
                      setState(() {
                        loadShares();
                      });
                    },),
                  BottomAddButton(onPressed: addShare)
                ]),
              ),
              
              onRefresh: () async{
                return loadShares();
              }
            )
        ),
      )
    ;
    } catch(e) {
      print(e);
      return Scaffold(body: Center(child: Text("An error occurred while loading the shares. Please try again later.")));
    }
    
  }
}

class ShockerShareEntry extends StatefulWidget {
  final OpenShockShare share;
  final AlarmListManager manager;

  const ShockerShareEntry({Key? key, required this.share, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerShareEntryState(share, manager);
}

class ShockerShareEntryState extends State<ShockerShareEntry> {
  final OpenShockShare share;
  final AlarmListManager manager;
  OpenShockShareLimits limits = OpenShockShareLimits();
  bool editing = false;

  ShockerShareEntryState(this.share, this.manager);

  void setPausedState(bool paused) async {
    String? error = await OpenShockClient().setPauseStateOfShare(share, manager, paused);
    if(error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    setState(() { });
  }

  void openEditLimitsDialog() async {
    print("Editing limits");
    limits = OpenShockShareLimits.from(share);
    setState(() {
      editing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Card(
      color: t.colorScheme.onInverseSurface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(padding: EdgeInsets.all(10), child: 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(share.sharedWith.name, style: t.textTheme.headlineSmall,),
              Row(
                spacing: 10,
                children: [
                  if(!editing)
                    IconButton(onPressed: () {
                      openEditLimitsDialog();
                    }, icon: Icon(Icons.edit)),
                  if(share.paused)
                    IconButton(onPressed: () {
                      setPausedState(false);
                    }, icon: Icon(Icons.play_arrow)),
                  if(!share.paused)
                    IconButton(onPressed: () {
                      setPausedState(true);
                    }, icon: Icon(Icons.pause)),
                ],
              )
            ],
          ),
          if(!editing)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          spacing: 10,
                          children: [
                            ShockerShareEntryPermission(share: share, type: ControlType.sound, value: share.permissions.sound),
                            ShockerShareEntryPermission(share: share, type: ControlType.vibrate, value: share.permissions.vibrate),
                            ShockerShareEntryPermission(share: share, type: ControlType.shock, value: share.permissions.shock),
                            ShockerShareEntryPermission(share: share, type: ControlType.live, value: share.permissions.live),
                          ],
                        ),
                        
                      ],
                    ),
                    Text('Intensity limit: ${share.limits.intensity ?? "None"}'),
                    Text('Duration limit: ${share.limits.duration != null ? "${(share.limits.duration!/100).round()/10} s" : "None"}'),
                  ],
                ),
                if(share.paused)
                  GestureDetector( child: Chip(
                    label: Text("paused"),
                    backgroundColor: t.colorScheme.errorContainer,
                    side: BorderSide.none,
                    avatar: Icon(Icons.info, color: t.colorScheme.error,)
                  ),
                  onTap: () {
                    showDialog(context: context, builder: (context) => AlertDialog(title: Text("Share is paused"), content: Text("You paused the share for ${share.sharedWith.name}. This means they cannot interact with this shocker at all. You can resume it by pressing the play button."),
                    actions: [TextButton(onPressed: () {
                      Navigator.of(context).pop();
                    }, child: Text("Ok"))],));
                  },),
              ],
            ),
          if(editing)
            ShockerShareEntryEditor(share: share, manager: manager, limits: limits,),
          
          if(editing) 
          Padding(padding: EdgeInsets.only(top: 30), child:
            Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  IconButton(onPressed: () async {
                    setState(() {
                      editing = false;
                    });
                  }, icon: Icon(Icons.cancel)),
                  IconButton(onPressed: () async {
                    String? error = await OpenShockClient().setLimitsOfShare(share, limits, manager);
                      if(error != null) {
                        showDialog(context: context, builder: (context) => AlertDialog(title: Text("Error"), content: Text(error), actions: [TextButton(onPressed: () {
                          Navigator.of(context).pop();
                        }, child: Text("Ok"))],));
                        return;
                      }
                      setState(() {
                        editing = false;
                      });
                  }, icon: Icon(Icons.save))
                ],)
          )
        ],
      ),
      ) 
    );
  }
}

class ShockerShareCodeEntry extends StatefulWidget {
  final OpenShockShareCode shareCode;
  final AlarmListManager manager;
  final Function() onDeleted;

  const ShockerShareCodeEntry({Key? key, required this.shareCode, required this.manager, required this.onDeleted}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerShareCodeEntryState(shareCode, manager, onDeleted);
}

class ShockerShareCodeEntryState extends State<ShockerShareCodeEntry> {
  final OpenShockShareCode shareCode;
  final AlarmListManager manager;
  final Function() onDeleted;
  OpenShockShareLimits limits = OpenShockShareLimits();
  bool editing = false;

  ShockerShareCodeEntryState(this.shareCode, this.manager, this.onDeleted);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Card(
      color: t.colorScheme.onInverseSurface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(padding: EdgeInsets.all(10), child: 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text("Unclaimed", style: t.textTheme.headlineSmall,),
                IconButton(onPressed: () {
                  showDialog(context: context, builder: (context) => AlertDialog(title: Text("Unclaimed share code"), content: Text("You created this share. No user has claimed it yet. You can use the share button to share the code with your friend. When they claim the code they will have access to your shocker."), actions: [TextButton(onPressed: () {
                    Navigator.of(context).pop();
                  }, child: Text("Ok"))],));
                }, icon: Icon(Icons.info))
              ],),
              Row(
                spacing: 10,
                children: [
                  IconButton(onPressed: () async {
                    Share.share("Claim my shocker with this share code: ${shareCode.id}");
                  }, icon: Icon(Icons.share)),
                  IconButton(onPressed: () async {
                    String? error = await manager.deleteShareCode(shareCode);
                    if(error != null) {
                      showDialog(context: context, builder: (context) => AlertDialog(title: Text("Error"), content: Text(error), actions: [TextButton(onPressed: () {
                        Navigator.of(context).pop();
                      }, child: Text("Ok"))],));
                      return;
                    }
                    onDeleted();
                  }, icon: Icon(Icons.delete))
                ],
              )
            ],
          ),
        ],
      ),
      ) 
    );
  }
}

class ShockerShareEntryEditor extends StatefulWidget {
  OpenShockShare share;
  OpenShockShareLimits limits;
  AlarmListManager manager;

  ShockerShareEntryEditor({Key? key, required this.share, required this.manager, required this.limits}) : super(key: key) {
  }

  @override
  State<StatefulWidget> createState() => ShockerShareEntryEditorState(share, manager, limits);
}

class ShockerShareEntryEditorState extends State<ShockerShareEntryEditor> {
  OpenShockShareLimits limits;
  AlarmListManager manager;
  OpenShockShare share;
  
  ShockerShareEntryEditorState(this.share, this.manager, this.limits);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(
            children: [
              Column(
                spacing: 10,
                children: [
                  Text("Limits", style: t.textTheme.headlineMedium),
                  IntensityDurationSelector(duration: limits.limits.duration ?? 30000, intensity: limits.limits.intensity ?? 100, onSet: (intensity, duration) {
                    setState(() {
                      limits.limits.duration = duration;
                      limits.limits.intensity = intensity;
                    });
                  }, maxDuration: 30000, maxIntensity: 100),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  ShockerShareEntryPermissionEditor(manager: manager, share: share, type: ControlType.sound, value: limits.permissions.sound, onSet: (value) {
                    setState(() {
                      limits.permissions.sound = value;
                    });
                  },),
                  ShockerShareEntryPermissionEditor(manager: manager, share: share, type: ControlType.vibrate, value: limits.permissions.vibrate, onSet: (value) {
                    setState(() {
                      limits.permissions.vibrate = value;
                    });
                  },),
                ],),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  ShockerShareEntryPermissionEditor(manager: manager, share: share, type: ControlType.shock, value: limits.permissions.shock, onSet: (value) {
                    setState(() {
                      limits.permissions.shock = value;
                    });
                  },),
                  ShockerShareEntryPermissionEditor(manager: manager, share: share, type: ControlType.live, value: limits.permissions.live, onSet: (value) {
                    setState(() {
                      limits.permissions.live = value;
                    });
                  },),
                ],)
              ]
            ),
            ],
          );
  }
}

class ShockerShareEntryPermission extends StatelessWidget {
  final OpenShockShare share;
  final ControlType type;
  final bool value;

  const ShockerShareEntryPermission({Key? key, required this.share, required this.type, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return GestureDetector(
      child: 
        OpenShockClient.getIconForControlType(type, color: value ? Colors.green : Colors.red)
    );
  }
}

class ShockerShareEntryPermissionEditor extends StatefulWidget {
  final OpenShockShare share;
  final ControlType type;
  final bool value;
  final Function(bool) onSet;
  final AlarmListManager manager;

  const ShockerShareEntryPermissionEditor({Key? key, required this.share, required this.type, required this.value, required this.manager, required this.onSet}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerShareEntryPermissionEditorState(share, type, value, manager, onSet);
}

class ShockerShareEntryPermissionEditorState extends State<ShockerShareEntryPermissionEditor> {
  OpenShockShare share;
  ControlType type;
  bool value;
  Function(bool) onSet;

  AlarmListManager manager;

  Map<ControlType, String> descriptions = {
    ControlType.sound: "This allows the other person to let your shocker beep",
    ControlType.vibrate: "This allows the other person to let your shocker vibrate",
    ControlType.shock: "This allows the other person to shock you via your shocker",
    ControlType.live: "This allows the other person to use the live control feature. This feature allows the other person to control your shocker with the given intensity without a duration limit while controlling the intensity live."
  };

  Map<ControlType, String> names = {
    ControlType.sound: "Sound",
    ControlType.vibrate: "Vibrate",
    ControlType.shock: "Shock",
    ControlType.live: "Live"
  };

  ShockerShareEntryPermissionEditorState(this.share, this.type, this.value, this.manager, this.onSet);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        Row(children: [
          OpenShockClient.getIconForControlType(type),
          IconButton(onPressed: () {
            showDialog(context: context, builder: (context) => AlertDialog(title: Text(names[type] ?? "Unknown control type"), content: Text(descriptions[type] ?? "Unknown control type"), actions: [TextButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: Text("Ok"))],));
          }, icon: Icon(Icons.info))
        ],),
        Switch(value: value, onChanged: (v) {
          setState(() {
            value = v;
            onSet(v);
          });
        })
      ],
    );
  }
}