import 'package:flutter/material.dart';

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
                return ShockerShareEntry(share: share, manager: manager,);
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

  ShockerShareEntryState(this.share, this.manager);

  void setPausedState(bool paused) async {
    String? error = await OpenShockClient().setPauseStateOfShare(share, manager, paused);
    if(error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    setState(() { });
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
              Text(share.sharedWith.name, style: TextStyle(fontSize: 24)),
              Row(
                spacing: 10,
                children: [

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
                  Text('Duration limit: ${share.limits.duration ?? "None"}'),
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
          )
        ],
      ),) 
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