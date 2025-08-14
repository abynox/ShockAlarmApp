import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/vibrations.dart';

class HapticSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  const HapticSwitch({
    required this.value,
    required this.onChanged,
    this.switchKey,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      key: switchKey,
      value: value,
      onChanged: (value) {
        ShockAlarmVibrations.switchChanged(value);
        this.onChanged(value);
      },
    );
  }
}