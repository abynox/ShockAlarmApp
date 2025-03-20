import 'package:flutter/material.dart';

class DynamicChildLayout extends StatefulWidget {
  final List<Widget> children;
  final int minWidth;
  DynamicChildLayout({Key? key, required this.children, this.minWidth = 200})
      : super(key: key);

  @override
  _DynamicChildLayoutState createState() => _DynamicChildLayoutState();
}

class _DynamicChildLayoutState extends State<DynamicChildLayout> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      int count = (constraints.maxWidth / widget.minWidth).toInt();
      return SingleChildScrollView(child: Wrap(
        children: widget.children
            .map((child) =>
                Container(width: constraints.maxWidth / count, child: child))
            .toList(),
      ),);
    });
  }
}
