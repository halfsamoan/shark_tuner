import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/string_care/string_care_model.dart';
import 'package:toauner_app/src/string_care/string_care_store.dart';

void main() {
  test('store round trips the ledger and keeps a recoverable backup', () async {
    final directory = await Directory.systemTemp.createTemp('toauner-care-');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonStringCareStore(directoryProvider: () async => directory);
    final first = StringCareLedger.empty().recordInstallation(
      id: 'first',
      installedOn: DateTime.utc(2026, 1, 1),
      recordedAtUtc: DateTime.utc(2026, 1, 1),
    );
    final second = first.recordInstallation(
      id: 'second',
      installedOn: DateTime.utc(2026, 7, 1),
      recordedAtUtc: DateTime.utc(2026, 7, 1),
    );

    await store.save(first);
    await store.save(second);
    expect((await store.load()).activeInstallation!.id, 'second');

    await File(
      '${directory.path}${Platform.pathSeparator}string-care.v1.json',
    ).writeAsString('{broken');
    expect((await store.load()).activeInstallation!.id, 'first');
  });

  test('missing or unrecoverable data loads an empty ledger', () async {
    final directory = await Directory.systemTemp.createTemp('toauner-care-');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonStringCareStore(directoryProvider: () async => directory);

    expect((await store.load()).installations, isEmpty);
    await File(
      '${directory.path}${Platform.pathSeparator}string-care.v1.json',
    ).writeAsString('{broken');
    expect((await store.load()).installations, isEmpty);
  });

  test(
    'saving after recovery never replaces a valid backup with corruption',
    () async {
      final directory = await Directory.systemTemp.createTemp('toauner-care-');
      addTearDown(() => directory.delete(recursive: true));
      final store = JsonStringCareStore(
        directoryProvider: () async => directory,
      );
      final first = StringCareLedger.empty().recordInstallation(
        id: 'first',
        installedOn: DateTime.utc(2026, 1, 1),
        recordedAtUtc: DateTime.utc(2026, 1, 1),
      );
      final second = first.recordInstallation(
        id: 'second',
        installedOn: DateTime.utc(2026, 6, 1),
        recordedAtUtc: DateTime.utc(2026, 6, 1),
      );
      await store.save(first);
      await store.save(second);
      final primary = File(
        '${directory.path}${Platform.pathSeparator}string-care.v1.json',
      );
      await primary.writeAsString('{broken');

      final recovered = await store.load();
      expect(recovered.activeInstallation!.id, 'first');
      await store.save(
        recovered.recordInstallation(
          id: 'recovered',
          installedOn: DateTime.utc(2026, 7, 1),
          recordedAtUtc: DateTime.utc(2026, 7, 1),
        ),
      );
      await primary.writeAsString('{broken-again');

      expect((await store.load()).activeInstallation!.id, 'first');
    },
  );
}
