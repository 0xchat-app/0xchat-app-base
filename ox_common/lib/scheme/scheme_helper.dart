

import '../const/common_constant.dart';
import '../log_util.dart';
import '../ox_common.dart';

typedef SchemeHandler = Function(String uri, String action, Map<String, String> queryParameters);

class SchemeHelper {

  static SchemeHandler? defaultHandler;
  static Map<String, SchemeHandler> schemeAction = {};

  static register(String action, SchemeHandler handler) {
    schemeAction[action.toLowerCase()] = handler;
  }

  static tryHandlerForOpenAppScheme() async {
    String url = await OXCommon.channelPreferences.invokeMethod(
      'getAppOpenURL',
    );
    LogUtil.d("App open URL: $url");

    handleAppURI(url);
  }

  static handleAppURI(String uri) async {
    if (uri.isEmpty) return ;

    String action = '';
    Map<String, String> query = <String, String>{};

    try {
      final uriObj = Uri.parse(uri);
      if (uriObj.scheme != CommonConstant.APP_SCHEME) return ;

      action = uriObj.host.toLowerCase();
      query = uriObj.queryParameters;
    } catch (_) {
      final appScheme = '${CommonConstant.APP_SCHEME}://';
      if (uri.startsWith(appScheme)) {
        action = uri.replaceFirst(appScheme, '');
        uri = appScheme;
      }
    }

    final handler = schemeAction[action];
    if (handler != null) {
      handler(uri, action, query);
      return;
    }

    defaultHandler?.call(uri, action, query);
  }
}