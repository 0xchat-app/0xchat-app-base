
import 'dart:io';

import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_localizable/ox_localizable.dart';

///Title: permission_utils
///Copyright: Copyright (c) 2018
///CreateTime: 2021-4-24 14:40
///@author john
///@CheckItem Fill in by oneself
///@since Dart 2.3

class PermissionUtils{
 
  static void showPermission(BuildContext? context, Map<Permission, PermissionStatus> permissionMap){
    if(permissionMap.containsKey(Permission.storage) && !permissionMap[Permission.storage]!.isGranted && permissionMap.containsKey(Permission.camera) && !permissionMap[Permission.camera]!.isGranted && permissionMap.containsKey(Permission.microphone) && !permissionMap[Permission.microphone]!.isGranted){
      CommonToast.instance.show(context, Localized.text('ox_common.permiss_storage_camera_microphone_refuse'));
    }else if(permissionMap.containsKey(Permission.storage) && !permissionMap[Permission.storage]!.isGranted && permissionMap.containsKey(Permission.camera) && !permissionMap[Permission.camera]!.isGranted) {
      CommonToast.instance.show(context,Localized.text('ox_common.permiss_storage_camera_refuse'));
    }else if(permissionMap.containsKey(Permission.storage) && !permissionMap[Permission.storage]!.isGranted && permissionMap.containsKey(Permission.microphone) && !permissionMap[Permission.microphone]!.isGranted) {
      CommonToast.instance.show(context,Localized.text('ox_common.permiss_storage_microphone_refuse'));
    }else if(permissionMap.containsKey(Permission.camera) && !permissionMap[Permission.camera]!.isGranted && permissionMap.containsKey(Permission.microphone) && !permissionMap[Permission.microphone]!.isGranted) {
      CommonToast.instance.show(context,Localized.text('ox_common.permiss_camera_microphone_refuse'));
    }else if(permissionMap.containsKey(Permission.storage) && !permissionMap[Permission.storage]!.isGranted){
      CommonToast.instance.show(context,Localized.text('ox_common.permiss_storage_refuse'));
    }else if(permissionMap.containsKey(Permission.camera) && !permissionMap[Permission.camera]!.isGranted){
      CommonToast.instance.show(context,Localized.text('ox_common.permiss_camera_refuse'));
    }else if(permissionMap.containsKey(Permission.microphone) && !permissionMap[Permission.microphone]!.isGranted){
      CommonToast.instance.show(context,Localized.text('ox_common.permiss_microphone_refuse'));
    }
  }

  static Future<bool> getPhotosPermission() async {
    DeviceInfoPlugin plugin = DeviceInfoPlugin();
    bool permissionGranted = false;
    if (Platform.isAndroid && (await plugin.androidInfo).version.sdkInt < 33) {
      if (await Permission.storage.request().isGranted) {
        permissionGranted = true;
      } else if (await Permission.storage.request().isPermanentlyDenied) {
        await openAppSettings();
      } else if (await Permission.audio.request().isDenied) {
        permissionGranted = false;
      }
    } else {
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) {
        permissionGranted = true;
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      } else if (status.isDenied) {
        permissionGranted = false;
      }
    }
    return permissionGranted;
  }
}