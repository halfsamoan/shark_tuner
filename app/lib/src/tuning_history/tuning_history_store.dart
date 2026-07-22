import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'tuning_history_model.dart';

typedef TuningHistoryLoader = Future<TuningHistoryLedger> Function();
typedef TuningHistorySaver = Future<void> Function(TuningHistoryLedger ledger);
typedef TuningHistoryRecorder = Future<void> Function(TuningHistoryEntry entry);
typedef TuningHistoryDirectoryProvider = Future<Directory> Function();

const _fileName = 'tuning-history.v1.json';

final class JsonTuningHistoryStore {
  JsonTuningHistoryStore({
    this.directoryProvider = getApplicationSupportDirectory,
  });

  final TuningHistoryDirectoryProvider directoryProvider;
  Future<void> _writeQueue = Future.value();

  Future<TuningHistoryLedger> load() async {
    final directory = await directoryProvider();
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    final backup = File('${file.path}.bak');
    for (final candidate in [file, backup]) {
      try {
        if (await candidate.exists()) {
          return decodeTuningHistoryLedger(await candidate.readAsString());
        }
      } on Object {
        // Try the recoverable backup before returning an empty ledger.
      }
    }
    return TuningHistoryLedger.empty();
  }

  Future<void> append(TuningHistoryEntry entry) => _enqueue(() async {
    final ledger = await load();
    await _saveNow(ledger.record(entry));
  });

  Future<void> save(TuningHistoryLedger ledger) =>
      _enqueue(() => _saveNow(ledger));

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _writeQueue.then((_) => operation());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _saveNow(TuningHistoryLedger ledger) async {
    final directory = await directoryProvider();
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString(
      encodeTuningHistoryLedger(ledger),
      flush: true,
    );
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
    decodeTuningHistoryLedger(await file.readAsString());
    return true;
  } on Object {
    return false;
  }
}

final _defaultTuningHistoryStore = JsonTuningHistoryStore();

Future<TuningHistoryLedger> loadTuningHistoryLedger() =>
    _defaultTuningHistoryStore.load();

Future<void> saveTuningHistoryLedger(TuningHistoryLedger ledger) =>
    _defaultTuningHistoryStore.save(ledger);

Future<void> recordTuningHistoryEntry(TuningHistoryEntry entry) =>
    _defaultTuningHistoryStore.append(entry);
