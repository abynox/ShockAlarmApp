import 'dart:convert';
import 'dart:io';

import '../stores/alarm_store.dart';
import 'package:path_provider/path_provider.dart';

class JsonFileStorage {
  File? _file;

  JsonFileStorage();

  JsonFileStorage.toFile(this._file);

  Future<void> writeList(List<ObservableAlarmBase> alarms) async {
    await _ensureFileSet();
    _file!.writeAsString(jsonEncode(alarms));
  }

  Future<List<ObservableAlarmBase>> readList() async {
    await _ensureFileSet();
    if (_file!.existsSync()) {
      String content = await _file!.readAsString();
      List<dynamic> parsedList = jsonDecode(content) as List;
      //return parsedList.map((map) => ObservableAlarmBase.fromJson(map)).toList();
    }
    return [];
  }

  Future<void> _ensureFileSet() async {
    if (_file == null) {
      _file = await _getLocalFile();
    }
  }

  Future<File> _getLocalFile() async {
    return _getLocalPath().then((path) => File('$path/alarms.json'));
  }

  Future<String> _getLocalPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
}