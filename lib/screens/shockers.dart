import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/screens/shares.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:sticky_headers/sticky_headers.dart';
import '../components/hub_item.dart';
import '../components/shocker_item.dart';

class ShockerScreen extends StatefulWidget {
  final AlarmListManager manager;

  const ShockerScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerScreenState(manager);

  static startRedeemShareCode(
      AlarmListManager manager, BuildContext context, Function reloadState) {
    showDialog(
        context: context,
        builder: (context) {
          TextEditingController codeController = TextEditingController();
          return AlertDialog(
            title: Text("Redeem share code"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(labelText: "Share code"),
                  )
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
                    String code = codeController.text;
                    if (code.isEmpty) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("Invalid code"),
                              content: Text("The code cannot be empty"),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Ok"))
                              ],
                            );
                          });
                      return;
                    }
                    if (await redeemShareCode(code, context, manager)) {
                      Navigator.of(context).pop();
                      reloadState();
                    }
                  },
                  child: Text("Redeem"))
            ],
          );
        });
  }

  static Future<bool> redeemShareCode(
      String code, BuildContext context, AlarmListManager manager) async {
    showDialog(
        context: context,
        builder: (context) {
          return LoadingDialog(title: "Redeeming code");
        });
    String? error = await manager.redeemShareCode(code);
    if (error != null) {
      Navigator.of(context).pop();
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Error"),
              content: Text(error),
              actions: <Widget>[
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Ok"))
              ],
            );
          });
      return false;
    }
    await manager.updateShockerStore();
    Navigator.of(context).pop();
    return true;
  }

  static startAddHub(AlarmListManager manager, BuildContext context,
      Function reloadState) async {
    Navigator.of(context).pop();
    showDialog(
        context: context,
        builder: (context) {
          TextEditingController nameController = TextEditingController();
          return AlertDialog(
            title: Text("Add new hub"),
            content: (TextField(
              decoration: InputDecoration(labelText: "Hub name"),
              controller: nameController,
            )),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () async {
                    String name = nameController.text;
                    if (name.isEmpty) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("Invalid name"),
                              content: Text("The name cannot be empty"),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Ok"))
                              ],
                            );
                          });
                      return;
                    }
                    showDialog(
                        context: context,
                        builder: (context) {
                          return LoadingDialog(title: "Creating hub");
                        });
                    CreatedHub? hub = await manager.addHub(name);
                    if (hub.error != null || hub.hubId == null) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("Error"),
                              content: Text(hub.error ?? "Unknown error"),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Ok"))
                              ],
                            );
                          });
                      return;
                    }
                    await manager.updateShockerStore();
                    reloadState();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    // ToDo add pair code thingy
                    await HubItem.pairHub(context, manager, hub.hubId!);
                  },
                  child: Text("Add"))
            ],
          );
        });
  }

  static startPairShocker(AlarmListManager manager, BuildContext context,
      Function reloadState) async {
    showDialog(
        context: context,
        builder: (context) {
          return LoadingDialog(title: "Loading devices");
        });
    List<OpenShockDevice> devices = await manager.getDevices();
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    showDialog(
        context: context,
        builder: (context) {
          TextEditingController nameController = TextEditingController();
          // number only
          TextEditingController rfIdController =
              TextEditingController(text: Random().nextInt(65535).toString());
          String shockerType = "CaiXianlin";
          OpenShockDevice? device;
          return AlertDialog(
            title: Text("Add new shocker"),
            content: SingleChildScrollView(
              child: Column(
                spacing: 10,
                children: <Widget>[
                  DropdownMenu<OpenShockDevice>(
                      label: Text("Device"),
                      onSelected: (value) {
                        device = value;
                      },
                      dropdownMenuEntries: [
                        for (OpenShockDevice device in devices)
                          DropdownMenuEntry(label: device.name, value: device),
                      ]),
                  DropdownMenu<String>(
                    dropdownMenuEntries: [
                      DropdownMenuEntry(
                          label: "CaiXianlin", value: "CaiXianlin"),
                      DropdownMenuEntry(
                          label: "PetTrainer", value: "PetTrainer"),
                      DropdownMenuEntry(
                          label: "Petrainer998DR", value: "Petrainer 998DR"),
                    ],
                    onSelected: (value) {
                      shockerType = value ?? "CaiXianlin";
                    },
                    label: Text("Shocker type"),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: "Shocker Name"),
                  ),
                  TextField(
                    controller: rfIdController,
                    decoration: InputDecoration(labelText: "RF ID"),
                    keyboardType: TextInputType.number,
                  )
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
                    String name = nameController.text;
                    if (name.isEmpty) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("Invalid name"),
                              content: Text("The name cannot be empty"),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Ok"))
                              ],
                            );
                          });
                      return;
                    }
                    int rfId = int.tryParse(rfIdController.text) ?? 0;
                    if (rfId < 0 || rfId > 65535) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("Invalid RF ID"),
                              content: Text(
                                  "The RF ID must be a number between 0 and 65535"),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Ok"))
                              ],
                            );
                          });
                      return;
                    }
                    showDialog(
                        context: context,
                        builder: (context) {
                          return LoadingDialog(title: "Adding shocker");
                        });

                    String? error = await manager.addShocker(
                        name, rfId, shockerType, device);
                    Navigator.of(context).pop();
                    if (error != null) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("Error"),
                              content: Text(error),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Ok"))
                              ],
                            );
                          });
                      return;
                    }
                    manager.updateShockerStore();
                    Navigator.of(context).pop();
                    showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text("Almost done"),
                            content: Text(
                                "Your shocker was created successfully. To pair it with your hub hold down the on/off button until it beeps a few times. Then press the vibrate button in the app to pair it."),
                            actions: <Widget>[
                              TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text("Ok"))
                            ],
                          );
                        });
                  },
                  child: Text("Pair"))
            ],
          );
        });
  }

  static getFloatingActionButton(
      AlarmListManager manager, BuildContext context, Function reloadState) {
    return FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              if (!manager.hasValidAccount()) {
                return AlertDialog(
                  title: Text("You're not logged in"),
                  content: Text(
                      "Login to OpenShock to add a shocker. To do this visit the settings page."),
                  actions: <Widget>[
                    TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text("Ok"))
                  ],
                );
              }
              return AlertDialog(
                title: Text("Add device"),
                content: Text("What do you want to do?"),
                actions: <Widget>[
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        startRedeemShareCode(manager, context, reloadState);
                      },
                      child: Text("Redeem share code")),
                  TextButton(
                      onPressed: () async {
                        await startPairShocker(manager, context, reloadState);
                      },
                      child: Text("Add new shocker")),
                  TextButton(
                      onPressed: () async {
                        startAddHub(manager, context, reloadState);
                      },
                      child: Text("Add new hub")),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text("Cancel")),
                ],
              );
            },
          );
        },
        child: Icon(Icons.add));
  }
}

