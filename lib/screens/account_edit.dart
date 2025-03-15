import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/delete_dialog.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/dialogs/ErrorDialog.dart';
import 'package:shock_alarm_app/dialogs/LoadingDialog.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/screens/logs.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

import '../stores/alarm_store.dart';

class AccountEdit extends StatefulWidget {
  Token token;

  AccountEdit({Key? key, required this.token}) : super(key: key);

  @override
  _AccountEditState createState() => _AccountEditState();
}

class _AccountEditState extends State<AccountEdit> {
  List<OpenShockApiToken>? tokens;
  List<OpenShockUserSession>? sessions;

  @override
  void initState() {
    super.initState();
    updateData();
  }

  Future updateData() async {
    tokens = await OpenShockClient().getApiTokens(widget.token);
    setState(() {});
    ErrorContainer<List<OpenShockUserSession>> s = await OpenShockClient().getSessions(widget.token);
    if(s.error != null) {
      ErrorDialog.show("Failed to get sessions", s.error!);
      return;
    }
    sessions = s.value;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text('Account Edit'),
        ),
        body: PagePadding(
            child: ConstrainedContainer(
                child: DesktopMobileRefreshIndicator(
                    onRefresh: updateData,
                    child: ListView(children: [
                      
                      Text(
                        'Account of ${widget.token.name}',
                        textAlign: TextAlign.center,
                        style: t.textTheme.headlineMedium,
                      ),
                      Padding(padding: EdgeInsets.all(15)),
                      Text(
                        "Api Tokens",
                        style: t.textTheme.headlineSmall,
                      ),
                      if (tokens == null)
                        Center(
                          child: CircularProgressIndicator(),
                        ),
                      if (tokens != null)
                        for (var token in tokens!)
                          PaddedCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(token.name,
                                          style: t.textTheme.headlineSmall),
                                      Padding(padding: EdgeInsets.all(5)),
                                      Text(
                                          "last used: ${ShockerLogEntry.formatDateTime(token.lastUsed, fallback: "Never")}",
                                          style: t.textTheme.labelLarge),

                                      Text(
                                          "valid until: ${ShockerLogEntry.formatDateTime(token.validUntil, fallback: "forever")}",
                                          style: t.textTheme.labelLarge),
                                      Text(
                                          "created: ${ShockerLogEntry.formatDateTime(token.createdOn, fallback: "Unknown")}",
                                          style: t.textTheme.labelLarge),
                                      Wrap(
                                        spacing: 5,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text("permissions:",
                                              style: t.textTheme.labelLarge),
                                          for (var permission
                                              in token.permissions)
                                            Chip(label: Text(permission))
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                Row(
                                  spacing: 10,
                                  children: [
                                    IconButton(
                                        onPressed: () async {
                                          await showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  ApiTokenEditDialog(
                                                      token: widget.token,
                                                      apiToken: token));
                                          await updateData();
                                        },
                                        icon: Icon(Icons.edit)),
                                    IconButton(
                                        onPressed: () async {
                                          showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  DeleteDialog(
                                                    onDelete: () async {
                                                      LoadingDialog.show(
                                                          "Deleting Api Token...");
                                                      ErrorContainer<bool>
                                                          error =
                                                          await OpenShockClient()
                                                              .deleteApiToken(
                                                                  widget.token,
                                                                  token);
                                                      Navigator.of(context)
                                                          .pop();
                                                      if (error.error != null) {
                                                        ErrorDialog.show(
                                                            "Failed to delete Api token",
                                                            error.error!);
                                                        return;
                                                      }
                                                      Navigator.of(context)
                                                          .pop();
                                                      await updateData();
                                                    },
                                                    title: "Delete Api Token?",
                                                    body:
                                                        "Do you really want to delete ${token.name} and thus revoke access from any application using it?",
                                                  ));
                                        },
                                        icon: Icon(Icons.delete)),
                                  ],
                                ),
                              ],
                            ),
                          ),


                          Padding(padding: EdgeInsets.all(15)),
                      Text(
                        "Sessions",
                        style: t.textTheme.headlineSmall,
                      ),
                      if (sessions == null)
                        Center(
                          child: CircularProgressIndicator(),
                        ),
                      if (sessions != null)
                        for (var session in sessions!)
                          PaddedCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(session.userAgent ?? "Unknown User Agent",
                                          style: t.textTheme.headlineSmall),
                                      Padding(padding: EdgeInsets.all(5)),
                                      Text(
                                          session.ip ?? "Unknown IP",
                                          style: t.textTheme.labelLarge),
                                      Text(
                                          "last used: ${ShockerLogEntry.formatDateTime(session.lastUsed, fallback: "Never")}",
                                          style: t.textTheme.labelLarge),
                                      Text(
                                          "expires: ${ShockerLogEntry.formatDateTime(session.expires, fallback: "forever")}",
                                          style: t.textTheme.labelLarge),
                                      Text(
                                          "created: ${ShockerLogEntry.formatDateTime(session.created, fallback: "Unknown")}",
                                          style: t.textTheme.labelLarge),
                                    ],
                                  ),
                                ),
                                Row(
                                  spacing: 10,
                                  children: [
                                    IconButton(
                                        onPressed: () async {
                                          showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  DeleteDialog(
                                                    onDelete: () async {
                                                      LoadingDialog.show(
                                                          "Deleting Session...");
                                                      ErrorContainer<bool>
                                                          error =
                                                          await OpenShockClient()
                                                              .deleteSession(
                                                                  widget.token,
                                                                  session);
                                                      Navigator.of(context)
                                                          .pop();
                                                      if (error.error != null) {
                                                        ErrorDialog.show(
                                                            "Failed to delete Session token",
                                                            error.error!);
                                                        return;
                                                      }
                                                      Navigator.of(context)
                                                          .pop();
                                                      await updateData();
                                                    },
                                                    title: "Delete Session?",
                                                    body:
                                                        "Do you really want to delete the session and thus revoke access from any application using it?",
                                                  ));
                                        },
                                        icon: Icon(Icons.delete)),
                                  ],
                                ),
                              ],
                            ),
                          )
                    ])))),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () async {
            await showDialog(
                context: context,
                builder: (context) => ApiTokenEditDialog(
                    token: widget.token,
                    apiToken: OpenShockApiToken("New API Token", [], null)));
            await updateData();
          },
        ));
  }
}

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
    ThemeData t = Theme.of(context);
    return AlertDialog(
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
          Padding(padding: EdgeInsets.all(10)),
          Text("Permissions", style: TextStyle(fontSize: 20)),
          for (var permission in availableApiTokenPermissions)
            Row(
              children: [
                Switch(
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
            Padding(padding: EdgeInsets.all(10)),
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
                      return AlertDialog(
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
