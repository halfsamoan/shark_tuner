import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/tuning_history/tuning_history_model.dart';

void main() {
  test('ledger keeps newest completions, deduplicates, and caps history', () {
    var ledger = TuningHistoryLedger.empty();
    for (var index = 0; index < 105; index++) {
      ledger = ledger.record(_entry('session-$index', minute: index));
    }

    expect(ledger.entries, hasLength(TuningHistoryLedger.maximumEntries));
    expect(ledger.entries.first.id, 'session-104');
    expect(ledger.entries.last.id, 'session-5');

    final replacement = _entry('session-50', minute: 200, elapsedSeconds: 42);
    ledger = ledger.record(replacement);
    expect(ledger.entries.first.elapsed, const Duration(seconds: 42));
    expect(
      ledger.entries.where((entry) => entry.id == 'session-50'),
      hasLength(1),
    );
  });

  test('codec round trips song and direct-tuning completions', () {
    final ledger = TuningHistoryLedger.empty()
        .record(
          _entry(
            'song-session',
            minute: 2,
            songId: 'eruption',
            songTitle: 'Eruption',
            artist: 'Van Halen',
          ),
        )
        .record(_entry('direct-session', minute: 3));

    final decoded = decodeTuningHistoryLedger(
      encodeTuningHistoryLedger(ledger),
    );

    expect(decoded.entries, hasLength(2));
    expect(decoded.entries.last.songTitle, 'Eruption');
    expect(decoded.entries.last.artist, 'Van Halen');
    expect(decoded.entries.first.songId, isNull);
    expect(decoded.entries.first.tuningVersion, 1);
  });

  test('codec rejects malformed or unsupported documents', () {
    expect(
      () => decodeTuningHistoryLedger('{"schemaVersion":2,"entries":[]}'),
      throwsFormatException,
    );
    expect(
      () => decodeTuningHistoryLedger(
        '{"schemaVersion":1,"entries":[{"id":"broken"}]}',
      ),
      throwsFormatException,
    );
  });
}

TuningHistoryEntry _entry(
  String id, {
  required int minute,
  int elapsedSeconds = 90,
  String? songId,
  String? songTitle,
  String? artist,
}) {
  return TuningHistoryEntry(
    id: id,
    completedAtUtc: DateTime.utc(2026, 7, 14, 10, minute),
    tuningId: 'guitar-standard',
    tuningVersion: 1,
    tuningName: 'E Standard',
    elapsed: Duration(seconds: elapsedSeconds),
    stringCount: 6,
    songId: songId,
    songTitle: songTitle,
    artist: artist,
  );
}
