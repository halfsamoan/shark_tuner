import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'string_care_model.dart';

typedef StringCareLoader = Future<StringCareLedger> Function();
typedef StringCareSaver = Future<void> Function(StringCareLedger ledger);
typedef StringCareDirectoryProvider = Future<Directory> Function();

const _fileName = 'string-care.v1.json';

final class JsonStringCareStore {
  JsonStringCareStore({
    this.directoryProvider = getApplicationSupportDirectory,
  });

  final StringCareDirectoryProvider directoryProvider;

  Future<StringCareLedger> load() async {
    final directory = await directoryProvider();
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    final backup = File('${file.path}.bak');
    for (final candidate in [file, backup]) {
      try {
        if (await candidate.exists()) {
          return decodeStringCareLedger(await candidate.readAsString());
        }
      } on Object {
        // Try the recoverable backup before returning an empty ledger.
      }
    }
    return StringCareLedger.empty();
  }

  Future<void> save(StringCareLedger ledger) async {
    final directory = await directoryProvider();
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString(encodeStringCareLedger(ledger), flush: true);
    if (await file.exists()) {
      if (await _containsValidLedger(file)) {
        if (await backup.exists()) {
          await backup.delete();
        }
        await file.copy(backup.path);
      }
      await file.delete();
    }
    await temporary.rename(file.path);
  }
}

Future<bool> _containsValidLedger(File file) async {
  try {
    decodeStringCareLedger(await file.readAsString());
    return true;
  } on Object {
    return false;
  }
}

final _defaultStringCareStore = JsonStringCareStore();

Future<StringCareLedger> loadStringCareLedger() =>
    _defaultStringCareStore.load();

Future<void> saveStringCareLedger(StringCareLedger ledger) =>
    _defaultStringCareStore.save(ledger);
