import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class QrCard extends StatelessWidget {
  String data;

  QrCard({required this.data});

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Card(
        color: Color(0xFFFFFFFF),
        child: Padding(
            padding: EdgeInsets.all(20),
            child: PrettyQrView(
                decoration: PrettyQrDecoration(
                    shape: PrettyQrSmoothSymbol(
                  color: Color.fromARGB(255, 97, 86, 86),
                )),
                qrImage: QrImage(
                  QrCode(8, QrErrorCorrectLevel.Q)..addData(data),
                ))));
  }
}
