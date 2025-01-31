import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/components/card.dart';
import 'package:shock_alarm_app/components/delete_dialog.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/screens/share_link_edit.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

import '../components/constrained_container.dart';
import '../components/desktop_mobile_refresh_indicator.dart';

class ShareLinkCreationDialog extends StatefulWidget {
  String shareLinkName = "";
  DateTime? expiresOn = DateTime.now().add(Duration(days: 1));

  @override
  State<StatefulWidget> createState() => ShareLinkCreationDialogState();
}

class ShareLinkCreationDialogState extends State<ShareLinkCreationDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Create Share Link"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: "Name",
            ),
            onChanged: (value) {
              widget.shareLinkName = value;
            },
          ),
          Padding(padding: EdgeInsets.all(15)),
          Text("Expires: ${widget.expiresOn.toString().split(".").first}",
              style: TextStyle(fontSize: 20)),
          TextButton(
              onPressed: () async {
                widget.expiresOn = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                    initialDate: widget.expiresOn);
                if (widget.expiresOn == null) return;
                TimeOfDay? time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(widget.expiresOn!));
                setState(() {
                  widget.expiresOn = DateTime(
                      widget.expiresOn!.year,
                      widget.expiresOn!.month,
                      widget.expiresOn!.day,
                      time!.hour,
                      time.minute);
                });
              },
              child: Text("Change expiry")),
        ],
      ),
      actions: <Widget>[
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Cancel")),
        TextButton(
            onPressed: () async {
              if (widget.shareLinkName.isEmpty) {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Name is empty"),
                        content: Text("Please enter a name for the share link"),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text("Ok"))
                        ],
                      );
                    });
                return;
              }

              showDialog(
                  context: context,
                  builder: (context) =>
                      LoadingDialog(title: "Creating Share Link"));
              PairCode error = await AlarmListManager.getInstance()
                  .createShareLink(widget.shareLinkName, widget.expiresOn!);
              if (error.error != null) {
                Navigator.of(context).pop();
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Error creating share link"),
                        content: Text(error.error!),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text("Ok"))
                        ],
                      );
                    });
                return;
              }
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ShareLinkEditScreen(
                      shareLink: OpenShockShareLink.fromId(
                          error.code!,
                          widget.shareLinkName,
                          AlarmListManager.getInstance().getAnyUserToken()))));
              AlarmListManager.getInstance().reloadShareLinksMethod!();
            },
            child: Text("Create")),
      ],
    );
  }
}

class ShareLinksScreen extends StatefulWidget {
  const ShareLinksScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShareLinksScreenState();

  static getFloatingActionButton(
      AlarmListManager manager, BuildContext context, Function reloadState) {
    return FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              if (!manager.hasValidAccount()) {
                return AlertDialog(
                  title: Text("You're not logged in"),
                  content: Text(
                      "Login to OpenShock to create a Share Link. To do this visit the settings page."),
                  actions: <Widget>[
                    TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text("Ok"))
                  ],
                );
              }
              return ShareLinkCreationDialog();
            },
          );
        },
        child: Icon(Icons.add));
  }
}

class ShareLinksScreenState extends State<ShareLinksScreen> {
  bool initialLoading = false;

  Future loadShares() async {
    AlarmListManager.getInstance().shareLinks =
        await AlarmListManager.getInstance().getShareLinks();
    setState(() {
      initialLoading = false;
    });
  }

  @override
  void initState() {
    AlarmListManager.getInstance().reloadShareLinksMethod = loadShares;
    if (AlarmListManager.getInstance().shareLinks == null) {
      initialLoading = true;
      loadShares();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Widget> shareEntries = [];
    if (AlarmListManager.getInstance().shareLinks != null) {
      for (OpenShockShareLink shareLink
          in AlarmListManager.getInstance().shareLinks!) {
        shareEntries
            .add(ShareLinkItem(shareLink: shareLink, reloadMethod: loadShares));
      }
    }
    if (shareEntries.isEmpty) {
      shareEntries.add(Center(
          child: Text("No share links created yet",
              style: t.textTheme.headlineSmall)));
    }
    shareEntries.insert(
        0,
        IconButton(
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text("What are share links?"),
                      content: Text(
                          "Share links are a way to share your shockers with people who do not have an OpenShock account and don't want to create one (or for giving a group access to your shockers). Share links have limits just like normal shares. However people can just use any name they want to access the share link. Their actions will also be shown in the shockers log."),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text("Ok"))
                      ],
                    );
                  });
            },
            icon: Icon(Icons.info)));
    return initialLoading
            ? Center(child: CircularProgressIndicator())
            : DesktopMobileRefreshIndicator(
                onRefresh: loadShares,
                child: ConstrainedContainer(child: ListView(children: shareEntries),));
  }
}

class ShareLinkItem extends StatelessWidget {
  final OpenShockShareLink shareLink;
  final Function reloadMethod;

  const ShareLinkItem(
      {Key? key, required this.shareLink, required this.reloadMethod})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
        child: Row(
      children: [
        Expanded(child: Text(shareLink.name)),
        Row(
          children: [
            IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return DeleteDialog(
                            onDelete: () async {
                              showDialog(
                                  context: context,
                                  builder: (context) => LoadingDialog(
                                      title: "Deleting ${shareLink.name}"));
                              String? error =
                                  await AlarmListManager.getInstance()
                                      .deleteShareLink(shareLink);
                              Navigator.of(context).pop();
                              if (error != null) {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title:
                                            Text("Error deleting share link"),
                                        content: Text(error),
                                        actions: [
                                          TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: Text("Ok"))
                                        ],
                                      );
                                    });
                                return;
                              }
                              Navigator.of(context).pop();
                              reloadMethod();
                            },
                            title: "Delete ${shareLink.name}",
                            body:
                                "Are you sure you want to delete ${shareLink.name}?");
                      });
                }),
            IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('QR Code for ${shareLink.name}'),
                          content: QrCard(data: shareLink.getLink()),
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
            IconButton(
                icon: Icon(Icons.share),
                onPressed: () {
                  Share.share(shareLink.getLink());
                }),
            IconButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) {
                    return ShareLinkEditScreen(shareLink: shareLink);
                  }));
                },
                icon: Icon(Icons.edit))
          ],
        )
      ],
    ));
  }
}
