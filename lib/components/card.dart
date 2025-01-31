import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class PaddedCard extends StatefulWidget {
  final Widget child;
  final Color? color;

  const PaddedCard({Key? key, required this.child, this.color}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PaddedCardState();
}

class PaddedCardState extends State<PaddedCard> {
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Card(
      color: widget.color ?? t.colorScheme.onInverseSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
          padding: const EdgeInsets.all(10),
          child: widget.child,
      ),
    );
  }
}