import 'dart:async';

import 'package:flutter/services.dart';

/// Android activity operations, isolated from the media session and its texture.
abstract interface class AndroidPlayerHost {
  Stream<AndroidPlayerEvent> get events;
  Future<void> setFullscreen(bool enabled, {required bool landscape});
  Future<void> setKeepScreenOn(bool enabled);
  Future<void> setPlaybackActive(bool enabled);
  Future<void> setPipEnabled(bool enabled);
  Future<bool> enterPip();
  Future<bool> getPipSupported();
  Future<double> getVolume();
  Future<void> setVolume(double volume);
  Future<double> getBrightness();
  Future<void> setBrightness(double brightness);
}

class AndroidPlayerEvent {
  const AndroidPlayerEvent(this.name, this.value);
  final String name;
  final Object? value;
}

class AndroidActivityPlayerHost implements AndroidPlayerHost {
  AndroidActivityPlayerHost._() {
    _channel.setMethodCallHandler((call) async {
      _events.add(AndroidPlayerEvent(call.method, call.arguments));
    });
  }
  static final instance = AndroidActivityPlayerHost._();
  static const _channel = MethodChannel('nova/android');
  final _events = StreamController<AndroidPlayerEvent>.broadcast();
  @override
  Stream<AndroidPlayerEvent> get events => _events.stream;
  @override
  Future<void> setFullscreen(bool enabled, {required bool landscape}) =>
      _channel.invokeMethod<void>('setFullscreen', {
        'enabled': enabled,
        'landscape': landscape,
      });
  @override
  Future<void> setKeepScreenOn(bool enabled) =>
      _channel.invokeMethod<void>('setKeepScreenOn', enabled);
  @override
  Future<void> setPlaybackActive(bool enabled) =>
      _channel.invokeMethod<void>('setPlaybackActive', enabled);
  @override
  Future<void> setPipEnabled(bool enabled) =>
      _channel.invokeMethod<void>('setPipEnabled', enabled);
  @override
  Future<bool> enterPip() async =>
      await _channel.invokeMethod<bool>('enterPip') ?? false;
  @override
  Future<bool> getPipSupported() async =>
      await _channel.invokeMethod<bool>('getPipSupported') ?? false;
  @override
  Future<double> getVolume() async =>
      (await _channel.invokeMethod<num>('getVolume'))?.toDouble() ?? 70;
  @override
  Future<void> setVolume(double volume) =>
      _channel.invokeMethod<void>('setVolume', volume.clamp(0, 100));
  @override
  Future<double> getBrightness() async =>
      (await _channel.invokeMethod<num>('getBrightness'))?.toDouble() ?? .5;
  @override
  Future<void> setBrightness(double brightness) =>
      _channel.invokeMethod<void>('setBrightness', brightness);
}
