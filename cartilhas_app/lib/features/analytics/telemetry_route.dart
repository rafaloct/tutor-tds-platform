import 'package:flutter/material.dart';

import 'app_telemetry_service.dart';

class TelemetryRouteData {
  const TelemetryRouteData({
    required this.pageId,
    this.courseId = AppTelemetryService.applicationCourseId,
    this.resourceId,
    this.featureId,
  });

  final String pageId;
  final String courseId;
  final String? resourceId;
  final String? featureId;
}

MaterialPageRoute<T> trackedRoute<T>({
  required WidgetBuilder builder,
  required String pageId,
  String courseId = AppTelemetryService.applicationCourseId,
  String? resourceId,
  String? featureId,
}) => MaterialPageRoute<T>(
  builder: builder,
  settings: RouteSettings(
    name: '/$pageId',
    arguments: TelemetryRouteData(
      pageId: pageId,
      courseId: courseId,
      resourceId: resourceId,
      featureId: featureId,
    ),
  ),
);

class TelemetryNavigatorObserver extends NavigatorObserver {
  TelemetryNavigatorObserver(this.telemetry);

  final AppTelemetryService telemetry;
  Future<void> _trackingTail = Future<void>.value();

  @visibleForTesting
  Future<void> get settled => _trackingTail;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _track(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _track(previousRoute, includeAccessEvents: false);
    }
  }

  void _track(Route<dynamic> route, {bool includeAccessEvents = true}) {
    final data = route.settings.arguments;
    if (data is TelemetryRouteData) {
      _enqueue(
        () => telemetry.trackPage(
          pageId: data.pageId,
          courseId: data.courseId,
          resourceId: data.resourceId,
          featureId: data.featureId,
          includeAccessEvents: includeAccessEvents,
        ),
      );
      return;
    }
    if (route.settings.name == '/') {
      _enqueue(() => telemetry.trackPage(pageId: 'welcome'));
    }
  }

  void _enqueue(Future<int> Function() operation) {
    _trackingTail = _trackingTail
        .then((_) => operation())
        .then<void>((_) {})
        .onError((_, _) {});
  }
}
