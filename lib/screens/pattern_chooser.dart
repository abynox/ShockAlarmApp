import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/card.dart';
import 'package:shock_alarm_app/components/delete_dialog.dart';
import 'package:shock_alarm_app/components/dynamic_child_layout.dart';
import 'package:shock_alarm_app/components/live_controls.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

class PatternChooser extends StatefulWidget {
  final Function(LivePattern) onPatternSelected;

  PatternChooser({Key? key, required this.onPatternSelected}) : super(key: key);

  @override
  _PatternChooserState createState() => _PatternChooserState();
}

class _PatternChooserState extends State<PatternChooser> {
  LivePattern? selectedPattern;

  void onLongPress(pattern) {
    showDialog(context: context, builder: (context) => DeleteDialog(onDelete: () {
      AlarmListManager.getInstance().removePattern(pattern);
      setState(() {});
    }, title: "Delete ${pattern.name}?", body: "Do you really want to delete the pattern ${pattern.name}?"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
              'Choose a pattern'),
        ),
        body: DynamicChildLayout(
          children:AlarmListManager.getInstance()
              .livePatterns.isEmpty ? [Text("No patterns, create some before loading them")] : [
                GestureDetector(

                  onTap: () {
                    widget.onPatternSelected(LivePattern());
                    Navigator.pop(context);
                  },
                  child: PaddedCard(
                      child: Column(children: [
                        Icon(Icons.add),
                    Text("Create new pattern or just use the live controls"),
                  ])),
                ),
                
                ...AlarmListManager.getInstance()
              .livePatterns
              .map(
                (pattern) => GestureDetector(

                  onTap: () {
                    widget.onPatternSelected(pattern);
                    Navigator.pop(context);
                  },
                  onLongPress: () => onLongPress(pattern),
                  onSecondaryTap: () => onLongPress(pattern),
                  child: PaddedCard(
                      child: Column(
                        children: [
                    Text("${pattern.name.isEmpty
                        ? 'Unnamed Pattern'
                        : pattern.name} (${(pattern.getMaxTime() / 1000).toStringAsFixed(1)} s)"),
                    PatternPreview(pattern: pattern)
                  ])),
                ),
              )
              .toList()],
        ));
  }
}
