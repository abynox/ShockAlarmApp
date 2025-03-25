import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/screens/shares/shares.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class ShockerShareEntry extends StatefulWidget {
  OpenShockShare share;
  final AlarmListManager manager;
  Function() onRebuild;

  ShockerShareEntry(
      {Key? key,
      required this.share,
      required this.manager,
      required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _ShockerShareEntryState();
}

class _ShockerShareEntryState extends State<ShockerShareEntry> {
  OpenShockShareLimits limits = OpenShockShareLimits();

  bool editing = false;
  bool deleting = false;
  bool saving = false;
  bool pausing = false;

  void setPausedState(bool paused) async {
    setState(() {
      pausing = true;
    });
    String? error = await OpenShockClient()
        .setPauseStateOfShare(widget.share, widget.manager, paused);
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
    limits = OpenShockShareLimits.from(widget.share);
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
                  "Are you sure you want to delete the share with ${widget.share.sharedWith.name}?\n\n(You can create a new one later). If you just want their access to temporarely stop, you can pause the share instead."),
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
                      String? errorMessage =
                          await widget.manager.deleteShare(widget.share);
                      if (errorMessage != null) {
                        setState(() {
                          deleting = false;
                        });
                        ErrorDialog.show(
                            "Failed to delete share", errorMessage);
                        return;
                      }
                      Navigator.of(context).pop();
                      widget.onRebuild();
                    },
                    child: Text("Delete"))
              ],
            ));
  }

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
            Text(
              widget.share.sharedWith.name,
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
                                .setLimitsOfShare(
                                    widget.share, limits, widget.manager);
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
                if (widget.share.paused)
                  (pausing
                      ? CircularProgressIndicator()
                      : IconButton(
                          onPressed: () {
                            setPausedState(false);
                          },
                          icon: Icon(Icons.play_arrow))),
                if (!widget.share.paused)
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
                              value: widget.share.permissions.sound),
                          ShockerShareEntryPermission(
                              type: ControlType.vibrate,
                              value: widget.share.permissions.vibrate),
                          ShockerShareEntryPermission(
                              type: ControlType.shock,
                              value: widget.share.permissions.shock),
                          ShockerShareEntryPermission(
                              type: ControlType.live,
                              value: widget.share.permissions.live),
                        ],
                      ),
                    ],
                  ),
                  Text(
                      'Intensity limit: ${widget.share.limits.intensity ?? "None"}'),
                  Text(
                      'Duration limit: ${widget.share.limits.duration != null ? "${(widget.share.limits.duration! / 100).round() / 10} s" : "None"}'),
                ],
              ),
              if (widget.share.paused)
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
                        "You paused the share for ${widget.share.sharedWith.name}. This means they cannot interact with this shocker at all. You can resume it by pressing the play button.");
                  },
                ),
            ],
          ),
        if (editing)
          ShockerShareEntryEditor(
            limits: limits,
          ),
      ],
    ));
  }
}
