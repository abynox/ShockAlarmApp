import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/haptic_switch.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'account/account_edit.dart';
import '../../stores/alarm_store.dart';
import '../../services/alarm_list_manager.dart';

class TokenItem extends StatefulWidget {
  final Token token;
  final AlarmListManager manager;
  final Function onRebuild;

  const TokenItem(
      {Key? key,
      required this.token,
      required this.manager,
      required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      TokenItemState(token, manager, onRebuild);
}

class TokenItemState extends State<TokenItem> {
  final Token token;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;
  bool deleting = false;

  TokenItemState(this.token, this.manager, this.onRebuild);

  void _delete() async {
    deleting = true;
    if (token.flavor == TokenFlavor.openshock) {
      String? error = await manager.deleteToken(token);
      await manager.updateShockerStore();
      if (error != null) {
        setState(() {
          deleting = false;
        });
        ErrorDialog.show("Failed to sign out", error);
      }
    } else if (token.flavor == TokenFlavor.alarmserver) {
      await manager.deleteAlarmServerToken(token);
    }
    onRebuild();
  }

  void _save() {
    if (token.flavor == TokenFlavor.openshock)
      manager.saveToken(token);
    else if (token.flavor == TokenFlavor.alarmserver)
      manager.saveAlarmServerToken(token);
    expanded = false;
    onRebuild();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Token saved'),
      duration: Duration(seconds: 1),
    ));
  }

  void askLogout() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Logout?"),
              content: Text("Do you want to log out?"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      _delete();
                    },
                    child: Text("Logout"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (token.type == TokenType.session)
                    Text(
                      token.invalidSession
                          ? "Invalid session, log in again "
                          : "Logged in as ",
                    ),
                  if (token.type == TokenType.token)
                    Text(
                      "Api Token",
                    ),
                  if (token.type == TokenType.sharelink)
                    Text(
                      "Share Link", 
                    ),
                  Text(
                    token.type == TokenType.sharelink ? "${token.name} (${token.userId})" : token.name,
                    style: t.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${token.flavor == TokenFlavor.openshock ? "OpenShock" : "AlarmServer"} (${token.server.replaceAll("http://", "").replaceAll("https://", "")})",
                    style: t.textTheme.labelSmall,
                  ),
                  if (token.serverUnreachable)
                    Text("Couldn't reach server",
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: t.colorScheme.error)),
                  if (token.invalidSession)
                    Text("Invalid session, please log in again",
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: t.colorScheme.error)),
                ],
              ),
              Row(
                spacing: 10,
                children: [
                  if (manager.settings.allowTokenEditing)
                    IconButton(
                        onPressed: () {
                          setState(() {
                            expanded = !expanded;
                          });
                        },
                        icon: Icon(expanded
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded)),
                  if (!manager.settings.allowTokenEditing && deleting)
                    CircularProgressIndicator(),
                  if (token.flavor == TokenFlavor.openshock && token.type == TokenType.session)
                    IconButton(
                      icon: Icon(Icons.person),
                      onPressed: () async {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                AccountEditScreen(token: token)));
                        onRebuild();
                      },
                    ),
                  if (!manager.settings.allowTokenEditing && !deleting)
                    IconButton(
                      icon: Icon(Icons.logout),
                      onPressed: askLogout,
                    ),
                ],
              )
            ],
          ),
          if (expanded)
            Column(
              children: [
                TextField(
                  controller: TextEditingController(text: token.token),
                  style: t.textTheme.bodyMedium,
                  onChanged: (newToken) => token.token = newToken,
                  obscureText: true,
                  decoration: InputDecoration(labelText: "Token"),
                  obscuringCharacter: "*",
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text("Is session"),
                    HapticSwitch(
                      value: token.type == TokenType.session,
                      onChanged: (value) {
                        setState(() {
                          token.type = value ? TokenType.session : TokenType.token;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    if (deleting) CircularProgressIndicator(),
                    if (!deleting)
                      IconButton(
                        icon: Icon(Icons.logout),
                        onPressed: _delete,
                      ),
                    IconButton(
                      icon: Icon(Icons.save),
                      onPressed: _save,
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
