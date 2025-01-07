import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class HubItem extends StatefulWidget {
  Hub hub;
  AlarmListManager manager;
  HubItem({Key? key, required this.hub, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => HubItemState(hub, manager);
}

class HubItemState extends State<HubItem> {
  Hub hub;
  AlarmListManager manager;

  HubItemState(this.hub, this.manager);

  void startRenameHub() {
    TextEditingController controller = TextEditingController();
    controller.text = hub.name;
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text("Rename hub"),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: "Name"
        ),
      ),
      actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Cancel")),
        TextButton(onPressed: () async {
          showDialog(context: context, builder: (context) => AlertDialog(
            title: Text("Renaming hub"),
            content: Row(children: [CircularProgressIndicator()]),
          ));
          String? errorMessage = await manager.renameHub(hub, controller.text);
          Navigator.of(context).pop();
          if(errorMessage != null) {
            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to rename hub"), content: Text(errorMessage), actions: [TextButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: Text("Ok"))],));
            return;
          }
          Navigator.of(context).pop();
          setState(() {
            hub.name = controller.text;
          });
        
        }, child: Text("Rename"))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(padding: EdgeInsets.all(10), child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(hub.name, style: TextStyle(fontSize: 20)),
              if(hub.isOwn) PopupMenuButton(iconColor: t.colorScheme.onSurfaceVariant, itemBuilder: (context) {
                return [
                  PopupMenuItem(value: "rename", child: Row(
                    spacing: 10,
                    children: [
                    Icon(Icons.edit, color: t.colorScheme.onSurfaceVariant,),
                    Text("Rename")
                  ],)),
                  PopupMenuItem(value: "logs", child: Row(
                    spacing: 10,
                    children: [
                      Icon(Icons.list, color: t.colorScheme.onSurfaceVariant,),
                    Text("Logs")
                  ],)),
                  PopupMenuItem(value: "shares", child: Row(
                    spacing: 10,
                    children: [
                      Icon(Icons.share, color: t.colorScheme.onSurfaceVariant,),
                    Text("Shares")
                  ],)),
                  PopupMenuItem(value: "delete", child: Row(
                    spacing: 10,
                    children: [
                      Icon(Icons.delete, color: t.colorScheme.onSurfaceVariant,),
                    Text("Delete")
                  ],))
              ];
          }, onSelected: (String value) {
            if(value == "rename") {
              startRenameHub();
            }
          },),
            ],
          ),
        ],
      )), 
    );
  }
}