import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shock_alarm_app/dialogs/ErrorDialog.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

import '../services/openshock.dart';

class ShockerDetails extends StatefulWidget {
  OpenShockShocker shocker;
  int? apiTokenId;
  List<OpenShockDevice> devices;

  ShockerDetails({required this.shocker, required this.devices, this.apiTokenId});
  @override
  ShockerDetailsState createState() => ShockerDetailsState();
}

class ShockerDetailsState extends State<ShockerDetails> {
  TextEditingController nameController = TextEditingController();
  // number only
  TextEditingController rfIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    nameController.text = widget.shocker.name;
    rfIdController =
        TextEditingController(text: widget.shocker.rfId?.toString());
    return SingleChildScrollView(
      child: Column(
        spacing: 10,
        children: <Widget>[
          if(widget.shocker.id.isNotEmpty) TextField(
              readOnly: true,
              decoration: InputDecoration(labelText: "Id (readonly)"),
              controller: TextEditingController(
                text: widget.shocker.id,
              )),
          DropdownMenu<String>(
              width: double.infinity,
              label: Text("Hub"),
              onSelected: (value) {
                widget.shocker.device = value;
              },
              initialSelection: widget.shocker.device,
              dropdownMenuEntries: [
                for (OpenShockDevice device in widget.devices.where((x) => widget.apiTokenId == null || (x.apiTokenReference?.id ?? 0) == widget.apiTokenId))
                  DropdownMenuEntry(label: device.name, value: device.id),
              ]),
          DropdownMenu<String>(
            width: double.infinity,
            dropdownMenuEntries: [
              DropdownMenuEntry(label: "CaiXianlin", value: "CaiXianlin"),
              DropdownMenuEntry(label: "PetTrainer", value: "PetTrainer"),
              DropdownMenuEntry(
                  label: "Petrainer998DR", value: "Petrainer 998DR"),
            ],
            onSelected: (value) {
              widget.shocker.model = value ?? "CaiXianlin";
            },
            initialSelection: widget.shocker.model,
            label: Text("Shocker type"),
          ),
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: "Shocker Name"),
            onChanged: (value) {
              widget.shocker.name = value;
            },
          ),
          TextField(
            controller: rfIdController,
            decoration: InputDecoration(labelText: "RF ID"),
            keyboardType: TextInputType.number,
            onEditingComplete: rfEditComplete,
            onTapOutside: (event) {
              rfEditComplete();
            },
          )
        ],
      ),
    );
  }

  void rfEditComplete() {
    try {
      int proposedValue = int.parse(rfIdController.text);
      if (proposedValue < 0 || proposedValue > 65535) {
        throw Exception("Invalid value");
      }
      widget.shocker.rfId = proposedValue;
    } catch (e) {
      ErrorDialog.show(
          "Invalid RF ID", "The RF ID must be a number between 0 and 65535");
    }
  }
}
