import 'dart:convert';

import 'package:chatcore/chat-core.dart';
import 'package:ox_cache_manager/ox_cache_manager.dart';
import 'package:ox_common/const/common_constant.dart';
import 'package:ox_common/log_util.dart';
import 'package:ox_common/utils/ox_userinfo_manager.dart';
import 'package:ox_common/utils/storage_key_tool.dart';
import 'package:package_info_plus/package_info_plus.dart';

///Title: user_config_tool
///Description: TODO(about multiple user)
///Copyright: Copyright (c) 2021
///@author Michael
///CreateTime: 2023/12/18 19:11
class UserConfigTool{
  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return OXUserInfoManager.sharedInstance.settingsMap[key] ?? defaultValue;
  }

  static Future<void> saveSetting(String key, dynamic value) async {
    OXUserInfoManager.sharedInstance.settingsMap[key] = value;
    Map<String, dynamic> settingsMap = Map.from(OXUserInfoManager.sharedInstance.settingsMap);
    if (settingsMap.isNotEmpty) {
      UserDBISAR? currentUser = Account.sharedInstance.me;
      if (currentUser != null) {
        String jsonString = json.encode(settingsMap);
        currentUser.settings = jsonString;
        Account.sharedInstance.syncMe();
      }
    }
  }

  static Future<void> updateSettingFromDB(String? settings) async {
    if (settings != null && settings.isNotEmpty){
      Map<String, dynamic> loadedSettings = json.decode(settings);
      if (loadedSettings.isNotEmpty) {
        OXUserInfoManager.sharedInstance.settingsMap = loadedSettings;
      }
    }
  }

  static Future<void> compatibleOldSettings(UserDBISAR userDB) async {
    List<StorageSettingKey> settingKeyList = StorageSettingKey.values;
    String? settings = userDB.settings;
    if (settings == null){
      Map<String, dynamic> settingsMap = {};
      await Future.forEach(settingKeyList, (e) async {
        final eValue = await OXCacheManager.defaultOXCacheManager.getForeverData(e.name);
        settingsMap[e.name] = eValue;
      });
      if (settingsMap.isNotEmpty) {
        OXUserInfoManager.sharedInstance.settingsMap = settingsMap;
        defaultNotificationValue();
        await migrateSharedPreferencesData();
        UserDBISAR? currentUser = Account.sharedInstance.me;
        if (currentUser != null) {
          String jsonString = json.encode(settingsMap);
          currentUser.settings = jsonString;
          Account.sharedInstance.syncMe();
        }
      }
    }
  }

  static void defaultNotificationValue() async {
    String? jsonString = OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_NOTIFICATION_LIST.name];
    if (jsonString == null || jsonString.isEmpty){
      Map<String, Map<String, dynamic>> notificationMap = {};
      notificationMap[CommonConstant.NOTIFICATION_PUSH_NOTIFICATIONS.toString()] = { 'id': CommonConstant.NOTIFICATION_PUSH_NOTIFICATIONS, 'isSelected': true};
      notificationMap[CommonConstant.NOTIFICATION_PRIVATE_MESSAGES.toString()] = { 'id': CommonConstant.NOTIFICATION_PRIVATE_MESSAGES, 'isSelected': true};
      notificationMap[CommonConstant.NOTIFICATION_CHANNELS.toString()] = { 'id': CommonConstant.NOTIFICATION_CHANNELS, 'isSelected': true};
      notificationMap[CommonConstant.NOTIFICATION_ZAPS.toString()] = { 'id': CommonConstant.NOTIFICATION_ZAPS, 'isSelected': true};
      notificationMap[CommonConstant.NOTIFICATION_SOUND.toString()] = { 'id': CommonConstant.NOTIFICATION_SOUND, 'isSelected': true};
      notificationMap[CommonConstant.NOTIFICATION_VIBRATE.toString()] = { 'id': CommonConstant.NOTIFICATION_VIBRATE, 'isSelected': true};
      notificationMap[CommonConstant.NOTIFICATION_REACTIONS.toString()] = { 'id': CommonConstant.NOTIFICATION_REACTIONS, 'isSelected': true};
      notificationMap[CommonConstant.NOTIFICATION_REPLIES.toString()] = { 'id': CommonConstant.NOTIFICATION_REPLIES, 'isSelected': true};
      notificationMap[CommonConstant.NOTIFICATION_GROUPS.toString()] = { 'id': CommonConstant.NOTIFICATION_GROUPS, 'isSelected': true};
      OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_NOTIFICATION_LIST.name] = json.encode(notificationMap);
    }
  }

  static Future<Map<String, MultipleUserModel>> getAllUser() async {
    String? jsonString = await OXCacheManager.defaultOXCacheManager.getForeverData(StorageKeyTool.KEY_PUBKEY_LIST, defaultValue: '');

    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }

    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    LogUtil.e('Michael:---getAllUser---userMapJson =${jsonMap}');
    return jsonMap.map((key, value) => MapEntry(key, MultipleUserModel.fromJson(value)));
  }

  static Future<void> saveUser(UserDBISAR userDB) async {
    Map<String, MultipleUserModel> currentUserMap = await getAllUser();
    MultipleUserModel? userModel = currentUserMap[userDB.pubKey];
    String tempName = userDB.name ?? '';
    String saveName = tempName.isEmpty ? (userModel == null || userModel.name.isEmpty ? userDB.shortEncodedPubkey : userModel.name) : tempName;
    String tempDns = userDB.dns ?? '';
    String saveDns = tempDns.isEmpty ? (userModel == null || userModel.dns.isEmpty ? '' : userModel.dns) : tempDns;
    String? tempPic = userDB.picture ?? '';
    String savePic = tempPic.isEmpty ? (userModel == null || userModel.picture.isEmpty ? '' : userModel.picture) : tempPic;
    currentUserMap[userDB.pubKey] = MultipleUserModel(
      pubKey: userDB.pubKey,
      name: saveName,
      dns: saveDns,
      picture: savePic,
    );
    String userMapJson = json.encode(currentUserMap);
    LogUtil.e('saveUser: userMapJson =${userMapJson}');
    bool insertResult = await OXCacheManager.defaultOXCacheManager.saveForeverData(StorageKeyTool.KEY_PUBKEY_LIST, userMapJson);

  }

  static Future<void> deleteUser(Map<String, MultipleUserModel> currentUserMap, String pubkey) async {
    currentUserMap.remove(pubkey);
    String userMapJson = json.encode(currentUserMap);
    bool insertResult = await OXCacheManager.defaultOXCacheManager.saveForeverData(StorageKeyTool.KEY_PUBKEY_LIST, userMapJson);
  }

  static Future<void> compatibleOld(UserDBISAR userDB) async {
    String? jsonString = await OXCacheManager.defaultOXCacheManager.getForeverData(StorageKeyTool.KEY_PUBKEY_LIST, defaultValue: '');
    if (jsonString == null || jsonString.isEmpty) {
      saveUser(userDB);
      compatibleOldSettings(userDB);
    }
  }
  static compatibleOldAmberStatus(String localPubKey) async {
    final bool? localIsLoginAmber = await OXCacheManager.defaultOXCacheManager.getForeverData(StorageKeyTool.KEY_IS_LOGIN_AMBER);
    if (localPubKey.isNotEmpty && localIsLoginAmber != null && localIsLoginAmber) {
      await OXCacheManager.defaultOXCacheManager.saveForeverData('${localPubKey}${StorageKeyTool.KEY_IS_LOGIN_AMBER}', localIsLoginAmber);
      await OXCacheManager.defaultOXCacheManager.saveForeverData(StorageKeyTool.KEY_IS_LOGIN_AMBER, false);
    }
  }

  static migrateSharedPreferencesData() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final migrationTargetVersion = "1.3.1";
    if (compareVersion(currentVersion, migrationTargetVersion) != 0) return;

    bool migrationCompleted = await OXCacheManager.defaultOXCacheManager.getForeverData('migration_completed') ?? false;
    try {
      if (!migrationCompleted) {
        String? pubKey = OXUserInfoManager.sharedInstance.currentUserInfo?.pubKey;
        if (pubKey == null) return;
        final results = await Future.wait([
          OXCacheManager.defaultOXCacheManager.getForeverData('$pubKey.isShowWalletSelector', defaultValue: true),
          OXCacheManager.defaultOXCacheManager.getForeverData('$pubKey.defaultWallet'),
          OXCacheManager.defaultOXCacheManager.getForeverData('${pubKey}_defaultZapAmount'),
          OXCacheManager.defaultOXCacheManager.getForeverData('${pubKey}_${StorageSettingKey.KEY_DEFAULT_ZAP_DESCRIPTION.name}'),
          OXCacheManager.defaultOXCacheManager.getData(StorageSettingKey.KEY_ICE_SERVER.name, defaultValue: ''),
          OXCacheManager.defaultOXCacheManager.getForeverData(StorageSettingKey.KEY_FILE_STORAGE_SERVER.name, defaultValue: ''),
          OXCacheManager.defaultOXCacheManager.getForeverData(StorageSettingKey.KEY_FILE_STORAGE_SERVER_INDEX.name, defaultValue: 0),
        ]);

        OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_IS_SHOW_WALLET_SELECTOR.name] = results[0];
        OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_DEFAULT_WALLET.name] = results[1];
        OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_DEFAULT_ZAP_AMOUNT.name] = results[2];
        OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_DEFAULT_ZAP_DESCRIPTION.name] = results[3];
        OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_ICE_SERVER.name] = results[4];
        OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_FILE_STORAGE_SERVER.name] = results[5];
        OXUserInfoManager.sharedInstance.settingsMap[StorageSettingKey.KEY_FILE_STORAGE_SERVER_INDEX.name] = results[6];

        await OXCacheManager.defaultOXCacheManager.saveForeverData('migration_completed', true);
      }
    } catch (e) {
      LogUtil.e('Migrate Shared Preferences Data Failed');
    }
  }

  static int compareVersion(String version1, String version2) {
    int v1 = int.parse(version1.replaceAll('.', ''));
    int v2 = int.parse(version2.replaceAll('.', ''));
    return v1.compareTo(v2);
  }
}

class MultipleUserModel{
  String pubKey;
  String name;
  String picture;
  String dns;

  MultipleUserModel({this.pubKey = '', this.name = '', this.picture = '', this.dns = ''});

  factory MultipleUserModel.fromJson(Map<String, dynamic> json) {
    return MultipleUserModel(
      pubKey: json['pubKey'],
      name: json['name'] ?? '',
      picture: json['picture'] ?? '',
      dns: json['dns'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pubKey': pubKey,
      'name': name,
      'picture': picture,
      'dns': dns,
    };
  }
}
