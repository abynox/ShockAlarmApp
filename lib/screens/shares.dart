import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/dialogs/ErrorDialog.dart';
import 'package:shock_alarm_app/dialogs/InfoDialog.dart';
import 'package:shock_alarm_app/dialogs/LoadingDialog.dart';
import 'package:shock_alarm_app/main.dart';

import '../components/qr_card.dart';
import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class SharesScreen extends StatefulWidget {
  AlarmListManager manager;
  Shocker shocker;

  SharesScreen({Key? key, required this.manager, required this.shocker})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => SharesScreenState(manager, shocker);
}

class SharesScreenState extends State<SharesScreen> {
  AlarmListManager manager;
  Shocker shocker;
  List<OpenShockShare> shares = [];
  List<OpenShockShareCode> shareCodes = [];
  bool initialLoading = false;
  bool loadingShareCodes = false;
  Color activeColor = Colors.green;
  Color inactiveColor = Colors.red;
  SharesScreenState(this.manager, this.shocker);

  @override
  void initState() {
    super.initState();
    initialLoading = true;
    loadingShareCodes = true;
    loadShares();
  }

  Future<void> loadShares() async {
    final newShares = await manager.getShockerShares(shocker);
    setState(() {
      shares = newShares;
      initialLoading = false;
      loadingShareCodes = true;
    });

    final newShareCodes = await manager.getShockerShareCodes(shocker);
    setState(() {
      shareCodes = newShareCodes;
      loadingShareCodes = false;
    });
  }

  Future addShare() async {
    OpenShockShareLimits limits = OpenShockShareLimits();
    OpenShockShare share = OpenShockShare();
    await showDialog(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              content: ShockerShareEntryEditor(limits: limits),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      LoadingDialog.show("Creating share");

                      String? error = await OpenShockClient()
                          .addShare(shocker, limits, manager);
                      Navigator.of(context).pop();
                      if (error != null) {
                        ErrorDialog.show("Failed to create share", error);
                        return;
                      }
                      Navigator.of(context).pop();
                    },
                    child: Text("Create share"))
              ],
            ));
    setState(() {
      loadShares();
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Widget> shareEntries = [];
    for (OpenShockShare share in shares) {
      shareEntries.add(ShockerShareEntry(
          share: share,
          manager: manager,
          key: ValueKey(share.sharedWith.id),
          onRebuild: () {
            setState(() {
              loadShares();
            });
          }));
    }
    for (OpenShockShareCode code in shareCodes) {
      shareEntries.add(ShockerShareCodeEntry(
        shareCode: code,
        manager: manager,
        key: ValueKey(code.id),
        onDeleted: () {
          setState(() {
            loadShares();
          });
        },
      ));
    }
    if(loadingShareCodes) {
      // show loading for share codes when shares have already loaded in
      shareEntries.add(Center(child: CircularProgressIndicator()));
    }
    if (shareEntries.isEmpty) {
      shareEntries.add(Center(
          child: Text(
              "You have no shares yet. You can add a share by pressing the add button below.",
              style: t.textTheme.headlineSmall)));
    }
    try {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            spacing: 10,
            children: [Text('Shares for ${shocker.name}')],
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
                        return loadShares();
                      },
                      child: ListView(children: shareEntries))),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            addShare();
          },
          child: Icon(Icons.add),
        ),
      );
    } catch (e) {
      print(e);
      return Scaffold(
          body: Center(
              child: Text(
                  "An error occurred while loading the shares. Please try again later.")));
    }
  }
}

class ShockerShareEntry extends StatefulWidget {
  final OpenShockShare share;
  final AlarmListManager manager;
  Function() onRebuild;

