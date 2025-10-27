import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/delete_dialog.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/screens/settings/settings_screen.dart';
import 'package:shock_alarm_app/screens/share_links/share_link_edit/share_link_edit.dart';
import 'package:shock_alarm_app/screens/shares/shares.dart';
import 'package:shock_alarm_app/screens/user_shares/user_share_edit.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

import '../../components/constrained_container.dart';
import '../../components/desktop_mobile_refresh_indicator.dart';

class UserSharesScreen extends StatefulWidget {
  const UserSharesScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _UserSharesScreen();
}

class _UserSharesScreen extends State<UserSharesScreen> {
  bool initialLoading = false;

  Future loadShares() async {
    await AlarmListManager.getInstance().updateUserShares();
    if (!mounted) return;
    setState(() {
      initialLoading = false;
    });
  }

  @override
  void initState() {
    if (AlarmListManager.getInstance().userShares == null) {
      initialLoading = true;
      loadShares();
    }
    AlarmListManager.getInstance().reloadAllMethod = () {
      if (!mounted) return;
      setState(() {});
    };
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Widget> shareEntries = [];
    if (AlarmListManager.getInstance().userShares != null) {
      for (OpenShockUserWithShares user
          in AlarmListManager.getInstance().userShares!.outgoing) {
        shareEntries.add(UserShareItem(user: user, reloadMethod: loadShares));
      }
      if (shareEntries.isEmpty) {
        shareEntries.add(Center(
            child: Text(
                AlarmListManager.getInstance().hasValidAccount()
                    ? "Nothing shared yet"
                    : "You're not logged in",
                style: t.textTheme.headlineSmall)));
      }
    }
    shareEntries.insert(
        0,
        IconButton(
            onPressed: () {
              InfoDialog.show("What are User Shares?",
                  "This page shows the shockers you shared listed by user. You can therefore easily manage your shares per user from here.");
            },
            icon: Icon(Icons.info)));
    return initialLoading
        ? Center(child: CircularProgressIndicator())
        : DesktopMobileRefreshIndicator(
            onRefresh: loadShares,
            child: ConstrainedContainer(
              child: ListView(children: shareEntries),
            ));
  }
}

class UserShareItem extends StatefulWidget {
  final OpenShockUserWithShares user;
  final Function reloadMethod;
  bool pausing = false;

  UserShareItem({Key? key, required this.user, required this.reloadMethod})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _UserShareItem();
}

class _UserShareItem extends State<UserShareItem> {
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
        child: Row(
      children: [
        Expanded(child: Text(widget.user.name)),
        Expanded(
            child: Wrap(
          children: widget.user.shares
              .map((x) => Chip(
                    label: Text(x.shockerReference?.name ?? "-"),
                    backgroundColor:
                        x.paused ? t.colorScheme.errorContainer : null,
                  ))
              .toList(),
        )),
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
                              LoadingDialog.show(
                                  "Deleting all shares with ${widget.user.name}");
                              List<String> errors = [];
                              for (OpenShockShare s in widget.user.shares) {
                                String? e = await AlarmListManager.getInstance()
                                    .deleteShare(s);
                                if (e != null) errors.add(e);
                              }
                              Navigator.of(context).pop();
                              if (errors.isNotEmpty) {
                                ErrorDialog.show(
                                    "Error deleting ${errors.length} shares",
                                    errors.join("\n\n"));
                                return;
                              }
                              Navigator.of(context).pop();
                              InfoDialog.show("Deleted shares",
                                  "${widget.user.name} won't have access to your shockers anymore. In case you change your mind you can send a new invite at any time");
                              widget.reloadMethod();
                            },
                            title: "Revoke access to all shockers?",
                            body:
                                "Are you sure you want to revoke access to your shockers for '${widget.user.name}'? '${widget.user.name}' won't be able to control them afterwards");
                      });
                }),
            IconButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) {
                    return UserShareEditScreen(user: widget.user);
                  }));
                },
                icon: Icon(Icons.edit)),
            widget.pausing
                ? CircularProgressIndicator()
                : IconButton(
                    onPressed: () async {
                      setState(() {
                        widget.pausing = true;
                      });
                      bool newPauseState =
                          widget.user.shares.any((x) => !x.paused);
                      List<String> errors = [];
                      for (var share in widget.user.shares) {
                        String? error = await OpenShockClient()
                            .setPauseStateOfShare(share, newPauseState);
                        if (error != null) {
                          errors.add(error);
                        } else {
                          if (mounted) {
                            setState(() {
                              share.paused = newPauseState;
                            });
                          }
                        }
                      }
                      if (mounted) {
                        widget.pausing = false;
                      }
                      if (errors.isNotEmpty) {
                        ErrorDialog.show(
                            "An error occurred while pausing ${errors.length} shares",
                            errors.join("\n\n"));
                      }
                    },
                    icon: Icon(widget.user.shares.any((x) => !x.paused)
                        ? Icons.pause
                        : Icons.play_arrow))
          ],
        )
      ],
    ));
  }
}
