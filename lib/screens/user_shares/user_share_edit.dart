import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/screens/share_links/share_link_edit/share_link_shocker.dart';
import 'package:shock_alarm_app/screens/shares/shocker_share_entry.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/screens/shares/shocker_share_code_entry.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';

import '../../../services/alarm_list_manager.dart';
import '../../../services/openshock.dart';

class UserShareEditScreen extends StatefulWidget {
  OpenShockUserWithShares user;

  UserShareEditScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _UserShareEditScreenState();
}

class _UserShareEditScreenState extends State<UserShareEditScreen> {
  Color activeColor = Colors.green;
  Color inactiveColor = Colors.red;

  @override
  void initState() {
    super.initState();
    loadShare();
  }

  Future<void> loadShare() async {
    await AlarmListManager.getInstance().updateUserShares();
    widget.user = (widget.user.outgoing ? AlarmListManager.getInstance().userShares?.outgoing : AlarmListManager.getInstance().userShares?.incoming)?.firstWhere((x) => x.id == widget.user.id) ?? widget.user;
    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Widget> shareEntries = [];
    for (OpenShockShare share in widget.user.shares) {
      shareEntries.add(ShockerShareEntry(
          share: share,
          showUsername: false,
          key: ValueKey(share.shockerReference?.getIdentifier() ?? share.sharedWith.id),
          onRebuild: () {
            setState(() {
              loadShare();
            });
          }));
    }

    if (shareEntries.isEmpty) {
      shareEntries.add(Center(
          child: Text(
              "No shockers associated with this user anymore.",
              style: t.textTheme.headlineSmall)));
    }
    try {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            spacing: 10,
            children: [Text('Shares with ${widget.user.name}')],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(
            bottom: 15,
            left: 15,
            right: 15,
            top: 50,
          ),
          child: ConstrainedContainer(
                  child: DesktopMobileRefreshIndicator(
                      onRefresh: () async {
                        return loadShare();
                      },
                      child: ListView(children: shareEntries))),
        ),
      );
    } catch (e) {
      print(e);
      return Scaffold(
          body: Center(
              child: Text(
                  "An error occurred while loading the shares with ${widget.user.name}. Please try again later.")));
    }
  }
}