  ShockerShareEntry(
      {Key? key,
      required this.share,
      required this.manager,
      required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      ShockerShareEntryState(share, manager, onRebuild);
}

class ShockerShareEntryState extends State<ShockerShareEntry> {
  final AlarmListManager manager;
  OpenShockShare share;
  OpenShockShareLimits limits = OpenShockShareLimits();
  Function() onRebuild;
  bool editing = false;
  bool deleting = false;
  bool saving = false;
  bool pausing = false;

  ShockerShareEntryState(this.share, this.manager, this.onRebuild);

  void setPausedState(bool paused) async {
    setState(() {
      pausing = true;
    });
    String? error =
        await OpenShockClient().setPauseStateOfShare(share, manager, paused);
    setState(() {
      pausing = false;
    });
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void openEditLimitsDialog() async {
    print("Editing limits");
    limits = OpenShockShareLimits.from(share);
    setState(() {
      editing = true;
    });
  }

  void deleteShare() async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Delete share"),
              content: Text(
                  "Are you sure you want to delete the share with ${share.sharedWith.name}?\n\n(You can create a new one later). If you just want their access to temporarely stop, you can pause the share instead."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      setState(() {
                        deleting = true;
                      });
                      String? errorMessage = await manager.deleteShare(share);
                      if (errorMessage != null) {
                        setState(() {
                          deleting = false;
                        });
                        ErrorDialog.show("Failed to delete share", errorMessage);
                        return;
                      }
                      Navigator.of(context).pop();
                      onRebuild();
                    },
                    child: Text("Delete"))
              ],
            ));
  }

  @override
  void didUpdateWidget(covariant ShockerShareEntry oldWidget) {
    share = oldWidget.share;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Card(
        color: t.colorScheme.onInverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    share.sharedWith.name,
                    style: t.textTheme.headlineSmall,
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      if (editing)
                        IconButton(
                            onPressed: () async {
                              setState(() {
                                editing = false;
                              });
                            },
                            icon: Icon(Icons.cancel)),
                      if (editing)
                        (saving
                            ? CircularProgressIndicator()
                            : IconButton(
                                onPressed: () async {
                                  setState(() {
                                    saving = true;
                                  });
                                  String? error = await OpenShockClient()
                                      .setLimitsOfShare(share, limits, manager);
                                  setState(() {
                                    saving = false;
                                  });
                                  if (error != null) {
                                    ErrorDialog.show("Failed to save limits", error);
                                    return;
                                  }
                                  setState(() {
                                    editing = false;
                                  });
                                },
                                icon: Icon(Icons.save))),
                      if (!editing)
                        (deleting
                            ? CircularProgressIndicator()
                            : IconButton(
                                onPressed: () {
                                  deleteShare();
                                },
                                icon: Icon(Icons.delete))),
                      if (!editing)
                        IconButton(
                            onPressed: () {
                              openEditLimitsDialog();
                            },
                            icon: Icon(Icons.edit)),
                      if (share.paused)
                        (pausing
                            ? CircularProgressIndicator()
                            : IconButton(
                                onPressed: () {
                                  setPausedState(false);
                                },
                                icon: Icon(Icons.play_arrow))),
                      if (!share.paused)
                        (pausing
                            ? CircularProgressIndicator()
                            : IconButton(
                                onPressed: () {
                                  setPausedState(true);
                                },
                                icon: Icon(Icons.pause))),
                    ],
                  )
                ],
              ),
              if (!editing)
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
                                ShockerShareEntryPermission(
                                    type: ControlType.sound,
                                    value: share.permissions.sound),
                                ShockerShareEntryPermission(
                                    type: ControlType.vibrate,
                                    value: share.permissions.vibrate),
                                ShockerShareEntryPermission(
                                    type: ControlType.shock,
                                    value: share.permissions.shock),
                                ShockerShareEntryPermission(
                                    type: ControlType.live,
                                    value: share.permissions.live),
                              ],
                            ),
                          ],
                        ),
                        Text(
                            'Intensity limit: ${share.limits.intensity ?? "None"}'),
                        Text(
                            'Duration limit: ${share.limits.duration != null ? "${(share.limits.duration! / 100).round() / 10} s" : "None"}'),
                      ],
                    ),
                    if (share.paused)
                      GestureDetector(
                        child: Chip(
                            label: Text("paused"),
                            backgroundColor: t.colorScheme.errorContainer,
                            side: BorderSide.none,
                            avatar: Icon(
                              Icons.info,
                              color: t.colorScheme.error,
                            )),
                        onTap: () {
                          InfoDialog.show("Share is paused",
                            "You paused the share for ${share.sharedWith.name}. This means they cannot interact with this shocker at all. You can resume it by pressing the play button.");
                        },
                      ),
                  ],
                ),
              if (editing)
                ShockerShareEntryEditor(
                  limits: limits,
                ),
            ],
          ),
        ));
  }
}

class ShockerShareCodeEntry extends StatefulWidget {
  final OpenShockShareCode shareCode;
  final AlarmListManager manager;
  final Function() onDeleted;

  const ShockerShareCodeEntry(
      {Key? key,
      required this.shareCode,
      required this.manager,
      required this.onDeleted})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      ShockerShareCodeEntryState(shareCode, manager, onDeleted);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        "Unclaimed",
                        style: t.textTheme.headlineSmall,
                      ),
                      IconButton(
                          onPressed: () {
                            InfoDialog.show("Unclaimed share code",
                                "This share code has not been claimed yet. You can share it with your friend by pressing the share button. When they claim the code they will have access to your shocker.");
                          },
                          icon: Icon(Icons.info))
                    ],
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      if (deleting)
                        CircularProgressIndicator()
                      else
                        IconButton(
                            onPressed: () async {
                              setState(() {
                                deleting = true;
                              });
                              String? error =
                                  await manager.deleteShareCode(shareCode);
                              if (error != null) {
                                setState(() {
                                  deleting = false;
                                });
                                ErrorDialog.show("Failed to delete share code", error);
                                return;
                              }
                              onDeleted();
                            },
                            icon: Icon(Icons.delete)),
                      IconButton(
                          onPressed: () async {
                            Share.share(
                                "Claim my shocker with this share code: ${shareCode.id}");
                          },
                          icon: Icon(Icons.share)),
                      IconButton(
                          onPressed: () async {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog.adaptive(
                                    title: Text('Scan to claim'),
                                    content: QrCard(
                                        data:
                                            "openshock://sharecode/${shareCode.id}"),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text('Close'))
                                    ],
                                  );
                                });
                          },
                          icon: Icon(Icons.qr_code)),
                    ],
                  )
                ],
              ),
            ],
          ),
        ));
  }
}

