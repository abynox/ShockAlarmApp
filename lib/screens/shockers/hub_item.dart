import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/components/haptic_switch.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/delete_dialog.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/shares/shares.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

import '../../main.dart';
import '../ota_update/update_hub.dart';

class HubItem extends StatefulWidget {
  Hub hub;
  AlarmListManager manager;
  Function onRebuild;
  HubItem(
      {Key? key,
      required this.hub,
      required this.manager,
      required this.onRebuild})
      : super(key: key);

  static Future pairHub(
      BuildContext context, AlarmListManager manager, String hubId) async {
    await showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Get pair code?"),
              content: Text(
                  "Do you want to get a pair code for this hub? It is valid for 15 minutes."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Close")),
                TextButton(
                    onPressed: () async {
                      LoadingDialog.show("Getting pair code");
                      PairCode pairCode = await manager.getPairCode(hubId);
                      Navigator.of(context).pop();
                      if (pairCode.error != null || pairCode.code == null) {
                        ErrorDialog.show("Failed to get pair code",
                            pairCode.error ?? "Unknown error");
                        return;
                      }
                      manager.onDeviceStatusUpdated = (OpenShockDevice device) {
                        if (device.device != hubId) return;
                        if (!device.online) return;
                        // The hub has come online. We can close the pop up.
                        Navigator.of(navigatorKey.currentContext!).pop();
                        showDialog(
                            context: navigatorKey.currentContext!,
                            builder: (context) => AlertDialog.adaptive(
                                  title: Text("Hub paired!"),
                                  content: Column(
                                    spacing: 10,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          "Your hub has come online under your account! You can now use it."),
                                      Text(
                                          "In case you didn't enter your pair code yet, here is your pair code again: ${pairCode.code}")
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          manager.onDeviceStatusUpdated = null;
                                          Navigator.of(context).pop();
                                        },
                                        child: Text("Ok"))
                                  ],
                                ));
                        manager.onDeviceStatusUpdated = null;
                      };
                      // copy to clipboard
                      if (pairCode.code != null)
                        Clipboard.setData(ClipboardData(text: pairCode.code!));
                      Navigator.of(context).pop();
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog.adaptive(
                                title: Text("Pair code"),
                                content: SingleChildScrollView(
                                    child: Column(spacing: 10, children: [
                                  Text("Your pair code is"),
                                  Row(
                                    spacing: 10,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        pairCode.code!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.copy),
                                        onPressed: () => Clipboard.setData(
                                            ClipboardData(
                                                text: pairCode.code!)),
                                      )
                                    ],
                                  ),
                                  Text(
                                      "Please connect to the OpenShock WiFi network which your hub has made. Make sure you disable mobile data! Once you're connected a pop up should open in this app to open the hub configuration page (alternatively open http://10.10.10.10). Once you're on there connect the hub with your WiFi and enter the pair code in the account linking section.")
                                ])),
                                actions: [
                                  TextButton(
                                      onPressed: () {
                                        manager.onDeviceStatusUpdated = null;
                                        Navigator.of(context).pop();
                                      },
                                      child: Text("Ok"))
                                ],
                              ));
                    },
                    child: Text("Get pair code"))
              ],
            ));
  }

  @override
  State<StatefulWidget> createState() => HubItemState(hub, manager, onRebuild);
}

class HubItemState extends State<HubItem> {
  Hub hub;
  Function onRebuild;
  AlarmListManager manager;

  HubItemState(this.hub, this.manager, this.onRebuild);

