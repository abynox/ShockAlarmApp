import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/shocker_item.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../stores/alarm_store.dart';
import '../services/alarm_list_manager.dart';
import '../components/edit_alarm_days.dart';
import '../components/edit_alarm_time.dart';

class ToneItem extends StatefulWidget {
  final AlarmTone tone;
  final AlarmListManager manager;
  final Function onRebuild;

  const ToneItem({Key? key, required this.tone, required this.manager, required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ToneItemState(tone, manager, onRebuild);
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

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return  GestureDetector(
          onTap: () => {
            setState(() {
              expanded = !expanded;
            })
          },
          child:
            Card(
              color: t.colorScheme.onInverseSurface,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(tone.name)
                          ],
                        ),
                        Column(children: [
                          IconButton(onPressed: () {setState(() {
                            expanded = !expanded;
                          });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded))
                        ],)
                      ],
                    ),
                    if (expanded) Column(
                      children: [
                        Column(children: tone.components.map((component) {
                          return ToneComponentItem(component: component, manager: manager, onRebuild: onRebuild);
                        }).toList()),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: _delete,
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
                )
              ),
            ),
          );
  }
}

class ToneComponentItem extends StatefulWidget {
  final AlarmToneComponent component;
  final AlarmListManager manager;
  final Function onRebuild;

  const ToneComponentItem({Key? key, required this.component, required this.manager, required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ToneComponentItemState(component, manager, onRebuild);
}

class ToneComponentItemState extends State<ToneComponentItem> {
  final AlarmToneComponent component;
  final AlarmListManager manager;
  final Function onRebuild;
  
  ToneComponentItemState(this.component, this.manager, this.onRebuild);

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    TextEditingController timeController = TextEditingController(text: (component.time / 1000.0).toString());
    return  
      Card(
        color: t.colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  Row(spacing: 10, children: [
                      DropdownMenu<ControlType?>(dropdownMenuEntries: [
                          DropdownMenuEntry(label: "Shock", value: ControlType.shock,),
                          DropdownMenuEntry(label: "Vibration", value: ControlType.vibrate,),
                          DropdownMenuEntry(label: "Sound", value: ControlType.sound,),
                        ],
                        initialSelection: component.type,
                        onSelected: (value) {
                          setState(() {
                            component.type = value;
                          });
                        }),
                        Expanded(child: 
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Time (sec)",
                              hintText: "Time"
                            ),
                            onSubmitted:(value) {
                              component.time = (double.parse(value) * 1000).toInt();
                            } ,
                            controller: timeController,
                          ),
                        )
                  ],),

                    IntensityDurationSelector(key: ValueKey(component.type), controlsContainer: ControlsContainer(currentIntensity: component.intensity, currentDuration: component.duration), onSet: (intensity, duration) {
                            setState(() {
                              component.duration = duration;
                              component.intensity = intensity;
                            });
                          }, maxDuration: 3000,
                          maxIntensity: 100,
                          showIntensity: component.type != ControlType.sound,
                          type: component.type ?? ControlType.shock,),
                    ],
                  ),
            ],
          )
        ),
      );
  }
}