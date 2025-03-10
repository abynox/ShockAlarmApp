import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/screens/random_shocks.dart';

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
                  MaterialPageRoute(builder: (context) => RandomShocks()));
            },
            child: PaddedCard(
              child: Column(
                children: [
                  Text('Random shocks'),
                  Text('Generate random shocks'),
                ],
              ),
            ),
          )
        ],
      ))),
    );
  }
}
