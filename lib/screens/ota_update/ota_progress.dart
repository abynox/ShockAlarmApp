import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../../services/openshock.dart';

class OtaProgressScreen extends StatefulWidget {
  final Hub hub;

  OtaProgressScreen({Key? key, required this.hub}) : super(key: key);

  @override
  _OtaProgressScreenState createState() => _OtaProgressScreenState();
}

class _OtaProgressScreenState extends State<OtaProgressScreen> {
  OTAInstallProgress? progress;
  double overAllProgress = 0.0;
  bool done = false;

  Map<int, String> status = {
    -2: 'Waiting for Hub',
    0: 'Fetching Metadata',
    1: 'Preparing for Install',
    2: 'Flashing Filesystem',
    3: 'Verifying Filesystem',
    4: 'Flashing Application',
    5: 'Marking Application Bootable',
    6: 'Rebooting...'
  };

  @override
  void initState() {
    super.initState();
    AlarmListManager.getInstance().onOtaInstallProgress = (progress) {
      setState(() {
        this.progress = progress;
        updateProgress();
      });
    };
    AlarmListManager.getInstance().otaInstallSucceeded = () {
      setState(() {
        done = true;
      });
    };
  }

  void updateProgress() {
    double partialProgress = progress?.progress ?? 0.0;
    switch (progress?.step) {
      case 0:
        overAllProgress = 0.01 + partialProgress * 0.04;
        break;
      case 1:
        overAllProgress = 0.05 + partialProgress * 0.01;
        break;
      case 2:
        overAllProgress = 0.06 + partialProgress * 0.022;
        break;
      case 3:
        overAllProgress = 0.28 + partialProgress * 0.02;
        break;
      case 4:
        overAllProgress = 0.30 + partialProgress * 0.49;
        break;
      case 5:
        overAllProgress = 0.79 + partialProgress * 0.01;
        break;
      case 6:
        overAllProgress = 0.80 + partialProgress * 0.01;
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OTA Progress'),
      ),
      body: PagePadding(
        child: ConstrainedContainer(
          child: Column(
            children: [
              Text('Updating ${widget.hub.name}...',
                  style: Theme.of(context).textTheme.headlineLarge),
              PredefinedSpacing(),
              if (progress == null) CircularProgressIndicator(),
              if (progress != null && !done) ...[
                Text(status[progress!.step] ?? 'Unknown',
                    style: Theme.of(context).textTheme.headlineMedium),
                LinearProgressIndicator(
                  value: overAllProgress,
                ),
              ],
              if (done) ...[
                  Text('Update succeeded!',
                      style: Theme.of(context).textTheme.headlineMedium),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Back'),
                  )
                ]
            ],
          ),
        ),
      ),
    );
  }
}
