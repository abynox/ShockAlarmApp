
import 'package:flutter/material.dart';

class Settings {
  bool showRandomDelay = true;
  bool useRangeSliderForRandomDelay = true;
  bool useRangeSliderForIntensity = false;
  bool useRangeSliderForDuration = false;

  bool disableHubFiltering = true;

  bool allowTokenEditing = false;
  bool useHttpShocking = false;

  bool useAlarmServer = false;

  bool useGroupedShockerSelection = true;

  int alarmToneRepeatDelayMs = 1500;

  int maxAlarmLengthSeconds = 60;

  ThemeMode theme = ThemeMode.system;

  bool showFirmwareVersion = false;
  bool allowTonesForControls = false;
  bool liveControlsLogWorkaround = false;
  bool allowMultiServerLogin = false;
  bool lerpIntensity = false;
  bool useSeperateSliders = false;
  bool increaseMaxDuration = false;
  bool confirmShock = false;
  int confirmShockMinIntensity = 50;
  int confirmShockMinDuration = 2000;
  bool enforceHardLimitInsteadOfShock = false;
  bool forceLoginV1 = false;
  
  bool getEnforceHardLimitInsteadOfShock() {
    return enforceHardLimitInsteadOfShock && confirmShock;
  }
  bool enableUiVibrations = true;

  Settings();

  Settings.fromJson(Map<String, dynamic> json) {
    if(json["showRandomDelay"] != null)
      showRandomDelay = json["showRandomDelay"];
    if(json["useRangeSliderForRandomDelay"] != null)
      useRangeSliderForRandomDelay = json["useRangeSliderForRandomDelay"];
    if(json["useRangeSliderForIntensity"] != null)
      useRangeSliderForIntensity = json["useRangeSliderForIntensity"];
    if(json["useRangeSliderForDuration"] != null)
      useRangeSliderForDuration = json["useRangeSliderForDuration"];
    if(json["useAlarmServer"] != null)
      useAlarmServer = json["useAlarmServer"];
    if(json["disableHubFiltering"] != null)
      disableHubFiltering = json["disableHubFiltering"];
    if(json["allowTokenEditing"] != null)
      allowTokenEditing = json["allowTokenEditing"];
    if(json["useHttpShocking"] != null)
      useHttpShocking = json["useHttpShocking"];
    if(json["useGroupedShockerSelection_1"] != null)
      useGroupedShockerSelection = json["useGroupedShockerSelection_1"]; // _1 added so the default saved value on existing installations gets changed
    if(json["theme"] != null)
      theme = ThemeMode.values[json["theme"]];
    if(json["showFirmwareVersion"] != null)
      showFirmwareVersion = json["showFirmwareVersion"];
    if(json["allowTonesForControls"] != null)
      allowTonesForControls = json["allowTonesForControls"];
    if(json["liveControlsLogWorkaround"] != null)
      liveControlsLogWorkaround = json["liveControlsLogWorkaround"];
    if(json["allowMultiServerLogin"] != null)
      allowMultiServerLogin = json["allowMultiServerLogin"];
    if(json["lerpIntensity"] != null)
      lerpIntensity = json["lerpIntensity"];
    if(json["useSeperateSliders"] != null)
      useSeperateSliders = json["useSeperateSliders"];
    if(json["increaseMaxDuration"] != null)
      increaseMaxDuration = json["increaseMaxDuration"];
    if(json["confirmShock"] != null)
      confirmShock = json["confirmShock"];
    if(json["confirmShockMinIntensity"] != null)
      confirmShockMinIntensity = json["confirmShockMinIntensity"];
    if(json["confirmShockMinDuration"] != null)
      confirmShockMinDuration = json["confirmShockMinDuration"];
    if(json["enforceHardLimitInsteadOfShock"] != null)
      enforceHardLimitInsteadOfShock = json["enforceHardLimitInsteadOfShock"];
    if(json["enableUiVibrations"] != null)
      enableUiVibrations = json["enableUiVibrations"];
    if(json["forceLoginV1"] != null)
      forceLoginV1 = json["forceLoginV1"];
      
  }

  Map<String, dynamic> toJson() {
    return {
      "showRandomDelay": showRandomDelay,
      "useRangeSliderForRandomDelay": useRangeSliderForRandomDelay,
      "useRangeSliderForIntensity": useRangeSliderForIntensity,
      "useRangeSliderForDuration": useRangeSliderForDuration,
      "disableHubFiltering": disableHubFiltering,
      "allowTokenEditing": allowTokenEditing,
      "useHttpShocking": useHttpShocking,
      "useGroupedShockerSelection_1": useGroupedShockerSelection,
      "theme": theme.index,
      "showFirmwareVersion": showFirmwareVersion,
      "useAlarmServer": useAlarmServer,
      "allowTonesForControls": allowTonesForControls,
      "liveControlsLogWorkaround": liveControlsLogWorkaround,
      "allowMultiServerLogin": allowMultiServerLogin,
      "lerpIntensity": lerpIntensity,
      "useSeperateSliders": useSeperateSliders,
      "increaseMaxDuration": increaseMaxDuration,
      "confirmShock": confirmShock,
      "confirmShockMinIntensity": confirmShockMinIntensity,
      "confirmShockMinDuration": confirmShockMinDuration,
      "enforceHardLimitInsteadOfShock": enforceHardLimitInsteadOfShock,
      "enableUiVibrations": enableUiVibrations,
      "forceLoginV1": forceLoginV1
    };
  }
}