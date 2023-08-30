import 'dart:convert';

import 'package:chatcore/chat-core.dart';
import 'package:flutter/cupertino.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:ox_cache_manager/ox_cache_manager.dart';
import 'package:ox_common/const/common_constant.dart';
import 'package:ox_common/log_util.dart';
import 'package:ox_common/utils/storage_key_tool.dart';
import 'package:ox_common/utils/ox_chat_binding.dart';
import 'package:ox_common/utils/ox_relay_manager.dart';
import 'package:ox_common/widgets/common_toast.dart';
import 'package:ox_module_service/ox_module_service.dart';

abstract class OXUserInfoObserver {
  void didLoginSuccess(UserDB? userInfo);

  void didSwitchUser(UserDB? userInfo);

  void didLogout();

  void didUpdateUserInfo() {}
}

class OXUserInfoManager {
  UserDB? currentUserInfo;

  static final OXUserInfoManager sharedInstance = OXUserInfoManager._internal();

  OXUserInfoManager._internal();

  factory OXUserInfoManager() {
    return sharedInstance;
  }

  final List<OXUserInfoObserver> _observers = <OXUserInfoObserver>[];

  final List<VoidCallback> initDataActions = [];

  bool get isLogin => (currentUserInfo != null);

  bool _initFriendsCompleted = false;
  bool _initChannelsCompleted = false;
  bool _initAllCompleted = false;

  Future initDB(String pubkey) async {
    DB.sharedInstance.deleteDBIfNeedMirgration = false;
    await DB.sharedInstance.open(pubkey + ".db", version: CommonConstant.dbVersion);
  }

  Future initLocalData() async {
    ///account auto-login
    final String? localPriv = await OXCacheManager.defaultOXCacheManager.getForeverData('PrivKey');
    final String? localPubKey = await OXCacheManager.defaultOXCacheManager.getForeverData('pubKey');
    final String? localDefaultPw = await OXCacheManager.defaultOXCacheManager.getForeverData('defaultPw');
    if (localPriv != null && localPriv.isNotEmpty) {
      OXCacheManager.defaultOXCacheManager.saveForeverData('PrivKey', null);
      OXCacheManager.defaultOXCacheManager.removeData('PrivKey');
      String? privKey = UserDB.decodePrivkey(localPriv);
      if (privKey == null || privKey.isEmpty) {
        LogUtil.e('Oxchat : Auto-login failed, please log in again.');
        return;
      }
      String pubkey = Account.getPublicKey(privKey);
      await initDB(pubkey);
      final UserDB? tempUserDB = await Account.loginWithPriKey(privKey);
      if (tempUserDB != null) {
        currentUserInfo = tempUserDB;
        _initDatas();
        await OXCacheManager.defaultOXCacheManager.saveForeverData('pubKey', tempUserDB.pubKey);
        await OXCacheManager.defaultOXCacheManager.saveForeverData('defaultPw', tempUserDB.defaultPassword);
      }
    } else if (localPubKey != null && localPubKey.isNotEmpty && localDefaultPw != null && localDefaultPw.isNotEmpty) {
      await initDB(localPubKey);
      final UserDB? tempUserDB = await Account.loginWithPubKeyAndPassword(localPubKey, localDefaultPw);
      if (tempUserDB != null) {
        currentUserInfo = tempUserDB;
        _initDatas();
      }
    } else {
      return;
    }
  }

  void addObserver(OXUserInfoObserver observer) => _observers.add(observer);

  bool removeObserver(OXUserInfoObserver observer) => _observers.remove(observer);

  Future<void> loginSuccess(UserDB userDB) async {
    OXUserInfoManager.sharedInstance.currentUserInfo = userDB;
    OXCacheManager.defaultOXCacheManager.saveForeverData('pubKey', userDB.pubKey);
    OXCacheManager.defaultOXCacheManager.saveForeverData('defaultPw', userDB.defaultPassword);
    LogUtil.e('Michael: data loginSuccess friends =${Contacts.sharedInstance.allContacts.values.toList().toString()}');
    _initDatas();
    for (OXUserInfoObserver observer in _observers) {
      observer.didLoginSuccess(currentUserInfo);
    }
  }

  void addChatCallBack() async {
    Contacts.sharedInstance.secretChatRequestCallBack = (SecretSessionDB ssDB) async {
      LogUtil.e("Michael: init secretChatRequestCallBack ssDB.sessionId =${ssDB.sessionId}");
      OXChatBinding.sharedInstance.secretChatRequestCallBack(ssDB);
    };
    Contacts.sharedInstance.secretChatAcceptCallBack = (SecretSessionDB ssDB) {
      LogUtil.e("Michael: init secretChatAcceptCallBack ssDB.sessionId =${ssDB.sessionId}");
      OXChatBinding.sharedInstance.secretChatAcceptCallBack(ssDB);
    };
    Contacts.sharedInstance.secretChatRejectCallBack = (SecretSessionDB ssDB) {
      LogUtil.e("Michael: init secretChatRejectCallBack ssDB.sessionId =${ssDB.sessionId}");
      OXChatBinding.sharedInstance.secretChatRejectCallBack(ssDB);
    };
    Contacts.sharedInstance.secretChatUpdateCallBack = (SecretSessionDB ssDB) {
      LogUtil.e("Michael: init secretChatUpdateCallBack ssDB.sessionId =${ssDB.sessionId}");
      OXChatBinding.sharedInstance.secretChatUpdateCallBack(ssDB);
    };
    Contacts.sharedInstance.secretChatCloseCallBack = (SecretSessionDB ssDB) {
      LogUtil.e("Michael: init secretChatCloseCallBack");
      OXChatBinding.sharedInstance.secretChatCloseCallBack(ssDB);
    };
    Contacts.sharedInstance.secretChatMessageCallBack = (String secretSessionId, MessageDB message) {
      LogUtil.e("Michael: init secretChatMessageCallBack secretSessionId =${secretSessionId}; message.id =${message.messageId}");
      OXChatBinding.sharedInstance.secretChatMessageCallBack(message, secretSessionId: secretSessionId);
    };
    Contacts.sharedInstance.privateChatMessageCallBack = (MessageDB message) {
      LogUtil.e("Michael: init privateChatMessageCallBack message.id =${message.messageId}");
      OXChatBinding.sharedInstance.privateChatMessageCallBack(message);
    };
    Contacts.sharedInstance.contactUpdatedCallBack = () {
      LogUtil.e("Michael: init contactUpdatedCallBack");
      OXChatBinding.sharedInstance.contactUpdatedCallBack();
      _initFriendsCompleted = true;
      if (_initChannelsCompleted && !_initAllCompleted) {
        _initMessage();
      }
    };
    Channels.sharedInstance.channelMessageCallBack = (MessageDB messageDB) async {
      LogUtil.e('Michael: init  channelMessageCallBack');
      OXChatBinding.sharedInstance.channalMessageCallBack(messageDB);
    };

    Channels.sharedInstance.myChannelsUpdatedCallBack = () async {
      LogUtil.e('Michael: init  myChannelsUpdatedCallBack');
      OXChatBinding.sharedInstance.channelsUpdatedCallBack();
      _initChannelsCompleted = true;
      if (_initFriendsCompleted && !_initAllCompleted) {
        _initMessage();
      }
    };
  }

