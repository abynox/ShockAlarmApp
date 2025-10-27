import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/screens/settings/settings_screen.dart';
import 'package:shock_alarm_app/screens/share_links/share_links.dart';
import 'package:shock_alarm_app/screens/shockers/individual/shockers.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/screens/tools/bottom/shocker_unpause_dialog.dart';
import 'package:shock_alarm_app/screens/user_shares/create_user_share_dialog.dart';
import 'package:shock_alarm_app/screens/user_shares/invites_screen.dart';
import 'package:shock_alarm_app/screens/user_shares/user_shares_screen.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

class UserShareScreen extends StatefulWidget {
  int i = 1;

  @override
  State<StatefulWidget> createState() => _UserShareScreen();

  static getFloatingActionButton(BuildContext context, Function reloadState) {
    return FloatingActionButton(
        onPressed: () {
          if (!AlarmListManager.supportsWs()) {
            if (!AlarmListManager.getInstance().hasValidAccount()) {
              ErrorDialog.show("Not logged in",
                  "Login to OpenShock to create a Share Link. To do this visit the settings page.");
              return;
            }
            showDialog(
                context: context,
                builder: (builder) => ShareLinkCreationDialog());
          }
          showDialog(
            context: context,
            builder: (context) => AlertDialog.adaptive(
              title: Text("Shares"),
              content: Text("What do you want to do?"),
              actions: <Widget>[
                TextButton(onPressed: () async {      
                  Navigator.pop(context);
                  showDialog(context: context, builder: (context) => ShockerSelectDialog("Select shockers to share", (shockers) {
                    Navigator.pop(context);
                    showDialog(context: context, builder: (context) => CreateUserShareDialog(shockersToShare: shockers));
                  }, "Continue"));
                }, child: Text("Create Invite")),
                TextButton(onPressed: () async {
                  Navigator.of(context).pop();
                  ShockerScreen.startRedeemShareCode(AlarmListManager.getInstance(), context, reloadState);
                }, child: Text("Claim Invite or share code")),
                TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      if (!AlarmListManager.getInstance().hasValidAccount()) {
                        ErrorDialog.show("Not logged in",
                            "Login to OpenShock to create a Share Link. To do this visit the settings page.");
                        return;
                      }
                      showDialog(
                          context: context,
                          builder: (context) => ShareLinkCreationDialog());
                    },
                    child: Text("Create share link")),
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
              ],
            ),
          );
        },
        child: Icon(Icons.add));
  }
}

class _UserShareScreen extends State<UserShareScreen> {
  void changeScreen(Set<int> i) {
    setState(() {
      widget.i = i.firstOrNull ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedContainer(
        child: Column(
      children: [
        Padding(padding: PredefinedSpacing.paddingLarge()),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text("Share links")),
            ButtonSegment(value: 1, label: Text("Shared")),
            ButtonSegment(value: 2, label: Text("Invites")),
          ],
          showSelectedIcon: false,
          selected: {
            widget.i
          },
          emptySelectionAllowed: false,
          multiSelectionEnabled: false,
          onSelectionChanged: changeScreen),
        if (widget.i == 0)
          Expanded(child: ShareLinksScreen())
        else if (widget.i == 1)
          Expanded(child: UserSharesScreen())
        else if (widget.i == 2)
          Expanded(child: InvitesScreen())
      ],
    ));
  }
}
