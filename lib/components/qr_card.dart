import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class QrCard extends StatefulWidget {
  String data;
  Color c = Color.fromARGB(255, 48, 44, 44);
  bool copied = false;

  QrCard({required this.data});

  @override
  State<StatefulWidget> createState() => QrCardState();
}

class QrCardState extends State<QrCard> {
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Card(
        color: Color(0xFFFFFFFF),
        child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrettyQrView(
                    decoration: PrettyQrDecoration(
                        shape: PrettyQrSmoothSymbol(
                      color: widget.c,
                    )),
                    qrImage: QrImage(
                      QrCode(8, QrErrorCorrectLevel.Q)..addData(widget.data),
                    )),
                Padding(padding: EdgeInsets.all(10)),
                Center(
                    child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.data));
                  },
                  child: TextButton(
                    child: Row(
                      children: [
                        Text(widget.data),
                        if (widget.copied)
                          Icon(Icons.check, color: Colors.green),
                      ],
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.data));
                      widget.copied = true;
                      setState(() {});
                    },
                  ),
                )),
              ],
            )));
  }
}
