import '../stores/alarm_store.dart';

class AlarmListManager {
  final AlarmList _alarms;
  final TokenList _tokens = TokenList();
  //final JsonFileStorage _storage = JsonFileStorage();

  AlarmListManager(this._alarms);

  saveAlarm(ObservableAlarmBase alarm) async {
    final index =
        _alarms.alarms.indexWhere((findAlarm) => alarm.id == findAlarm.id);
    if (index == -1) {
      print('Adding new alarm');
      _alarms.alarms.add(alarm);
    } else {
      _alarms.alarms[index] = alarm;
    }
    //await _storage.writeList(_alarms.alarms);
  }

  void saveToken(Token token) {
    final index = _tokens.tokens.indexWhere((findToken) => token.id == findToken.id);
    if (index == -1) {
      _tokens.tokens.add(token);
    } else {
      _tokens.tokens[index] = token;
    }
    //await _storage.writeList(_tokens.tokens);
  }

  void deleteAlarm(ObservableAlarmBase alarm) {
    _alarms.alarms.removeWhere((findAlarm) => alarm.id == findAlarm.id);
    //await _storage.writeList(_alarms.alarms);
  }

  getAlarms() {
    return _alarms.alarms;
  }

  getTokens() {
    return _tokens.tokens;
  }

  void deleteToken(Token token) {
    _tokens.tokens.removeWhere((findToken) => token.id == findToken.id);
    //await _storage.writeList(_tokens.tokens);
  }
}