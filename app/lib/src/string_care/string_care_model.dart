import 'dart:convert';

enum StringCareStatusKind { noRecord, fresh, dueSoon, due, overdue }

final class StringInstallationRecord {
  StringInstallationRecord({
    required this.id,
    required DateTime installedOn,
    required DateTime recordedAtUtc,
    this.gaugeLabel,
    this.tuningId,
  }) : installedOn = _dateOnlyUtc(installedOn),
       recordedAtUtc = recordedAtUtc.toUtc() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id');
    }
    _validateOptionalLabel(gaugeLabel, 'gaugeLabel');
    _validateOptionalLabel(tuningId, 'tuningId');
  }

  final String id;
  final DateTime installedOn;
  final DateTime recordedAtUtc;
  final String? gaugeLabel;
  final String? tuningId;
}

final class StringCareStatus {
  const StringCareStatus({
    required this.kind,
    this.ageDays,
    this.daysUntilReminder,
    this.gaugeLabel,
  });

  final StringCareStatusKind kind;
  final int? ageDays;
  final int? daysUntilReminder;
  final String? gaugeLabel;
}

final class StringCareLedger {
  StringCareLedger._({
    required List<StringInstallationRecord> installations,
    required this.reminderIntervalDays,
  }) : installations = List.unmodifiable(installations) {
    if (!supportedReminderIntervals.contains(reminderIntervalDays)) {
      throw ArgumentError.value(reminderIntervalDays, 'reminderIntervalDays');
    }
    final ids = installations.map((entry) => entry.id).toSet();
    if (ids.length != installations.length) {
      throw ArgumentError.value(
        installations,
        'installations',
        'Duplicate ID.',
      );
    }
  }

  factory StringCareLedger.empty() =>
      StringCareLedger._(installations: const [], reminderIntervalDays: 90);

  static const supportedReminderIntervals = [30, 60, 90, 120];

  final List<StringInstallationRecord> installations;
  final int reminderIntervalDays;

  StringInstallationRecord? get activeInstallation =>
      installations.isEmpty ? null : installations.first;

  StringCareLedger withReminderIntervalDays(int days) {
    return StringCareLedger._(
      installations: installations,
      reminderIntervalDays: days,
    );
  }

  StringCareLedger recordInstallation({
    required String id,
    required DateTime installedOn,
    required DateTime recordedAtUtc,
    String? gaugeLabel,
    String? tuningId,
  }) {
    final record = StringInstallationRecord(
      id: id,
      installedOn: installedOn,
      recordedAtUtc: recordedAtUtc,
      gaugeLabel: _normalizedOptional(gaugeLabel),
      tuningId: _normalizedOptional(tuningId),
    );
    return StringCareLedger._(
      installations: [
        record,
        ...installations.where((entry) => entry.id != id),
      ],
      reminderIntervalDays: reminderIntervalDays,
    );
  }

  StringCareLedger clearInstallations() {
    return StringCareLedger._(
      installations: const [],
      reminderIntervalDays: reminderIntervalDays,
    );
  }

  StringCareStatus statusOn(DateTime date) {
    final active = activeInstallation;
    if (active == null) {
      return const StringCareStatus(kind: StringCareStatusKind.noRecord);
    }
    final ageDays = _dateOnlyUtc(date).difference(active.installedOn).inDays;
    final safeAgeDays = ageDays < 0 ? 0 : ageDays;
    final remaining = reminderIntervalDays - safeAgeDays;
    final kind = switch (remaining) {
      < 0 => StringCareStatusKind.overdue,
      0 => StringCareStatusKind.due,
      <= 21 => StringCareStatusKind.dueSoon,
      _ => StringCareStatusKind.fresh,
    };
    return StringCareStatus(
      kind: kind,
      ageDays: safeAgeDays,
      daysUntilReminder: remaining,
      gaugeLabel: active.gaugeLabel,
    );
  }
}

const _stringCareSchemaVersion = 1;

String encodeStringCareLedger(StringCareLedger ledger) {
  return jsonEncode({
    'schemaVersion': _stringCareSchemaVersion,
    'reminderIntervalDays': ledger.reminderIntervalDays,
    'installations': [
      for (final entry in ledger.installations)
        {
          'id': entry.id,
          'installedOn': _dateKey(entry.installedOn),
          'recordedAtUtc': entry.recordedAtUtc.toIso8601String(),
          if (entry.gaugeLabel != null) 'gaugeLabel': entry.gaugeLabel,
          if (entry.tuningId != null) 'tuningId': entry.tuningId,
        },
    ],
  });
}

StringCareLedger decodeStringCareLedger(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('String care data must be an object.');
  }
  final document = decoded.cast<String, Object?>();
  if (document['schemaVersion'] != _stringCareSchemaVersion) {
    throw const FormatException('Unsupported string care schema version.');
  }
  final interval = document['reminderIntervalDays'];
  final rawInstallations = document['installations'];
  if (interval is! int || rawInstallations is! List) {
    throw const FormatException('Invalid string care document.');
  }
  final installations = <StringInstallationRecord>[];
  for (final raw in rawInstallations) {
    if (raw is! Map) {
      throw const FormatException('Installation must be an object.');
    }
    final entry = raw.cast<String, Object?>();
    final id = entry['id'];
    final installedOn = entry['installedOn'];
    final recordedAtUtc = entry['recordedAtUtc'];
    if (id is! String || installedOn is! String || recordedAtUtc is! String) {
      throw const FormatException('Installation has invalid required fields.');
    }
    final parsedInstalledOn = _parseDateKey(installedOn);
    final parsedRecordedAt = DateTime.tryParse(recordedAtUtc);
    if (parsedRecordedAt == null || !parsedRecordedAt.isUtc) {
      throw const FormatException('recordedAtUtc must be a UTC timestamp.');
    }
    final gaugeLabel = entry['gaugeLabel'];
    final tuningId = entry['tuningId'];
    if ((gaugeLabel != null && gaugeLabel is! String) ||
        (tuningId != null && tuningId is! String)) {
      throw const FormatException('Installation optional fields are invalid.');
    }
    installations.add(
      StringInstallationRecord(
        id: id,
        installedOn: parsedInstalledOn,
        recordedAtUtc: parsedRecordedAt,
        gaugeLabel: gaugeLabel as String?,
        tuningId: tuningId as String?,
      ),
    );
  }
  try {
    return StringCareLedger._(
      installations: installations,
      reminderIntervalDays: interval,
    );
  } on ArgumentError catch (error) {
    throw FormatException('Invalid string care values: $error');
  }
}

DateTime _dateOnlyUtc(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime _parseDateKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw const FormatException('installedOn must be YYYY-MM-DD.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw const FormatException('installedOn is not a valid date.');
  }
  return parsed;
}

String? _normalizedOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

void _validateOptionalLabel(String? value, String name) {
  if (value != null && value.length > 80) {
    throw ArgumentError.value(value, name, 'Must be 80 characters or fewer.');
  }
}
