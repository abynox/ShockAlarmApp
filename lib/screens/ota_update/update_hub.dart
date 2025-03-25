import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/screens/logs/shocker_log_entry.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/screens/logs/logs.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../../services/firmware.dart';
import '../../services/openshock.dart';
import 'ota_progress.dart';

class UpdateHubScreen extends StatefulWidget {
  final Hub hub;

  UpdateHubScreen({Key? key, required this.hub}) : super(key: key);

  @override
  _UpdateHubScreenState createState() => _UpdateHubScreenState();
}

class _UpdateHubScreenState extends State<UpdateHubScreen> {
  Map<String, String>? firmware;
  List<OpenShockOTAUpdate>? updates;

  @override
  void initState() {
    super.initState();
    FirmwareGetter.getAvailableFirmware().then((value) {
      if(!mounted) return;
      setState(() {
        firmware = value;
      });
    });
    OpenShockClient().getOTAUpdateHistory(widget.hub).then((value) {
      updates = value;
    });
  }

  void startUpdate(String version) async {
    AlarmListManager.getInstance().startHubUpdate(widget.hub, version);
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => OtaProgressScreen(hub: widget.hub)));
  }

  void updateHub(String version) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog.adaptive(
              title: Text('Update Hub'),
              content: RichText(
                  text: TextSpan(children: [
                TextSpan(text: 'Are you sure you want to update'),
                TextSpan(
                    text: ' ${widget.hub.name} ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'to version '),
                TextSpan(
                    text: version,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: '?')
              ])),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      startUpdate(version);
                    },
                    child: Text('Update')),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text('OTA Update'),
        ),
        body: PagePadding(
            child: ConstrainedContainer(
                child: SingleChildScrollView(
          child: Column(
            children: [
              PaddedCard(
                  child: Column(
                children: [
                  Center(
                    child: Text(
                      'OTA Updates for',
                      style: t.textTheme.headlineSmall,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 10,
                    children: [
                      Icon(
                        Icons.circle,
                        color: AlarmListManager.getInstance()
                                .onlineHubs
                                .contains(widget.hub.id)
                            ? Color(0xFF14F014)
                            : Color(0xFFF01414),
                        size: 20,
                      ),
                      Text(widget.hub.name, style: t.textTheme.headlineMedium),
                    ],
                  ),
                      Text(widget.hub.firmwareVersion,
                          style: t.textTheme.labelLarge)
                ],
              )),
              PredefinedSpacing(),
              Text("Available firmware updates",
                  style: t.textTheme.headlineSmall),
              if (firmware == null)
                Center(
                  child: CircularProgressIndicator(),
                ),
              if (firmware != null)
                ...firmware!.entries.map((firmware) {
                  return PaddedCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              spacing: 10,
                              children: [
                                Text(firmware.key,
                                    style: t.textTheme.headlineMedium),
                                if (widget.hub.firmwareVersion ==
                                    firmware.value)
                                  Chip(label: Text("Currently Installed")),
                              ],
                            ),
                            Text(firmware.value, style: t.textTheme.labelLarge)
                          ],
                        ),
                        ElevatedButton(
                            onPressed: () {
                              updateHub(firmware.value);
                            },
                            child: Text('Install')),
                      ],
                    ),
                  );
                }),
              PredefinedSpacing(),
              Text("Past updates", style: t.textTheme.headlineSmall),
              if (updates == null)
                Center(
                  child: CircularProgressIndicator(),
                ),
              if (updates != null)
                ...updates!.map((update) {
                  return PaddedCard(
                      child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            spacing: 10,
                            children: [
                              Text(
                                ShockerLogEntry.formatDateTime(
                                    update.startedAt),
                                style: t.textTheme.headlineMedium,
                              ),
                              Chip(label: Text(update.status.toString()))
                            ],
                          ),
                          Text(update.version, style: t.textTheme.labelLarge),
                          Text(update.id.toRadixString(16),
                              style: t.textTheme.labelMedium),
                        ],
                      ),
                      Text(update.message ?? "")
                    ],
                  ));
                })
            ],
          ),
        ))));
  }
}
