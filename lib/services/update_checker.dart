import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  String url = 'https://api.github.com/repos/ComputerElite/ShockAlarmApp/releases/latest';
  String releaseUrl = 'https://github.com/ComputerElite/ShockAlarmApp/releases/latest';

  void promptUpdateIfAvailable() async {
    print('Checking for updates...');
    bool updateAvailable = await isUpdateAvailable();
    print('Update available: $updateAvailable');
    if (updateAvailable) {
      showDialog(context: navigatorKey.currentContext!, builder: (BuildContext context) => AlertDialog.adaptive(
        title: const Text('Update Available'),
        content: const Text('A new version of ShockAlarm is available. Please update to the latest version.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Ignore'),
            onPressed: () {
              Navigator.of(context).pop();
            }
          ),
          TextButton(
            child: const Text('Open Download Page'),
            onPressed: () {
              // Open the GitHub release page
              Navigator.of(context).pop();
              launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication);
            }
          ),
        ],
      ));
    } else {
      print('You are using the latest version.');
    }
  }

  Future<bool> isUpdateAvailable() async {

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String version = packageInfo.version;

    // Fetch the latest release information from the GitHub API
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      String latestVersion = data['tag_name'];

      // Compare the versions
      return _compareVersions(version, latestVersion);
    } else {
      throw Exception('Failed to load release information');
    }
  }

  bool _compareVersions(String currentVersion, String latestVersion) {
    List<String> currentParts = currentVersion.split('.');
    List<String> latestParts = latestVersion.split('.');

    for (int i = 0; i < currentParts.length && i < 3; i++) { // 0.1.2.3; Ignore 3
      int currentPart = int.parse(currentParts[i]);
      int latestPart = int.parse(latestParts[i]);

      if (currentPart < latestPart) {
        return true; // Update available
      } else if (currentPart > latestPart) {
        return false; // No update available
      }
    }
    return false; // No update available
  }
}