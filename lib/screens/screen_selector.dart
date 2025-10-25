import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/shockers/shock_screen_selector.dart';
import 'package:shock_alarm_app/screens/shockers/individual/shockers.dart';
import 'package:shock_alarm_app/screens/user_shares/user_share_screen.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../services/alarm_list_manager.dart';
import 'alarms/alarms.dart';
import 'share_links/share_links.dart';
import 'settings/settings_screen.dart';
import '../stores/alarm_store.dart';
import 'package:universal_html/html.dart' as html;

class ScreenSelectorScreen extends StatefulWidget {
  final AlarmListManager manager;

  ScreenSelectorScreen({Key? key, required this.manager}) : super(key: key);

  bool setPageSwipeEnabled = true;

  @override
  State<StatefulWidget> createState() =>
      ScreenSelectorScreenState(manager: manager);
}

class ScreenSelectorScreenState extends State<ScreenSelectorScreen> {
  final AlarmListManager manager;
  int _selectedIndex = 2;
  bool supportsAlarms = isAndroid();
  PageController pageController = PageController();
  List<Widget> screens = [];
  List<BottomNavigationBarItem> navigationBarItems = [];
  List<Widget?> floatingActionButtons = [];

  void removeTokenFromUrl() {
    var newUri = Uri.base;
    newUri = newUri.replace(queryParameters: {});

    html.window.history.replaceState(null, '', newUri.toString());
  }

