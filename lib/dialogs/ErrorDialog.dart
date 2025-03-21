import 'package:flutter/material.dart';
import 'package:shock_alarm_app/main.dart';

class ErrorDialog {
  static Future show(String title, String message) async {
    return showDialog(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return AlertDialog.adaptive(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Ok"))
            ],
          );
        });
  }
}