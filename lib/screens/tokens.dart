import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/shock_disclamer.dart';
import 'package:shock_alarm_app/dialogs/ErrorDialog.dart';
import 'package:shock_alarm_app/dialogs/InfoDialog.dart';
import 'package:shock_alarm_app/dialogs/LoadingDialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/screens/tones.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/token_item.dart';
import '../stores/alarm_store.dart';
import 'shares.dart';
import 'tools.dart';

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

  Future doAlarmServerLogin(String server, String username, String password, bool register) async {
    LoadingDialog.show(register ? "Registering" : "Logging in");
    ErrorContainer<Token> worked =
        await manager.alarmServerLogin(server, username, password, register);

    AlarmListManager.getInstance().reloadAllMethod = () {
      setState(() {});
    };
    if (worked.error == null) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
      AlarmListManager.getInstance().reloadAllMethod!();
    } else {
      Navigator.of(context).pop();
      ErrorDialog.show("Login failed", worked.error!);
      return;
    }

    ErrorContainer<Token> populatedToken =
        await AlarmServerClient().populateTokenForAccount(worked.value);
    if (populatedToken.error != null || populatedToken.value == null) {
      ErrorDialog.show("Login failed", populatedToken.error!);
      return;
    }
    if (populatedToken.value?.userId != "") {
      // We already have a token, just save it
      AlarmListManager.getInstance()
          .saveAlarmServerToken(populatedToken.value!);
      AlarmListManager.getInstance().reloadAllMethod!();
      AlarmListManager.getInstance().pageSelectorReloadMethod!();
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text("Success"),
                content: Text(
                    "You are now logged in to the AlarmServer (ShockAlarmWeb). An OpenShock token has already been found on your AlarmServer account. It has therefor been choosen.\n\nIf you wish to choose another token, visit the AlarmServer website, delete all tokens and add only the one you want."),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text("Ok"))
                ],
              ));
      return;
    }
    Token? OpenShockToken = AlarmListManager.getInstance().getAnyUserToken();
    if (OpenShockToken == null) {
      ErrorDialog.show("Login failed",
          "No OpenShock token found. Please log in to OpenShock first.");
      AlarmListManager.getInstance()
          .deleteAlarmServerToken(populatedToken.value!);
      return;
    }
    if (OpenShockToken.isSession) {
      // Ask whether to create a new token
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text("No token found"),
                content: Text(
                    "You are logged in to OpenShock, but no token was found on your AlarmServer account. Do you want to create a new OpenShock api token for your AlarmServer account? By default the api token will be valid forever. If you do not want to create a token, you can add one manually on the AlarmServer website and then log in here."),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        AlarmListManager.getInstance()
                            .deleteAlarmServerToken(populatedToken.value!);
                      },
                      child: Text("No")),
                  TextButton(
                      onPressed: () async {
                        LoadingDialog.show("Adding token to account");
                        ErrorContainer<String> apiToken =
                            await OpenShockClient().createApiToken(
                                OpenShockToken,
                                OpenShockApiToken(
                                    "ShockAlarm-AlarmServer-${Uri.parse(server).host}",
                                    ["shockers.use"],
                                    null));

                        if (apiToken.error != null) {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                          ErrorDialog.show(
                              "Failed to create api token, you have been logged out of the AlarmServer",
                              apiToken.error!);
                          AlarmListManager.getInstance()
                              .deleteAlarmServerToken(populatedToken.value!);
                          return;
                        }
                        ErrorContainer<Token> t = await AlarmServerClient()
                            .addOpenShockTokenToAccount(
                                worked.value,
                                Token(DateTime.now().microsecondsSinceEpoch,
                                    apiToken.value!,
                                    server: OpenShockToken.server));
                        Navigator.of(context).pop();
                        if (t.error != null) {
                          Navigator.of(context).pop();
                          ErrorDialog.show(
                              "Failed to add token, you have been logged out of the AlarmServer",
                              t.error!);
                          AlarmListManager.getInstance()
                              .deleteAlarmServerToken(populatedToken.value!);
                          return;
                        }
                        AlarmListManager.getInstance()
                            .saveAlarmServerToken(t.value!);
                        Navigator.of(context).pop();
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: Text("Success"),
                                  content: Text(
                                      "Token added to account. You can now create alarms."),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          AlarmListManager.getInstance()
                                              .reloadAllMethod!();
                                          AlarmListManager.getInstance().pageSelectorReloadMethod!();
                                        },
                                        child: Text("Ok"))
                                  ],
                                ));
                      },
                      child: Text("Yes")),
                ],
              ));
    } else {
      // Ask whether to use the token
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text("Use OpenShock token?"),
                content: Text(
                    "You are logged in to OpenShock. Do you want to use the token found on your OpenShock account to log in to the AlarmServer (ShockAlarmWeb)?\n\nIf you choose no, your account will be removed from ShockAlarm. Add a token on the AlarmServer website manually and then log in again.\n\nIf you choose yes, your token will be transmitted to the AlarmServer and will be stored on your account there. It will then be able to trigger the alarms."),
                actions: [
                  TextButton(
                      onPressed: () async {
                        LoadingDialog.show("Adding token to account");
                        ErrorContainer<Token> t = await AlarmServerClient()
                            .addOpenShockTokenToAccount(
                                worked.value, OpenShockToken);
                        Navigator.of(context).pop();
                        if (t.error != null) {
                          ErrorDialog.show("Failed to add token", t.error!);
                          AlarmListManager.getInstance()
                              .deleteAlarmServerToken(populatedToken.value!);
                          return;
                        }
                        AlarmListManager.getInstance()
                            .saveAlarmServerToken(t.value!);
                        Navigator.of(context).pop();
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: Text("Success"),
                                  content: Text(
                                      "Token added to account. You can now create alarms."),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          AlarmListManager.getInstance()
                                              .reloadAllMethod!();
                                          
                                          AlarmListManager.getInstance().pageSelectorReloadMethod!();
                                        },
                                        child: Text("Ok"))
                                  ],
                                ));
                      },
                      child: Text("Yes")),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        AlarmListManager.getInstance()
                            .deleteAlarmServerToken(populatedToken.value!);
                      },
                      child: Text("No"))
                ],
              ));
    }
  }

  @override
  void initState() {
    manager.reloadAllMethod = rebuild;
    super.initState();
  }

  Future showAlarmServerTokenLoginPopup() async {
    TextEditingController serverController = TextEditingController();
    TextEditingController usernameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    serverController.text = "https://dev1.rui2015.me";
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Login to ShockAlarmWeb"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  TextField(
                    decoration: InputDecoration(labelText: "Server"),
                    controller: serverController,
                  ),
                  AutofillGroup(
                      child: Column(
                    children: [
                      TextField(
                          decoration: InputDecoration(labelText: "Username"),
                          autofillHints: [AutofillHints.username],
                          controller: usernameController),
                      TextField(
                          decoration: InputDecoration(labelText: "Password"),
                          autofillHints: [AutofillHints.password],
                          obscureText: true,
                          obscuringCharacter: "*",
                          controller: passwordController)
                    ],
                  ))
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                child: Text("Register"),
                onPressed: () {
                  doAlarmServerLogin(serverController.text,
                      usernameController.text, passwordController.text, true);
                },
              ),
              TextButton(
                  onPressed: () async {
                    doAlarmServerLogin(
                        serverController.text,
                        usernameController.text,
                        passwordController.text,
                        false);
                  },
                  child: Text("Login"))
            ],
          );
        });
  }

  Future showTokenLoginPopupRedirect() async {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Login to OpenShock"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  FilledButton(
                    child: Text("Log in via openshock.app"),
                    onPressed: () => {
                      launchUrl(Uri.parse(
                          "https://openshock.app/t/?name=ShockAlarm&redirect_uri=${Uri.encodeComponent(Uri.base.toString())}${Uri.encodeComponent("?server=https://api.openshock.app&token=%")}&permissions=${availableApiTokenPermissions.join(",")}"))
                    },
                  ),
                  Padding(padding: EdgeInsets.all(10)),
                  Text(
                      "Not working or want to choose another server? Try manual login below.",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    showTokenLoginPopup();
                  },
                  child: Text("Manual login"))
            ],
          );
        });
  }

  Future showTokenLoginPopup() async {
    TextEditingController serverController = TextEditingController();
    TextEditingController tokenController = TextEditingController();
    serverController.text = "https://api.openshock.app";
    GestureRecognizer recognizer = TapGestureRecognizer()
      ..onTap = () {
        launchUrl(Uri.parse("https://next.openshock.app/settings/api-tokens"));
      };
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Login to OpenShock"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!,
                      child: SelectableText.rich(TextSpan(children: [
                        TextSpan(
                            text:
                                "As you are using a browser, you must use a token to sign in. To get one visit "),
                        TextSpan(
                            text:
                                "https://next.openshock.app/settings/api-tokens",
                            recognizer: recognizer,
                            style: TextStyle(
                                color: Theme.of(context).hintColor,
                                decoration: TextDecoration.underline),
                            mouseCursor: SystemMouseCursors.click),
                        TextSpan(
                            text:
                                " and generate a token with all permissions. Then paste it here.")
                      ]))),
                  TextField(
                    decoration: InputDecoration(labelText: "Server"),
                    controller: serverController,
                  ),
                  AutofillGroup(
                      child: Column(
                    children: [
                      TextField(
                          decoration: InputDecoration(labelText: "Token"),
                          obscureText: true,
                          obscuringCharacter: "*",
                          controller: tokenController)
                    ],
                  )),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                child: Text("Register"),
                onPressed: () {
                  launchUrl(
                      Uri.parse("https://openshock.app/#/account/signup"));
                },
              ),
              TextButton(
                  onPressed: () async {
                    LoadingDialog.show("Logging in");
                    bool worked = await manager.loginToken(
                        serverController.text, tokenController.text);
                    if (worked) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      AlarmListManager.getInstance().reloadAllMethod!();
                    } else {
                      Navigator.of(context).pop();
                      ErrorDialog.show(
                          "Login failed", "Check server, email and password");
                    }
                  },
                  child: Text("Login"))
            ],
          );
        });
  }

  Future showLoginPopup() async {
    TextEditingController serverController = TextEditingController();
    TextEditingController usernameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    serverController.text = "https://api.openshock.app";
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Login to OpenShock"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  TextField(
                    decoration: InputDecoration(labelText: "Server"),
                    controller: serverController,
                  ),
                  AutofillGroup(
                      child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(labelText: "Email"),
                        controller: usernameController,
                        autofillHints: [AutofillHints.email],
                      ),
                      TextField(
                        decoration: InputDecoration(labelText: "Password"),
                        obscureText: true,
                        obscuringCharacter: "*",
                        controller: passwordController,
                        autofillHints: [AutofillHints.password],
                      )
                    ],
                  ))
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                child: Text("Register"),
                onPressed: () {
                  launchUrl(
                      Uri.parse("https://openshock.app/#/account/signup"));
                },
              ),
              TextButton(
                  onPressed: () async {
                    LoadingDialog.show("Logging in");
                    bool worked = await manager.login(serverController.text,
                        usernameController.text, passwordController.text);
                    if (worked) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      AlarmListManager.getInstance().reloadAllMethod!();
                    } else {
                      Navigator.of(context).pop();
                      ErrorDialog.show(
                          "Login failed", "Check server, email and password");
                    }
                  },
                  child: Text("Login"))
            ],
          );
        });
  }

  TokenScreenState(this.manager);
  @override
  Widget build(BuildContext context) {
    AlarmListManager.getInstance().reloadAllMethod = () {
      navigatorKey.currentState?.setState(() {
        // ignore: invalid_use_of_protected_member
      });
    };
    ThemeData t = Theme.of(context);
    return ConstrainedContainer(
        child: ListView(
      children: <Widget>[
        Column(
          spacing: 10,
          children: [
            Text(
              'Settings',
              style: t.textTheme.headlineMedium,
            ),
            for (var token in manager.getTokens())
              TokenItem(
                  token: token,
                  manager: manager,
                  onRebuild: rebuild,
                  key: ValueKey(token.id)),
            if (manager.getTokens().isEmpty)
              Card(
                color: t.colorScheme.onInverseSurface,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                      "You are not logged in to OpenShock, log in to access your devices",
                      style: t.textTheme.headlineSmall),
                ),
              ),
          ],
        ),

        if (AlarmListManager.getInstance().settings.useAlarmServer) ...[
          Column(
            spacing: 10,
            children: [
              for (var token in manager.getAlarmServerTokens())
                TokenItem(
                    token: token,
                    manager: manager,
                    onRebuild: rebuild,
                    key: ValueKey(token.id)),
              if (manager.getAlarmServerTokens().isEmpty)
                Card(
                  color: t.colorScheme.onInverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                        "You are not logged into an AlarmServer. Log in to one to schedule alarms on Web an Linux",
                        textAlign: TextAlign.center,
                        style: t.textTheme.headlineSmall),
                  ),
                ),
            ],
          ),
        ],
        Padding(padding: EdgeInsets.all(10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          spacing: 10,
          children: [
            if (manager.getTokens().isEmpty)
              FilledButton(
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (context) => ShockDisclaimer());
                  AlarmListManager.getInstance().reloadAllMethod = () {
                    setState(() {});
                  };
                  if (kIsWeb) {
                    showTokenLoginPopupRedirect();
                  } else {
                    showLoginPopup();
                  }
                },
                child: Text("Log in to OpenShock",
                    style:
                        TextStyle(fontSize: t.textTheme.titleMedium!.fontSize)),
              ),
            if (manager.getAlarmServerTokens().isEmpty &&
                manager.settings.useAlarmServer)
              FilledButton(
                onPressed: () async {
                  showAlarmServerTokenLoginPopup();
                },
                child: Text("Log in to AlarmServer",
                    style:
                        TextStyle(fontSize: t.textTheme.titleMedium!.fontSize)),
              ),
          ],
        ),

        Padding(padding: EdgeInsets.all(10)),
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
                switch (
                    context.findAncestorStateOfType<MyAppState>()?.themeMode) {
                  null => throw UnimplementedError(), // should never be null ig
                  ThemeMode.system => 0,
                  ThemeMode.light => 1,
                  ThemeMode.dark => 2,
                }
              },
              onSelectionChanged: (Set<int> newSelection) {
                if (newSelection.isNotEmpty) {
                  switch (newSelection.first) {
                    case 0:
                      context
                          .findAncestorStateOfType<MyAppState>()
                          ?.setThemeMode(ThemeMode.system);
                      break;
                    case 1:
                      context
                          .findAncestorStateOfType<MyAppState>()
                          ?.setThemeMode(ThemeMode.light);
                      break;
                    case 2:
                      context
                          .findAncestorStateOfType<MyAppState>()
                          ?.setThemeMode(ThemeMode.dark);
                      break;
                  }
                  setState(() {});
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
            Switch(
                value: manager.settings.showRandomDelay,
                key: ValueKey("showRandomDelay"),
                onChanged: (value) {
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
            Text("Use grouped shocker controlling"),
            Switch(
                value: manager.settings.useGroupedShockerSelection,
                key: ValueKey("useGroupedShockerSelection"),
                onChanged: (value) {
                  setState(() {
                    manager.settings.useGroupedShockerSelection = value;
                    manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Use range slider for random delay"),
            Switch(
                value: manager.settings.useRangeSliderForRandomDelay,
                key: ValueKey("useRangeSliderForRandomDelay"),
                onChanged: (value) {
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
            Switch(
                value: manager.settings.useRangeSliderForIntensity,
                key: ValueKey("useRangeSliderForIntensity"),
                onChanged: (value) {
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
            Switch(
                value: manager.settings.useRangeSliderForDuration,
                key: ValueKey("useRangeSliderForDuration"),
                onChanged: (value) {
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
            Switch(
                value: manager.settings.disableHubFiltering,
                key: ValueKey("disableHubFiltering"),
                onChanged: (value) {
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
            Text("Show hub firmware version"),
            Switch(
                value: manager.settings.showFirmwareVersion,
                key: ValueKey("showFirmwareVersion"),
                onChanged: (value) {
                  setState(() {
                    manager.settings.showFirmwareVersion = value;
                    manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Use http instead of ws for shocking"),
            Switch(
                value: manager.settings.useHttpShocking,
                key: ValueKey("useHttpShocking"),
                onChanged: (value) {
                  setState(() {
                    manager.settings.useHttpShocking = value;
                    manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Allow choosing tones for controls"),
            Switch(
                value: manager.settings.allowTonesForControls,
                key: ValueKey("allowTonesForControls"),
                onChanged: (value) {
                  setState(() {
                    manager.settings.allowTonesForControls = value;
                    manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
            Text("Use AlarmServer for alarms"),
            IconButton(onPressed: () {
              InfoDialog.show("What is a Alarm Server?",
              "An Alarm Server is an Open Source server which allows for scheduling of alarms. These alarms can be edited via this app but are then stored on the server. Your alarms will be tied to a user account of your choice which you will have to create.\n\nIn order for the Alarm Server to be able to send alarms (control your shockers) it also needs access to your OpenShock account. This is done via Api Tokens. You can therefore revoke access to your OpenShock account by simply deleting the Api token at any time.\n\n\nThis feature was added so ShockAlarm users can also create alarms which will be triggered even when their device is off. On Android this feature is not needed as alarms work on device as long as you use the app.");
            }, icon: Icon(Icons.info))],),
            Switch(
                value: manager.settings.useAlarmServer,
                key: ValueKey("useAlarmServer"),
                onChanged: (value) {
                  setState(() {
                    manager.settings.useAlarmServer = value;
                    manager.saveSettings();
                    manager.pageSelectorReloadMethod!();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => ToolsScreen()));
              },
              child: Text("More tools")),
            if(manager.settings.allowTonesForControls) FilledButton(onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AlarmToneScreen(manager)));
              }, child: Text("Edit Tones"))
          ]
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                              title: Text("About"),
                              content: Text(
                                  "This app is made by ComputerElite. It is fully open source and can be found on GitHub. If you have any issues, report them there. Thank you so much for using my app! See safety rules in the safety section for more information."),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      launchUrl(Uri.parse(issues_url));
                                    },
                                    child: Text("Report issue")),
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Ok"))
                              ]));
                },
                child: Text("About")),
            TextButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) => ShockDisclaimer());
                },
                child: Text("Safety")),
          ],
        )
      ],
    ));
  }
}
