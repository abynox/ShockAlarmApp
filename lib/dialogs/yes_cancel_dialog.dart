import 'package:flutter/material.dart';
import 'package:shock_alarm_app/main.dart';

class YesCancelDialog {
  static void show(String title, String body, VoidCallback onYes) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog.adaptive(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(onPressed: onYes, child: Text("Yes"))
              ],
            );
      },
    );
  }
}
