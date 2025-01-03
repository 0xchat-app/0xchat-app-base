import 'package:flutter/material.dart';

class OXClientPageManager {
  static final OXClientPageManager sharedInstance =
      OXClientPageManager._internal();

  factory OXClientPageManager() {
    return sharedInstance;
  }

  OXClientPageManager._internal();

  final List<Widget> _pages = [];
  final ValueNotifier<Widget?> currentPage = ValueNotifier(null);

  void pushPage(Widget page) {
    print('==page==$page');
    // if(isPageAlreadyPushed(page)) return;
    _pages.add(page);
    getCurrentPage();
  }

  bool isPageAlreadyPushed(Widget widget) {
    return _pages.last.runtimeType == widget.runtimeType;
  }

  void getCurrentPage() {
    print('=====hwx');
    print('===_pages==${_pages}');
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
