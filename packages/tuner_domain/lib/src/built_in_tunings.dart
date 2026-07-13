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
}
