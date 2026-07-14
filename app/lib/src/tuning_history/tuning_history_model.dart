import 'dart:convert';

final class TuningHistoryEntry {
  TuningHistoryEntry({
    required this.id,
    required DateTime completedAtUtc,
    required this.tuningId,
    required this.tuningVersion,
    required this.tuningName,
    required this.elapsed,
    required this.stringCount,
    this.songId,
    this.songTitle,
    this.artist,
  }) : completedAtUtc = completedAtUtc.toUtc() {
    _requireLabel(id, 'id');
    _requireLabel(tuningId, 'tuningId');
    _requireLabel(tuningName, 'tuningName');
    _validateOptionalLabel(songId, 'songId');
    _validateOptionalLabel(songTitle, 'songTitle');
    _validateOptionalLabel(artist, 'artist');
    if (tuningVersion <= 0) {
      throw ArgumentError.value(tuningVersion, 'tuningVersion');
    }
    if (elapsed.isNegative || elapsed == Duration.zero) {
      throw ArgumentError.value(elapsed, 'elapsed');
    }
    if (stringCount <= 0) {
      throw ArgumentError.value(stringCount, 'stringCount');
    }
  }

  final String id;
  final DateTime completedAtUtc;
  final String tuningId;
  final int tuningVersion;
  final String tuningName;
  final Duration elapsed;
  final int stringCount;
  final String? songId;
  final String? songTitle;
  final String? artist;
}

final class TuningHistoryLedger {
  TuningHistoryLedger._(List<TuningHistoryEntry> entries)
    : entries = List.unmodifiable(entries) {
    final ids = entries.map((entry) => entry.id).toSet();
    if (ids.length != entries.length) {
      throw ArgumentError.value(entries, 'entries', 'Duplicate ID.');
    }
    if (entries.length > maximumEntries) {
      throw ArgumentError.value(entries, 'entries', 'Too many entries.');
    }
  }

  factory TuningHistoryLedger.empty() => TuningHistoryLedger._(const []);

  static const maximumEntries = 100;

  final List<TuningHistoryEntry> entries;

  TuningHistoryLedger record(TuningHistoryEntry entry) {
    final updated = [
      entry,
      ...entries.where((candidate) => candidate.id != entry.id),
    ];
    return TuningHistoryLedger._(
      updated.take(maximumEntries).toList(growable: false),
    );
  }

  TuningHistoryLedger clear() => TuningHistoryLedger.empty();
}

const _schemaVersion = 1;

String encodeTuningHistoryLedger(TuningHistoryLedger ledger) => jsonEncode({
  'schemaVersion': _schemaVersion,
  'entries': [for (final entry in ledger.entries) _encodeEntry(entry)],
});

TuningHistoryLedger decodeTuningHistoryLedger(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Tuning history must be an object.');
  }
  final document = decoded.cast<String, Object?>();
  if (document['schemaVersion'] != _schemaVersion) {
    throw const FormatException('Unsupported tuning history schema version.');
  }
  final rawEntries = document['entries'];
  if (rawEntries is! List) {
    throw const FormatException('Tuning history entries must be a list.');
  }
  try {
    return TuningHistoryLedger._([
      for (final raw in rawEntries) _decodeEntry(raw),
    ]);
  } on ArgumentError catch (error) {
    throw FormatException('Invalid tuning history values: $error');
  }
}

Map<String, Object> _encodeEntry(TuningHistoryEntry entry) => {
  'id': entry.id,
  'completedAtUtc': entry.completedAtUtc.toIso8601String(),
  'tuningId': entry.tuningId,
  'tuningVersion': entry.tuningVersion,
  'tuningName': entry.tuningName,
  'elapsedMilliseconds': entry.elapsed.inMilliseconds,
  'stringCount': entry.stringCount,
  if (entry.songId != null) 'songId': entry.songId!,
  if (entry.songTitle != null) 'songTitle': entry.songTitle!,
  if (entry.artist != null) 'artist': entry.artist!,
};

TuningHistoryEntry _decodeEntry(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('Tuning history entry must be an object.');
  }
  final entry = raw.cast<String, Object?>();
  final id = entry['id'];
  final timestamp = entry['completedAtUtc'];
  final tuningId = entry['tuningId'];
  final tuningVersion = entry['tuningVersion'];
  final tuningName = entry['tuningName'];
  final elapsedMilliseconds = entry['elapsedMilliseconds'];
  final stringCount = entry['stringCount'];
  if (id is! String ||
      timestamp is! String ||
      tuningId is! String ||
      tuningVersion is! int ||
      tuningName is! String ||
      elapsedMilliseconds is! int ||
      stringCount is! int) {
    throw const FormatException('Tuning history entry is missing fields.');
  }
  final completedAt = DateTime.tryParse(timestamp);
  if (completedAt == null || !completedAt.isUtc) {
    throw const FormatException('completedAtUtc must be a UTC timestamp.');
  }
  final songId = entry['songId'];
  final songTitle = entry['songTitle'];
  final artist = entry['artist'];
  if ((songId != null && songId is! String) ||
      (songTitle != null && songTitle is! String) ||
      (artist != null && artist is! String)) {
    throw const FormatException('Tuning history song fields are invalid.');
  }
  return TuningHistoryEntry(
    id: id,
    completedAtUtc: completedAt,
    tuningId: tuningId,
    tuningVersion: tuningVersion,
    tuningName: tuningName,
    elapsed: Duration(milliseconds: elapsedMilliseconds),
    stringCount: stringCount,
    songId: songId as String?,
    songTitle: songTitle as String?,
    artist: artist as String?,
  );
}

void _requireLabel(String value, String name) {
  if (value.trim().isEmpty || value.length > 160) {
    throw ArgumentError.value(value, name);
  }
}

void _validateOptionalLabel(String? value, String name) {
  if (value != null && (value.trim().isEmpty || value.length > 160)) {
    throw ArgumentError.value(value, name);
  }
}