  void startRenameHub() {
    TextEditingController controller = TextEditingController();
    controller.text = hub.name;
    showDialog(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Edit hub"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.hub.id.isNotEmpty)
                    TextField(
                        readOnly: true,
                        decoration: InputDecoration(labelText: "Id (readonly)"),
                        controller: TextEditingController(
                          text: widget.hub.id,
                        )),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(labelText: "Name"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      LoadingDialog.show("Renaming hub");
                      String? errorMessage =
                          await manager.renameHub(hub, controller.text);
                      Navigator.of(context).pop();
                      if (errorMessage != null) {
                        ErrorDialog.show("Failed to rename hub", errorMessage);
                        return;
                      }
                      Navigator.of(context).pop();
                      onRebuild();
                    },
                    child: Text("Rename"))
              ],
            ));
  }

  void deleteHub() {
    showDialog(
        context: context,
        builder: (context) => DeleteDialog(
            onDelete: () async {
              LoadingDialog.show("Deleting hub");
              String? errorMessage = await manager.deleteHub(hub);
              Navigator.of(context).pop();
              if (errorMessage != null) {
                ErrorDialog.show("Failed to delete hub", errorMessage);
                return;
              }
              Navigator.of(context).pop();
              await manager.updateShockerStore();
              onRebuild();
            },
            title: "Delete hub",
            body:
                "Are you sure you want to delete this hub? This will also delete all shockers and shares associated with this hub. This action cannot be undone!"));
  }

  void regenerateToken() {
    bool showToken = true;
    showAdaptiveDialog(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, setState) {
              return AlertDialog.adaptive(
                  title: Text("Regenerate/show token"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          "Regenerating a hub token will invalidate the current one. Therefore you will have to repair your hub. Any application using the token will also have its access revoked"),
                      Row(
                        spacing: 10,
                        children: [
                          HapticSwitch(
                              value: showToken,
                              onChanged: (value) => setState(() {
                                    showToken = value;
                                  })),
                          Text("Show new token afterwards")
                        ],
                      )
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text("Cancel")),
                    TextButton(
                        onPressed: () => showCurrentToken(isCurrent: true),
                        child: Text("Show current")),
                    TextButton(
                        onPressed: () async {
                          LoadingDialog.show("Regenerating token");
                          ErrorContainer<bool> errorMessage =
                              await OpenShockClient()
                                  .regenerateDeviceToken(hub);
                          if (errorMessage.error != null) {
                            Navigator.of(context).pop();
                            ErrorDialog.show("Failed to regenerate token",
                                errorMessage.error!);
                            return;
                          }
                          Navigator.of(context).pop();
                          if (showToken) {
                            showCurrentToken();
                          } else {
                            Navigator.of(context).pop();
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog.adaptive(
                                    title: Text("Hub Token regenerated!"),
                                    content: Text(
                                        "Your token has been regenerated."),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: Text("Ok"))
                                    ],
                                  );
                                });
                          }
                        },
                        child: Text("Regenerate"))
                  ]);
            }));
  }

  void showCurrentToken({bool isCurrent = false}) async {
    LoadingDialog.show("Loading${isCurrent ? "" : " new"} token");
    // ToDo: show new token
    ErrorContainer<OpenShockDevice> device =
        await OpenShockClient().getDeviceDetails(hub);
    Navigator.of(context).pop();
    if (device.error != null) {
      ErrorDialog.show("Failed to get${isCurrent ? "" : " new"} token details",
          device.error!);
      return;
    }
    Navigator.of(context).pop();
    showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog.adaptive(
              title: Text(
                  isCurrent ? "Current hub token" : "Hub token regenerated!"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Your${isCurrent ? "" : " new"} token is"),
                  QrCard(data: device.value!.token),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Ok"))
              ],
            ));
  }

  void captivePortal() {
    showDialog(
        context: context,
        builder: (builder) => AlertDialog.adaptive(
              title: Text("Captive portal"),
              content: Text(
                  "The captive portal is the website hosted on your hub itself. It's only available in your wifi ans is used for managing the wifi connection and account linking. Here you can enable or disable it."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      setEnable(context, true);
                    },
                    child: Text("Enable")),
                TextButton(
                    onPressed: () async {
                      setEnable(context, false);
                    },
                    child: Text("Disable"))
              ],
            ));
  }

  void setEnable(BuildContext context, bool enable) async {
    LoadingDialog.show("${enable ? "Enabling" : "Disabling"} captive portal");
    String? errorMessage = await manager.setCaptivePortal(hub, enable);
    Navigator.of(context).pop();
    if (errorMessage != null) {
      ErrorDialog.show(
          "Failed to ${enable ? "enable" : "disable"} captive portal",
          errorMessage);
      return;
    }
    Navigator.of(context).pop();
    onRebuild();
  }

  void updateHub() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => UpdateHubScreen(hub: hub)));
  }

  @override
  void dispose() {
    super.dispose();
    AlarmListManager.getInstance()
        .liveControlGatewayConnections[hub.id]
        ?.onLatency = null;
  }

  @override
  void didUpdateWidget(covariant HubItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (AlarmListManager.getInstance()
        .liveControlGatewayConnections
        .containsKey(hub.id)) {
      AlarmListManager.getInstance()
          .liveControlGatewayConnections[hub.id]!
          .onLatency = () {
        setState(() {});
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Container(
      color: t.colorScheme.surface,
      child: Padding(
          padding: PredefinedSpacing.paddingMedium(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      spacing: 5,
                      children: [
                        Icon(
                          Icons.circle,
                          color: manager.onlineHubs.contains(hub.id)
                              ? Color(0xFF14F014)
                              : Color(0xFFF01414),
                          size: 10,
                        ),
                        Text("${hub.name}",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 20)),
                        Text(
                          "${hub.firmwareVersion != "" && manager.settings.showFirmwareVersion ? " (v. ${hub.firmwareVersion})" : ""}${AlarmListManager.getInstance().liveControlGatewayConnections.containsKey(hub.id) ? " (${"${AlarmListManager.getInstance().liveControlGatewayConnections[hub.id]!.getLatency()}ms"} latency)" : ""}",
                          style: t.textTheme.labelMedium,
                        )
                      ],
                    ),
                  ),
                  if (hub.isOwn)
                    PopupMenuButton(
                      iconColor: t.colorScheme.onSurfaceVariant,
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem(
                              value: "edit",
                              child: Row(
                                spacing: 10,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                  Text("Edit")
                                ],
                              )),
                          PopupMenuItem(
                              value: "regenerate",
                              child: Row(
                                spacing: 10,
                                children: [
                                  Icon(
                                    Icons.replay_outlined,
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                  Text("Regenerate/Show Token")
                                ],
                              )),
                          PopupMenuItem(
                              value: "pair",
                              child: Row(
                                spacing: 10,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                  Text("Pair hub")
                                ],
                              )),
                          if (AlarmListManager.supportsWs())
                            PopupMenuItem(
                                value: "update",
                                child: Row(
                                  spacing: 10,
                                  children: [
                                    Icon(
                                      Icons.upgrade,
                                      color: t.colorScheme.onSurfaceVariant,
                                    ),
                                    Text("OTA Update")
                                  ],
                                )),
                          if (AlarmListManager.supportsWs())
                            PopupMenuItem(
                                value: "captive",
                                child: Row(
                                  spacing: 10,
                                  children: [
                                    Icon(
                                      Icons.ad_units,
                                      color: t.colorScheme.onSurfaceVariant,
                                    ),
                                    Text("Captive portal")
                                  ],
                                )),
                          PopupMenuItem(
                              value: "delete",
                              child: Row(
                                spacing: 10,
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                  Text("Delete")
                                ],
                              ))
                        ];
                      },
                      onSelected: (String value) {
                        if (value == "edit") {
                          startRenameHub();
                        }
                        if (value == "update") {
                          updateHub();
                        }
                        if (value == "delete") {
                          deleteHub();
                        }
                        if (value == "pair") {
                          HubItem.pairHub(context, manager, hub.id);
                        }
                        if (value == "captive") {
                          captivePortal();
                        }
                        if (value == "regenerate") {
                          regenerateToken();
                        }
                      },
                    ),
                ],
              ),
            ],
          )),
    );
  }
}
