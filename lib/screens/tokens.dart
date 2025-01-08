import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import '../components/token_item.dart';
import 'shares.dart';

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
        content: SingleChildScrollView(child: 
          Column(
            children: <Widget>[
              TextField(
                decoration: InputDecoration(
                  labelText: "Server"
                ),
                controller: serverController,

              ),
              AutofillGroup(child: 
                Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Email"
                      ),
                      controller: usernameController,
                      autofillHints: [AutofillHints.email],
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Password"
                      ),
                      obscureText: true,
                      obscuringCharacter: "*",
                      controller: passwordController,
                      autofillHints: [AutofillHints.password],
                    )
                  ],
                )
              )
              
            ],
          ),
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
              showDialog(context: context, builder: (context) => LoadingDialog(title: "Logging in"));
              bool worked  = await manager.login(serverController.text, usernameController.text, passwordController.text);
              if(worked) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
              else {
                Navigator.of(context).pop();
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
    return ListView(
        children: <Widget>[
          Column(
            spacing: 10,
            children: [
              Text(
                'Settings',
                style: t.textTheme.headlineMedium,
              ),

              for(var token in manager.getTokens())
                TokenItem(token: token, manager: manager, onRebuild: rebuild, key: ValueKey(token.id)),
              if(manager.getTokens().isEmpty)
                Card(
                  color: t.colorScheme.onInverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: 
                    Text("You are not logged in, please log in to access your devices", style: t.textTheme.headlineSmall),
                  ),
                ),
              
            ],
          ),
          FilledButton(onPressed: () {
            showLoginPopup();
          }, child: Text("Log in to OpenShock", style: TextStyle(fontSize: t.textTheme.titleMedium!.fontSize)),),
          
          // Actual options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Show option for random delay"),
              Switch(value: manager.settings.showRandomDelay, onChanged: (value) {
                setState(() {
                  manager.settings.showRandomDelay = value;
                  manager.saveSettings();
                });
              })
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Use range slider for random delay"),
              Switch(value: manager.settings.useRangeSliderForRandomDelay, onChanged: (value) {
                setState(() {
                  manager.settings.useRangeSliderForRandomDelay = value;
                  manager.saveSettings();
                });
              })
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Disable hub filtering"),
              Switch(value: manager.settings.disableHubFiltering, onChanged: (value) {
                setState(() {
                  manager.settings.disableHubFiltering = value;
                  manager.saveSettings();
                });
              })
            ],
          ),
          IconButton(onPressed: () {
            showDialog(context: context, builder: (context) => AlertDialog(
              title: Text("About"),
              content: Text("This app is made by ComputerElite. It is fully open source and can be found on GitHub. If you have any issues, please report them there. Thank you so much for using my app!"),
              actions: [
                TextButton(onPressed: () {
                  Navigator.of(context).pop();
                }, child: Text("Ok"))
              ]));
          }, icon: Icon(Icons.info))
        ],
      );
  }
}