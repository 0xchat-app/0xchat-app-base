import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ox_common/widgets/common_webview+nostr.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ox_common/mixin/common_js_method_mixin.dart';
import 'package:ox_common/navigator/navigator.dart';
import 'package:ox_common/utils/adapt.dart';
import 'package:ox_common/utils/theme_color.dart';
import 'package:ox_common/widgets/common_appbar.dart';
import 'package:ox_common/widgets/common_image.dart';
import 'package:ox_localizable/ox_localizable.dart';
import 'package:ox_theme/ox_theme.dart';


typedef UrlCallBack = void Function(String);

class CommonWebView extends StatefulWidget {
  final String url;
  final String? title;
  final bool hideAppbar;
  final UrlCallBack? urlCallback;

  CommonWebView(this.url,
      {this.title, this.hideAppbar = false, this.urlCallback});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return CommonWebViewState<CommonWebView>();
  }
}

class CommonWebViewState<T extends StatefulWidget> extends State<T>
    with CommonJSMethodMixin<T> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();
  late WebViewController currentController;

  get controller => _controller;

  double loadProgress = 0;
  bool showProgress = false;

  Map<String, Function> get jsMethods => {};

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // Enable hybrid composition.
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    //If you use WillPopScope on your ios model, you cannot scroll right to close
    return Platform.isAndroid
        ? WillPopScope(
            child: _root(),
            onWillPop: () async {
              WebViewController webViewController = await _controller.future;
              if (await webViewController.canGoBack()) {
                webViewController.goBack();
                return false;
              }
              return true;
            })
        : _root();
  }

  _root() {
    return Scaffold(
      appBar: !(widget as CommonWebView).hideAppbar ? _renderAppBar() : null,
      body: Builder(builder: (BuildContext context) {
        return buildBody();
      }),
    );
  }

  Widget buildBody() {
    return Column(
      children: [
        Visibility(
          visible: !(widget as CommonWebView).hideAppbar && showProgress,
          child: LinearProgressIndicator(
            value: loadProgress.toDouble(),
            minHeight: 3,
            valueColor: AlwaysStoppedAnimation(ThemeColor.red),
            backgroundColor: Colors.transparent,
          ),
        ),
        Expanded(
          child: buildWebView(),
        )
      ],
    );
  }

  Widget buildWebView() {
    return WebView(
        debuggingEnabled: kDebugMode,
        initialUrl: Uri.encodeFull(formatUrl((widget as CommonWebView).url)),
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController webViewController) {
          currentController = webViewController;
          _controller.complete(webViewController);
        },
        javascriptChannels: nostrChannels,
        onPageFinished: (url) {
          setState(() {
            showProgress = false;
          });
          currentController.runJavascript(windowNostrJavaScript);
        },
        onProgress: (process) {
          if (loadProgress != 1) {
            setState(() {
              loadProgress = process / 100;
              showProgress = true;
            });
          }
        },
        navigationDelegate: (navigationDelegate) async {
          (widget as CommonWebView).urlCallback?.call(navigationDelegate.url);
          return NavigationDecision.navigate;
        });
  }

  _renderAppBar() {
    return CommonAppBar(
      useLargeTitle: false,
      title: (widget as CommonWebView).title ?? "",
      centerTitle: true,
      leading: WebViewBackBtn(
          _controller.future,
          CommonImage(
            iconName: "icon_back.png",
            width: Adapt.px(24),
            height: Adapt.px(24),
          )),
      actions: [
        GestureDetector(
          onTap: () => OXNavigator.pop(context),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Adapt.px(18)),
            child: CommonImage(
              iconName: 'title_close.png',
              width: Adapt.px(24),
              height: Adapt.px(24),
            ),
          ),
        )
      ],
    );
  }

  String formatUrl(String url) {
    if (url.contains("?")) {
      return url +
          "&lang=${Localized.getCurrentLanguage().symbol()}&theme=${ThemeManager.getCurrentThemeStyle().value()}";
    } else {
      return url +
          "?lang=${Localized.getCurrentLanguage().symbol()}&theme=${ThemeManager.getCurrentThemeStyle().value()}";
    }
  }
}

class WebViewBackBtn extends StatelessWidget {
  final Future<WebViewController> _webViewControllerFuture;
  final Widget backIcon;

  WebViewBackBtn(this._webViewControllerFuture, this.backIcon);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return FutureBuilder<WebViewController>(
      future: _webViewControllerFuture,
      builder:
          (BuildContext context, AsyncSnapshot<WebViewController> snapshot) {
        final bool webViewReady =
            snapshot.connectionState == ConnectionState.done;
        WebViewController? controller = snapshot.data;
        return controller != null
            ? IconButton(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                icon: this.backIcon,
                onPressed: webViewReady
                    ? () async {
                        if (await controller.canGoBack()) {
                          await controller.goBack();
                        } else {
                          OXNavigator.pop(context);
                        }
                      }
                    : null,
              )
            : Container();
      },
    );
  }
}
