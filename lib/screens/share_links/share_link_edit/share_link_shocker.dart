import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/screens/share_links/share_link_edit/share_link_edit.dart';
import 'package:shock_alarm_app/screens/shares/shares.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class ShareLinkShocker extends StatefulWidget {
  final OpenShockShareLink shareLink;
  final Shocker shocker;
  final Function() onRebuild;

  const ShareLinkShocker(
      {Key? key,
      required this.shareLink,
      required this.shocker,
      required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _ShareLinkShockerState();
}


class _ShareLinkShockerState extends State<ShareLinkShocker> {
  bool editing = false;
  bool deleting = false;
  bool loadingPause = false;

  OpenShockShareLimits limits = OpenShockShareLimits();

  void setPausedState(bool paused) async {
    setState(() {
      loadingPause = true;
    });
    String? error = await OpenShockClient().setPauseStateOfShareLinkShocker(
        widget.shareLink, widget.shocker, paused);
    setState(() {
      loadingPause = false;
      if(error == null){

        if (paused) {
          widget.shocker.pauseReasons.add(PauseReason.shareLink);
        } else {
          widget.shocker.pauseReasons.remove(PauseReason.shareLink);
        }
      }
    });
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
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
    showDialog(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Remove shocker"),
              content: Text(
                  "Are you sure you want to remove shocker ${widget.shocker.name} from the share link ${widget.shareLink.name}?\n\n(You can create a new one again later)"),
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
                      String? errorMessage = await OpenShockClient()
                          .removeShockerFromShareLink(
                              widget.shareLink, widget.shocker);
                      if (errorMessage != null) {
                        setState(() {
                          deleting = false;
                        });
                        ErrorDialog.show("Error removing shocker", errorMessage);
                        return;
                      }
                      Navigator.of(context).pop();
                      widget.onRebuild();
                    },
                    child: Text("Remove"))
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
                widget.shocker.name,
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
                    IconButton(
                        onPressed: () async {
                          String? error = await OpenShockClient()
                              .setLimitsOfShareLinkShocker(
                                  widget.shareLink, widget.shocker, limits);
                          if (error != null) {
                            ErrorDialog.show("Error saving limits", error);
                            return;
                          }
                          setState(() {
                            widget.shocker.setLimits(limits);
                            editing = false;
                          });
                        },
                        icon: Icon(Icons.save)),
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
                  if (widget.shocker.pauseReasons
                      .contains(PauseReason.shareLink))
                    loadingPause
                        ? CircularProgressIndicator()
                        : IconButton(
                            onPressed: () {
                              setPausedState(false);
                            },
                            icon: Icon(Icons.play_arrow)),
                  if (!widget.shocker.pauseReasons
                      .contains(PauseReason.shareLink))
                    loadingPause
                        ? CircularProgressIndicator()
                        : IconButton(
                            onPressed: () {
                              setPausedState(true);
                            },
                            icon: Icon(Icons.pause)),
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
                                value: widget.shocker.soundAllowed),
                            ShockerShareEntryPermission(
                                type: ControlType.vibrate,
                                value: widget.shocker.vibrateAllowed),
                            ShockerShareEntryPermission(
                                type: ControlType.shock,
                                value: widget.shocker.shockAllowed),
                            ShockerShareEntryPermission(
                                type: ControlType.live,
                                value: widget.shocker.liveAllowed),
                          ],
                        ),
                      ],
                    ),
                    Text(
                        'Intensity limit: ${widget.shocker.intensityLimit ?? "None"}'),
                    Text(
                        'Duration limit: ${(widget.shocker.durationLimit / 100).round() / 10} s'),
                  ],
                ),
                if (!widget.shocker.pauseReasons.isEmpty)
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
                      String unpauseInstructions =
                          "You can unpause it by pressing the play button";
                      if (widget.shocker.pauseReasons
                          .contains(PauseReason.shareLink)) {
                        unpauseInstructions += " here";
                        if (widget.shocker.pauseReasons.length > 1)
                          unpauseInstructions += " and";
                      }
                      if (widget.shocker.pauseReasons
                          .contains(PauseReason.shocker)) {
                        unpauseInstructions += " on the devices page";
                      }
                      unpauseInstructions += ".";
                      InfoDialog.show("Shocker is paused",
                          "The shocker ${widget.shocker.name} is paused on ${widget.shocker.getPausedLevels()} Level. This means ${widget.shareLink.name} cannot interact with this shocker at all. $unpauseInstructions");
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
    );
  }
}
