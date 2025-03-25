
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/main.dart';

class LoadingDialog extends StatelessWidget {
  final String title;
  const LoadingDialog({
    required this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
        title: Text(title),
        content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [CircularProgressIndicator()]),
        actions: []);
  }

  static void show(String title) {
    showDialog(
        context: navigatorKey.currentContext!, builder: (context) => LoadingDialog(title: title));
  }
}