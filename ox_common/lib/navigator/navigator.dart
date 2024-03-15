import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ox_common/navigator/page_router.dart';

enum OXPushPageType {
  slideToLeft,
  noAnimation,
  transparent,
}

enum OXStackPageOption {
  reset,
  push,
  pop,
  replace
}

class OXNavigator extends Navigator {

  static final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

  static List<NavigatorObserver> observer = [];

  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  @optionalTypeArgs
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    // Remove the current focus
    FocusScope.of(context).requestFocus(FocusNode());
    if (canPop(context)) {
      Navigator.pop(context, result);
    } else {
      SystemNavigator.pop();
    }
  }

  /// Flutter stack
  static void popToRoot<T extends Object>(BuildContext context) {
    // Remove the current focus
    FocusScope.of(context).requestFocus(FocusNode());
    if (canPop(context)) {
      Navigator.popUntil(context, (Route<dynamic> route) {
        return route.isFirst;
      });
    }
  }

  /// Pop to a specific page (currently only supported within the Flutter stack)
  /// pageType: The 'runtimeType.toString' of the page, which is used to simply specify the pop of the page
  /// pageId: Specified pageId, used for more complex navigation pops to a designated page. The pageId is generated by the designated page itself
  static void popToPage<T extends Object>(BuildContext context,
      {String? pageType, Object? pageId, isPrepage = false}) {
    assert(() {
      if (pageType == null && pageId == null) {
        throw FlutterError('The OXNavigator.popToPage method requires at least one of the parameters: pageType or pageId.');
      }
      return true;
    }());
    // Remove the current focus
    FocusScope.of(context).requestFocus(FocusNode());
    bool isFindPage = false;
    int prepage = 0;
    Navigator.popUntil(context, (Route<dynamic> route) {
      bool checkPageType = true;
      if (pageType != null && !isFindPage) {
        checkPageType = route.settings.name == pageType;
        isFindPage = checkPageType;
      }
      bool checkPageId = true;
      if (pageId != null && !isFindPage) {
        checkPageId = route.settings.arguments == pageId;
        isFindPage = checkPageId;
      }
      final bool isTargetPage = isPrepage ? (prepage == 1) && (checkPageType && checkPageId) : checkPageType && checkPageId;
      if (isFindPage) {
        prepage = 1;
      }
      return isTargetPage || route.isFirst;
    });
  }

  static void close(BuildContext context) {
    // Remove the current focus
    FocusScope.of(context).requestFocus(FocusNode());
    SystemNavigator.pop();
  }

  @optionalTypeArgs
  static Future<T?> push<T extends Object?>(
      BuildContext context, Route<T> route) {
    // // Remove the current focus
    // FocusScope.of(context).requestFocus(FocusNode());
    return Navigator.push<T>(context, route);
  }

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
      BuildContext context, Widget page,
      {TO? result}) {
    return Navigator.pushReplacement<T, TO>(
      context,
      generalPageRouter(builder: (_) => page),
      result: result,
    );
  }

  static replace<T extends Object?, TO extends Object?>(
      BuildContext context, Widget page,
      {TO? result}) {
    return Navigator.pushReplacement<T, TO>(context,
      generalPageRouter(
        builder: (_) => page,
        pageName: page.runtimeType.toString(),
      ),
      result: result
    );
  }

  @optionalTypeArgs
  static Future<T?> pushPage<T extends Object?>(
      BuildContext? context,
      Widget Function(BuildContext? context) builder, {
        String? pageName,
        Object? pageId,
        bool fullscreenDialog = false,
        OXPushPageType type = OXPushPageType.slideToLeft,
      }) {
    pageName ??= builder(null).runtimeType.toString();
    context ??= navigatorKey.currentContext;
    if (context == null) return Future.value(null);

    final routeSettings = RouteSettings(
      name: pageName,
      arguments: pageId,
    );
    PageRoute<T> route;

    switch (type) {
      case OXPushPageType.slideToLeft:
        route = SlideLeftToRightRoute<T>(
          fullscreenDialog: fullscreenDialog,
          settings: routeSettings,
          builder: builder,
        );
      case OXPushPageType.noAnimation:
        route = NoAnimationPageRoute<T>(
          builder: builder,
          settings: routeSettings,
        );
      case OXPushPageType.transparent:
        route = TransparentPageRoute<T>(
          builder: builder,
          settings: routeSettings,
        );
    }

    return OXNavigator.push(
      context,
      route,
    );
  }

  static Future<T?> presentPage<T extends Object?>(
      BuildContext? context,
      Widget Function(BuildContext? context) builder, {
        String? pageName,
        Object? pageId,
        bool fullscreenDialog = false,
        bool allowPageScroll = false,
      }) {
    context ??= navigatorKey.currentContext;
    if (context == null) return Future.value(null);

    pageName ??= builder(null).runtimeType.toString();
    if (fullscreenDialog) {
      return OXNavigator.push(
        context,
        generalPageRouter<T>(
          builder: builder,
          pageName: pageName,
          pageId: pageId,
          fullscreenDialog: true,
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: !allowPageScroll,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) =>
            Container(
              height: MediaQuery.of(context).size.height * 0.9,
              child: builder(context),
            ),
      );
    }
  }

  static PageRoute<T> generalPageRouter<T>({
    required Widget Function(BuildContext? context) builder,
    String? pageName,
    Object? pageId,
    fullscreenDialog = false,
  }) {
    return SlideLeftToRightRoute<T>(
      fullscreenDialog: fullscreenDialog,
      settings: RouteSettings(
        name: pageName,
        arguments: pageId,
      ),
      builder: builder,
    );
  }
}
