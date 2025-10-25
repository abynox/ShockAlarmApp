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
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

import '../../components/constrained_container.dart';
import '../../components/desktop_mobile_refresh_indicator.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _InvitesScreen();

  static getFloatingActionButton(
      AlarmListManager manager, BuildContext context, Function reloadState) {
    return null;
  }
}

class _InvitesScreen extends State<InvitesScreen> {
  bool initialLoading = false;

  Future loadInvites() async {
    await AlarmListManager.getInstance().updateInvites();
    if(!mounted) return;
    setState(() {
      initialLoading = false;
    });
  }

  @override
  void initState() {
    if (AlarmListManager.getInstance().invites == null) {
      initialLoading = true;
      loadInvites();
    }
    AlarmListManager.getInstance().reloadAllMethod = () {
      if(!mounted) return;
      setState(() {});
    };
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Widget> inviteEntries = [];
    if (AlarmListManager.getInstance().invites != null) {
      inviteEntries.add(Text("Incoming", style: t.textTheme.headlineSmall,));
      int counter = 0;
      for (OpenShockShareInvite invite in AlarmListManager.getInstance().invites!.where((x) => !x.outgoing)) {
        inviteEntries
            .add(InviteItem(invite: invite, reloadMethod: loadInvites));
        counter++;
      }
      if(counter == 0) {
        inviteEntries.add(Center(
            child: Text(AlarmListManager.getInstance().hasValidAccount() ? "No incoming invites" : "You're not logged in",
                style: t.textTheme.headlineSmall)));
      }
      counter = 0;
      inviteEntries.add(Text("Outgoing", style: t.textTheme.headlineSmall,));
      for (OpenShockShareInvite invite in AlarmListManager.getInstance().invites!.where((x) => x.outgoing)) {
        inviteEntries
            .add(InviteItem(invite: invite, reloadMethod: loadInvites));
        counter++;
      }
      if(counter == 0) {
        inviteEntries.add(Center(
            child: Text(AlarmListManager.getInstance().hasValidAccount() ? "No outgoing invites" : "You're not logged in",
                style: t.textTheme.headlineSmall)));
      }
    }
    inviteEntries.insert(
        0,
        IconButton(
            onPressed: () {
              InfoDialog.show("What are Invites?",
                  "Invites allow you to easily share shockers with your friends. You can send an invite to a friend by selecting multiple shocker, pressing the 3 dots and then 'create share'. You can then just input your friends username to send them a share invite. On this page they can then accept it. Same goes vice versa.");
            },
            icon: Icon(Icons.info)));
    return initialLoading
            ? Center(child: CircularProgressIndicator())
            : DesktopMobileRefreshIndicator(
                onRefresh: loadInvites,
                child: ConstrainedContainer(child: ListView(children: inviteEntries),));
  }
}

class InviteItem extends StatelessWidget {
  final OpenShockShareInvite invite;
  final Function reloadMethod;

  const InviteItem(
      {Key? key, required this.invite, required this.reloadMethod})
      : super(key: key);

  void showQr() {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) {
        return AlertDialog.adaptive(
          title: Text('QR Code for invite'),
          content: QrCard(data: "openshock://invite/${invite.id}"),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'))
          ],
        );
      });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
        child: Row(
      children: [
        Expanded(child: Text(invite.getDisplayName())),
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
                              LoadingDialog.show("Deleting ${invite.getDisplayName()}");
                              String? error =
                                  await AlarmListManager.getInstance()
                                      .deleteInvite(invite);
                              Navigator.of(context).pop();
                              if (error != null) {
                                ErrorDialog.show("Error deleting invite", error);
                                return;
                              }
                              Navigator.of(context).pop();
                              reloadMethod();
                            },
                            title: "Delete Invite",
                            body:
                                "Are you sure you want to delete the ${invite.outgoing ? "outgoing" : "incoming"} invite '${invite.getDisplayName()}'?");
                      });
                }),
            if(invite.sharedWith == null) ...[IconButton(
                  onPressed: showQr,
                  icon: Icon(Icons.qr_code)),
              IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () {
                    Share.share("I invite you to control my shockers. Here's the invite code: ${invite.id}");
                  })],
            if(!invite.outgoing) IconButton(
                onPressed: () async {
                  LoadingDialog.show("Accepting invite");
                  String? error = await OpenShockClient().acceptInvite(invite.id);
                  Navigator.pop(context);
                  if(error != null) {
                    ErrorDialog.show("Error accepting invite", error);
                    return;
                  }
                  InfoDialog.show("Invite accepted", "You successfully accepted the invite by ${invite.getDisplayName()}. You can now control their shockers via the shockers page");
                  AlarmListManager.getInstance().updateShockerStore();
                  reloadMethod();
                },
                icon: Icon(Icons.check))
          ],
        )
      ],
    ));
  }
}
