import 'package:flutter/material.dart';
import 'package:shock_alarm_app/screens/shares.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

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
        context: context,
        builder: (context) => AlertDialog(
              title: Text("Get pair code?"),
              content: Text(
                  "Do you want to get a pair code for this hub? It is valid for 15 minutes."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      showDialog(
                          context: context,
                          builder: (context) =>
                              LoadingDialog(title: "Getting pair code"));
                      PairCode pairCode = await manager.getPairCode(hubId);
                      Navigator.of(context).pop();
                      if (pairCode.error != null || pairCode.code == null) {
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: Text("Failed to get pair code"),
                                  content:
                                      Text(pairCode.error ?? "Unknown error"),
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
                      Navigator.of(context).pop();
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: Text("Pair code"),
                                content: SingleChildScrollView(
                                    child: Column(spacing: 10, children: [
                                  Text("Your pair code is"),
                                  Text(
                                    pairCode.code!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge,
                                  ),
                                  Text(
                                      "To pair your hub with your account enter the pair code in the ui of your hub. Connect to your hub's wifi. Then connect it with your wifi and enter the code.")
                                ])),
                                actions: [
                                  TextButton(
                                      onPressed: () {
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
        builder: (context) => AlertDialog(
              title: Text("Rename hub"),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(labelText: "Name"),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      showDialog(
                          context: context,
                          builder: (context) =>
                              LoadingDialog(title: "Renaming hub"));
                      String? errorMessage =
                          await manager.renameHub(hub, controller.text);
                      Navigator.of(context).pop();
                      if (errorMessage != null) {
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: Text("Failed to rename hub"),
                                  content: Text(errorMessage),
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
        builder: (context) => AlertDialog(
              title: Text("Delete hub"),
              content: Text(
                  "Are you sure you want to delete this hub? This will also delete all shockers associated with this hub. This action cannot be undone!"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      showDialog(
                          context: context,
                          builder: (context) =>
                              LoadingDialog(title: "Deleting hub"));
                      String? errorMessage = await manager.deleteHub(hub);
                      Navigator.of(context).pop();
                      if (errorMessage != null) {
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: Text("Failed to delete hub"),
                                  content: Text(errorMessage),
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
                      Navigator.of(context).pop();
                      setState(() {
                        manager.hubs.remove(hub);
                        manager.saveShockers();
                      });
                      onRebuild();
                    },
                    child: Text("Delete"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Container(
      color: t.colorScheme.surface,
      child: Padding(
          padding: EdgeInsets.all(10),
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
                        Text(hub.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 20))
                      ],
                    ),
                  ),
                  if (hub.isOwn)
                    PopupMenuButton(
                      iconColor: t.colorScheme.onSurfaceVariant,
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem(
                              value: "rename",
                              child: Row(
                                spacing: 10,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                  Text("Rename")
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
                        if (value == "rename") {
                          startRenameHub();
                        }
                        if (value == "delete") {
                          deleteHub();
                        }
                        if (value == "pair") {
                          HubItem.pairHub(context, manager, hub.id);
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
