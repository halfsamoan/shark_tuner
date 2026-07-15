import 'package:flutter/services.dart';

typedef AppSettingsLauncher = Future<bool> Function();

const _channel = MethodChannel('app.toauner/settings');

/// Opens the platform settings page for SharkTune.
///
/// Platform failures are reported as `false` so the permission recovery card
/// remains usable even when an adapter is temporarily unavailable.
Future<bool> openToaunerAppSettings() async {
  try {
    return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
