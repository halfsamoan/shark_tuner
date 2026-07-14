import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/tuning_history/tuning_history_model.dart';
import 'package:toauner_app/src/tuning_history/tuning_history_store.dart';

void main() {
  test(
    'store round trips history and recovers its last valid backup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'toauner-history-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = JsonTuningHistoryStore(
        directoryProvider: () async => directory,
      );
      final first = TuningHistoryLedger.empty().record(_entry('first', 1));
      final second = first.record(_entry('second', 2));

      await store.save(first);
      await store.save(second);
      expect((await store.load()).entries.first.id, 'second');

      await File(
        '${directory.path}${Platform.pathSeparator}tuning-history.v1.json',
      ).writeAsString('{broken');
      expect((await store.load()).entries.single.id, 'first');
    },
  );

  test('append serializes concurrent writes without losing sessions', () async {
    final directory = await Directory.systemTemp.createTemp('toauner-history-');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonTuningHistoryStore(
      directoryProvider: () async => directory,
    );

    await Future.wait([
      store.append(_entry('first', 1)),
      store.append(_entry('second', 2)),
      store.append(_entry('third', 3)),
    ]);

    final ids = (await store.load()).entries.map((entry) => entry.id).toSet();
    expect(ids, {'first', 'second', 'third'});
  });

  test('missing or unrecoverable data loads an empty ledger', () async {
    final directory = await Directory.systemTemp.createTemp('toauner-history-');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonTuningHistoryStore(
      directoryProvider: () async => directory,
    );

    expect((await store.load()).entries, isEmpty);
    await File(
      '${directory.path}${Platform.pathSeparator}tuning-history.v1.json',
    ).writeAsString('{broken');
    expect((await store.load()).entries, isEmpty);
  });
}

TuningHistoryEntry _entry(String id, int minute) => TuningHistoryEntry(
  id: id,
  completedAtUtc: DateTime.utc(2026, 7, 14, 10, minute),
  tuningId: 'guitar-standard',
  tuningVersion: 1,
  tuningName: 'E Standard',
  elapsed: const Duration(seconds: 90),
  stringCount: 6,
);
