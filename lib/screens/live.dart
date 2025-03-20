import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/screens/home.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

class LiveScreen extends StatefulWidget {
  @override
  _LiveScreenState createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  @override
  void initState() {
    super.initState();
    AlarmListManager.getInstance().reloadAllMethod = () {
      setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Controls'),
      ),
      body: PagePadding(
        child: ConstrainedContainer(
          child: ListView(
            children: <Widget>[
              
            ],
          ),
        ),
      ),
    );
  }
}