import 'package:flutter/material.dart';
import 'package:shock_alarm_app/dialogs/delete_dialog.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/services/limits.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../../stores/alarm_store.dart';
import '../../services/alarm_list_manager.dart';
import '../alarms/edit_alarm_days.dart';
import '../alarms/edit_alarm_time.dart';
import '../../components/padded_card.dart';
import '../shockers/shocking_controls.dart';

class ToneItem extends StatefulWidget {
  final AlarmTone tone;
  final AlarmListManager manager;
  final Function onRebuild;

  const ToneItem(
      {Key? key,
      required this.tone,
      required this.manager,
      required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      ToneItemState(tone, manager, onRebuild);
}

class ToneItemState extends State<ToneItem> {
  final AlarmTone tone;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;

  ToneItemState(this.tone, this.manager, this.onRebuild);

  void _delete() {
    manager.deleteTone(tone);
    onRebuild();
  }

  void _save() {
    manager.saveTone(tone);
    expanded = false;
    onRebuild();
  }

  void addComponent() {
    tone.components.add(AlarmToneComponent(type: ControlType.vibrate));
    setState(() {});
  }

  void onDeleteComponent(AlarmToneComponent component) {
    tone.components.remove(component);
    manager.saveTone(tone);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
        child: Column(
      children: [
        GestureDetector(
          onTap: () => {
            setState(() {
              expanded = !expanded;
              if (!expanded) _save();
            })
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextButton(
                    onPressed: () async {
                      String newName = "";
                      TextEditingController controller =
                          TextEditingController(text: tone.name);
                      await showDialog(
                          context: context,
                          builder: (builder) {
                            return AlertDialog.adaptive(
                              title: Text("Rename tone"),
                              content: TextField(controller: controller),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Cancel")),
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      tone.name = controller.text;
                                      _save();
                                    },
                                    child: Text("Save"))
                              ],
                            );
                          });
                    },
                    child: Text(tone.name),
                  )
                ],
              ),
              Column(
                children: [
                  IconButton(
                      onPressed: () {
                        setState(() {
                          expanded = !expanded;
                        });
                      },
                      icon: Icon(expanded
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded))
                ],
              )
            ],
          ),
        ),
        if (expanded)
          Column(
            children: [
              Column(
                  children: tone.components.map((component) {
                return ToneComponentItem(
                  component: component,
                  manager: manager,
                  onRebuild: onRebuild,
                  onDelete: onDeleteComponent,
                  key: ValueKey(component.getId()),
                );
              }).toList()),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (builder) => DeleteDialog(
                              onDelete: () {
                                _delete();
                                Navigator.of(context).pop();
                              },
                              title: "Delete tone",
                              body:
                                  "Are you sure you want to delete this tone?"));
                    },
                    icon: Icon(Icons.delete),
                  ),
                  IconButton(onPressed: addComponent, icon: Icon(Icons.add)),
                  IconButton(
                    onPressed: _save,
                    icon: Icon(Icons.save),
                  ),
                ],
              ),
            ],
          ),
      ],
    ));
  }
}

class ToneComponentItem extends StatefulWidget {
  final AlarmToneComponent component;
  final AlarmListManager manager;
  final Function onRebuild;
  final Function(AlarmToneComponent) onDelete;

  const ToneComponentItem(
      {Key? key,
      required this.component,
      required this.manager,
      required this.onRebuild,
      required this.onDelete})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ToneComponentItemState();
}

class ToneComponentItemState extends State<ToneComponentItem> {
  ToneComponentItemState();

  void _delete() {
    widget.onDelete(widget.component);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
      color: t.colorScheme.surface,
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 5,
            children: [
              Row(
                spacing: 10,
                children: [
                  DropdownMenu<ControlType?>(
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          label: "Shock",
                          value: ControlType.shock,
                        ),
                        DropdownMenuEntry(
                          label: "Vibration",
                          value: ControlType.vibrate,
                        ),
                        DropdownMenuEntry(
                          label: "Sound",
                          value: ControlType.sound,
                        ),
                      ],
                      initialSelection: widget.component.type,
                      onSelected: (value) {
                        setState(() {
                          widget.component.type = value;
                        });
                      }),
                  SecondTextField(
                    timeMs: widget.component.time,
                    label: "Time",
                    onSet: (value) {
                      setState(() {
                        widget.component.time = value;
                      });
                    },
                  ),
                ],
              ),
              IntensityDurationSelector(
                key: ValueKey(widget.component.type),
                showSeperateIntensities: false,
                controlsContainer: ControlsContainer.fromInts(
                    intensity: widget.component.intensity,
                    duration: widget.component.duration),
                onSet: (container) {
                  setState(() {
                    widget.component.duration =
                        container.durationRange.start.toInt();
                    widget.component.intensity =
                        container.intensityRange.start.toInt();
                  });
                },
                maxDuration: OpenShockLimits.getMaxDuration(),
                maxIntensity: 100,
                showIntensity: widget.component.type != ControlType.sound,
                type: widget.component.type ?? ControlType.shock,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(onPressed: _delete, icon: Icon(Icons.delete))
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}

class SecondTextField extends StatelessWidget {
  int timeMs = 0;
  String label = "";
  Function(int) onSet;

  SecondTextField(
      {Key? key,
      required this.timeMs,
      required this.onSet,
      required this.label})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    TextEditingController timeController =
        TextEditingController(text: (timeMs / 1000.0).toString());
    return Expanded(
      child: TextField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: "$label (sec)", hintText: label),
        onSubmitted: (value) {
          timeMs = (double.parse(value) * 1000).toInt();
          onSet(timeMs);
        },
        onTapOutside: (event) {
          timeMs = (double.parse(timeController.text) * 1000).toInt();
          onSet(timeMs);
        },
        controller: timeController,
      ),
    );
  }
}
