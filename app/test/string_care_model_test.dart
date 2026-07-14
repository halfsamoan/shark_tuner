import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/string_care/string_care_model.dart';

void main() {
  test('new installation becomes active and calendar age is deterministic', () {
    final ledger = StringCareLedger.empty().recordInstallation(
      id: 'set-1',
      installedOn: DateTime.utc(2026, 5, 1),
      recordedAtUtc: DateTime.utc(2026, 5, 3, 10),
      gaugeLabel: '10–46',
      tuningId: 'guitar-6-standard',
    );

    final status = ledger.statusOn(DateTime.utc(2026, 7, 14));
    expect(ledger.activeInstallation!.id, 'set-1');
    expect(status.kind, StringCareStatusKind.dueSoon);
    expect(status.ageDays, 74);
    expect(status.daysUntilReminder, 16);
    expect(status.gaugeLabel, '10–46');
  });

  test(
    'user interval controls due and overdue status without hidden advice',
    () {
      final ledger = StringCareLedger.empty()
          .withReminderIntervalDays(30)
          .recordInstallation(
            id: 'set-1',
            installedOn: DateTime.utc(2026, 6, 1),
            recordedAtUtc: DateTime.utc(2026, 6, 1),
          );

      expect(
        ledger.statusOn(DateTime.utc(2026, 7, 1)).kind,
        StringCareStatusKind.due,
      );
      final overdue = ledger.statusOn(DateTime.utc(2026, 7, 14));
      expect(overdue.kind, StringCareStatusKind.overdue);
      expect(overdue.daysUntilReminder, -13);
    },
  );

  test('codec round trips ordered history and rejects unknown versions', () {
    final ledger = StringCareLedger.empty()
        .withReminderIntervalDays(120)
        .recordInstallation(
          id: 'older',
          installedOn: DateTime.utc(2026, 1, 2),
          recordedAtUtc: DateTime.utc(2026, 1, 2, 12),
          gaugeLabel: '10–46',
        )
        .recordInstallation(
          id: 'active',
          installedOn: DateTime.utc(2026, 7, 13),
          recordedAtUtc: DateTime.utc(2026, 7, 13, 12),
          gaugeLabel: '11–56',
          tuningId: 'guitar-6-drop-c',
        );

    final decoded = decodeStringCareLedger(encodeStringCareLedger(ledger));
    expect(decoded.reminderIntervalDays, 120);
    expect(decoded.installations.map((entry) => entry.id), ['active', 'older']);
    expect(decoded.activeInstallation!.gaugeLabel, '11–56');
    expect(
      () => decodeStringCareLedger('{"schemaVersion":2,"installations":[]}'),
      throwsFormatException,
    );
  });

  test('only explicit supported reminder intervals are accepted', () {
    expect(
      () => StringCareLedger.empty().withReminderIntervalDays(45),
      throwsArgumentError,
    );
    expect(StringCareLedger.supportedReminderIntervals, [30, 60, 90, 120]);
  });

  test('clearing history preserves the user reminder interval', () {
    final cleared = StringCareLedger.empty()
        .withReminderIntervalDays(60)
        .recordInstallation(
          id: 'set-1',
          installedOn: DateTime.utc(2026, 7, 1),
          recordedAtUtc: DateTime.utc(2026, 7, 1),
        )
        .clearInstallations();

    expect(cleared.installations, isEmpty);
    expect(cleared.reminderIntervalDays, 60);
  });

  test('local install date can cross the UTC date boundary', () {
    final ledger = StringCareLedger.empty().recordInstallation(
      id: 'after-midnight-kst',
      installedOn: DateTime(2026, 7, 14),
      recordedAtUtc: DateTime.utc(2026, 7, 13, 16),
    );

    expect(ledger.activeInstallation!.installedOn, DateTime.utc(2026, 7, 14));
  });
}
