import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

class DesktopMobileRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const DesktopMobileRefreshIndicator({super.key, required this.onRefresh, required this.child});

  @override
  State<StatefulWidget> createState() => DesktopMobileRefreshIndicatorState();
}

class DesktopMobileRefreshIndicatorState extends State<DesktopMobileRefreshIndicator> {
  final GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey<RefreshIndicatorState>();
  final FocusNode refreshFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    AlarmListManager.getInstance().onRefresh = () {
      refreshKey.currentState?.show();
    };
    return RefreshIndicator(
        key: refreshKey,
        onRefresh: widget.onRefresh,
        child: kIsWeb ? Column(
          children: [
            IconButton(onPressed: () {
              refreshKey.currentState?.show();
            }, icon: Icon(Icons.refresh)),
            Expanded(child: widget.child)
          ],
        ) : widget.child
      );
  }

  @override
  void dispose() {
    refreshFocusNode.dispose();
    super.dispose();
  }
}