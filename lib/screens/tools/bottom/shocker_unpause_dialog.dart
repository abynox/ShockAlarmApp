import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/haptic_switch.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/screens/tools/bottom/bottom.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class ShockerSelectDialog extends StatefulWidget {
  String title;
  Function(List<Shocker>) confirmCallback;
  String buttonText;

  ShockerSelectDialog(this.title, this.confirmCallback, this.buttonText, {Key? key}) : super(key: key);


  @override
  State<StatefulWidget> createState() => _ShockerSelectDialog();
}

class _ShockerSelectDialog extends State<ShockerSelectDialog> {
  List<Shocker> toUnpause = [];

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return AlertDialog.adaptive(
      title: Text(widget.title),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AlarmListManager.getInstance()
              .shockers
              .where((x) => x.isOwn)
              .map((shocker) => Row(
                    spacing: 10,
                    children: [
                      HapticSwitch(
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
              widget.confirmCallback(toUnpause);
            },
            child: Text(widget.buttonText)),
      ],
    );
  }
}
