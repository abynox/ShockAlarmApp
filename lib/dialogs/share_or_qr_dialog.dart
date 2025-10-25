import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/main.dart';

class ShareOrQrDialog extends StatelessWidget {
  String title;
  String body;
  String shareString;
  String qrContent;
  String qrTitle;

  ShareOrQrDialog(
      {required this.title, required this.body, required this.shareString, required this.qrContent, required this.qrTitle});

  static void show(String title, String body, String shareString, String qrContent, String qrTitle) {
    showDialog(
        context: navigatorKey.currentContext!, builder: (context) => ShareOrQrDialog(title: title, body: body, shareString: shareString, qrContent: qrContent, qrTitle: qrTitle));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(title),
      content: SingleChildScrollView(child: Column(
        children: [
          Text(body),
          Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 30, children: [
            IconButton(onPressed: () {
              Share.share(shareString);
            }, icon: Icon(Icons.share, size: 32,)),
            IconButton(onPressed: () {
              showDialog(context: context, builder: (context) => AlertDialog.adaptive(
                title: Text(qrTitle),
                content: QrCard(data: qrContent),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Close'))
                ],
              ));
            }, icon: Icon(Icons.qr_code, size: 32,)),
          ],)
        ],
        
      )),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Close"))
      ],
    );
  }
}
