import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'instrument_theme.dart';

enum TunerToleranceMode { beginner, pro }

extension TunerToleranceModeValues on TunerToleranceMode {
  String get label => switch (this) {
    TunerToleranceMode.beginner => '초보',
    TunerToleranceMode.pro => '프로',
  };

  double get holdToleranceCents => switch (this) {
    TunerToleranceMode.beginner => 5,
    TunerToleranceMode.pro => 2,
  };
}

@immutable
final class AppPreferences {
  const AppPreferences({
    this.themeId = SharkTuneThemeId.abyss,
    this.toleranceMode = TunerToleranceMode.beginner,
    this.hapticsEnabled = true,
    this.reduceMotion = false,
    this.hasSeenTunerPrimer = false,
    this.recentSearches = const [],
  });

  final SharkTuneThemeId themeId;
  final TunerToleranceMode toleranceMode;
  final bool hapticsEnabled;
  final bool reduceMotion;
  final bool hasSeenTunerPrimer;
  final List<String> recentSearches;

  AppPreferences copyWith({
    SharkTuneThemeId? themeId,
    TunerToleranceMode? toleranceMode,
    bool? hapticsEnabled,
    bool? reduceMotion,
    bool? hasSeenTunerPrimer,
    List<String>? recentSearches,
  }) {
    return AppPreferences(
      themeId: themeId ?? this.themeId,
      toleranceMode: toleranceMode ?? this.toleranceMode,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hasSeenTunerPrimer: hasSeenTunerPrimer ?? this.hasSeenTunerPrimer,
      recentSearches: List.unmodifiable(recentSearches ?? this.recentSearches),
    );
  }
}

typedef AppPreferencesSaver = Future<void> Function(AppPreferences value);
typedef AppPreferencesDirectoryProvider = Future<Directory> Function();

const _schemaVersion = 1;
const _fileName = 'app-preferences.v1.json';

String encodeAppPreferences(AppPreferences value) => jsonEncode({
  'schemaVersion': _schemaVersion,
  'themeId': value.themeId.name,
  'toleranceMode': value.toleranceMode.name,
  'hapticsEnabled': value.hapticsEnabled,
  'reduceMotion': value.reduceMotion,
  'hasSeenTunerPrimer': value.hasSeenTunerPrimer,
  'recentSearches': value.recentSearches,
});

AppPreferences decodeAppPreferences(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('App preferences must be an object.');
  }
  final document = decoded.cast<String, Object?>();
  if (document['schemaVersion'] != _schemaVersion) {
    throw const FormatException('Unsupported app preferences schema.');
  }
  final themeName = document['themeId'];
  final toleranceName = document['toleranceMode'];
  final hapticsEnabled = document['hapticsEnabled'];
  final reduceMotion = document['reduceMotion'];
  final hasSeenTunerPrimer = document['hasSeenTunerPrimer'];
  final recentSearches = document['recentSearches'];
  if (themeName is! String ||
      toleranceName is! String ||
      hapticsEnabled is! bool ||
      reduceMotion is! bool ||
      hasSeenTunerPrimer is! bool ||
      recentSearches is! List ||
      recentSearches.any((value) => value is! String)) {
    throw const FormatException('Invalid app preferences fields.');
  }
  final themeId = SharkTuneThemeId.values
      .where((value) => value.name == themeName)
      .firstOrNull;
  final toleranceMode = TunerToleranceMode.values
      .where((value) => value.name == toleranceName)
      .firstOrNull;
  if (themeId == null || toleranceMode == null) {
    throw const FormatException('Unknown app preferences enum value.');
  }
  return AppPreferences(
    themeId: themeId,
    toleranceMode: toleranceMode,
    hapticsEnabled: hapticsEnabled,
    reduceMotion: reduceMotion,
    hasSeenTunerPrimer: hasSeenTunerPrimer,
    recentSearches: List.unmodifiable(recentSearches.cast<String>()),
  );
}

final class JsonAppPreferencesStore {
  JsonAppPreferencesStore({
    this.directoryProvider = getApplicationSupportDirectory,
  });

  final AppPreferencesDirectoryProvider directoryProvider;

  Future<AppPreferences> load() async {
    final directory = await directoryProvider();
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    final backup = File('${file.path}.bak');
    for (final candidate in [file, backup]) {
      try {
        if (await candidate.exists()) {
          return decodeAppPreferences(await candidate.readAsString());
        }
      } on Object {
        // Try the backup before returning safe defaults.
      }
    }
    return const AppPreferences();
  }

  Future<void> save(AppPreferences value) async {
    final directory = await directoryProvider();
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString(encodeAppPreferences(value), flush: true);
    if (await file.exists()) {
      if (await _containsValidPreferences(file)) {
        if (await backup.exists()) await backup.delete();
        await file.copy(backup.path);
      }
      await file.delete();
    }
    await temporary.rename(file.path);
  }
}

Future<bool> _containsValidPreferences(File file) async {
  try {
    decodeAppPreferences(await file.readAsString());
    return true;
  } on Object {
    return false;
  }
}

final class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController({
    required AppPreferences initialValue,
    required this.saver,
  }) : _value = initialValue;

  AppPreferences _value;
  final AppPreferencesSaver saver;
  Future<void> _pendingSave = Future.value();

  AppPreferences get value => _value;

  void setTheme(SharkTuneThemeId value) =>
      _replace(_value.copyWith(themeId: value));

  void setToleranceMode(TunerToleranceMode value) =>
      _replace(_value.copyWith(toleranceMode: value));

  void setHapticsEnabled(bool value) =>
      _replace(_value.copyWith(hapticsEnabled: value));

  void setReduceMotion(bool value) =>
      _replace(_value.copyWith(reduceMotion: value));

  void markTunerPrimerSeen() {
    if (_value.hasSeenTunerPrimer) return;
    _replace(_value.copyWith(hasSeenTunerPrimer: true));
  }

  void recordRecentSearch(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final next = [
      normalized,
      ..._value.recentSearches.where(
        (value) => value.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(5).toList(growable: false);
    _replace(_value.copyWith(recentSearches: next));
  }

  void clearRecentSearches() =>
      _replace(_value.copyWith(recentSearches: const []));

  Future<void> flush() => _pendingSave;

  void _replace(AppPreferences next) {
    _value = next;
    notifyListeners();
    _pendingSave = _pendingSave.then((_) => saver(next));
  }
}

class AppPreferencesScope extends InheritedNotifier<AppPreferencesController> {
  const AppPreferencesScope({
    super.key,
    required AppPreferencesController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppPreferencesController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppPreferencesScope>();
    assert(scope != null, 'AppPreferencesScope is missing above this context.');
    return scope!.notifier!;
  }

  static AppPreferencesController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppPreferencesScope>()
        ?.notifier;
  }
}

extension AppPreferencesContext on BuildContext {
  AppPreferencesController get appPreferences => AppPreferencesScope.of(this);
}

bool shouldReduceMotion(BuildContext context) {
  final userPreference =
      AppPreferencesScope.maybeOf(context)?.value.reduceMotion ?? false;
  return userPreference || MediaQuery.disableAnimationsOf(context);
}