  void redoLayout(bool initialReload) {
    if (manager.settings.useAlarmServer &&
        manager.getAlarmServerUserToken() != null) {
      supportsAlarms = true;
    } else {
      supportsAlarms = isAndroid();
    }

    screens = [
      if (supportsAlarms) AlarmsScreen(manager: manager),
      UserShareScreen(),
      ShockScreenSelector(manager: manager),
      SettingsScreen(manager: manager),
    ];
    navigationBarItems = [
      if (supportsAlarms)
        BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarms'),
      BottomNavigationBarItem(icon: Icon(Icons.link), label: 'Shares'),
      BottomNavigationBarItem(
          icon: OpenShockClient.getIconForControlType(ControlType.shock),
          label: 'Devices'),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
    ];
    floatingActionButtons = <Widget?>[
      if (supportsAlarms)
        FloatingActionButton(
            onPressed: () async {
              TimeOfDay tod = TimeOfDay.fromDateTime(DateTime.now());
              final newAlarm = new Alarm(
                  id: manager.getNewAlarmId(),
                  name: 'New Alarm',
                  hour: tod.hour,
                  minute: tod.minute,
                  active: false);
              await manager.saveAlarm(newAlarm);
              manager.reloadAllMethod!();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Alarm added'),
                duration: Duration(seconds: 3),
              ));
            },
            child: Icon(Icons.add)),
      UserShareScreen.getFloatingActionButton(context, () {
        setState(() {});
      }),
      ShockerScreen.getFloatingActionButton(manager, context, () {
        setState(() {});
      }),
      null,
    ];
    if (!initialReload) {
      _selectedIndex = min(_selectedIndex, screens.length);
      setState(() {});
      if (mounted) _tap(_selectedIndex, true);
    }
  }

  static bool addedKeyboardListener = false;

  @override
  void initState() {
    if (isAndroid()) {
      const platform = MethodChannel('shock-alarm/protocol');
      try {
        platform.setMethodCallHandler((MethodCall call) async {
          if (call.method == 'onProtocolUrlReceived') {
            onProtocolUrlReceived(call.arguments);
          }
        });
      } catch (e) {
        print("Could not init method channel : ${e.toString()}");
      }
    }
    if (kIsWeb) {
      String? token;
      String? server;
      for (MapEntry<String, String> s in Uri.base.queryParameters.entries) {
        if (s.key == "server") {
          server = s.value;
        }
        if (s.key == "token") {
          token = s.value;
          removeTokenFromUrl();
        }
      }
      if (token != null && server != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          manager.loginToken(server!, token!).then(
            (value) async {
              showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog.adaptive(
                      title: Text("Token login"),
                      content: Text(
                          "You have been logged in with a token as user ${manager.getTokenByToken(token)?.name}"),
                      actions: [
                        TextButton(
                            onPressed: () {
                              html.window.location.href =
                                  Uri.base.toString().split('?')[0];
                            },
                            child: Text("Reload page"))
                      ],
                    );
                  });
            },
          );
        });
      }
    }

    if (!addedKeyboardListener) {
      addedKeyboardListener = true;
      print("registering keyboard listener");
      ServicesBinding.instance.keyboard.addHandler(_onKey);
    }

    redoLayout(true);
    manager.pageSelectorReloadMethod = () {
      redoLayout(false);
    };

    manager.getPageIndex().then((index) {
      if (index != -1) {
        _selectedIndex = min(index, screens.length);
      } else {
        if (!manager.hasAccountWithShockers()) _selectedIndex = 3;
        if (!supportsAlarms) _selectedIndex -= 1;
      }
      setState(() {});
      _tap(_selectedIndex, true);
    });
    manager.updateShockerStore();
    super.initState();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.f5:
          if (manager.onRefresh != null) manager.onRefresh!();
          break;
      }
    }
    return false;
  }

  @override
  void onProtocolUrlReceived(String url) {
    String log = 'Url received: $url';
    List<String> parts = url.split('/');
    if (parts.length < 4) return;
    String action = parts[2];
    String code = parts[3];
    if(action == "sharelink") {
      // openshock://sharelink/<code>?name=<name>&server=<server>
      print("Sharelink url received");
      print("Url: $url");

      Uri uri = Uri.parse(url);
      String? name = uri.queryParameters['name'];
      name ??= "Unknown";
      String? host = uri.queryParameters['server'];
      host ??= "https://api.openshock.app";
      String shareId = uri.pathSegments[0];
      TextEditingController nameController = TextEditingController();
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog.adaptive(
              title: Text("Add share link?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                  "This will allow you to control someone elses shocker without requiring to be logged into OpenShock.\n\nName: $name\nOpenShock instance: $host\nShare Id: $shareId"),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Your name",
                    ),
                    controller: nameController,
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Close")),
                TextButton(
                    onPressed: () async {
                      if(await SettingsScreen.AddShareLink(nameController.text, host!, shareId)) {
                        Navigator.of(context).pop();
                        manager.reloadAllMethod!();
                      }
                    },
                    child: Text("Redeem"))
              ],
            );
          });
    } 
    else if (action == "sharecode") {
       // openshock://sharecode/<code>
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog.adaptive(
              title: Text("Redeem share code?"),
              content: Text(
                  "This will allow you to control someone elses shocker. The code is $code"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Close")),
                TextButton(
                    onPressed: () async {
                      if (await ShockerScreen.redeemShareCodeOrInvite(
                          code, context, manager)) {
                        Navigator.of(context).pop();
                        manager.reloadAllMethod!();
                      }
                    },
                    child: Text("Redeem"))
              ],
            );
          });
    } else if (action == "invite") {
       // openshock://invite/<code>
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog.adaptive(
              title: Text("Claim invite?"),
              content: Text(
                  "This will allow you to control someone elses shocker. The invite code is $code"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Close")),
                TextButton(
                    onPressed: () async {
                      if (await ShockerScreen.redeemShareCodeOrInvite(
                          code, context, manager)) {
                        Navigator.of(context).pop();
                        InfoDialog.show("Claimed invite", "You can now control more shockers!");
                        manager.reloadAllMethod!();
                      }
                    },
                    child: Text("Claim"))
              ],
            );
          });
    }
  }

  ScreenSelectorScreenState({required this.manager});

  void _tap(int index, bool switchPage) {
    index = max(0, min(index, screens.length - 1));
    setState(() {
      if (switchPage) pageController.jumpToPage(index);
      _selectedIndex = index;
    });
    AlarmListManager.getInstance().savePageIndex(index);
  }

  final FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    manager.startAllWS();
    return Scaffold(
        body: PageView(
          onPageChanged: (index) => _tap(index, false),
          controller: pageController,
          physics: widget.setPageSwipeEnabled
              ? null
              : NeverScrollableScrollPhysics(),
          children: screens.map((e) => PagePadding(child: e)).toList(),
        ),
        appBar: null,
        floatingActionButton: floatingActionButtons.elementAt(_selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          items: navigationBarItems,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) => _tap(index, true),
        ));
  }

  void setPageSwipeEnabled(bool value) {
    setState(() {
      widget.setPageSwipeEnabled = value;
    });
  }
}
