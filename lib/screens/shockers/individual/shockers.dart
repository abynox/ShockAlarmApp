import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/desktop_mobile_refresh_indicator.dart';
import 'package:shock_alarm_app/components/dynamic_child_layout.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_details.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/screens/shares/shares.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:sticky_headers/sticky_headers.dart';
import '../hub_item.dart';
import '../shocker_item.dart';

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
          return AlertDialog.adaptive(
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
                      ErrorDialog.show(
                          "Invalid code", "The code cannot be empty");
                      return;
                    }
                    if (await redeemShareCode(code, context, manager)) {
                      Navigator.of(context).pop();

                      await AlarmListManager.getInstance().updateShockerStore();
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
    LoadingDialog.show("Redeeming code");
    String? error = await manager.redeemShareCode(code);
    if (error != null) {
      Navigator.of(context).pop();
      ErrorDialog.show("Error", error);
      return false;
    }
    await AlarmListManager.getInstance().updateShockerStore();
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
          return AlertDialog.adaptive(
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
                      ErrorDialog.show(
                          "Invalid name", "The name cannot be empty");
                      return;
                    }
                    LoadingDialog.show("Creating hub");
                    CreatedHub? hub = await manager.addHub(name);
                    if (hub.error != null || hub.hubId == null) {
                      Navigator.of(context).pop();
                      ErrorDialog.show("Error", hub.error ?? "Unknown error");
                      return;
                    }
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    await manager.updateShockerStore();
                    reloadState();
                    // ToDo add pair code thingy
                    await HubItem.pairHub(context, manager, hub.hubId!);
                    await manager.updateShockerStore();
                    reloadState();
                  },
                  child: Text("Add"))
            ],
          );
        });
  }

  static startPairShocker(AlarmListManager manager, BuildContext context,
      Function reloadState) async {
    LoadingDialog.show("Loading devices");
    List<OpenShockDevice> devices = await manager.getDevices();
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    OpenShockShocker newShocker = OpenShockShocker();
    newShocker.rfId = Random().nextInt(65535);
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog.adaptive(
            title: Text("Add new shocker"),
            content: ShockerDetails(
              shocker: newShocker,
              devices: devices,
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () async {
                    String name = newShocker.name;
                    if (name.isEmpty) {
                      ErrorDialog.show(
                          "Invalid name", "The name cannot be empty");
                      return;
                    }
                    int rfId = newShocker.rfId ?? 0;
                    LoadingDialog.show("Adding shocker");
                    OpenShockDevice? device;
                    for (OpenShockDevice d in devices) {
                      if (d.id == newShocker.device) {
                        device = d;
                        break;
                      }
                    }
                    String? error = await manager.addShocker(
                        name, rfId, newShocker.model ?? "CaiXianlin", device);
                    Navigator.of(context).pop();
                    if (error != null) {
                      ErrorDialog.show("Error", error);
                      return;
                    }
                    Navigator.of(context).pop();
                    InfoDialog.show("Almost done",
                        "Your shocker was created successfully. To pair it with your hub hold down the on/off button until it beeps a few times. Then press the vibrate button in the app to pair it.");
                    await manager.updateShockerStore();
                    reloadState();
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
              if (!manager.hasAccountWithShockers()) {
                return AlertDialog.adaptive(
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
              return AlertDialog.adaptive(
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

  @override
  void initState() {
    super.initState();
    AlarmListManager.getInstance().onRefresh = () {
      setState(() {});
    };
    if (!AlarmListManager.supportsWs())
      AlarmListManager.getInstance().updateHubStatusViaHttp();
  }

  int? executeAll(ControlType type, int intensity, int duration) {
    List<Control> controls = [];
    int highestDuration = 0;
    for (Shocker s in AlarmListManager.getInstance().getSelectedShockers()) {
      print(s.controls.durationRange.start);
      Control c = s.getLimitedControls(type, AlarmListManager.getInstance().settings.useSeperateSliders && type == ControlType.vibrate ? s.controls.getRandomVibrateIntensity() : s.controls.getRandomIntensity(), s.controls.getRandomDuration());
      if (c.duration > highestDuration) {
        highestDuration = c.duration;
      }
      controls.add(c);
    }
    if (type == ControlType.stop) {
      // Temporary workaround until OpenShock fixed the issue with stop. So for now we send them individually
      for (Control c in controls) {
        AlarmListManager.getInstance().sendControls([c]);
      }
      return 0;
    }
    AlarmListManager.getInstance().sendControls(controls);
    print(highestDuration);
    return highestDuration;
  }

  ShockerScreenState(this.manager);
  @override
  Widget build(BuildContext context) {
    AlarmListManager.getInstance().reloadAllMethod = () {
      setState(() {});
    };
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
            //liveActive: AlarmListManager.getInstance().liveControlGatewayConnections.containsKey(shocker.key?.id ?? ""),
            shocker: s,
            manager: manager,
            onRebuild: rebuild,
            key: ValueKey(s.getIdentifier())));
      }
      shockers.add(StickyHeader(
          header: ConstrainedContainer(
              width: 1500,
              child: HubItem(
                  hub: shocker.key!,
                  manager: manager,
                  key: ValueKey(shocker.key!.getIdentifier(manager)),
                  onRebuild: rebuild)),
          content: ConstrainedContainer(
              width: 1500,
              child: DynamicChildLayout(
                minWidth: 450,
                children: shockerWidgets,
              ))));
    }
    Shocker limitedShocker = AlarmListManager.getInstance().getSelectedShockerLimits();
    return DesktopMobileRefreshIndicator(
      onRefresh: () async {
        await manager.updateShockerStore();
        setState(() {});
      },
      child: Column(
        children: [
          Expanded(child: SingleChildScrollView(child: Column(children: [
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
          ]),),),
          if(AlarmListManager.getInstance().selectedShockers.isNotEmpty) Column(
            children: [
              Padding(padding: PredefinedSpacing.paddingExtraSmall()),
              ShockingControls(
                            manager: AlarmListManager.getInstance(),
                            controlsContainer: AlarmListManager.getInstance().controls,
                            durationLimit: limitedShocker.durationLimit,
                            showSliders: false,
                            intensityLimit: limitedShocker.intensityLimit,
                            soundAllowed: limitedShocker.soundAllowed,
                            vibrateAllowed: limitedShocker.vibrateAllowed,
                            shockAllowed: limitedShocker.shockAllowed,
                            onDelayAction: executeAll,
                            onProcessAction: executeAll,
                            onSet: (container) {},
                            key: ValueKey(
                                DateTime.now().millisecondsSinceEpoch)),
            ],
          )
        ],
      ),
    );
  }
}
