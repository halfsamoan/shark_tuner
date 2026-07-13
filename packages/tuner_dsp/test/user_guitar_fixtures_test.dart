import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/support/corpus_preparation.dart';
import '../tool/support/pcm16_wave.dart';

void main() {
  late File manifestFile;
  late List<Map<String, dynamic>> fixtures;

  setUpAll(() {
    manifestFile = [
      File('test/fixtures/public/manifest.public.v1.json'),
      File('packages/tuner_dsp/test/fixtures/public/manifest.public.v1.json'),
    ].firstWhere((candidate) => candidate.existsSync());
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    fixtures = (manifest['fixtures'] as List)
        .cast<Map<String, dynamic>>()
        .where((fixture) => fixture['corpusClass'] == 'user-guitar')
        .toList();
  });

  test('commits every user recording with explicit provenance', () {
    expect(fixtures, hasLength(19));
    expect(
      fixtures.where((fixture) => fixture['offTuning'] == true),
      hasLength(6),
    );
    expect(
      fixtures.where((fixture) => fixture['clippingDetected'] == true),
      hasLength(13),
    );
    expect(
      fixtures,
      everyElement(
        allOf(
          allOf(
            containsPair('dataset', 'user-guitar-samsung-sm-s926n-20260713-v1'),
            containsPair('rights', 'project_provided_user_recording'),
            containsPair('sourceExtension', '.mp3'),
            containsPair('detectedSourceContainer', 'RIFF/WAVE'),
            containsPair('sourceExtensionMatchesContainer', false),
            containsPair('recordingAppPackage', 'recorderpro.voicememos.audio'),
            containsPair(
              'recordingAppUrl',
              'https://play.google.com/store/apps/details?id=recorderpro.voicememos.audio',
            ),
          ),
          allOf(
            containsPair('referenceTunerPackage', 'lior.hai.soundanalyzertest'),
            containsPair(
              'referenceTunerUrl',
              'https://play.google.com/store/apps/details?id=lior.hai.soundanalyzertest',
            ),
            containsPair('a4ReferenceHz', 440),
            containsPair(
              'referenceKind',
              'uncalibrated_mobile_tuner_nominal_center',
            ),
          ),
        ),
      ),
    );
  });

  test('outputs deterministic 4.5 second mono PCM16 at 48 kHz', () async {
    for (final fixture in fixtures) {
      final file = File.fromUri(
        manifestFile.absolute.parent.uri.resolve(fixture['file'] as String),
      );
      final wave = decodePcm16Wave(file.readAsBytesSync());

      expect(wave.sampleRateHz, 48000, reason: fixture['id'] as String);
      expect(wave.sourceChannelCount, 1, reason: fixture['id'] as String);
      expect(
        wave.monoSamples,
        hasLength(216000),
        reason: fixture['id'] as String,
      );
      expect(
        await sha256File(file),
        fixture['outputSha256'],
        reason: fixture['id'] as String,
      );
    }
  });
}
