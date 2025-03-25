import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/delete_dialog.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/screens/logs/shocker_log_entry.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/settings/account/account_session.dart';
import 'package:shock_alarm_app/screens/settings/account/api_token_edit_dialog.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

import '../../../stores/alarm_store.dart';

class AccountEditScreen extends StatefulWidget {
  Token token;

  AccountEditScreen({Key? key, required this.token}) : super(key: key);

  @override
  _AccountEditScreenState createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
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
    ErrorContainer<List<OpenShockUserSession>> s =
        await OpenShockClient().getSessions(widget.token);
    if (s.error != null) {
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
                      PredefinedSpacing(),
                      Text(
                        "Api Tokens",
                        style: t.textTheme.headlineSmall,
                      ),
                      if (tokens == null)
                        Center(
                          child: CircularProgressIndicator(),
                        ),
                      if (tokens != null)
                        ...tokens!.map((token) => ApiToken(
                            token: token,
                            userToken: widget.token,
                            onUpdated: updateData)),
                      PredefinedSpacing(),
                      Text(
                        "Sessions",
                        style: t.textTheme.headlineSmall,
                      ),
                      if (sessions == null)
                        Center(
                          child: CircularProgressIndicator(),
                        ),
                      if (sessions != null)
                        ...sessions!.map((session) => AccountSession(
                            session: session,
                            token: widget.token,
                            onDeleted: updateData))
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

class ApiToken extends StatelessWidget {
  OpenShockApiToken token;
  Token userToken;
  Function() onUpdated;

  ApiToken(
      {Key? key,
      required this.token,
      required this.userToken,
      required this.onUpdated})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(token.name, style: t.textTheme.headlineSmall),
                Padding(padding: PredefinedSpacing.paddingExtraSmall()),
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
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text("permissions:", style: t.textTheme.labelLarge),
                    for (var permission in token.permissions)
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
                        builder: (context) => ApiTokenEditDialog(
                            token: userToken, apiToken: token));
                    onUpdated.call();
                  },
                  icon: Icon(Icons.edit)),
              IconButton(
                  onPressed: () async {
                    showDialog(
                        context: context,
                        builder: (context) => DeleteDialog(
                              onDelete: () async {
                                LoadingDialog.show("Deleting Api Token...");
                                ErrorContainer<bool> error =
                                    await OpenShockClient()
                                        .deleteApiToken(userToken, token);
                                Navigator.of(context).pop();
                                if (error.error != null) {
                                  ErrorDialog.show("Failed to delete Api token",
                                      error.error!);
                                  return;
                                }
                                Navigator.of(context).pop();
                                onUpdated.call();
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
    );
  }
}
