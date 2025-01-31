import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/grouped_shockers.dart';
import 'package:shock_alarm_app/screens/shockers.dart';
import 'package:shock_alarm_app/screens/tones.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:uni_links5/uni_links.dart';
import '../components/alarm_item.dart';
import '../services/alarm_list_manager.dart';
import 'share_links.dart';
import 'tokens.dart';
import '../stores/alarm_store.dart';

class ScreenSelector extends StatefulWidget {
  final AlarmListManager manager;

  const ScreenSelector({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ScreenSelectorState(manager: manager);
}

class ScreenSelectorState extends State<ScreenSelector> {
  final AlarmListManager manager;
  int _selectedIndex = 3;
  bool supportsAlarms = isAndroid();
  PageController pageController = PageController();
  List<Widget> screens = [];
  List<BottomNavigationBarItem> navigationBarItems = [];
  List<Widget?> floatingActionButtons = [];

  @override
  void initState() {
    try {
      if (isAndroid()) {
        getInitialLink().then((String? url) {
          if (url != null) {
            onProtocolUrlReceived(url);
          }
        });
      }
    } catch (e) {
      print("Error getting initial link (perhaps wrong platform): $e");
    }
    screens = [
      if (supportsAlarms) HomeScreen(manager: manager),
      ShockerScreen(manager: manager),
      GroupedShockerScreen(manager: manager),
      ShareLinksScreen(),
      TokenScreen(manager: manager),
    ];
    navigationBarItems = [
      if (supportsAlarms)
        BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarms'),
      BottomNavigationBarItem(
          icon: OpenShockClient.getIconForControlType(ControlType.shock),
          label: 'Devices'),
      BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Grouped'),
      BottomNavigationBarItem(icon: Icon(Icons.link), label: 'Share Links'),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
    ];
    floatingActionButtons = <Widget?>[
      if (supportsAlarms)
        FloatingActionButton(
            onPressed: () {
              TimeOfDay tod = TimeOfDay.fromDateTime(DateTime.now());
              print("alarms: ${manager.getAlarms().length}");
              final newAlarm = new Alarm(
                  id: manager.getNewAlarmId(),
                  name: 'New Alarm',
                  hour: tod.hour,
                  minute: tod.minute,
                  active: false);
              setState(() {
                manager.saveAlarm(newAlarm);
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Alarm added'),
                duration: Duration(seconds: 3),
              ));
            },
            child: Icon(Icons.add)),
      ShockerScreen.getFloatingActionButton(manager, context, () {
        setState(() {});
      }),
      ShockerScreen.getFloatingActionButton(manager, context, () {
        setState(() {});
      }),
      ShareLinksScreen.getFloatingActionButton(manager, context, () {
        setState(() {});
      }),
      null,
    ];

    manager.getPageIndex().then((index) {
      if (index != -1) {
        _tap(min(index, screens.length));
      } else {
        if (manager.getAnyUserToken() == null) _selectedIndex = 4;
        if (!supportsAlarms) _selectedIndex -= 1;
      }
      setState(() {});
    });
    super.initState();
  }

  @override
  void onProtocolUrlReceived(String url) {
    String log = 'Url received: $url';
    List<String> parts = url.split('/');
    if (parts.length < 4) return;
    String action = parts[2];
    String code = parts[3];
    if (action == "sharecode") {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
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
                      if (await ShockerScreen.redeemShareCode(
                          code, context, manager)) {
                        Navigator.of(context).pop();
                        manager.reloadAllMethod!();
                      }
                    },
                    child: Text("Redeem"))
              ],
            );
          });
    }
  }

  ScreenSelectorState({required this.manager});

  void _tap(int index) {
    index = max(0, min(index, screens.length - 1));
    setState(() {
      pageController.jumpToPage(index);
      _selectedIndex = index;
    });
    AlarmListManager.getInstance().savePageIndex(index);
  }

  final FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    manager.startAnyWS();
    manager.reloadAllMethod = () {
      setState(() {});
    };
    return Scaffold(
        body: KeyboardListener(
            autofocus: true,
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                switch (event.logicalKey) {
                  case LogicalKeyboardKey.arrowLeft:
                    _tap(_selectedIndex - 1);
                    break;
                  case LogicalKeyboardKey.arrowRight:
                    _tap(_selectedIndex + 1);
                    break;
                  case LogicalKeyboardKey.f5:
                    if (manager.onRefresh != null) manager.onRefresh!();
                    break;
                }
              }
            },
            focusNode: focusNode,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 15,
                left: 15,
                right: 15,
                top: 15,
              ),
              child: PageView(
                children: screens,
                onPageChanged: _tap,
                controller: pageController,
              ),
            )),
        appBar: null,
        floatingActionButton: floatingActionButtons.elementAt(_selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          items: navigationBarItems,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _tap,
        ));
  }
}

class HomeScreen extends StatefulWidget {
  final AlarmListManager manager;

  const HomeScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HomeScreenState(manager);
}

class PagePadding extends StatefulWidget {
  final Widget child;

  const PagePadding({Key? key, required this.child}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PagePaddingState();
}

class PagePaddingState extends State<PagePadding> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: EdgeInsets.all(10),
      child: widget.child,
    );
  }
}

class HomeScreenState extends State<HomeScreen> {
  final AlarmListManager manager;

  HomeScreenState(this.manager);

  void rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    manager.context = context;
    ThemeData t = Theme.of(context);
    return ListView(
      children: [
        Text(
          'Your alarms',
          style: t.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        Text(
          "Alarms are currently semi working",
          style: t.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        Center(
          child: TextButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AlarmToneScreen(manager)));
              },
              child: Text("Edit Tones")),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final alarm = manager.getAlarms()[index];

              return AlarmItem(
                  alarm: alarm,
                  manager: manager,
                  onRebuild: rebuild,
                  key: ValueKey(alarm.id));
            },
            itemCount: manager.getAlarms().length,
          ),
        )
      ],
    );
  }
}
