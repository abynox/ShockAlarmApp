import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/components/card.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:share_plus/share_plus.dart';

import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';
import 'shares.dart';

class ShareLinkEditScreen extends StatefulWidget {
  OpenShockShareLink shareLink;

  ShareLinkEditScreen({Key? key, required this.shareLink}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShareLinkEditScreenState();
}

class ShareLinkEditScreenState extends State<ShareLinkEditScreen> {
  bool initialLoading = false;
  Color activeColor = Colors.green;
  Color inactiveColor = Colors.red;
  OpenShockShareLink? shareLink;

  @override
  void initState() {
    super.initState();
    initialLoading = true;
    loadShare();
  }

  Future<void> loadShare() async {
    shareLink = await AlarmListManager.getInstance().getShareLink(widget.shareLink);
    setState(() {
      initialLoading = false;
    });
  }

  Future addShocker() async {
    List<String> existingShockers = shareLink!.shockers.map((e) => e.id).toList();
    List<Shocker> ownShockers = await AlarmListManager.getInstance().shockers.where((element) => element.isOwn && !existingShockers.contains(element.id)).toList();
    Shocker? selectedShocker = null;

    if(ownShockers.length <= 0) {
      showDialog(context: context, builder: (context) => AlertDialog(title: Text("All done"), content: Text("You have already added all your shockers to this share link."), actions: [TextButton(onPressed: () {
        Navigator.of(context).pop();
      }, child: Text("Ok"))],));
      return;
    }

    await showDialog(context: context, builder: (context) => AlertDialog(
      title: 
          Text("Add a shocker to the share link"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownMenu<Shocker?>(
          dropdownMenuEntries: 
            ownShockers.map((shocker) => DropdownMenuEntry<Shocker?>(value: shocker, label: shocker.name)).toList(),
          initialSelection: selectedShocker,
          onSelected: (value) {
            setState(() {
              selectedShocker = value;
            });
          }),
        ],
      ),
      actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Cancel")),
        TextButton(onPressed: () async {
          if(selectedShocker == null) {
            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Error"), content: Text("Please select a shocker to add"), actions: [TextButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: Text("Ok"))],));
            return;
          }
          showDialog(context: context, builder: (context) => LoadingDialog(title: "Adding shocker"));

          String? error = await AlarmListManager.getInstance().addShockerToShareLink(selectedShocker, shareLink!);
          Navigator.of(context).pop();
          if(error != null) {
            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Error"), content: Text(error), actions: [TextButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: Text("Ok"))],));
            return;
          }
          Navigator.of(context).pop();
        }, child: Text("Add shocker"))
      ],
    ));
    setState(() {
      loadShare();
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Widget> shareEntries = [];
    if(shareLink != null) {
       for(Shocker shocker in shareLink!.shockers) {
        shareEntries.add(
        ShareLinkShocker(shareLink: shareLink!, shocker: shocker, key: ValueKey(shocker.getIdentifier()), onRebuild: () {
          setState(() {
            loadShare();
          });
        }));
      }
    }
   
    if(shareEntries.isEmpty) {
      shareEntries.add(Center(child: Text("This share link doesn't have any shockers yet. You can add a shocker by pressing the add button below."
            ,style: t.textTheme.headlineSmall)));
    }
    try {
      return Scaffold(
      appBar: AppBar(
        title: Row(
          spacing: 10,
          children: [
            Text('ShareLink ${widget.shareLink.name}')
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
            DesktopMobileRefreshIndicator(
              onRefresh: () async {
                return loadShare();
              },
              child: ListView(children: shareEntries))
        ),
        floatingActionButton: FloatingActionButton(onPressed: () {
          addShocker();
        }, child: Icon(Icons.add),),
      );
    } catch(e) {
      print(e);
      return Scaffold(body: Center(child: Text("An error occurred while loading the share link. Please try again later.")));
    }

  }
}

class ShareLinkShocker extends StatefulWidget {
  final OpenShockShareLink shareLink;
  final Shocker shocker;
  final Function() onRebuild;

  const ShareLinkShocker({Key? key, required this.shareLink, required this.shocker, required this.onRebuild}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShareLinkShockerState();
}

class ShareLinkShockerState extends State<ShareLinkShocker> {
  bool editing = false;
  bool deleting = false;
  bool loadingPause = false;

  OpenShockShareLimits limits = OpenShockShareLimits();
  
  void setPausedState(bool paused) async {
    setState(() {
      loadingPause = true;
    });
    String? error = await OpenShockClient().setPauseStateOfShareLinkShocker(widget.shareLink, widget.shocker, paused);
    setState(() {
      loadingPause = false;
      if(paused) {
        widget.shocker.pauseReasons.add(PauseReason.shareLink);
      } else {
        widget.shocker.pauseReasons.remove(PauseReason.shareLink);
      }
    });
    if(error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void openEditLimitsDialog() async {
    print("Editing limits");
    limits = OpenShockShareLimits.fromShocker(widget.shocker);
    setState(() {
      editing = true;
    });
  }

  void deleteShare() async {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text("Remove shocker"), content: Text("Are you sure you want to remove shocker ${widget.shocker.name} from the share link ${widget.shareLink.name}?\n\n(You can add it again later)"), actions: [
      TextButton(onPressed: () {
        Navigator.of(context).pop();
      }, child: Text("Cancel")),
      TextButton(onPressed: () async {
        setState(() {
          deleting = true;
        });
        String? errorMessage = await OpenShockClient().removeShockerFromShareLink(widget.shareLink, widget.shocker);
        if(errorMessage != null) {
          setState(() {
            deleting = false;
          });
          showDialog(context: context, builder: (context) => AlertDialog(title: Text(errorMessage), content: Text(errorMessage), actions: [TextButton(onPressed: () {
            Navigator.of(context).pop();
          }, child: Text("Ok"))],));
          return;
        }
        Navigator.of(context).pop();
        widget.onRebuild();
      }, child: Text("Remove"))
    ],));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.shocker.name, style: t.textTheme.headlineSmall,),
              Row(
                spacing: 10,
                children: [
                  if(editing) 

                    IconButton(onPressed: () async {
                      setState(() {
                        editing = false;
                      });
                    }, icon: Icon(Icons.cancel)),
                  if(editing)
                    IconButton(onPressed: () async {
                      String? error = await OpenShockClient().setLimitsOfShareLinkShocker(widget.shareLink, widget.shocker, limits);
                        if(error != null) {
                          showDialog(context: context, builder: (context) => AlertDialog(title: Text("Error"), content: Text(error), actions: [TextButton(onPressed: () {
                            Navigator.of(context).pop();
                          }, child: Text("Ok"))],));
                          return;
                        }
                        setState(() {
                          widget.shocker.setLimits(limits);
                          editing = false;
                        });
                    }, icon: Icon(Icons.save)),
                  if(!editing) 
                    (deleting ? CircularProgressIndicator() : IconButton(onPressed: () {
                      deleteShare();
                    }, icon: Icon(Icons.delete))),
                  if(!editing)
                    IconButton(onPressed: () {
                      openEditLimitsDialog();
                    }, icon: Icon(Icons.edit)),
                  if(widget.shocker.pauseReasons.contains(PauseReason.shareLink))
                    loadingPause ? CircularProgressIndicator() :
                    IconButton(onPressed: () {
                      setPausedState(false);
                    }, icon: Icon(Icons.play_arrow)),
                  if(!widget.shocker.pauseReasons.contains(PauseReason.shareLink))
                    loadingPause ? CircularProgressIndicator() :
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
                            ShockerShareEntryPermission(type: ControlType.sound, value: widget.shocker.soundAllowed),
                            ShockerShareEntryPermission(type: ControlType.vibrate, value: widget.shocker.vibrateAllowed),
                            ShockerShareEntryPermission(type: ControlType.shock, value: widget.shocker.shockAllowed),
                            ShockerShareEntryPermission(type: ControlType.live, value: widget.shocker.liveAllowed),
                          ],
                        ),
                        
                      ],
                    ),
                    Text('Intensity limit: ${widget.shocker.intensityLimit ?? "None"}'),
                    Text('Duration limit: ${(widget.shocker.durationLimit/100).round()/10} s'),
                  ],
                ),
                if(!widget.shocker.pauseReasons.isEmpty)
                  GestureDetector( child: Chip(
                    label: Text("paused"),
                    backgroundColor: t.colorScheme.errorContainer,
                    side: BorderSide.none,
                    avatar: Icon(Icons.info, color: t.colorScheme.error,)
                  ),
                  onTap: () {
                    String unpauseInstructions = "You can unpause it by pressing the play button";
                    if(widget.shocker.pauseReasons.contains(PauseReason.shareLink)) {
                      unpauseInstructions += " here";
                      if(widget.shocker.pauseReasons.length > 1) unpauseInstructions += " and";
                    }
                    if(widget.shocker.pauseReasons.contains(PauseReason.shocker)) {
                      unpauseInstructions += " on the shockers page";
                    }
                    unpauseInstructions += ".";
                    showDialog(context: context, builder: (context) => AlertDialog(title: Text("Shocker is paused"), content: Text("The shocker ${widget.shocker.name} is paused on ${widget.shocker.getPausedLevels()} Level. This means ${widget.shareLink.name} cannot interact with this shocker at all. $unpauseInstructions"),
                    actions: [TextButton(onPressed: () {
                      Navigator.of(context).pop();
                    }, child: Text("Ok"))],));
                  },),
              ],
            ),
          if(editing)
            ShockerShareEntryEditor(limits: limits,),
          
        ],
      ),);
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
  bool deleting = false;

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
                  if(deleting)
                    CircularProgressIndicator()
                  else
                    IconButton(onPressed: () async {
                      setState(() {
                        deleting = true;
                      });
                      String? error = await manager.deleteShareCode(shareCode);
                      if(error != null) {
                        deleting = false;
                        showDialog(context: context, builder: (context) => AlertDialog(title: Text("Error"), content: Text(error), actions: [TextButton(onPressed: () {
                          Navigator.of(context).pop();
                        }, child: Text("Ok"))],));
                        return;
                      }
                      onDeleted();
                    }, icon: Icon(Icons.delete)),
                  IconButton(onPressed: () async {
                    Share.share("Claim my shocker with this share code: ${shareCode.id}");
                  }, icon: Icon(Icons.share)),
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

class LoadingDialog extends StatelessWidget {
  final String title;
  const LoadingDialog({
    required this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(title: Text(title), content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator()]), actions: []);
  }
}