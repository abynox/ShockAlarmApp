import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/haptic_switch.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

class ApiTokenEditDialog extends StatefulWidget {
  Token token;
  OpenShockApiToken apiToken;

  ApiTokenEditDialog({Key? key, required this.token, required this.apiToken})
      : super(key: key);

  @override
  _ApiTokenEditDialogState createState() => _ApiTokenEditDialogState();
}

class _ApiTokenEditDialogState extends State<ApiTokenEditDialog> {
  TextEditingController nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    nameController.text = widget.apiToken.name;
    return AlertDialog.adaptive(
      title:
          Text("${widget.apiToken.id == null ? "Create" : "Edit"} Api Token"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Name", style: TextStyle(fontSize: 20)),
          TextField(
            controller: nameController,
            onChanged: (value) => widget.apiToken.name = value,
          ),
          PredefinedSpacing(),
          Text("Permissions", style: TextStyle(fontSize: 20)),
          for (var permission in availableApiTokenPermissions)
            Row(
              children: [
                HapticSwitch(
                    value: widget.apiToken.permissions.contains(permission),
                    onChanged: (value) {
                      if (value) {
                        widget.apiToken.permissions.add(permission);
                      } else {
                        widget.apiToken.permissions.remove(permission);
                      }
                      setState(() {});
                    }),
                Text(permission),
              ],
            ),
          if (widget.apiToken.id == null) ...[
            PredefinedSpacing(),
            Text(
                "Valid until: ${widget.apiToken.validUntil == null ? "forever" : widget.apiToken.validUntil.toString().split(".").first}",
                style: TextStyle(fontSize: 20)),
            FilledButton(
                onPressed: () async {
                  widget.apiToken.validUntil = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                      initialDate: widget.apiToken.validUntil);
                  if (widget.apiToken.validUntil == null) return;
                  TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay.fromDateTime(widget.apiToken.validUntil!));
                  setState(() {
                    widget.apiToken.validUntil = DateTime(
                        widget.apiToken.validUntil!.year,
                        widget.apiToken.validUntil!.month,
                        widget.apiToken.validUntil!.day,
                        time!.hour,
                        time.minute);
                  });
                },
                child: Text("Change validity")),
          ]
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
              if (widget.apiToken.id == null) {
                // Create
                LoadingDialog.show("Creating Api Token...");
                ErrorContainer<String> error = await OpenShockClient()
                    .createApiToken(widget.token, widget.apiToken);
                Navigator.of(context).pop();
                if (error.error != null) {
                  ErrorDialog.show("Failed to update Api token", error.error!);
                  return;
                }
                Navigator.of(context).pop();
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog.adaptive(
                        title: Text(
                            'QR Code for Api Token ${widget.apiToken.name}'),
                        content: QrCard(data: error.value!),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Close'))
                        ],
                      );
                    });
                return;
              }
              LoadingDialog.show("Updating Api Token...");
              ErrorContainer<bool> error = await OpenShockClient()
                  .updateApiToken(widget.token, widget.apiToken);
              Navigator.of(context).pop();
              if (error.error != null) {
                ErrorDialog.show("Failed to update Api token", error.error!);
                return;
              }
              Navigator.of(context).pop();
            },
            child: Text(widget.apiToken.id == null ? "Create" : "Update")),
      ],
    );
  }
}
