const Map<String, Map<String, List<String>>> flutterErrors = {
  'package:flutter/src/animation/animation_controller.dart': {
    'AnimationController.animateWith': ['TickerCanceled'],
    'AnimationController.stop': ['TickerCanceled'],
    'AnimationController.value': ['TickerCanceled'],
  },
  'package:flutter/src/animation/curves.dart': {
    'Cubic.transformInternal': ['ArgumentError'],
    'ParametricCurve.transformInternal': ['UnimplementedError'],
  },
  'package:flutter/src/animation/tween_sequence.dart': {
    'TweenSequence.transform': ['StateError'],
  },
  'package:flutter/src/cupertino/interface_level.dart': {
    'CupertinoUserInterfaceLevel.of': ['FlutterError'],
  },
  'package:flutter/src/foundation/basic_types.dart': {
    'CachingIterable.elementAt': ['IndexError'],
  },
  'package:flutter/src/foundation/binding.dart': {
    'BindingBase.debugCheckZone': ['AssertionError'],
  },
  'package:flutter/src/foundation/collections.dart': {
    'mergeSort': ['TypeError'],
  },
  'package:flutter/src/foundation/diagnostics.dart': {
    'DiagnosticsNode.toTimelineArguments': ['FlutterError'],
  },
  'package:flutter/src/foundation/platform.dart': {
    'debugDefaultTargetPlatformOverride': ['FlutterError'],
  },
  'package:flutter/src/foundation/serialization.dart': {
    'WriteBuffer.done': ['StateError'],
  },
  'package:flutter/src/foundation/timeline.dart': {
    'FlutterTimeline.debugCollect': ['StateError'],
    'FlutterTimeline.debugCollectionEnabled': ['StateError'],
    'FlutterTimeline.debugReset': ['StateError'],
  },
  'package:flutter/src/gestures/pointer_router.dart': {
    'PointerRouter.debugGlobalRouteCount': ['UnsupportedError'],
  },
  'package:flutter/src/material/input_decorator.dart': {
    'InputDecoration.applyDefaults': ['ArgumentError'],
  },
  'package:flutter/src/material/material_localizations.dart': {
    'DefaultMaterialLocalizations.formatHour': ['AssertionError'],
  },
  'package:flutter/src/material/scaffold.dart': {
    'Scaffold.geometryOf': ['FlutterError'],
    'Scaffold.of': ['FlutterError'],
    'ScaffoldMessengerState.showSnackBar': ['Object'],
  },
  'package:flutter/src/material/theme_data.dart': {
    'ThemeData.copyWith': ['ArgumentError'],
    'ThemeData.new': ['ArgumentError'],
  },
  'package:flutter/src/painting/decoration.dart': {
    'Decoration.getClipPath': ['UnsupportedError'],
  },
  'package:flutter/src/painting/image_cache.dart': {
    'ImageCache.putIfAbsent': ['Object'],
  },
  'package:flutter/src/painting/image_stream.dart': {
    'ImageStreamCompleter.reportError': ['FlutterError'],
  },
  'package:flutter/src/painting/text_painter.dart': {
    'TextPainter.debugDisposed': ['StateError'],
    'TextPainter.layout': ['StateError'],
    'TextPainter.paint': ['StateError'],
  },
  'package:flutter/src/rendering/box.dart': {
    'RenderBox.debugCannotComputeDryLayout': ['FlutterError'],
    'RenderBox.size': ['StateError'],
  },
  'package:flutter/src/rendering/object.dart': {
    'RenderObject.constraints': ['StateError'],
    'RenderObject.getTransformTo': ['FlutterError'],
  },
  'package:flutter/src/rendering/view.dart': {
    'RenderView.constraints': ['StateError'],
  },
  'package:flutter/src/scheduler/binding.dart': {
    'SchedulerBinding.debugAssertNoPendingPerformanceModeRequests': [
      'FlutterError',
    ],
    'SchedulerBinding.debugAssertNoTimeDilation': ['FlutterError'],
  },
  'package:flutter/src/services/asset_bundle.dart': {
    'NetworkAssetBundle.load': ['FlutterError'],
    'PlatformAssetBundle.load': ['FlutterError'],
    'PlatformAssetBundle.loadBuffer': ['FlutterError'],
  },
  'package:flutter/src/services/font_loader.dart': {
    'FontLoader.addFont': ['StateError'],
    'FontLoader.load': ['StateError'],
  },
  'package:flutter/src/services/message_codec.dart': {
    'MethodCodec.decodeEnvelope': ['PlatformException'],
  },
  'package:flutter/src/services/message_codecs.dart': {
    'JSONMethodCodec.decodeEnvelope': ['FormatException', 'PlatformException'],
    'JSONMethodCodec.decodeMethodCall': ['FormatException'],
    'StandardMessageCodec.decodeMessage': ['FormatException'],
    'StandardMessageCodec.readValue': ['FormatException'],
    'StandardMessageCodec.readValueOfType': ['FormatException'],
    'StandardMessageCodec.writeValue': ['ArgumentError'],
    'StandardMethodCodec.decodeEnvelope': [
      'FormatException',
      'PlatformException',
    ],
    'StandardMethodCodec.decodeMethodCall': ['FormatException'],
  },
  'package:flutter/src/services/platform_channel.dart': {
    'MethodChannel.invokeMethod': ['TypeError'],
    'MethodChannel.setMethodCallHandler': [
      'MissingPluginException',
      'PlatformException',
    ],
  },
  'package:flutter/src/services/platform_views.dart': {
    'AndroidViewController.dispatchPointerEvent': ['AssertionError'],
  },
  'package:flutter/src/services/raw_keyboard.dart': {
    'RawKeyEvent.fromMessage': ['FlutterError'],
  },
  'package:flutter/src/services/raw_keyboard_linux.dart': {
    'KeyHelper.new': ['FlutterError'],
  },
  'package:flutter/src/services/scribe.dart': {
    'Scribe.isFeatureAvailable': ['FlutterError'],
    'Scribe.isStylusHandwritingAvailable': [
      'FlutterError',
      'PlatformException',
    ],
  },
  'package:flutter/src/services/sensitive_content.dart': {
    'SensitiveContentService.getContentSensitivity': ['UnsupportedError'],
  },
  'package:flutter/src/widgets/async.dart': {
    'AsyncSnapshot.requireData': ['StateError'],
  },
  'package:flutter/src/widgets/basic.dart': {
    'Directionality.of': ['FlutterError'],
  },
  'package:flutter/src/widgets/binding.dart': {
    'WidgetsBinding.windowingOwner': ['UnsupportedError'],
    'WidgetsBinding.wrapWithDefaultView': ['StateError'],
  },
  'package:flutter/src/widgets/editable_text.dart': {
    'TextEditingController.selection': ['FlutterError'],
  },
  'package:flutter/src/widgets/focus_traversal.dart': {
    'FocusTraversalGroup.of': ['FlutterError'],
  },
  'package:flutter/src/widgets/framework.dart': {
    'Element.inflateWidget': ['Object'],
    'ParentDataElement.debugParentDataType': ['UnsupportedError'],
  },
  'package:flutter/src/widgets/list_wheel_scroll_view.dart': {
    'FixedExtentScrollController.selectedItem': ['AssertionError'],
  },
  'package:flutter/src/widgets/media_query.dart': {
    'MediaQuery.of': ['FlutterError', 'TypeError'],
  },
  'package:flutter/src/widgets/navigator.dart': {
    'Navigator.of': ['FlutterError'],
  },
  'package:flutter/src/widgets/page_view.dart': {
    'PageController.page': ['AssertionError'],
  },
  'package:flutter/src/widgets/router.dart': {
    'RouteInformationParser.parseRouteInformation': ['UnimplementedError'],
  },
  'package:flutter/src/widgets/selectable_region.dart': {
    'SelectionListenerNotifier.selection': ['Exception'],
  },
  'package:flutter/src/widgets/sliver.dart': {
    'KeepAlive.debugTypicalAncestorWidgetClass': ['FlutterError'],
    'SliverMultiBoxAdaptorElement.childCount': ['FlutterError'],
  },
  'package:flutter/src/widgets/sliver_tree.dart': {
    'TreeSliverController.of': ['FlutterError'],
  },
  'package:flutter/src/widgets/two_dimensional_viewport.dart': {
    'RenderTwoDimensionalViewport.computeAbsolutePaintOffsetFor': ['Exception'],
  },
  'package:flutter/src/widgets/widget_inspector.dart': {
    'WidgetInspectorService.disposeId': ['FlutterError'],
    'WidgetInspectorService.toObject': ['FlutterError'],
  },
  'package:flutter/src/widgets/widget_state.dart': {
    'WidgetStateMapper.noSuchMethod': ['FlutterError'],
    'WidgetStateMapper.resolve': ['ArgumentError'],
    'WidgetStateProperty.fromMap': ['ArgumentError'],
  },
};
