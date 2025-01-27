import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/shock_disclamer.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future showTokenLoginPopup() async {
    TextEditingController serverController = TextEditingController();
    TextEditingController tokenController = TextEditingController();
    serverController.text = "https://api.openshock.app";
    GestureRecognizer recognizer = TapGestureRecognizer()..onTap = () {
      launchUrl(Uri.parse("https://next.openshock.app/settings/api-tokens"));
    };
    return showDialog(context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Login to OpenShock"),
        content: SingleChildScrollView(child: 
          Column(
            children: <Widget>[
              DefaultTextStyle(style: Theme.of(context).textTheme.bodyMedium!, child: SelectableText.rich(TextSpan(children: [
                TextSpan(text: "As you are using a browser, you must use a token to sign in. To get one visit "),
                TextSpan(text: "https://next.openshock.app/settings/api-tokens", recognizer: recognizer, style: TextStyle(color: Theme.of(context).hintColor, decoration: TextDecoration.underline), mouseCursor: SystemMouseCursors.click),
                TextSpan(text: " and generate a token with all permissions. Then paste it here.")
              ]
              
              ))),
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
                        labelText: "Token"
                      ),
                      obscureText: true,
                      obscuringCharacter: "*",
                      controller: tokenController
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
              bool worked  = await manager.loginToken(serverController.text, tokenController.text);
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
          FilledButton(onPressed: () async {
            await showDialog(context: context, builder: (context) => ShockDisclaimer());
            if(kIsWeb) {
              showTokenLoginPopup();
            }
            else {
              showLoginPopup();
            }
          }, child: Text("Log in to OpenShock", style: TextStyle(fontSize: t.textTheme.titleMedium!.fontSize)),),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Theme"),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Icon(Icons.devices)),
                  ButtonSegment(value: 1, label: Icon(Icons.sunny)),
                  ButtonSegment(value: 2, label: Icon(Icons.nightlight)),
                ],
                selected: {
                  switch(context.findAncestorStateOfType<MyAppState>()?.themeMode){
                    null => throw UnimplementedError(), // should never be null ig
                    ThemeMode.system => 0,
                    ThemeMode.light => 1,
                    ThemeMode.dark => 2,
                  }
                },
                onSelectionChanged: (Set<int> newSelection) {
                  if(newSelection.isNotEmpty) {
                    switch(newSelection.first) {
                      case 0:
                        context.findAncestorStateOfType<MyAppState>()?.setThemeMode(ThemeMode.system);
                        break;
                      case 1:
                        context.findAncestorStateOfType<MyAppState>()?.setThemeMode(ThemeMode.light);
                        break;
                      case 2:
                        context.findAncestorStateOfType<MyAppState>()?.setThemeMode(ThemeMode.dark);
                        break;
                    }
                  }
                },
              )
            ],
          ),
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
              Text("Use range slider for intensity"),
              Switch(value: manager.settings.useRangeSliderForIntensity, onChanged: (value) {
                setState(() {
                  manager.settings.useRangeSliderForIntensity = value;
                  manager.saveSettings();
                });
              })
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Use range slider for duration"),
              Switch(value: manager.settings.useRangeSliderForDuration, onChanged: (value) {
                setState(() {
                  manager.settings.useRangeSliderForDuration = value;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Use http instead of ws for shocking"),
              Switch(value: manager.settings.useHttpShocking, onChanged: (value) {
                setState(() {
                  manager.settings.useHttpShocking = value;
                  manager.saveSettings();
                });
              })
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
            TextButton(onPressed: () {
            showDialog(context: context, builder: (context) => AlertDialog(
              title: Text("About"),
              content: Text("This app is made by ComputerElite. It is fully open source and can be found on GitHub. If you have any issues, report them there. Thank you so much for using my app! See safety rules in the safety section for more information."),
              actions: [
                TextButton(
                    onPressed: () {
                      launchUrl(Uri.parse(issues_url));
                    },
                    child: Text("Report issue")),
                TextButton(onPressed: () {
                  Navigator.of(context).pop();
                }, child: Text("Ok"))
              ]));
          }, child: Text("About")),
          TextButton(onPressed: () {
            showDialog(context: context, builder: (context) => ShockDisclaimer());
          }, child: Text("Safety")),
          ],)
        ],
      );
  }
}