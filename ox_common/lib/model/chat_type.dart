///Title: chat_type
///Description: TODO(Fill in by oneself)
///Copyright: Copyright (c) 2023
///@author Michael
///CreateTime: 2023/5/18 10:57

class ChatType {
  /// 0 Chat
  static const int chatSingle = 0;

  ///1 Normal Group Chat
  static const int chatGroup = 1;

  ///2 Channel Chat
  static const int chatChannel = 2;

  ///3 Secret Chat
  static const int chatSecret = 3;

  ///4 Stranger Chat
  static const int chatStranger = 4;

  ///5 Stranger secret Chat
  static const int chatSecretStranger = 5;

  ///7 Relay Group Chat (mapping relation massageDB.chatType = 4)
  static const int chatRelayGroup = 7;

  static const int chatNotice = 6;

}
