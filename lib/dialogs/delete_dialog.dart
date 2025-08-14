import 'package:flutter/material.dart';

class DeleteDialog extends StatelessWidget {
  VoidCallback onDelete;
  String title;
  String body;

  DeleteDialog(
      {required this.onDelete, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(title),
      content: SingleChildScrollView(child: Text(body)),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Cancel")),
        TextButton(onPressed: onDelete, child: Text("Delete"))
      ],
    );
  }
}
