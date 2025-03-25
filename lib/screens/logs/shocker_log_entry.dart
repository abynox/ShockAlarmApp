import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/openshock.dart';

class ShockerLogEntry extends StatelessWidget {
  final ShockerLog log;

  const ShockerLogEntry({Key? key, required this.log}) : super(key: key);

  static String formatDateTime(DateTime? dateTime, {bool alwaysShowDate = false, String fallback = "Unknown"}) {
    if(dateTime == null) {
      return fallback;
    }
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day && !alwaysShowDate;
    final timeString =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    final dateString =
        '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

    return isToday ? timeString : '$dateString $timeString';
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 10,
            children: [
              Expanded(child: Row(
                spacing: 10,
                children: [
                  log.getTypeIcon(),
                  if(log.getLiveIcon() != null) log.getLiveIcon()!,
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          spacing: 0,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.getName(),
                              style: t.textTheme.titleMedium,
                            )
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 10,
                          children: [
                            Text(formatDateTime(log.createdOn.toLocal())),
                          ],
                        ),
                      ]),),
                ]
              ),),
              Row(
                children: [
                  Text("${(log.duration / 100).round() / 10} s"),
                  Text(" @ "),
                  Text("${log.isLive() ? "up to " : ""}${log.intensity}"),
                ],
              ),
              Chip(label: Text(log.shockerReference?.name ?? "Unknown")),
            ]),
        Divider()
      ],
    );
  }
}
