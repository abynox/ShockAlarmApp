import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return KeyboardListener(
      focusNode: refreshFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f5) {
          refreshKey.currentState?.show();
        }
      },
      child: RefreshIndicator(
        key: refreshKey,
        onRefresh: widget.onRefresh,
        child: widget.child
      )
    );
  }

  @override
  void dispose() {
    refreshFocusNode.dispose();
    super.dispose();
  }
}