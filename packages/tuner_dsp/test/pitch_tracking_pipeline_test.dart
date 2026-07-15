import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

import '../tool/support/pcm16_wave.dart';

void main() {
  group('PitchTrackingPipeline', () {
    test('applies clarity gate before octave sanity and stabilization', () {
      final pipeline = PitchTrackingPipeline(
        targetFrequenciesHz: const [233.08188075904496],
      );

      final frame = pipeline.process(_estimate(116.54094, clarity: 0.89));

      expect(frame.confidenceAccepted, isFalse);
      expect(frame.targetAssistedConfidence, isFalse);
      expect(frame.octaveSanity, isNull);
      expect(frame.stabilized, isNull);
    });

    test('recovers a weak estimate only when it is near a known target', () {
      final assisted = PitchTrackingPipeline(targetFrequenciesHz: const [110]);
      final unanchored = PitchTrackingPipeline(targetFrequenciesHz: const []);

      final first = assisted.process(_estimate(110.5, clarity: 0.84));
      final second = assisted.process(_estimate(110.4, clarity: 0.85));
      final rejected = unanchored.process(_estimate(110.5, clarity: 0.84));

      expect(first.confidenceAccepted, isTrue);
      expect(first.targetAssistedConfidence, isTrue);
      expect(first.stabilized, isNull);
      expect(second.stabilized, isNotNull);
      expect(rejected.confidenceAccepted, isFalse);
    });

    test(
      'does not promote a truly octave-low D3 to the target at cold start',
      () {
        final d3Hz = _midiFrequencies([50]).single;
        final pipeline = PitchTrackingPipeline(
          targetFrequenciesHz: _midiFrequencies([40, 45, 50, 55, 59, 64]),
        );

        PitchTrackingFrame? frame;
        for (var index = 0; index < 3; index++) {
          frame = pipeline.process(_estimate(d3Hz / 2));
        }

        expect(frame!.octaveSanity!.kind, OctaveCorrectionKind.none);
        expect(frame.octaveSanity!.frequencyMultiplier, 1);
        expect(frame.stabilized, isNotNull);
        expect(frame.stabilized!.frequencyHz, closeTo(d3Hz / 2, 0.01));
      },
    );

    test('uses a recent stable anchor for an f/2 detector error', () {
      final pipeline = PitchTrackingPipeline(
        targetFrequenciesHz: _midiFrequencies([39, 44, 49, 54, 58, 63]),
      );

      for (var index = 0; index < 3; index++) {
        pipeline.process(_estimate(233.08188));
      }

      final frame = pipeline.process(_estimate(116.54094));

      expect(frame.octaveSanity!.kind, OctaveCorrectionKind.rawHalfFrequency);
      expect(frame.octaveSanity!.anchor, OctaveSanityAnchor.previousStable);
      expect(frame.octaveSanity!.frequencyMultiplier, 2);
      expect(
        frame.octaveSanity!.estimate.frequencyHz,
        closeTo(233.08188, 0.01),
      );
    });

    test('expires the previous-stable octave anchor after silence', () {
      final pipeline = PitchTrackingPipeline(targetFrequenciesHz: const []);
      for (var index = 0; index < 3; index++) {
        pipeline.process(_estimate(110));
      }
      for (var index = 0; index < 3; index++) {
        pipeline.process(null);
      }

      final frame = pipeline.process(_estimate(55));

      expect(frame.octaveSanity!.kind, OctaveCorrectionKind.none);
      expect(frame.octaveSanity!.anchor, OctaveSanityAnchor.none);
    });

    test(
      'corrects a 2f estimate and leaves an on-target estimate unchanged',
      () {
        final pipeline = PitchTrackingPipeline(
          targetFrequenciesHz: const [110],
        );

        final doubled = pipeline.process(_estimate(220));
        final onTarget = pipeline.process(_estimate(110));

        expect(
          doubled.octaveSanity!.kind,
          OctaveCorrectionKind.rawDoubleFrequency,
        );
        expect(doubled.octaveSanity!.estimate.frequencyHz, closeTo(110, 0.001));
        expect(onTarget.octaveSanity!.kind, OctaveCorrectionKind.none);
        expect(
          onTarget.octaveSanity!.estimate.frequencyHz,
          closeTo(110, 0.001),
        );
      },
    );

    test(
      'corrects an unambiguous third harmonic without stealing a string',
      () {
        final unambiguous = PitchTrackingPipeline(
          targetFrequenciesHz: const [110],
        );
        final sixStringAmbiguity = PitchTrackingPipeline(
          targetFrequenciesHz: const [82.4069, 246.9417],
        );

        final harmonic = unambiguous.process(_estimate(330));
        final realHighString = sixStringAmbiguity.process(_estimate(246.9417));

        expect(
          harmonic.octaveSanity!.kind,
          OctaveCorrectionKind.rawTripleFrequency,
        );
        expect(
          harmonic.octaveSanity!.frequencyMultiplier,
          closeTo(1 / 3, 1e-9),
        );
        expect(harmonic.octaveSanity!.estimate.frequencyHz, closeTo(110, .001));
        expect(realHighString.octaveSanity!.kind, OctaveCorrectionKind.none);
      },
    );

    test('uses the previous stable estimate when no target is available', () {
      final pipeline = PitchTrackingPipeline(targetFrequenciesHz: const []);
      for (var index = 0; index < 3; index++) {
        pipeline.process(_estimate(110));
      }

      final frame = pipeline.process(_estimate(220));

      expect(frame.octaveSanity!.kind, OctaveCorrectionKind.rawDoubleFrequency);
      expect(frame.octaveSanity!.anchor, OctaveSanityAnchor.previousStable);
    });
  });

  test(
    'user-s2-bb3-hard never emits an octave through the product pipeline',
    () {
      final manifestFile = _workspaceFile(
        'packages/tuner_dsp/test/fixtures/public/manifest.public.v1.json',
      );
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final fixture = (manifest['fixtures'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((item) => item['id'] == 'user-s2-bb3-hard');
      final waveFile = File.fromUri(
        manifestFile.parent.uri.resolve(fixture['file'] as String),
      );
      final wave = decodePcm16Wave(waveFile.readAsBytesSync());
      final detector = MpmDetector();
      final pipeline = PitchTrackingPipeline(
        targetFrequenciesHz: _midiFrequencies([39, 44, 49, 54, 58, 63]),
      );
      final nominalHz = (fixture['nominalFrequencyHz'] as num).toDouble();
      final windowSamples = fixture['windowSamples'] as int;
      final hopSamples = TunerDspConfig.hopSize;
      final stableStart =
          ((fixture['stableStartMs'] as int) * wave.sampleRateHz / 1000)
              .round();
      final stableEnd =
          ((fixture['stableEndMs'] as int) * wave.sampleRateHz / 1000).round();
      var rawHalfFrequencyCount = 0;
      var rawDoubleFrequencyCount = 0;
      var productOctaveCount = 0;
      var correctionCount = 0;
      final correctionTimesMs = <double>[];

      for (
        var offset = stableStart;
        offset + windowSamples <= stableEnd;
        offset += hopSamples
      ) {
        final raw = detector.detect(
          Float64List.sublistView(
            wave.monoSamples,
            offset,
            offset + windowSamples,
          ),
          sampleRate: wave.sampleRateHz.toDouble(),
        );
        if (raw != null) {
          final ratio = raw.frequencyHz / nominalHz;
          if (ratio >= 0.48 && ratio <= 0.52) {
            rawHalfFrequencyCount++;
          } else if (ratio >= 1.9 && ratio <= 2.1) {
            rawDoubleFrequencyCount++;
          }
        }
        final frame = pipeline.process(raw);
        if (frame.octaveSanity?.corrected ?? false) {
          correctionCount++;
          correctionTimesMs.add(offset * 1000 / wave.sampleRateHz);
          expect(raw!.clarity, greaterThanOrEqualTo(0.9));
        }
        final product = frame.stabilized;
        if (product != null) {
          final ratio = product.frequencyHz / nominalHz;
          if ((ratio >= 0.48 && ratio <= 0.52) ||
              (ratio >= 1.9 && ratio <= 2.1)) {
            productOctaveCount++;
          }
        }
      }

      expect(rawHalfFrequencyCount, 0);
      expect(rawDoubleFrequencyCount, greaterThan(0));
      expect(correctionCount, rawDoubleFrequencyCount);
      expect(correctionTimesMs, everyElement(greaterThanOrEqualTo(600)));
      expect(productOctaveCount, 0);
    },
  );

  test(
    'low C-sharp keeps note identity while recovering weak stable frames',
    () {
      final manifestFile = _workspaceFile(
        'packages/tuner_dsp/test/fixtures/public/manifest.public.v1.json',
      );
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final fixture = (manifest['fixtures'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere(
            (item) =>
                item['id'] ==
                'nsynth-low-48k-m37-v100-guitar_acoustic_015-037-100',
          );
      final waveFile = File.fromUri(
        manifestFile.parent.uri.resolve(fixture['file'] as String),
      );
      final wave = decodePcm16Wave(waveFile.readAsBytesSync());
      final nominalHz = (fixture['nominalFrequencyHz'] as num).toDouble();
      final windowSamples = fixture['windowSamples'] as int;
      final stableStart =
          ((fixture['stableStartMs'] as int) * wave.sampleRateHz / 1000)
              .round();
      final stableEnd =
          ((fixture['stableEndMs'] as int) * wave.sampleRateHz / 1000).round();
      final detector = MpmDetector();
      final pipeline = PitchTrackingPipeline(targetFrequenciesHz: [nominalHz]);
      final emittedCents = <double>[];
      final rawFrames = <String>[];
      var attempted = 0;

      for (
        var offset = stableStart;
        offset + windowSamples <= stableEnd;
        offset += TunerDspConfig.lowTuningHopSize
      ) {
        attempted++;
        final raw = detector.detect(
          Float64List.sublistView(
            wave.monoSamples,
            offset,
            offset + windowSamples,
          ),
          sampleRate: wave.sampleRateHz.toDouble(),
        );
        final frame = pipeline.process(raw);
        final product = frame.stabilized;
        rawFrames.add(
          '${raw?.clarity.toStringAsFixed(3)}:'
          '${raw?.centsFrom(nominalHz).toStringAsFixed(1)}:'
          '${frame.confidenceAccepted}',
        );
        if (product != null) {
          emittedCents.add(
            1200 * math.log(product.frequencyHz / nominalHz) / math.ln2,
          );
        }
      }

      expect(attempted, 57);
      expect(
        emittedCents.length / attempted,
        greaterThanOrEqualTo(.9),
        reason: rawFrames.join(', '),
      );
      expect(
        emittedCents.where((cents) => cents.abs() > 50),
        isEmpty,
        reason: emittedCents
            .map((value) => value.toStringAsFixed(1))
            .join(', '),
      );
    },
  );
}

PitchEstimate _estimate(double frequencyHz, {double clarity = 0.95}) {
  return PitchEstimate(
    frequencyHz: frequencyHz,
    clarity: clarity,
    periodSamples: TunerDspConfig.sampleRateHz / frequencyHz,
  );
}

List<double> _midiFrequencies(List<int> notes) {
  return [
    for (final note in notes) 440 * math.pow(2, (note - 69) / 12).toDouble(),
  ];
}

File _workspaceFile(String relativePath) {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File('${directory.path}/$relativePath');
    if (candidate.existsSync()) {
      return candidate;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Could not find workspace file: $relativePath');
    }
    directory = parent;
  }
}
