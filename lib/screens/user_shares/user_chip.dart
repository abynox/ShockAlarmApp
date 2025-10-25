import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class UserChip extends StatelessWidget {
  OpenShockUser? user;
  String altText;

  UserChip({required this.user, this.altText = "Unknown user"});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(user?.name ?? altText));
  }
}