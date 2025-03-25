import 'package:flutter/material.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/tools/bottom/bottom.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class ShockerUnpauseDialog extends StatefulWidget {
  const ShockerUnpauseDialog({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerUnpauseDialogState();
}

class ShockerUnpauseDialogState extends State<ShockerUnpauseDialog> {
  List<Shocker> toUnpause = [];

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return AlertDialog.adaptive(
      title: Text("Select shockers to unpause"),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AlarmListManager.getInstance()
              .shockers
              .where((x) => x.isOwn)
              .map((shocker) => Row(
                    spacing: 10,
                    children: [
                      Switch(
                          value: toUnpause.contains(shocker),
                          onChanged: (value) {
                            setState(() {
                              if (value) {
                                toUnpause.add(shocker);
                              } else {
                                toUnpause.remove(shocker);
                              }
                              print(toUnpause);
                            });
                          }),
                      Text("${shocker.hubReference!.name}.${shocker.name}")
                    ],
                  ))
              .toList()),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel")),
        TextButton(
            onPressed: () async {
              LoadingDialog.show("Unpausing shockers");
              for (var shocker in toUnpause) {
                String? error = await OpenShockClient().setPauseStateOfShocker(
                    shocker, AlarmListManager.getInstance(), false);
                if (error != null) {
                  Navigator.of(context).pop();
                  ErrorDialog.show(
                      "Error unpausing shocker ${shocker.name}", error);
                  return;
                }
              }
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text("Unpause")),
      ],
    );
  }
}
