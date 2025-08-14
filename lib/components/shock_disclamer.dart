import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/vibrations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

class ShockDisclaimer extends StatelessWidget {

  @override
  StatelessElement createElement() {
    ShockAlarmVibrations.important();
    return super.createElement();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    ThemeData t = Theme.of(context);
    return AlertDialog.adaptive(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: Color.fromARGB(255, 224, 165, 0),
              size: 50,
            ),
            Text("Safety warning"),
          ],
        ),
        content: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              "This app allows you to control devices that can deliver electric shocks and thus harm people! Only use shockers with a consenting human (18+), or on yourself! It mustn't be used on animals!\n\n",
            ),
            Text(
              "This app is provided as is and the developers are not responsible for any harm caused by the use of this app or the devices controlled by it! The information here is provided for informative purpose and doesn't cover all (but most) safety rules. As we use the app ourselves we do our best to make the app as reliable as possible.\n\n",
            ),
            Text(
              "To minimize the risk of injuries follow these rules:\n\n1. Do not wear the shocker near your neck, spine or chest\n2. Do not touch the pins of the shockers with both hands at once.\n\nConsequences include: Heart attacks, irregular heartbeat, breathing irregularities or difficulty, vision or hearing issues, loss of consciousness.\nIf you notice any issues call emergency services immediately!!!\n\n",
            ),
            Text(
              "This app uses OpenShock and implements safety features against abuse:\n\n1. At any time you can pause your shocker after which it cannot be used anymore\n2. You can share your shockers with other users. On these shares you can set limits for the maximum intensity and duration as well as e. g. revoke shocking permission completely.\n3. You can view logs of your shockers which will show who sent what and when they sent it\n4. You can set a global intensity limit in the settings so you don't accidentally shock at too high of an intensity\n\n",
            ),
            Text(
              "Thank you for using the app. Before shocking anyone make sure they are consenting voluntarily and that they are informed of the risks ahead of time. If at any point anyone feels at unease stop shocking immediately!!!\n\nIf you find any problems with the app or have feature requests, report them below\n\n",
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () {
                      launchUrl(Uri.parse(issues_url));
                    },
                    child: Text("Report issue")),
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("I agree")),
                TextButton(
                    onPressed: () {
                      launchUrl(Uri.parse("https://wiki.openshock.org/home/safety-rules/"));
                    },
                    child: Text("More info"))
              ],
            )
          ]),
        ));
  }
}
