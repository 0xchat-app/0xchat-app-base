
enum CustomMessageType {
  zaps,
  call,
}

extension CustomMessageTypeEx on CustomMessageType {
  String get value {
    switch (this) {
      case CustomMessageType.zaps:
        return '1';
      case CustomMessageType.call:
        return '2';
      default:
        return '-1';
    }
  }

  static CustomMessageType? fromValue(dynamic value) {
    try {
      return CustomMessageType.values.firstWhere((e) => e.value == value);
    } catch(e) {
      return null;
    }
  }
}