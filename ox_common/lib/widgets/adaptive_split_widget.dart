// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
// import 'package:ox_common/navigator/navigator.dart';
// import 'package:ox_common/utils/platform_utils.dart';
//
// import '../utils/ox_split_view_page_manager.dart';
//
// class AdaptiveSplitWidget extends StatefulWidget {
//   final Widget navigationList;
//   final ValueNotifier<Widget?> selectedContent;
//   final void Function(BuildContext context, dynamic item)? onSelectItem;
//
//   AdaptiveSplitWidget({
//     Key? key,
//     required this.navigationList,
//     required this.selectedContent,
//     this.onSelectItem,
//   }) : super(key: key);
//
//   @override
//   State<AdaptiveSplitWidget> createState() => _AdaptiveSplitWidgetState();
// }
//
// class _AdaptiveSplitWidgetState extends State<AdaptiveSplitWidget> {
//   Size? _lastSize;
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _startListeningWindowResize();
//     });
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//   }
//
//
//   void didUpdateWidget(covariant AdaptiveSplitWidget oldWidget) {
//     super.didUpdateWidget(oldWidget);
//
//   }
//
//   void _startListeningWindowResize() {
//     WidgetsBinding.instance.addPersistentFrameCallback((_) {
//       final newSize = MediaQuery.of(context).size;
//       if (_lastSize == null || newSize != _lastSize) {
//
//         if(_lastSize != null && _lastSize!.width < PlatformUtils.listWidth && newSize.width > PlatformUtils.listWidth){
//           // print('==OXNavigator.routeObserver.navigator!.context====${OXNavigator.pages}');
//           if(getPopablePageCount(context) > 1){
//             OXClientPageManager.sharedInstance.pushPage(OXNavigator.routeObserver.navigator!.widget);
//             OXNavigator.pop(OXNavigator.routeObserver.navigator!.context);
//             print('=====>>>>1111');
//           }
//
//         }
//         _lastSize = newSize;
//         setState(() {});
//       }
//     });
//   }
//
//   int getPopablePageCount(BuildContext context) {
//     int count = 0;
//     while (Navigator.of(context).canPop()) {
//       count++;
//       Navigator.of(context).pop();
//     }
//     return count;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         print('========constraints===$constraints');
//        return _bodyView(constraints);
//       },
//     );
//   }
//
//   Widget _bodyView(BoxConstraints constraints) {
//     print('===constraints.maxWidth==${constraints.maxWidth}');
//     final isWideScreen = constraints.maxWidth > PlatformUtils.listWidth;
//     if (!isWideScreen) {
//       return widget.navigationList;
//     }
//
//     return Row(
//       children: [
//       Container(
//       width: PlatformUtils.listWidth,
//       child: widget.navigationList,
//     ),
//
//         ValueListenableBuilder(
//             valueListenable: OXClientPageManager.sharedInstance.currentPage,
//             builder: (BuildContext context, messages, Widget? child){
//               print('=====>>>$messages');
//           return Expanded(
//             flex: 2,
//             child: messages ??
//                 Center(
//                   child: Text(
//                     'Select an item',
//                     style: TextStyle(
//                       fontSize: 18,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ),
//           );
//         }),
//       ],
//     );
//   }
// }
