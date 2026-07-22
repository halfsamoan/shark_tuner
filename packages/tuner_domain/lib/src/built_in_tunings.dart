import 'tuning_definition.dart';

abstract final class BuiltInTunings {
  static final standardGuitar = TuningDefinition(
    id: 'guitar-6-standard',
    version: 1,
    name: 'Standard',
    strings: const [
      TuningString(stringNumber: 6, midiNote: 40, label: 'E2'),
      TuningString(stringNumber: 5, midiNote: 45, label: 'A2'),
      TuningString(stringNumber: 4, midiNote: 50, label: 'D3'),
      TuningString(stringNumber: 3, midiNote: 55, label: 'G3'),
      TuningString(stringNumber: 2, midiNote: 59, label: 'B3'),
      TuningString(stringNumber: 1, midiNote: 64, label: 'E4'),
    ],
  );

  static final eFlatStandard = TuningDefinition(
    id: 'guitar-6-eb-standard',
    version: 1,
    name: 'E-flat Standard',
    strings: const [
      TuningString(stringNumber: 6, midiNote: 39, label: 'E♭2'),
      TuningString(stringNumber: 5, midiNote: 44, label: 'A♭2'),
      TuningString(stringNumber: 4, midiNote: 49, label: 'D♭3'),
      TuningString(stringNumber: 3, midiNote: 54, label: 'G♭3'),
      TuningString(stringNumber: 2, midiNote: 58, label: 'B♭3'),
      TuningString(stringNumber: 1, midiNote: 63, label: 'E♭4'),
    ],
  );

  static final dropD = TuningDefinition(
    id: 'guitar-6-drop-d',
    version: 1,
    name: 'Drop D',
    strings: const [
      TuningString(stringNumber: 6, midiNote: 38, label: 'D2'),
      TuningString(stringNumber: 5, midiNote: 45, label: 'A2'),
      TuningString(stringNumber: 4, midiNote: 50, label: 'D3'),
      TuningString(stringNumber: 3, midiNote: 55, label: 'G3'),
      TuningString(stringNumber: 2, midiNote: 59, label: 'B3'),
      TuningString(stringNumber: 1, midiNote: 64, label: 'E4'),
    ],
  );

  static final dStandard = TuningDefinition(
    id: 'guitar-6-d-standard',
    version: 1,
    name: 'D Standard',
    strings: const [
      TuningString(stringNumber: 6, midiNote: 38, label: 'D2'),
      TuningString(stringNumber: 5, midiNote: 43, label: 'G2'),
      TuningString(stringNumber: 4, midiNote: 48, label: 'C3'),
      TuningString(stringNumber: 3, midiNote: 53, label: 'F3'),
      TuningString(stringNumber: 2, midiNote: 57, label: 'A3'),
      TuningString(stringNumber: 1, midiNote: 62, label: 'D4'),
    ],
  );

  static final dropCSharp = TuningDefinition(
    id: 'guitar-6-drop-c-sharp',
    version: 1,
    name: 'Drop C-sharp',
    strings: const [
      TuningString(stringNumber: 6, midiNote: 37, label: 'C♯2'),
      TuningString(stringNumber: 5, midiNote: 44, label: 'G♯2'),
      TuningString(stringNumber: 4, midiNote: 49, label: 'C♯3'),
      TuningString(stringNumber: 3, midiNote: 54, label: 'F♯3'),
      TuningString(stringNumber: 2, midiNote: 58, label: 'A♯3'),
      TuningString(stringNumber: 1, midiNote: 63, label: 'D♯4'),
    ],
  );

  static final dropC = TuningDefinition(
    id: 'guitar-6-drop-c',
    version: 1,
    name: 'Drop C',
    strings: const [
      TuningString(stringNumber: 6, midiNote: 36, label: 'C2'),
      TuningString(stringNumber: 5, midiNote: 43, label: 'G2'),
      TuningString(stringNumber: 4, midiNote: 48, label: 'C3'),
      TuningString(stringNumber: 3, midiNote: 53, label: 'F3'),
      TuningString(stringNumber: 2, midiNote: 57, label: 'A3'),
      TuningString(stringNumber: 1, midiNote: 62, label: 'D4'),
    ],
  );

  static final dadgad = TuningDefinition(
    id: 'guitar-6-dadgad',
    version: 1,
    name: 'DADGAD',
    strings: const [
      TuningString(stringNumber: 6, midiNote: 38, label: 'D2'),
      TuningString(stringNumber: 5, midiNote: 45, label: 'A2'),
      TuningString(stringNumber: 4, midiNote: 50, label: 'D3'),
      TuningString(stringNumber: 3, midiNote: 55, label: 'G3'),
      TuningString(stringNumber: 2, midiNote: 57, label: 'A3'),
      TuningString(stringNumber: 1, midiNote: 62, label: 'D4'),
    ],
  );

  static final List<TuningDefinition> sixStringPresets = List.unmodifiable([
    standardGuitar,
    eFlatStandard,
    dropD,
    dStandard,
    dropCSharp,
    dropC,
    dadgad,
  ]);
}
