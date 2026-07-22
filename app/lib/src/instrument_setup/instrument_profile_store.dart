import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:tuner_domain/tuner_domain.dart';

typedef InstrumentProfileLoader = Future<InstrumentPegProfile?> Function();
typedef InstrumentProfileSaver =
    Future<void> Function(InstrumentPegProfile profile);

const _schemaVersion = 1;
const _fileName = 'instrument-peg-profile.v1.json';

Future<InstrumentPegProfile?> loadInstrumentPegProfile() async {
  try {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    if (!await file.exists()) {
      return null;
    }
    return decodeInstrumentPegProfile(await file.readAsString());
  } on Object {
    return null;
  }
}

Future<void> saveInstrumentPegProfile(InstrumentPegProfile profile) async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
  await file.writeAsString(encodeInstrumentPegProfile(profile), flush: true);
}

String encodeInstrumentPegProfile(InstrumentPegProfile profile) {
  return jsonEncode({
    'schemaVersion': _schemaVersion,
    'stringCount': profile.stringCount,
    'layout': profile.layout.name,
    'bassSideStringCount': profile.bassSideStringCount,
    'handedness': profile.handedness.name,
    'orientation': profile.orientation.name,
    'windingOverrides': {
      for (final entry in profile.windingOverrides.entries)
        '${entry.key}': entry.value.name,
    },
    'directionOverrides': {
      for (final entry in profile.directionOverrides.entries)
        '${entry.key}': entry.value.name,
    },
  });
}

InstrumentPegProfile decodeInstrumentPegProfile(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Instrument profile must be a JSON object.');
  }
  final document = decoded.cast<String, Object?>();
  if (document['schemaVersion'] != _schemaVersion) {
    throw const FormatException('Unsupported instrument profile version.');
  }
  final stringCount = _requiredInt(document, 'stringCount');
  final bassSideStringCount = _requiredInt(document, 'bassSideStringCount');
  final layout = _enumByName(
    HeadstockLayout.values,
    document['layout'],
    'layout',
  );
  final handedness = _enumByName(
    InstrumentHandedness.values,
    document['handedness'],
    'handedness',
  );
  final orientation = _enumByName(
    HeadstockOrientation.values,
    document['orientation'],
    'orientation',
  );
  final windingOverrides = _enumMap(
    document['windingOverrides'],
    StringWinding.values,
    'windingOverrides',
  );
  final directionOverrides = _enumMap(
    document['directionOverrides'],
    PegRotationDirection.values,
    'directionOverrides',
  );

  return switch (layout) {
    HeadstockLayout.split => InstrumentPegProfile.split(
      stringCount: stringCount,
      bassSideStringCount: bassSideStringCount,
      handedness: handedness,
      orientation: orientation,
      windingOverrides: windingOverrides,
      directionOverrides: directionOverrides,
    ),
    HeadstockLayout.inline => InstrumentPegProfile.inline(
      stringCount: stringCount,
      handedness: handedness,
      orientation: orientation,
      windingOverrides: windingOverrides,
      directionOverrides: directionOverrides,
    ),
    HeadstockLayout.classicalSplit => InstrumentPegProfile.classicalSplit(
      stringCount: stringCount,
      bassSideStringCount: bassSideStringCount,
      handedness: handedness,
      orientation: orientation,
      windingOverrides: windingOverrides,
      directionOverrides: directionOverrides,
    ),
  };
}

int _requiredInt(Map<String, Object?> document, String key) {
  final value = document[key];
  if (value is! int) {
    throw FormatException('$key must be an integer.');
  }
  return value;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, String key) {
  if (name is! String) {
    throw FormatException('$key must be a string.');
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  throw FormatException('Unknown $key value: $name');
}

Map<int, T> _enumMap<T extends Enum>(
  Object? source,
  List<T> values,
  String key,
) {
  if (source is! Map) {
    throw FormatException('$key must be an object.');
  }
  final result = <int, T>{};
  for (final entry in source.entries) {
    final stringNumber = int.tryParse(entry.key.toString());
    if (stringNumber == null) {
      throw FormatException('$key contains a non-numeric string key.');
    }
    result[stringNumber] = _enumByName(
      values,
      entry.value,
      '$key.$stringNumber',
    );
  }
  return result;
}
