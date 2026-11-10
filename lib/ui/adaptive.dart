import 'package:flutter/material.dart';

/// Screen policy is based on the available window, never on a phone model.
class NovaAdaptiveScope extends InheritedWidget {
  const NovaAdaptiveScope({
    super.key,
    required this.android,
    required super.child,
  });
  final bool android;
  static bool isAndroid(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NovaAdaptiveScope>()
          ?.android ??
      false;
  @override
  bool updateShouldNotify(NovaAdaptiveScope oldWidget) =>
      oldWidget.android != android;
}

double novaPageInset(BuildContext context) =>
    NovaAdaptiveScope.isAndroid(context)
    ? 12
    : MediaQuery.sizeOf(context).width < 600
    ? 16
    : 32;

bool novaTablet(BuildContext context) =>
    NovaAdaptiveScope.isAndroid(context) &&
    MediaQuery.sizeOf(context).width >= 600;
