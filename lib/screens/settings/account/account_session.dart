import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/delete_dialog.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/logs/shocker_log_entry.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

class AccountSession extends StatelessWidget {
  OpenShockUserSession session;
  Token token;
  Function() onDeleted;

  AccountSession({Key? key, required this.session, required this.token, required this.onDeleted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
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
                                      Padding(padding: PredefinedSpacing.paddingExtraSmall()),
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
                                                                  token,
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
                                                      onDeleted.call();
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
                          );
  }

}
