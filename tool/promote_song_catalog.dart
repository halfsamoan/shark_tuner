import 'dart:convert';
import 'dart:io';

import 'package:tuner_data/tuner_data.dart';

void main(List<String> arguments) {
  final options = _parseOptions(arguments);
  final input = File(options.inputPath);
  final output = File(options.outputPath);
  final candidates = (jsonDecode(input.readAsStringSync()) as Map)
      .cast<String, dynamic>();
  final promoted = promoteSongCatalog(
    candidates: candidates,
    approvedBy: options.approvedBy,
    approvedAt: DateTime.parse(options.approvedAt),
  );
  const encoder = JsonEncoder.withIndent('  ');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${encoder.convert(promoted)}\n');
}

_Options _parseOptions(List<String> arguments) {
  String? valueAfter(String name) {
    final index = arguments.indexOf(name);
    if (index < 0 || index + 1 >= arguments.length) {
      return null;
    }
    return arguments[index + 1];
  }

  final approvedBy = valueAfter('--approved-by')?.trim();
  final approvedAt = valueAfter('--approved-at')?.trim();
  if (approvedBy == null || approvedBy.isEmpty || approvedAt == null) {
    stderr.writeln(
      'Usage: dart run tool/promote_song_catalog.dart '
      '--approved-by <name> --approved-at <YYYY-MM-DD> '
      '[--input <path>] [--output <path>]',
    );
    exitCode = 64;
    throw ArgumentError('Explicit approval identity and date are required.');
  }
  return _Options(
    approvedBy: approvedBy,
    approvedAt: approvedAt,
    inputPath: valueAfter('--input') ?? 'data/songs/candidates.v1.json',
    outputPath: valueAfter('--output') ?? 'data/songs/catalog.v1.json',
  );
}

final class _Options {
  const _Options({
    required this.approvedBy,
    required this.approvedAt,
    required this.inputPath,
    required this.outputPath,
  });

  final String approvedBy;
  final String approvedAt;
  final String inputPath;
  final String outputPath;
}
