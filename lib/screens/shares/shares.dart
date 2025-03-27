import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/screens/shares/shocker_share_entry.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';

import '../../components/qr_card.dart';
import '../../services/alarm_list_manager.dart';
import '../../services/openshock.dart';

class SharesScreen extends StatefulWidget {
  AlarmListManager manager;
  Shocker shocker;

  SharesScreen({Key? key, required this.manager, required this.shocker})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _SharesScreenState(manager, shocker);
}

class _SharesScreenState extends State<SharesScreen> {
  AlarmListManager manager;
  Shocker shocker;
  List<OpenShockShare>? shares;
  List<OpenShockShareCode>? shareCodes;
  Color activeColor = Colors.green;
  Color inactiveColor = Colors.red;
  _SharesScreenState(this.manager, this.shocker);

  @override
  void initState() {
    super.initState();
    loadShares();
  }

  Future<void> loadShares() async {
    final newShares = await manager.getShockerShares(shocker);
    if(!mounted) return;
    setState(() {
      shares = newShares;
    });

    final newShareCodes = await manager.getShockerShareCodes(shocker);
    if(!mounted) return;
    setState(() {
      shareCodes = newShareCodes;
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
    for (OpenShockShare share in shares ?? []) {
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
    for (OpenShockShareCode code in shareCodes ?? []) {
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
    if (shareCodes == null) {
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
          child: shares == null
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
    return PaddedCard(
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
                          ErrorDialog.show(
                              "Failed to delete share code", error);
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
              showSeperateIntensities: false,
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
                  InfoDialog.show(names[type] ?? "Unknown control type",
                      descriptions[type] ?? "Unknown control type");
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
