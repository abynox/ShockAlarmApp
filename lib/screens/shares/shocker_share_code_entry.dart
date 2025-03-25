import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/screens/share_links/share_link_edit/share_link_edit.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

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
      _ShockerShareCodeEntryState(shareCode, manager, onDeleted);
}

class _ShockerShareCodeEntryState extends State<ShockerShareCodeEntry> {
  final OpenShockShareCode shareCode;
  final AlarmListManager manager;
  final Function() onDeleted;
  OpenShockShareLimits limits = OpenShockShareLimits();
  bool editing = false;
  bool deleting = false;

  _ShockerShareCodeEntryState(this.shareCode, this.manager, this.onDeleted);

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
                          "You created this share. No user has claimed it yet. You can use the share button to share the code with your friend. When they claim the code they will have access to your shocker.");
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
                          ErrorDialog.show("Error deleting share code", error);
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
              ],
            )
          ],
        ),
      ],
    ));
  }
}
