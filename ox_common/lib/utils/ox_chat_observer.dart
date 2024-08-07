import 'package:chatcore/chat-core.dart';
import 'package:ox_cache_manager/ox_cache_manager.dart';
import 'package:ox_common/utils/ox_chat_binding.dart';
import 'package:ox_common/utils/ox_userinfo_manager.dart';
import 'package:ox_common/utils/storage_key_tool.dart';

///Title: ox_chat_observer
///Description: TODO(Fill in by oneself)
///Copyright: Copyright (c) 2021
///@author Michael
///CreateTime: 2023/10/9 19:28
abstract mixin class OXChatObserver {
  void didSecretChatRequestCallBack() {}

  void didPrivateMessageCallBack(MessageDBISAR message) {}

  void didPrivateChatMessageUpdateCallBack(MessageDBISAR message, String replacedMessageId) {}

  void didSecretChatAcceptCallBack(SecretSessionDBISAR ssDB) {}

  void didSecretChatRejectCallBack(SecretSessionDBISAR ssDB) {}

  void didSecretChatCloseCallBack(SecretSessionDBISAR ssDB) {}

  void didSecretChatUpdateCallBack(SecretSessionDBISAR ssDB) {}

  void didContactUpdatedCallBack() {}

  void didCreateChannel(ChannelDBISAR? channelDB) {}

  void didDeleteChannel(ChannelDBISAR? channelDB) {}

  void didChannalMessageCallBack(MessageDBISAR message) {}

  void didGroupMessageCallBack(MessageDBISAR message) {}

  void didRelayGroupJoinReqCallBack(JoinRequestDBISAR joinRequestDB) {}

  void didRelayGroupModerationCallBack(ModerationDBISAR moderationDB) {}

  void didMessageActionsCallBack(MessageDBISAR message) {}

  void didChannelsUpdatedCallBack() {}

  void didGroupsUpdatedCallBack() {}

  void didRelayGroupsUpdatedCallBack() {}

  void didSessionUpdate() {}

  void didSecretChatMessageCallBack(MessageDBISAR message) {}

  void didPromptToneCallBack(MessageDBISAR message, int type) {}

  void didZapRecordsCallBack(ZapRecordsDBISAR zapRecordsDB) {
    final pubKey = OXUserInfoManager.sharedInstance.currentUserInfo?.pubKey ?? '';
    OXCacheManager.defaultOXCacheManager.saveData('$pubKey${StorageSettingKey.KEY_ZAP_BADGE.name}', true);
    OXChatBinding.sharedInstance.isZapBadge = true;
  }

  void didOfflinePrivateMessageFinishCallBack() {}
  void didOfflineSecretMessageFinishCallBack() {}
  void didOfflineChannelMessageFinishCallBack() {}
}