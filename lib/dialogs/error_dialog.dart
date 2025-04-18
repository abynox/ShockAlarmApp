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

  static void showDelayed(String title, String message) {
    // Cursed, but doesn't throw errors when building
    Future.delayed(const Duration(milliseconds: 1), () {
      show(title, message);
    });
  }
}