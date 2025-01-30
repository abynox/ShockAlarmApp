import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/components/card.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/screens/share_link_edit.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

import '../components/desktop_mobile_refresh_indicator.dart';

class ShareLinksScreen extends StatefulWidget {
  const ShareLinksScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShareLinksScreenState();
}

class ShareLinksScreenState extends State<ShareLinksScreen> {
  List<OpenShockShareLink> shareLinks = [];
  bool initialLoading = true;

  Future loadShares() async {
    shareLinks = await AlarmListManager.getInstance().getShareLinks();
    initialLoading = false;
  }

  @override
  void initState() {
    // TODO: implement initState
    initialLoading = true;
    loadShares().then((value) {
      setState(() {
        initialLoading = false;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final shareEntries =
        shareLinks.map((link) => ShareLinkItem(shareLink: link)).toList();
    return initialLoading
        ? Center(child: CircularProgressIndicator())
        : DesktopMobileRefreshIndicator(
            onRefresh: () async {
              return loadShares();
            },
            child: ListView(children: shareEntries));
  }
}

class ShareLinkItem extends StatelessWidget {
  final OpenShockShareLink shareLink;

  const ShareLinkItem({Key? key, required this.shareLink}) : super(key: key);

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
                  AlarmListManager.getInstance().deleteShareLink(shareLink);
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
                IconButton(onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                    return ShareLinkEditScreen(shareLink: shareLink);
                  }));
                }, icon: Icon(Icons.edit))
          ],
        )
      ],
    ));
  }
}
