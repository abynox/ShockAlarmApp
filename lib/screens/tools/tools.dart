import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/screens/tools/bottom/bottom.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/screens/tools/random_shocks/random_shocks.dart';

class ToolsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tools'),
      ),
      body: PagePadding(
          child: ConstrainedContainer(
              child: ListView(
        children: <Widget>[

          GestureDetector(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => RandomShocksScreen()));
            },
            child: PaddedCard(
              child: Column(
                children: [
                  Text('Random shocks'),
                  Text('Generate random shocks'),
                ],
              ),
            ),
          ),

          GestureDetector(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => BottomScreen()));
            },
            child: PaddedCard(
              child: Column(
                children: [
                  Text('Bottom Screen'),
                  Text('Shows logs and has an emergency stop button'),
                ],
              ),
            ),
          ),
        ],
      ))),
    );
  }
}
