import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';

class PagePadding extends StatefulWidget {
  final Widget child;

  const PagePadding({Key? key, required this.child}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PagePaddingState();
}


class PagePaddingState extends State<PagePadding> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: EdgeInsets.all(10),
      child: widget.child,
    );
  }
}
