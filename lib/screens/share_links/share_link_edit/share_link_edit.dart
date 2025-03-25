import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/screens/share_links/share_link_edit/share_link_shocker.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/screens/shares/shocker_share_code_entry.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';

import '../../../services/alarm_list_manager.dart';
import '../../../services/openshock.dart';
import '../../shares/shares.dart';

class ShareLinkEditScreen extends StatefulWidget {
  OpenShockShareLink shareLink;

  ShareLinkEditScreen({Key? key, required this.shareLink}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ShareLinkEditScreenState();
}

class _ShareLinkEditScreenState extends State<ShareLinkEditScreen> {
  bool initialLoading = false;
  Color activeColor = Colors.green;
  Color inactiveColor = Colors.red;
  OpenShockShareLink? shareLink;

  @override
  void initState() {
    super.initState();
    initialLoading = true;
    loadShare();
  }

  Future<void> loadShare() async {
    shareLink =
        await AlarmListManager.getInstance().getShareLink(widget.shareLink);
    setState(() {
      initialLoading = false;
    });
  }

  Future addShocker() async {
    List<String> existingShockers =
        shareLink!.shockers.map((e) => e.id).toList();
    List<Shocker> ownShockers = await AlarmListManager.getInstance()
        .shockers
        .where((element) =>
            element.isOwn && !existingShockers.contains(element.id) && element.apiTokenId == widget.shareLink.tokenId )
        .toList();
    Shocker? selectedShocker = null;
    OpenShockShareLimits limits = OpenShockShareLimits();

    if (ownShockers.length <= 0) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog.adaptive(
                title: Text("All done"),
                content: Text(
                    "You have already added all your shockers to this share link."),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text("Ok"))
                ],
              ));
      return;
    }

    await showDialog(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Add a shocker to the share link"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownMenu<Shocker?>(
                      dropdownMenuEntries: ownShockers
                          .map((shocker) => DropdownMenuEntry<Shocker?>(
                              value: shocker, label: shocker.name))
                          .toList(),
                      initialSelection: selectedShocker,
                      onSelected: (value) {
                        setState(() {
                          selectedShocker = value;
                        });
                      }),
                  ShockerShareEntryEditor(limits: limits),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      if (selectedShocker == null) {
                        ErrorDialog.show("Error", "Please select a shocker to add");
                        return;
                      }
                      LoadingDialog.show("Adding shocker");

                      String? error = await AlarmListManager.getInstance()
                          .addShockerToShareLink(selectedShocker, shareLink!);
                      if (error != null) {
                        Navigator.of(context).pop();
                        ErrorDialog.show("Error adding shocker", error);
                        return;
                      }
                      error = await OpenShockClient()
                          .setLimitsOfShareLinkShocker(
                              shareLink!, selectedShocker!, limits);
                      Navigator.of(context).pop();
                      if (error != null) {
                        ErrorDialog.show("Error setting limits", error);
                        return;
                      }
                      Navigator.of(context).pop();
                    },
                    child: Text("Add shocker"))
              ],
            ));
    setState(() {
      loadShare();
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Widget> shareEntries = [];
    if (shareLink != null) {
      for (Shocker shocker in shareLink!.shockers) {
        shareEntries.add(ShareLinkShocker(
            shareLink: shareLink!,
            shocker: shocker,
            key: ValueKey(shocker.getIdentifier()),
            onRebuild: () {
              setState(() {
                loadShare();
              });
            }));
      }
    }

    if (shareEntries.isEmpty) {
      shareEntries.add(Center(
          child: Text(
              "This share link doesn't have any shockers yet. You can add a shocker by pressing the add button below.",
              style: t.textTheme.headlineSmall)));
    }
    try {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            spacing: 10,
            children: [Text('ShareLink ${widget.shareLink.name}')],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(
            bottom: 15,
            left: 15,
            right: 15,
            top: 50,
          ),
          child: initialLoading
              ? Center(child: CircularProgressIndicator())
              : ConstrainedContainer(
                  child: DesktopMobileRefreshIndicator(
                      onRefresh: () async {
                        return loadShare();
                      },
                      child: ListView(children: shareEntries))),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            addShocker();
          },
          child: Icon(Icons.add),
        ),
      );
    } catch (e) {
      print(e);
      return Scaffold(
          body: Center(
              child: Text(
                  "An error occurred while loading the share link. Please try again later.")));
    }
  }
}