class ShockerScreenState extends State<ShockerScreen> {
  final AlarmListManager manager;

  void rebuild() {
    setState(() {});
  }

  ShockerScreenState(this.manager);
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Shocker> filteredShockers = manager.shockers.where((shocker) {
      return (manager.enabledHubs[shocker.hubReference?.id] ?? false) ||
          (manager.settings.disableHubFiltering);
    }).toList();
    // group by hub
    Map<Hub?, List<Shocker>> groupedShockers = {};
    for (Shocker shocker in filteredShockers) {
      if (!groupedShockers.containsKey(shocker.hubReference)) {
        groupedShockers[shocker.hubReference] = [];
      }
      groupedShockers[shocker.hubReference]!.add(shocker);
    }
    // now add all missing hubs
    for (Hub hub in manager.hubs) {
      if (!manager.settings.disableHubFiltering &&
          manager.enabledHubs[hub.id] == false) {
        continue;
      }
      if (!groupedShockers.containsKey(hub)) {
        groupedShockers[hub] = [];
      }
    }
    List<Widget> shockers = [];
    for (var shocker in groupedShockers.entries) {
      List<Widget> shockerWidgets = [];
      for (var s in shocker.value) {
        shockerWidgets.add(ShockerItem(
            shocker: s,
            manager: manager,
            onRebuild: rebuild,
            key: ValueKey(s.getIdentifier())));
      }
      shockers.add(StickyHeader(
          header: HubItem(
              hub: shocker.key!,
              manager: manager,
              key: ValueKey(shocker.key!.getIdentifier(manager)),
              onRebuild: rebuild),
          content: Column(
            children: shockerWidgets,
          )));
    }
    return DesktopMobileRefreshIndicator(
      onRefresh: () async {
        await manager.updateShockerStore();
        setState(() {});
      },
      child: ListView(children: [
        Text(
          'All devices',
          style: t.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        if (groupedShockers.isEmpty)
          Text(
            "No shockers found",
            style: t.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        if (!manager.settings.disableHubFiltering)
          Center(
              child: Wrap(
            spacing: 5,
            runAlignment: WrapAlignment.start,
            children: manager.enabledHubs.keys.map<FilterChip>((hub) {
              return FilterChip(
                  label: Text(manager.getHub(hub)?.name ?? "Unknown hub"),
                  onSelected: (bool value) {
                    manager.enabledHubs[hub] = value;
                    setState(() {});
                  },
                  selected: manager.enabledHubs[hub]!);
            }).toList(),
          )),
          ...(groupedShockers.isNotEmpty ? shockers : [])
      ]),
    );
  }
}
