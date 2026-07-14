import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:toauner_app/src/instrument_setup/instrument_profile_store.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  test('profile codec round trips physical layout and per-peg overrides', () {
    final profile = InstrumentPegProfile.split(
      stringCount: 7,
      bassSideStringCount: 4,
      handedness: InstrumentHandedness.left,
      orientation: HeadstockOrientation.reversed,
      windingOverrides: const {7: StringWinding.reversed},
      directionOverrides: const {7: PegRotationDirection.counterClockwise},
    );

    final encoded = encodeInstrumentPegProfile(profile);
    final decoded = decodeInstrumentPegProfile(encoded);

    expect(decoded.stringCount, 7);
    expect(decoded.layout, HeadstockLayout.split);
    expect(decoded.bassSideStringCount, 4);
    expect(decoded.handedness, InstrumentHandedness.left);
    expect(decoded.orientation, HeadstockOrientation.reversed);
    expect(decoded.windingOverrides, {7: StringWinding.reversed});
    expect(decoded.directionOverrides, {
      7: PegRotationDirection.counterClockwise,
    });
  });

  test('profile codec rejects unknown versions and malformed string keys', () {
    expect(
      () => decodeInstrumentPegProfile(jsonEncode({'schemaVersion': 2})),
      throwsFormatException,
    );
    expect(
      () => decodeInstrumentPegProfile(
        jsonEncode({
          'schemaVersion': 1,
          'stringCount': 6,
          'layout': 'inline',
          'bassSideStringCount': 6,
          'handedness': 'right',
          'orientation': 'standard',
          'windingOverrides': {'not-a-string': 'reversed'},
          'directionOverrides': <String, String>{},
        }),
      ),
      throwsFormatException,
    );
  });
}
