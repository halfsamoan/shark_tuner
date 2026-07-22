import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:tuner_data/tuner_data.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final targetsDocument =
        (jsonDecode(await File(options.targetsPath).readAsString()) as Map)
            .cast<String, dynamic>();
    final targets = parseBackboneTargets(targetsDocument);
    final targetMbids = targets.map((target) => target.recordingMbid).toSet();
    final canonicalRows = await _readSelectedCanonicalRows(
      File(options.canonicalPath),
      targetMbids,
    );
    final popularityRows = options.popularityPath == null
        ? const <Map<String, dynamic>>[]
        : await _readPopularityRows(File(options.popularityPath!));
    final document = buildSongCurationBackbone(
      canonicalRows: canonicalRows,
      targets: targets,
      popularityRows: popularityRows,
      capturedAtUtc: options.capturedAtUtc,
    );
    final output = File(options.outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(document)}\n',
      flush: true,
    );
    stdout.writeln(
      'Wrote ${canonicalRows.length} non-shipping backbone rows to '
      '${output.path}.',
    );
  } on Object catch (error) {
    stderr.writeln('Song backbone import failed: $error');
    exitCode = 1;
  }
}

Future<List<Map<String, String>>> _readSelectedCanonicalRows(
  File file,
  Set<String> targetMbids,
) async {
  List<String>? headers;
  final selected = <Map<String, String>>[];
  await for (final rawRow
      in file.openRead().transform(utf8.decoder).transform(csv.decoder)) {
    final row = rawRow.map((value) => value.toString()).toList(growable: false);
    if (headers == null) {
      headers = row;
      _requireColumns(headers);
      continue;
    }
    if (row.length != headers.length) {
      throw const FormatException('Canonical CSV row width does not match.');
    }
    final record = <String, String>{
      for (var index = 0; index < headers.length; index++)
        headers[index]: row[index],
    };
    final mbid = record['recording_mbid']?.toLowerCase();
    if (mbid != null && targetMbids.contains(mbid)) {
      selected.add(record);
      if (selected.length == targetMbids.length) break;
    }
  }
  if (headers == null) {
    throw const FormatException('Canonical CSV is empty.');
  }
  return selected;
}

Future<List<Map<String, dynamic>>> _readPopularityRows(File file) async {
  final decoded = jsonDecode(await file.readAsString());
  final rawRows = decoded is List
      ? decoded
      : decoded is Map && decoded['recordings'] is List
      ? decoded['recordings'] as List
      : throw const FormatException(
          'Popularity snapshot must be an array or recordings object.',
        );
  return rawRows
      .map((raw) {
        if (raw is! Map) {
          throw const FormatException('Popularity row must be an object.');
        }
        return raw.cast<String, dynamic>();
      })
      .toList(growable: false);
}

void _requireColumns(List<String> headers) {
  const required = {
    'artist_mbids',
    'artist_credit_name',
    'release_mbid',
    'release_name',
    'recording_mbid',
    'recording_name',
    'score',
  };
  final missing = required.difference(headers.toSet());
  if (missing.isNotEmpty) {
    throw FormatException('Canonical CSV columns missing: $missing');
  }
}

_Options _parseOptions(List<String> arguments) {
  final values = <String, String>{};
  for (var index = 0; index < arguments.length; index++) {
    final key = arguments[index];
    if (!key.startsWith('--') || index + 1 >= arguments.length) {
      throw const FormatException(_usage);
    }
    values[key] = arguments[++index];
  }
  final canonicalPath = values['--canonical-csv'];
  final targetsPath = values['--targets-json'];
  final outputPath = values['--output'];
  final capturedAt = DateTime.tryParse(values['--captured-at'] ?? '');
  if (canonicalPath == null ||
      targetsPath == null ||
      outputPath == null ||
      capturedAt == null ||
      !capturedAt.isUtc) {
    throw const FormatException(_usage);
  }
  return _Options(
    canonicalPath: canonicalPath,
    targetsPath: targetsPath,
    popularityPath: values['--popularity-json'],
    outputPath: outputPath,
    capturedAtUtc: capturedAt,
  );
}

final class _Options {
  const _Options({
    required this.canonicalPath,
    required this.targetsPath,
    required this.popularityPath,
    required this.outputPath,
    required this.capturedAtUtc,
  });

  final String canonicalPath;
  final String targetsPath;
  final String? popularityPath;
  final String outputPath;
  final DateTime capturedAtUtc;
}

const _usage = '''
Usage: dart run tool/import_song_backbone.dart
  --canonical-csv <canonical_musicbrainz_data.csv>
  --targets-json <backbone-targets.json>
  [--popularity-json <listenbrainz-popularity.json>]
  --captured-at <UTC ISO-8601 timestamp>
  --output <backbone.v1.json>

This tool performs no network requests and always emits shippingEligible=false.
''';
