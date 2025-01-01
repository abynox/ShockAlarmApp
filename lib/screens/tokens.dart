import 'package:flutter/material.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';
import '../components/bottom_add_button.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../components/token_item.dart';

class TokenScreen extends StatefulWidget {
  final AlarmListManager manager;

  const TokenScreen({Key? key, required this.manager}) : super(key: key);

  @override
  State<StatefulWidget> createState() => TokenScreenState(manager);
}

class TokenScreenState extends State<TokenScreen> {
  final AlarmListManager manager;

  void rebuild() {
    setState(() {});
  }

  TokenScreenState(this.manager);
  @override
  Widget build(BuildContext context) {
    return Column(
        children: <Widget>[
          Text(
            'Your tokens',
            style: TextStyle(fontSize: 28, color: Colors.white),
          ),
          Flexible(
            child: Observer(
              builder: (context) => ListView.builder(
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final token = manager.getTokens()[index];

                  return TokenItem(token: token, manager: manager, onRebuild: rebuild);
                },
                itemCount: manager.getTokens().length,
              ),
            ),
          ),
          BottomAddButton(
            onPressed: () {
              final newToken = new Token(
                DateTime.now().millisecondsSinceEpoch,
                ""
              );
              setState(() {
                manager.saveToken(newToken);
              });
            },
          )
        ],
      );
  }
}