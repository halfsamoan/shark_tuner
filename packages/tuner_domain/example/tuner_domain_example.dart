import 'package:tuner_domain/tuner_domain.dart';

void main() {
  for (final string in BuiltInTunings.standardGuitar.strings) {
    // ignore: avoid_print
    print('${string.label}: ${string.targetFrequencyHz()} Hz');
  }
}
