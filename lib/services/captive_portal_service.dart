import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:shock_alarm_app/main.dart";
import "package:url_launcher/url_launcher.dart";

class CaptivePortalService {
  static const String captivePortalUrl = 'http://10.10.10.10/';
  static bool captivePortalAvailable = false;
  static int scanInterval = 5; // seconds

  void init() {
    // Initialize the service if needed
  }
  
  Future continuousScan() async {
    while(true) {
      await Future.delayed(Duration(seconds: scanInterval));
      bool available = await isCaptivePortalAvailable();
      if(captivePortalAvailable != available) {
          if (available) {
            // Show snackbar
            showDialog(context: navigatorKey.currentContext!, builder: (builder) => AlertDialog.adaptive(
              title: const Text("Captive portal available"),
              content: const Text("Captive portal is available! Do you want to open it in your browser?"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(builder).pop();
                  },
                  child: const Text("No"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(builder).pop();
                    launchUrl(Uri.parse(captivePortalUrl));
                  },
                  child: const Text("Yes"),
                ),
              ],
            ));
          } else {
            // Do something if the captive portal is not available
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              SnackBar(
                content: Text('Captive portal is not available anymore!'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        captivePortalAvailable = available;
        continuousScan();
    }
  }

  Future<bool> isCaptivePortalAvailable() async {
    // Check whether a captive portal for OpenShock is present.
    // aka check whether 10.10.10.10 is reachable
    
    try {
      final response = await http.get(Uri.parse(captivePortalUrl));
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }


}