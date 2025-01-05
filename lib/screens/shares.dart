import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';

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
  }

  @override
  Widget build(BuildContext context) {
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
          RefreshIndicator(child: Flexible(child: 
            ListView.builder(
              itemCount: shares.length,
              itemBuilder: (context, index) {
                final share = shares[index];
                return ShockerShareEntry(share: share, manager: manager, key: ValueKey(share.sharedWith.id));
              },
            )
          ),onRefresh: () async{
          return loadShares();
        })
      ))
    ;
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
  OpenShockShareLimits? limits;
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
    editing = true;
    setState(() {
      limits = OpenShockShareLimits.from(share);
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
          if(editing) Column(
            children: [
              Column(
                spacing: 10,
                children: [
                  Text("Limits", style: t.textTheme.headlineMedium),
                  IntensityDurationSelector(duration: limits!.limits.duration ?? 30000, intensity: limits!.limits.intensity ?? 100, onSet: (intensity, duration) {
                    setState(() {
                      limits!.limits.duration = duration;
                      limits!.limits.intensity = intensity;
                    });
                  }, maxDuration: 30000, maxIntensity: 100),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  ShockerShareEntryPermissionEditor(manager: manager, share: share, type: ControlType.sound, value: limits!.permissions.sound, onSet: (value) {
                    setState(() {
                      limits!.permissions.sound = value;
                    });
                  },),
                  ShockerShareEntryPermissionEditor(manager: manager, share: share, type: ControlType.vibrate, value: limits!.permissions.vibrate, onSet: (value) {
                    setState(() {
                      limits!.permissions.vibrate = value;
                    });
                  },),
                ],),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  ShockerShareEntryPermissionEditor(manager: manager, share: share, type: ControlType.shock, value: limits!.permissions.shock, onSet: (value) {
                    setState(() {
                      limits!.permissions.shock = value;
                    });
                  },),
                  ShockerShareEntryPermissionEditor(manager: manager, share: share, type: ControlType.live, value: limits!.permissions.live, onSet: (value) {
                    setState(() {
                      limits!.permissions.live = value;
                    });
                  },),
                ],),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  IconButton(onPressed: () async {
                    setState(() {
                      editing = false;
                    });
                  }, icon: Icon(Icons.cancel)),
                  IconButton(onPressed: () async {
                    String? error = await OpenShockClient().setLimitsOfShare(share, limits!, manager);
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
              ]
            ),
            ],
          )
        ],
      ),
      ) 
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

  ShockerShareEntryPermissionEditorState(this.share, this.type, this.value, this.manager, this.onSet);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        OpenShockClient.getIconForControlType(type),
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