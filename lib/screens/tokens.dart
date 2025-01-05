import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';
import '../components/bottom_add_button.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../components/token_item.dart';

class TokenScreen extends StatefulWidget {
  final AlarmListManager manager;

  const TokenScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => TokenScreenState(manager);
}

class TokenScreenState extends State<TokenScreen> {
  final AlarmListManager manager;

  void rebuild() {
    setState(() {});
  }

  Future showErrorDialog(String title, String message) async {
    return showDialog(context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Ok")
          )
        ],
      );
    });
  }

  Future showLoginPopup() async {
    TextEditingController serverController = TextEditingController();
    TextEditingController usernameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    serverController.text = "https://api.openshock.app";
    return showDialog(context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Login to OpenShock"),
        content: Column(
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                labelText: "Server"
              ),
              controller: serverController,

            ),
            TextField(
              decoration: InputDecoration(
                labelText: "Email"
              ),
              controller: usernameController,
            ),
            TextField(
              decoration: InputDecoration(
                labelText: "Password"
              ),
              obscureText: true,
              obscuringCharacter: "*",
              controller: passwordController,
            )
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Cancel")
          ),
          TextButton(
            onPressed: () async {
              bool worked  = await manager.login(serverController.text, usernameController.text, passwordController.text);
              if(worked) Navigator.of(context).pop();
              else {
                showErrorDialog("Login failed", "Check server, email and password");
              }
            },
            child: Text("Login")
          )
        ],
      );
    });
  }

  TokenScreenState(this.manager);
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(
        children: <Widget>[
          Text(
            'Your accounts/tokens',
            style: t.textTheme.headlineMedium,
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final token = manager.getTokens()[index];

                return TokenItem(token: token, manager: manager, onRebuild: rebuild, key: ValueKey(token.id),);
              },
              itemCount: manager.getTokens().length,
            ),
          ),
          BottomAddButton(
            onPressed: () {
              final newToken = new Token(
                DateTime.now().millisecondsSinceEpoch,
                ""
              );
              setState(() {
                manager.saveToken(newToken);
              });
            },
          ),
          FilledButton(onPressed: () {
            showLoginPopup();
          }, child: Text("Log in to OpenShock", style: TextStyle(fontSize: t.textTheme.titleMedium!.fontSize)),)
        ],
      );
  }
}