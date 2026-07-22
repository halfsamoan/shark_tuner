import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Map<String, dynamic> session;
  late List<Map<String, dynamic>> recordings;

  setUpAll(() {
    final file = [
      File('tool/corpus/user_guitar_session_20260713.v1.json'),
      File(
        'packages/tuner_dsp/tool/corpus/'
        'user_guitar_session_20260713.v1.json',
      ),
    ].firstWhere((candidate) => candidate.existsSync());
    session = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    recordings = (session['recordings'] as List).cast<Map<String, dynamic>>();
  });

  test('records the uncalibrated capture and reference methods', () {
    expect(session['schemaVersion'], 1);
    expect(session['id'], 'user-guitar-samsung-sm-s926n-20260713-v1');
    expect(session['deviceModel'], 'Samsung SM-S926N');
    expect(session['sourceSampleRateHz'], 44100);
    expect(
      session['referenceKind'],
      'uncalibrated_mobile_tuner_nominal_center',
    );
    expect(session['referenceTunerPackage'], 'lior.hai.soundanalyzertest');
    expect(session['a4ReferenceHz'], 440);
  });

  test('maps all recordings to unique ASCII WAV slugs', () {
    expect(recordings, hasLength(19));
    final ids = recordings.map((item) => item['id'] as String).toSet();
    final outputs = recordings
        .map((item) => item['outputFile'] as String)
        .toSet();

    expect(ids, hasLength(19));
    expect(outputs, hasLength(19));
    expect(
      outputs,
      everyElement(
        matches(
          RegExp(r'^user-s[1-6]-[a-g](?:s|b)?[0-9]-(soft|medium|hard)\.wav$'),
        ),
      ),
    );
  });

  test('separates thirteen standard and six semitone-down recordings', () {
    expect(
      recordings.where((item) => item['offTuning'] == false),
      hasLength(13),
    );
    expect(recordings.where((item) => item['offTuning'] == true), hasLength(6));
  });

  test('corrects the mislabeled low string to E-flat 2', () {
    final recording = recordings.singleWhere(
      (item) => item['id'] == 'user-s6-eb2-hard',
    );

    expect(recording['midiNote'], 39);
    expect(recording['annotatedFrequencyHz'], 82);
    expect(recording['sourceLabelCorrection'], contains('E-flat 2'));
  });
}
