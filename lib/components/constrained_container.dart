import 'package:flutter/material.dart';

class ConstrainedContainer extends StatelessWidget {
  final Widget child;
  final double width;

  const ConstrainedContainer({Key? key, required this.child, this.width = 1000}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        child: child,
      ),
    );
  }
}
