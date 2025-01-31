import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class QrCard extends StatelessWidget {
  String data;
  Color c = Color.fromARGB(255, 48, 44, 44);

  QrCard({required this.data});

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
                      color: c,
                    )),
                    qrImage: QrImage(
                      QrCode(8, QrErrorCorrectLevel.Q)..addData(data),
                    )),
                Padding(padding: EdgeInsets.all(10)),
                Center(
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: data));
                      },
                  child: Text(
                    data,
                    style: t.textTheme.bodyMedium?.copyWith(color: c),
                    textAlign: TextAlign.center,
                  ),
                )),
              ],
            )));
  }
}
