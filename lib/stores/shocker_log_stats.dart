import 'dart:collection';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/openshock.dart';

class ShockerLogStatUser {
  String id;
  String name;
  Color color;

  ShockerLogStatUser(this.id, this.name, this.color);
}

class ShockerLogStats {
  Map<ControlType, ShockerLogDistributionStat> shockDistribution = {};
  Map<String, List<ShockerLog>> entriesPerUser = {};
  List<ShockerLog> logs = [];
  Map<String, ShockerLogStatUser> users = {};
  DateTime minDate = DateTime.now();
  DateTime maxDate = DateTime.now();
  List<String> selectedUsers = [];
 
  ThemeData themeData;

  ShockerLogStats({required this.themeData});

  void addLogs(List<ShockerLog> logs) {
    this.logs.addAll(logs);
  }


  void clear() {
    // Doesn't clear users
    logs.clear();
    shockDistribution.clear();
    entriesPerUser.clear();
    minDate = DateTime.now();
    maxDate = DateTime.now();
  }

  Color darken(Color c, double amount) {
    return Color.from(alpha: c.a, red: c.r * amount, green: c.g * amount, blue: c.b * amount);
  }

  void doStats() {
    // Sort logs by time
     List<Color> colors = [
      Color.fromRGBO(219, 54, 54, 1),
      Color.fromRGBO(235, 221, 30, 1),
      Color.fromARGB(255, 44, 122, 185),
      Color.fromRGBO(0, 192, 173, 1),
      Color.fromARGB(255, 6, 207, 12),
    ];
    for(ShockerLog log in logs) {
      // seperate logs into per user
      if(!users.containsKey(log.controlledBy.id)) {
        users[log.controlledBy.id] = ShockerLogStatUser(log.controlledBy.id, log.controlledBy.name, colors[users.length % colors.length]);
        selectedUsers.add(log.controlledBy.id);
      }
      if(!selectedUsers.contains(log.controlledBy.id)) {
        continue;
      }

      if(!entriesPerUser.containsKey(log.controlledBy.id)){
        entriesPerUser[log.controlledBy.id] = [];
      }
      entriesPerUser[log.controlledBy.id]?.add(log);

      if(!shockDistribution.containsKey(log.type)) {
        shockDistribution[log.type] = ShockerLogDistributionStat();
      }
      shockDistribution[log.type]?.addEntry(log);

      if(log.createdOn.isBefore(minDate)) {
        minDate = log.createdOn;
      }

      if(log.createdOn.isAfter(maxDate)) {
        maxDate = log.createdOn;
      }
    }
  }
}

class ShockerLogDistributionStat {
  SplayTreeMap<int, ShockerLogDistributionStatDataPoint> total = SplayTreeMap();

  void addEntry(ShockerLog l) {
    // As stop and sound aren't affected by intensity we can do this
    if(l.type == ControlType.stop || (l.type == ControlType.sound && l.intensity > 0)) l.intensity = 1;
    if(!total.containsKey(l.intensity)) {
      total[l.intensity] = ShockerLogDistributionStatDataPoint();
    }
    // Sum up the total duration at each intensity
    total[l.intensity]?.add(l);
  }
}

class ShockerLogDistributionStatDataPoint {
  SplayTreeMap<String, int> users = SplayTreeMap();

  void add(ShockerLog l) {
    users[l.controlledBy.id] = (users[l.controlledBy.id] ?? 0) + l.duration;
  }

  double getTotal() {
    return users.values.fold(0, (previousValue, element) => previousValue + element);
  }
}