import 'package:flutter/material.dart';
import 'package:shock_alarm_app/dialogs/ErrorDialog.dart';
import '../screens/account_edit.dart';
import '../stores/alarm_store.dart';
import '../services/alarm_list_manager.dart';

class TokenItem extends StatefulWidget {
  final Token token;
  final AlarmListManager manager;
  final Function onRebuild;

  const TokenItem({Key? key, required this.token, required this.manager, required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => TokenItemState(token, manager, onRebuild);
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
    if(token.tokenType == TokenType.openshock) {
      String? error = await manager.deleteToken(token);
      await manager.updateShockerStore();
      if(error != null) {
        setState(() {
          deleting = false;
        });
        ErrorDialog.show("Failed to sign out", error);
      }
    } else if(token.tokenType == TokenType.alarmserver) {
      await manager.deleteAlarmServerToken(token);
    }
    onRebuild();
  }

  void _save() {
    if(token.tokenType == TokenType.openshock)
      manager.saveToken(token);
    else if(token.tokenType == TokenType.alarmserver)
      manager.saveAlarmServerToken(token);
    expanded = false;
    onRebuild();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Token saved'),
      duration: Duration(seconds: 1),
    ));
  }

  void askLogout() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text("Logout?"),
      content: Text("Do you want to log out?"),
      actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Cancel")),
        TextButton(onPressed: () async {
          Navigator.of(context).pop();
          _delete();
        }, child: Text("Logout"))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return 
      Card(
        color: t.colorScheme.onInverseSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if(token.isSession)
                        Text(
                          token.invalidSession ? "Invalid session, log in again " : "Logged in as ",
                        ),
                      if(!token.isSession)
                        Text(
                          "Api Token",
                        ),
                      Text(
                        token.name,
                        style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(token.tokenType==TokenType.openshock? "OpenShock" : "AlarmServer")
                    ],
                  ),
                  Row(
                    spacing: 10,
                    children: [
                    if(manager.settings.allowTokenEditing)
                      IconButton(onPressed: () {setState(() {
                        expanded = !expanded;
                      });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)),
                    if(!manager.settings.allowTokenEditing && deleting)
                      CircularProgressIndicator(),
                    if(token.tokenType == TokenType.openshock && token.isSession)
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () async {
                          Navigator.of(context).push(MaterialPageRoute(builder: (context) => AccountEdit(token: token)));
                          onRebuild();
                        },
                      ),
                  if(!manager.settings.allowTokenEditing && !deleting)
                    IconButton(
                      icon: Icon(Icons.logout),
                      onPressed: askLogout,
                    ),
                  ],)
                ],
              ),
              if (expanded) Column(
                children: [
                  TextField(
                        controller: TextEditingController(text: token.token),
                        style: t.textTheme.bodyMedium,
                        onChanged: (newToken) => token.token = newToken,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Token"
                        ),
                        obscuringCharacter: "*",
                      ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text("Is session"),
                      Switch(
                        value: token.isSession,
                        onChanged: (value) {
                          setState(() {
                            token.isSession = value;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      if(deleting)
                        CircularProgressIndicator(),
                      if(!deleting)
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
          )
        ),
      );
  }
}