import '../services/openshock.dart';

class ShockerLogStats {
  Map<ControlType, ShockerLogDistributionStat> shockDistribution = {};
  Map<String, List<ShockerLog>> entriesPerUser = {};
  List<ShockerLog> logs = [];

  void addLogs(List<ShockerLog> logs) {
    this.logs.addAll(logs);
  }

  void doStats() {

    for(ShockerLog log in logs) {
      // seperate logs into per user
      if(!entriesPerUser.containsKey(log.controlledBy.id)){
        entriesPerUser[log.controlledBy.id] = [];
      }
      entriesPerUser[log.controlledBy.id]?.add(log);

      if(!shockDistribution.containsKey(log.type)) {
        shockDistribution[log.type] = ShockerLogDistributionStat();
      }
      shockDistribution[log.type]?.addEntry(log);
    }
  }
}

class ShockerLogDistributionStat {
  Map<int, int> total = {};

  void addEntry(ShockerLog l) {
    // As stop and sound aren't affected by intensity we can do this
    if(l.type == ControlType.stop || (l.type == ControlType.sound && l.intensity > 0)) l.intensity = 1;
    
    // Sum up the total duration at each intensity
    total[l.intensity] = (total[l.intensity] ?? 0) + l.duration;
  }
}