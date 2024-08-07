import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ox_common/utils/storage_key_tool.dart';

import 'package:ox_push/src/ox_push.dart';
import 'package:ox_common/log_util.dart';
import 'package:ox_cache_manager/ox_cache_manager.dart';
import 'constants.dart';
import 'push_picker_dialogs.dart';

class UnifiedPush {
  static Future<void> initialize({
    void Function(String endpoint, String instance)? onNewEndpoint,
    void Function(String instance)? onRegistrationFailed,
    void Function(String instance)? onUnregistered,
    void Function(Uint8List message, String instance)? onMessage,
  }) async {
    if (onNewEndpoint != null) _onNewEndpoint = onNewEndpoint;
    if (onRegistrationFailed != null) _onRegistrationFailed = onRegistrationFailed;
    if (onUnregistered != null) _onUnregistered = onUnregistered;
    if (onMessage != null) _onMessage = onMessage;

    OXPush.pushChannel.setMethodCallHandler(_methodCallHandler);
    await OXPush.pushChannel.invokeMethod(pluginEventInitialized, []);
    LogUtil.d("initializeCallback finished");
  }

  static Future<void> _methodCallHandler(MethodCall call) async {
    final instance = call.arguments["instance"] as String;
    switch (call.method) {
      case "onNewEndpoint":
        LogUtil.d("Push: --_methodCallHandler--OnNewEndpoint----instance =${instance}---endpoint =${call.arguments["endpoint"]}");
        _onNewEndpoint?.call(call.arguments["endpoint"], instance);
        break;
      case "onRegistrationFailed":
        _onRegistrationFailed?.call(instance);
        break;
      case "onUnregistered":
        _onUnregistered?.call(instance);
        break;
      case "onMessage":
        LogUtil.d("Push: --_methodCallHandler--onMessage----message =${call.arguments["message"]}");
        _onMessage?.call(call.arguments["message"], instance);
        break;
    }
  }

  static const noDistribAck = "noDistributorAck";

  static Future<void> initRegisterApp([String instance = defaultInstance, List<String>? features]) async {
    var distributor = await OXCacheManager.defaultOXCacheManager.getForeverData(StorageSettingKey.KEY_DISTRIBUTOR_NAME.name);
    if (distributor == null){
      distributor = ppnOxchat;
      await saveDistributor(distributor);
      await OXCacheManager.defaultOXCacheManager.saveForeverData(StorageSettingKey.KEY_DISTRIBUTOR_NAME.name, ppnOxchat);
    }
    await registerApp(instance = distributor, features = features);
  }

  static Future<String?> registerAppWithDialog(BuildContext context,
      [String instance = defaultInstance, List<String>? features]) async {
    String? picked;

    final distributors = await getDistributors(features);
    List<String> showDistributors = [];
    showDistributors.addAll(distributors);
    picked = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return PushPickerDialog(distributors: showDistributors,);
      },
    );
    if (picked != null ) {
      await OXCacheManager.defaultOXCacheManager.saveForeverData(StorageSettingKey.KEY_DISTRIBUTOR_NAME.name, picked);
      await saveDistributor(picked); //unable to store fake distributor —— noDistributorAck
      await registerApp(instance = picked, features = features);
    }

    return picked == null ? picked : getShowTitle(picked);
  }

  static Future<void> registerApp([String instance = defaultInstance, List<String>? features]) async {
    await OXPush.pushChannel.invokeMethod(pluginEventRegisterApplication, [instance, jsonEncode(features ?? [])]);
  }

  static Future<void> unregister([String instance = defaultInstance]) async {
    await OXPush.pushChannel.invokeMethod(pluginEventUnregister, [instance]);
  }

  static Future<List<String>> getDistributors(List<String>? features) async {
    return (await OXPush.pushChannel.invokeMethod(pluginEventGetDistributors, [jsonEncode(features ?? [])]))
        .cast<String>();
  }

  static Future<String?> getDistributor() async {
    return await OXPush.pushChannel.invokeMethod(pluginEventGetDistributor);
  }

  static Future<void> saveDistributor(String distributor) async {
    await OXPush.pushChannel.invokeMethod(pluginEventSaveDistributor, [distributor]);
  }

  static void Function(String endpoint, String instance)? _onNewEndpoint = (String e, String i) {};
  static void Function(String instance)? _onRegistrationFailed = (String i) {};
  static void Function(String instance)? _onUnregistered = (String i) {};
  static void Function(Uint8List message, String instance)? _onMessage = (Uint8List m, String i) {};
}