  void updateUserInfo(UserDB userDB) {}

  void updateSuccess() {
    for (OXUserInfoObserver observer in _observers) {
      observer.didUpdateUserInfo();
    }
  }

  Future logout() async {
    if (OXUserInfoManager.sharedInstance.currentUserInfo == null || OXUserInfoManager.sharedInstance.currentUserInfo!.privkey == null) {
      return;
    }
    await Account.logout(OXUserInfoManager.sharedInstance.currentUserInfo!.privkey!);
    LogUtil.e('Michael: data logout friends =${Contacts.sharedInstance.allContacts.values.toList().toString()}');
    OXCacheManager.defaultOXCacheManager.saveForeverData('pubKey', null);
    OXCacheManager.defaultOXCacheManager.saveForeverData('defaultPw', null);
    OXUserInfoManager.sharedInstance.currentUserInfo = null;
    _initFriendsCompleted = false;
    _initChannelsCompleted = false;
    _initAllCompleted = false;
    OXChatBinding.sharedInstance.clearSession();
    for (OXUserInfoObserver observer in _observers) {
      observer.didLogout();
    }
  }

  bool isCurrentUser(String userID) {
    return userID == currentUserInfo?.pubKey;
  }

  Future<bool> setNotification() async {
    bool updateNotificatin = false;
    if (!isLogin || !_initAllCompleted) return updateNotificatin;
    String deviceId = await OXCacheManager.defaultOXCacheManager.getForeverData(StorageKeyTool.KEY_PUSH_TOKEN, defaultValue: '');
    List<dynamic> dynamicList = await OXCacheManager.defaultOXCacheManager.getForeverData(StorageKeyTool.KEY_NOTIFICATION_SWITCH, defaultValue: []);
    List<String> jsonStringList = dynamicList.cast<String>();

    ///4 private chat,  10100,10101,10102,10103 add friend logic, 42  channel message, 9735
    List<int> kinds = [4, 10100, 10101, 10102, 10103, 42, 9735];
    for (String jsonString in jsonStringList) {
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      if (jsonMap['name'] == 'Push Notifications' && !jsonMap['isSelected']) {
        kinds = [];
        break;
      }
      if (jsonMap['name'] == 'Private Messages' && !jsonMap['isSelected']) {
        kinds.remove(4);
        kinds.remove(10100);
        kinds.remove(10101);
        kinds.remove(10102);
        kinds.remove(10103);
      }
      if (jsonMap['name'] == 'Channels' && !jsonMap['isSelected']) {
        kinds.remove(42);
      }
      if (jsonMap['name'] == 'Zaps' && !jsonMap['isSelected']) {
        kinds.remove(9735);
      }
    }

    if (kinds.isNotEmpty) {
      OKEvent okEvent = await NotificationHelper.sharedInstance.setNotification(deviceId, kinds, OXRelayManager.sharedInstance.relayAddressList);
      updateNotificatin = okEvent.status;
    }
    return updateNotificatin;
  }

  void _initDatas() async {
    addChatCallBack();
    initDataActions.forEach((fn) {
      fn();
    });
    Relays.sharedInstance.init().then((value) {
      Contacts.sharedInstance.initContacts(Contacts.sharedInstance.contactUpdatedCallBack);
      Channels.sharedInstance.initWithPrivkey(currentUserInfo!.privkey!, callBack: Channels.sharedInstance.myChannelsUpdatedCallBack);
    });
    Account.syncRelaysMetadataFromRelay(currentUserInfo!.pubKey!).then((value) {
      //List<String> relays
      OXRelayManager.sharedInstance.addRelaysSuccess(value);
    });
    LogUtil.e('Michael: data await Friends Channels init friends =${Contacts.sharedInstance.allContacts.values.toList().toString()}');
  }

  void _initMessage() {
    _initAllCompleted = true;
    Messages.sharedInstance.initWithPrivkey(currentUserInfo!.privkey!);
    NotificationHelper.sharedInstance.init(OXUserInfoManager.sharedInstance.currentUserInfo?.privkey ?? '', CommonConstant.serverPubkey);
    setNotification();
    OXModuleService.invoke(
      'ox_calling',
      'initRTC',
      [],
    );
  }
}