class ShockerShareEntryEditor extends StatefulWidget {
  OpenShockShareLimits limits;

  ShockerShareEntryEditor({Key? key, required this.limits}) : super(key: key) {}

  @override
  State<StatefulWidget> createState() => ShockerShareEntryEditorState(limits);
}

class ShockerShareEntryEditorState extends State<ShockerShareEntryEditor> {
  OpenShockShareLimits limits;

  ShockerShareEntryEditorState(this.limits);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          Column(spacing: 10, children: [
            Text("Limits", style: t.textTheme.headlineMedium),
            IntensityDurationSelector(
                controlsContainer: ControlsContainer.fromInts(
                    duration: limits.limits.duration ?? 30000,
                    intensity: limits.limits.intensity ?? 100),
                onSet: (container) {
                  setState(() {
                    limits.limits.duration =
                        container.durationRange.start.toInt();
                    limits.limits.intensity =
                        container.intensityRange.start.toInt();
                  });
                },
                maxDuration: 30000,
                maxIntensity: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ShockerShareEntryPermissionEditor(
                  type: ControlType.sound,
                  value: limits.permissions.sound,
                  onSet: (value) {
                    setState(() {
                      limits.permissions.sound = value;
                    });
                  },
                ),
                ShockerShareEntryPermissionEditor(
                  type: ControlType.vibrate,
                  value: limits.permissions.vibrate,
                  onSet: (value) {
                    setState(() {
                      limits.permissions.vibrate = value;
                    });
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ShockerShareEntryPermissionEditor(
                  type: ControlType.shock,
                  value: limits.permissions.shock,
                  onSet: (value) {
                    setState(() {
                      limits.permissions.shock = value;
                    });
                  },
                ),
                ShockerShareEntryPermissionEditor(
                  type: ControlType.live,
                  value: limits.permissions.live,
                  onSet: (value) {
                    setState(() {
                      limits.permissions.live = value;
                    });
                  },
                ),
              ],
            )
          ]),
        ],
      ),
    );
  }
}

class ShockerShareEntryPermission extends StatelessWidget {
  final ControlType type;
  final bool value;

  const ShockerShareEntryPermission(
      {Key? key, required this.type, required this.value})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return GestureDetector(
        child: OpenShockClient.getIconForControlType(type,
            color: value ? Colors.green : Colors.red));
  }
}

class ShockerShareEntryPermissionEditor extends StatefulWidget {
  final ControlType type;
  final bool value;
  final Function(bool) onSet;

  const ShockerShareEntryPermissionEditor(
      {Key? key, required this.type, required this.value, required this.onSet})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      ShockerShareEntryPermissionEditorState(type, value, onSet);
}

class ShockerShareEntryPermissionEditorState
    extends State<ShockerShareEntryPermissionEditor> {
  ControlType type;
  bool value;
  Function(bool) onSet;

  Map<ControlType, String> descriptions = {
    ControlType.sound: "This allows the other person to let your shocker beep",
    ControlType.vibrate:
        "This allows the other person to let your shocker vibrate",
    ControlType.shock:
        "This allows the other person to shock you via your shocker",
    ControlType.live:
        "This allows the other person to use the live control feature. This feature allows the other person to control your shocker with the given intensity without a duration limit while controlling the intensity live."
  };

  Map<ControlType, String> names = {
    ControlType.sound: "Sound",
    ControlType.vibrate: "Vibrate",
    ControlType.shock: "Shock",
    ControlType.live: "Live"
  };

  ShockerShareEntryPermissionEditorState(this.type, this.value, this.onSet);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            OpenShockClient.getIconForControlType(type),
            IconButton(
                onPressed: () {
                  InfoDialog.show(names[type] ?? "Unknown control type", descriptions[type] ?? "Unknown control type");
                },
                icon: Icon(Icons.info))
          ],
        ),
        Switch(
            value: value,
            onChanged: (v) {
              setState(() {
                value = v;
                onSet(v);
              });
            })
      ],
    );
  }
}
