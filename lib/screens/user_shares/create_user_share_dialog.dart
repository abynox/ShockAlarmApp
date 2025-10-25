import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/dialogs/share_or_qr_dialog.dart';
import 'package:shock_alarm_app/screens/shares/shares.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/limits.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class CreateUserShareDialog extends StatefulWidget {
  List<Shocker> shockersToShare;
  OpenShockShareLimits limits = OpenShockShareLimits();
  OpenShockUser? user;


  CreateUserShareDialog({required this.shockersToShare});
  
  @override
  State<StatefulWidget> createState() => _CreateUserShareDialog();
}

class _CreateUserShareDialog extends State<CreateUserShareDialog> {
  @override Widget build(BuildContext context) {
    // TODO: implement build
    return AlertDialog.adaptive(title: Text("Create share invite"),content: ShockerShareEntryEditor(limits: widget.limits),actions: [
      TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      LoadingDialog.show("Creating invite");
                      widget.limits.validate();

                      ErrorContainer<String> error = await OpenShockClient()
                          .createInvite(widget.shockersToShare, widget.limits, widget.user);
                      Navigator.of(context).pop();
                      if (error.error != null) {
                        ErrorDialog.show("Failed to create invite", error.error!);
                        return;
                      }
                      Navigator.of(context).pop();
                      if(widget.user != null) {
                        InfoDialog.show("Invite sent", "${widget.user?.name} got an invite to accept your share. Once they accept it they will have access to the shockers you shares. If you want to revoke the invite just cancel it in the Shares tab.");
                      } else {
                        ShareOrQrDialog.show("Invite created", "Share it with your friend! You can always do this at a later time via the Shares tab.", "I invite you to control my shockers. Here's the invite code: ${error.value}", "openshock://invite/${error.value}", "Scan to claim invite");
                      }
                    },
                    child: Text("Create share"))
    ],);
  }
}