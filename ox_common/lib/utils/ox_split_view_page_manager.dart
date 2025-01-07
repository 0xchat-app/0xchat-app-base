import 'package:flutter/material.dart';

class OXClientPageManager {
  static final OXClientPageManager sharedInstance =
      OXClientPageManager._internal();

  factory OXClientPageManager() {
    return sharedInstance;
  }

  OXClientPageManager._internal();

  final List<Widget Function(BuildContext? context)> _pages = [];
  final ValueNotifier<Widget Function(BuildContext? context)?> currentPage = ValueNotifier(null);

  void pushPage(Widget Function(BuildContext? context) builder) {
    // if(isPageAlreadyPushed(page)) return;
    _pages.add(builder);
    getCurrentPage();
  }

  bool isPageAlreadyPushed(Widget widget) {
    return _pages.last.runtimeType == widget.runtimeType;
  }

  void getCurrentPage() {
    if (_pages.isNotEmpty) {
      currentPage.value = _pages.last;
    } else {
      currentPage.value = null;
    }
  }

  void clearPages() {
    _pages.clear();
  }

  void popPages() {
    _pages.removeLast();
    getCurrentPage();
  }

  bool get isEmpty => _pages.isEmpty;
}
