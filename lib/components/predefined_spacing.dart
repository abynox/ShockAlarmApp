import 'package:flutter/widgets.dart';

class PredefinedSpacing extends StatelessWidget {
  static EdgeInsets paddingExtraSmall() => EdgeInsets.all(5);
  static EdgeInsets paddingSmall() => EdgeInsets.all(10);
  static EdgeInsets paddingMedium() => EdgeInsets.all(15);
  static EdgeInsets paddingExtraLarge() => EdgeInsets.all(40);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: paddingMedium()
    );
  }
}