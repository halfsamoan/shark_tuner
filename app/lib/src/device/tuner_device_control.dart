import 'package:flutter/services.dart';

typedef ScreenAwakeSetter = Future<bool> Function(bool enabled);

const _channel = MethodChannel('app.toauner/device');

/// Keeps the display awake while the live tuner is visible.
///
/// Failures remain non-fatal because tuning must still work on a platform
/// adapter that has not implemented this convenience yet.
Future<bool> setToaunerScreenAwake(bool enabled) async {
  try {
    return await _channel.invokeMethod<bool>('setScreenAwake', {
          'enabled': enabled,
        }) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
