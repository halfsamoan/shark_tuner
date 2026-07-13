import 'package:test/test.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  test('standard guitar targets the expected concert frequencies', () {
    final tuning = BuiltInTunings.standardGuitar;

    expect(tuning.strings.first.targetFrequencyHz(), closeTo(82.4069, 0.001));
    expect(tuning.strings.last.targetFrequencyHz(), closeTo(329.6276, 0.001));
  });

  test('a song-level cents offset shifts every target consistently', () {
    const target = TuningString(stringNumber: 1, midiNote: 69, label: 'A4');

    expect(target.targetFrequencyHz(centsOffset: 20), closeTo(445.1126, 0.001));
  });

  test('tuning snapshots own an immutable string list', () {
    final tuning = BuiltInTunings.dropD;

    expect(
      () => tuning.strings.add(
        const TuningString(stringNumber: 7, midiNote: 35, label: 'B1'),
      ),
      throwsUnsupportedError,
    );
  });
}
