import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'corpus_preparation.dart';

const _toolVersion = '1.0.0';

Future<int> runCorpusPreparation(
  List<String> arguments, {
  required Directory rootDirectory,
}) async {
  final options = _CorpusOptions.parse(arguments, rootDirectory: rootDirectory);
  if (options.showHelp) {
    stdout.writeln(_usage);
    return 0;
  }
  final outputDirectory = options.outputDirectory;
  outputDirectory.createSync(recursive: true);

  final sourceHashes = <String, String>{};
  final fixtures = <Map<String, Object?>>[];
  fixtures.addAll(
    await _prepareGuitarTechs(options: options, sourceHashes: sourceHashes),
  );
  fixtures.addAll(
    await _prepareNsynth(options: options, sourceHashes: sourceHashes),
  );
  fixtures.sort(
    (left, right) => (left['id'] as String).compareTo(right['id'] as String),
  );
  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'profile': options.profile.name,
    'generatedBy': 'tool/prepare_corpus.dart',
    'toolVersion': _toolVersion,
    'groundTruthPolicy': {
      'referenceKind': 'nominal_midi_note',
      'subCentGroundTruth': false,
      'allowedUses': [
        'valid-estimate rate',
        'octave-error rate',
        'nominal-note deviation',
        'stable-frame self-consistency',
      ],
    },
    'datasets': [
      {
        'id': 'guitartechs-v1',
        'title': 'Guitar-TECHS',
        'license': 'CC BY 4.0',
        'sourceUrl': 'https://zenodo.org/records/14963133',
        'archiveMd5': {
          'P1_singlenotes.zip': 'ca0c4674dde3805574685a313f7c39eb',
          'P2_singlenotes.zip': '40fbf03d8b04bb2cf42df20f36dc2254',
        },
      },
      {
        'id': 'nsynth-test',
        'title': 'NSynth Dataset test split',
        'license': 'CC BY 4.0',
        'sourceUrl': 'https://magenta.withgoogle.com/datasets/nsynth',
      },
    ],
    'fixtureCount': fixtures.length,
    'fixtures': fixtures,
  };
  final manifestFile = File(
    _join(outputDirectory.path, 'manifest.public.v1.json'),
  );
  manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  stdout.writeln(
    jsonEncode({
      'status': 'complete',
      'profile': options.profile.name,
      'fixtureCount': fixtures.length,
      'manifest': manifestFile.absolute.path,
    }),
  );
  return 0;
}

Future<List<Map<String, Object?>>> _prepareGuitarTechs({
  required _CorpusOptions options,
  required Map<String, String> sourceHashes,
}) async {
  final guitarRoot = Directory(_join(options.sourceRoot.path, 'guitar-techs'));
  if (!guitarRoot.existsSync()) {
    throw StateError(
      'Guitar-TECHS source directory is missing: ${guitarRoot.path}',
    );
  }
  final performances = [
    _GuitarPerformance(
      id: 'P1',
      midiFile: File(
        _join(
          guitarRoot.path,
          'P1_singlenotes',
          'P1_singlenotes',
          'midi',
          'midi_allsinglenotes.mid',
        ),
      ),
      diFile: File(
        _join(
          guitarRoot.path,
          'P1_singlenotes',
          'P1_singlenotes',
          'audio',
          'directinput',
          'directinput_allsinglenotes.wav',
        ),
      ),
      ampFile: File(
        _join(
          guitarRoot.path,
          'P1_singlenotes',
          'P1_singlenotes',
          'audio',
          'micamp',
          'micamp_allsinglenotes.wav',
        ),
      ),
    ),
    _GuitarPerformance(
      id: 'P2',
      midiFile: File(
        _join(
          guitarRoot.path,
          'P2_singlenotes',
          'P2_singlenotes',
          'midi',
          'midi_allsinglenotes.mid',
        ),
      ),
      diFile: File(
        _join(
          guitarRoot.path,
          'P2_singlenotes',
          'P2_singlenotes',
          'audio',
          'directinput',
          'directinput_allsinglenotes.wav',
        ),
      ),
      ampFile: File(
        _join(
          guitarRoot.path,
          'P2_singlenotes',
          'P2_singlenotes',
          'audio',
          'micamp',
          'micamp_allsinglenotes.wav',
        ),
      ),
    ),
  ];
  final fixtures = <Map<String, Object?>>[];
  for (final performance in performances) {
    _requireFiles([
      performance.midiFile,
      performance.diFile,
      performance.ampFile,
    ]);
    final allNotes = parseMidiNotes(performance.midiFile.readAsBytesSync());
    final notes = options.profile == _CorpusProfile.full
        ? allNotes
        : _selectGuitarTechsCiNotes(performance.id, allNotes);
    for (final source in [
      (kind: 'di', file: performance.diFile),
      (kind: 'amp', file: performance.ampFile),
    ]) {
      final reader = PcmWaveFileReader(source.file);
      try {
        if (reader.sampleRateHz != 48000) {
          throw StateError(
            '${source.file.path} uses ${reader.sampleRateHz} Hz, expected 48000 Hz.',
          );
        }
        var channelReason = 'mono_source';
        if (reader.channelCount > 1) {
          if (reader.channelCount != 2 || !reader.channelsAreIdentical(0, 1)) {
            throw StateError(
              '${source.file.path} has non-identical stereo channels; '
              'an explicit channel policy is required.',
            );
          }
          channelReason =
              'stereo_channels_verified_identical_channel_0_selected';
        }
        final sourceHash = await _cachedHash(source.file, sourceHashes);
        for (final note in notes) {
          final eventIndex = allNotes.indexOf(note);
          final clip = _extractAlignedClip(reader, note);
          final id =
              'guitartechs-${source.kind}-${performance.id.toLowerCase()}-'
              '${eventIndex.toString().padLeft(3, '0')}-m${note.midiNote}-v${note.velocity}';
          final relativeOutput = _forwardSlash(
            _join('audio', 'guitartechs-${source.kind}', '$id.wav'),
          );
          final outputFile = File(
            _joinParts([
              options.outputDirectory.path,
              ...relativeOutput.split('/'),
            ]),
          );
          outputFile.parent.createSync(recursive: true);
          outputFile.writeAsBytesSync(
            encodePcm16Wave(clip.samples, sampleRateHz: reader.sampleRateHz),
          );
          fixtures.add({
            'id': id,
            'file': relativeOutput,
            'corpusClass': 'guitartechs-${source.kind}',
            'dataset': 'guitartechs-v1',
            'license': 'CC BY 4.0',
            'sourceUrl': 'https://zenodo.org/records/14963133',
            'sourceFile': _relativeSource(options.sourceRoot, source.file),
            'sourceSha256': sourceHash,
            'sourceSampleRateHz': reader.sampleRateHz,
            'sourceBitsPerSample': reader.bitsPerSample,
            'sourceChannelCount': reader.channelCount,
            'selectedChannel': 0,
            'channelSelectionReason': channelReason,
            'performance': performance.id,
            'midiEventIndex': eventIndex,
            'midiStartSeconds': note.startSeconds,
            'midiEndSeconds': note.endSeconds,
            'alignedAttackSeconds':
                clip.alignedAttackFrame / reader.sampleRateHz,
            'alignmentOffsetMs':
                (clip.alignedAttackFrame / reader.sampleRateHz -
                    note.startSeconds) *
                1000,
            'nominalMidi': note.midiNote,
            'nominalFrequencyHz': midiFrequencyHz(note.midiNote),
            'velocity': note.velocity,
            'referenceKind': 'nominal_midi_note_not_subcent_ground_truth',
            'outputSampleRateHz': reader.sampleRateHz,
            'outputBitsPerSample': 16,
            'stableStartMs': 300,
            'stableEndMs': 1400,
            'windowSamples': 4096,
            'transforms': [
              'midi_onset_with_energy_alignment_v1',
              'selected_channel_0',
              'pcm_${reader.bitsPerSample}_to_pcm_16',
              'clip_1500ms_attack_at_50ms',
            ],
            'outputSha256': await sha256File(outputFile),
          });
        }
      } finally {
        reader.close();
      }
    }
  }
  return fixtures;
}

List<MidiNote> _selectGuitarTechsCiNotes(
  String performanceId,
  List<MidiNote> notes,
) {
  if (performanceId == 'P1') {
    return selectRepresentativeNotes(
      notes,
      targetMidiNotes: const [40, 52, 76],
      targetVelocities: const [20, 80, 127],
    );
  }
  return selectRepresentativeNotes(
    notes,
    targetMidiNotes: const [45, 64],
    targetVelocities: const [50, 105],
  );
}

_AlignedClip _extractAlignedClip(PcmWaveFileReader reader, MidiNote note) {
  final expectedFrame = (note.startSeconds * reader.sampleRateHz).round();
  final searchBefore = (reader.sampleRateHz * 0.15).round();
  final searchAfter = (reader.sampleRateHz * 0.25).round();
  final searchStart = math.max(0, expectedFrame - searchBefore);
  final searchEnd = math.min(reader.frameCount, expectedFrame + searchAfter);
  final searchSamples = reader.readSamples(
    searchStart,
    searchEnd - searchStart,
  );
  final alignedLocal = alignAttackSample(
    searchSamples,
    sampleRateHz: reader.sampleRateHz,
    expectedSample: expectedFrame - searchStart,
  );
  final alignedFrame = searchStart + alignedLocal;
  final clipLead = (reader.sampleRateHz * 0.05).round();
  final clipStart = math.max(0, alignedFrame - clipLead);
  final requestedLength = (reader.sampleRateHz * 1.5).round();
  final clipLength = math.min(requestedLength, reader.frameCount - clipStart);
  if (clipLength < (reader.sampleRateHz * 1.4).round()) {
    throw StateError(
      'Guitar-TECHS note is too close to the end of the source.',
    );
  }
  return _AlignedClip(
    alignedAttackFrame: alignedFrame,
    samples: reader.readSamples(clipStart, clipLength),
  );
}

Future<List<Map<String, Object?>>> _prepareNsynth({
  required _CorpusOptions options,
  required Map<String, String> sourceHashes,
}) async {
  final nsynthRoot = Directory(
    _join(options.sourceRoot.path, 'datasets', 'low_guitar_43_82hz', 'nsynth'),
  );
  final manifestFile = File(_join(nsynthRoot.path, 'manifest.csv'));
  _requireFiles([manifestFile]);
  final allRows = _readNsynthManifest(manifestFile);
  final rows = options.profile == _CorpusProfile.full
      ? allRows
      : _selectNsynthCiRows(allRows);
  final fixtures = <Map<String, Object?>>[];
  for (final row in rows) {
    final sourceFile = File(_join(nsynthRoot.path, row.file));
    _requireFiles([sourceFile]);
    final reader = PcmWaveFileReader(sourceFile);
    try {
      if (reader.sampleRateHz != 16000 ||
          reader.channelCount != 1 ||
          reader.bitsPerSample != 16) {
        throw StateError('${sourceFile.path} must be mono PCM16 at 16000 Hz.');
      }
      final sourceSamples = reader.readSamples(0, reader.frameCount);
      final sourceHash = await _cachedHash(sourceFile, sourceHashes);
      for (final targetRate in const [16000, 48000]) {
        final corpusClass = 'nsynth-low-${targetRate ~/ 1000}k';
        final id =
            '$corpusClass-m${row.midi}-v${row.velocity}-${row.originalKey}';
        final relativeOutput = _forwardSlash(
          _join('audio', corpusClass, '$id.wav'),
        );
        final outputFile = File(
          _joinParts([
            options.outputDirectory.path,
            ...relativeOutput.split('/'),
          ]),
        );
        outputFile.parent.createSync(recursive: true);
        final outputSamples = targetRate == reader.sampleRateHz
            ? Float64List.fromList(sourceSamples)
            : resampleCubic(
                sourceSamples,
                sourceRateHz: reader.sampleRateHz,
                targetRateHz: targetRate,
              );
        outputFile.writeAsBytesSync(
          encodePcm16Wave(outputSamples, sampleRateHz: targetRate),
        );
        fixtures.add({
          'id': id,
          'file': relativeOutput,
          'corpusClass': corpusClass,
          'dataset': 'nsynth-test',
          'license': 'CC BY 4.0',
          'sourceUrl': 'https://magenta.withgoogle.com/datasets/nsynth',
          'sourceFile': _relativeSource(options.sourceRoot, sourceFile),
          'sourceSha256': sourceHash,
          'sourceSampleRateHz': reader.sampleRateHz,
          'sourceBitsPerSample': reader.bitsPerSample,
          'sourceChannelCount': reader.channelCount,
          'selectedChannel': 0,
          'channelSelectionReason': 'mono_source',
          'originalKey': row.originalKey,
          'instrumentSource': row.source,
          'instrumentFamily': row.family,
          'nominalMidi': row.midi,
          'nominalFrequencyHz': row.frequencyHz,
          'velocity': row.velocity,
          'referenceKind': 'nominal_midi_note_not_subcent_ground_truth',
          'outputSampleRateHz': targetRate,
          'outputBitsPerSample': 16,
          'stableStartMs': 500,
          'stableEndMs': 3500,
          'windowSamples': 8192,
          'transforms': [
            'selected_channel_0',
            'canonical_pcm_16_wave',
            if (targetRate != reader.sampleRateHz) 'cubic_hermite_resample_v1',
          ],
          'outputSha256': await sha256File(outputFile),
        });
      }
    } finally {
      reader.close();
    }
  }
  return fixtures;
}

List<_NsynthRow> _readNsynthManifest(File file) {
  final lines = const LineSplitter().convert(file.readAsStringSync());
  if (lines.isEmpty ||
      lines.first != 'file,original_key,midi,freq_hz,velocity,source,family') {
    throw const FormatException(
      'Unexpected NSynth low-guitar manifest header.',
    );
  }
  final rows = <_NsynthRow>[];
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) {
      continue;
    }
    final fields = line.split(',');
    if (fields.length != 7) {
      throw FormatException('Unexpected NSynth manifest row: $line');
    }
    rows.add(
      _NsynthRow(
        family: fields[6],
        file: fields[0],
        frequencyHz: double.parse(fields[3]),
        midi: int.parse(fields[2]),
        originalKey: fields[1],
        source: fields[5],
        velocity: int.parse(fields[4]),
      ),
    );
  }
  rows.sort((left, right) {
    final midiComparison = left.midi.compareTo(right.midi);
    if (midiComparison != 0) {
      return midiComparison;
    }
    final velocityComparison = left.velocity.compareTo(right.velocity);
    return velocityComparison != 0
        ? velocityComparison
        : left.file.compareTo(right.file);
  });
  return rows;
}

List<_NsynthRow> _selectNsynthCiRows(List<_NsynthRow> rows) {
  const targetMidi = [29, 31, 34, 37, 40];
  const targetVelocity = [25, 50, 75, 100, 127];
  final selected = <_NsynthRow>[];
  for (var index = 0; index < targetMidi.length; index++) {
    final candidates =
        rows.where((row) => row.midi == targetMidi[index]).toList()..sort((
          left,
          right,
        ) {
          final leftDistance = (left.velocity - targetVelocity[index]).abs();
          final rightDistance = (right.velocity - targetVelocity[index]).abs();
          final distanceComparison = leftDistance.compareTo(rightDistance);
          return distanceComparison != 0
              ? distanceComparison
              : left.file.compareTo(right.file);
        });
    if (candidates.isEmpty) {
      throw StateError(
        'NSynth manifest has no MIDI ${targetMidi[index]} sample.',
      );
    }
    selected.add(candidates.first);
  }
  return selected;
}

Future<String> _cachedHash(File file, Map<String, String> cache) async {
  final path = file.absolute.path;
  return cache[path] ??= await sha256File(file);
}

void _requireFiles(List<File> files) {
  for (final file in files) {
    if (!file.existsSync()) {
      throw StateError('Corpus source file is missing: ${file.path}');
    }
  }
}

String _relativeSource(Directory root, File file) {
  final rootPath = root.absolute.path.endsWith(Platform.pathSeparator)
      ? root.absolute.path
      : '${root.absolute.path}${Platform.pathSeparator}';
  final filePath = file.absolute.path;
  if (!filePath.toLowerCase().startsWith(rootPath.toLowerCase())) {
    throw StateError('${file.path} is outside ${root.path}.');
  }
  return _forwardSlash(filePath.substring(rootPath.length));
}

String _forwardSlash(String path) => path.replaceAll('\\', '/');

String _joinParts(Iterable<String> parts) => parts.join(Platform.pathSeparator);

String _join(
  String first, [
  String? second,
  String? third,
  String? fourth,
  String? fifth,
  String? sixth,
  String? seventh,
]) {
  final parts = [
    first,
    second,
    third,
    fourth,
    fifth,
    sixth,
    seventh,
  ].whereType<String>();
  return parts.join(Platform.pathSeparator);
}

const _usage = '''
Prepare licensed public guitar corpora for local analysis or CI fixtures.

Usage:
  dart run tool/prepare_corpus.dart --profile=ci
  dart run tool/prepare_corpus.dart --profile=full

Options:
  --profile=ci|full  ci selects 20 representative clips; full processes all.
  --source-root=DIR  Repository root containing datasets/ and guitar-techs/.
  --output=DIR       Override the generated output directory.
  --help             Show this help.
''';

enum _CorpusProfile { ci, full }

final class _CorpusOptions {
  const _CorpusOptions({
    required this.outputDirectory,
    required this.profile,
    required this.showHelp,
    required this.sourceRoot,
  });

  factory _CorpusOptions.parse(
    List<String> arguments, {
    required Directory rootDirectory,
  }) {
    var profile = _CorpusProfile.ci;
    var sourceRoot = rootDirectory.absolute;
    Directory? outputDirectory;
    var showHelp = false;
    for (final argument in arguments) {
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
      } else if (argument.startsWith('--profile=')) {
        final value = argument.substring('--profile='.length);
        profile = switch (value) {
          'ci' => _CorpusProfile.ci,
          'full' => _CorpusProfile.full,
          _ => throw ArgumentError.value(
            value,
            '--profile',
            'Expected ci or full.',
          ),
        };
      } else if (argument.startsWith('--source-root=')) {
        sourceRoot = Directory(
          argument.substring('--source-root='.length),
        ).absolute;
      } else if (argument.startsWith('--output=')) {
        outputDirectory = Directory(
          argument.substring('--output='.length),
        ).absolute;
      } else {
        throw ArgumentError.value(argument, 'argument', 'Unknown option.');
      }
    }
    outputDirectory ??= profile == _CorpusProfile.ci
        ? Directory(
            _join(
              rootDirectory.absolute.path,
              'packages',
              'tuner_dsp',
              'test',
              'fixtures',
              'public',
            ),
          )
        : Directory(
            _join(rootDirectory.absolute.path, 'reports', 'corpus', 'full'),
          );
    return _CorpusOptions(
      outputDirectory: outputDirectory,
      profile: profile,
      showHelp: showHelp,
      sourceRoot: sourceRoot,
    );
  }

  final Directory outputDirectory;
  final _CorpusProfile profile;
  final bool showHelp;
  final Directory sourceRoot;
}

final class _GuitarPerformance {
  const _GuitarPerformance({
    required this.ampFile,
    required this.diFile,
    required this.id,
    required this.midiFile,
  });

  final File ampFile;
  final File diFile;
  final String id;
  final File midiFile;
}

final class _AlignedClip {
  const _AlignedClip({required this.alignedAttackFrame, required this.samples});

  final int alignedAttackFrame;
  final Float64List samples;
}

final class _NsynthRow {
  const _NsynthRow({
    required this.family,
    required this.file,
    required this.frequencyHz,
    required this.midi,
    required this.originalKey,
    required this.source,
    required this.velocity,
  });

  final String family;
  final String file;
  final double frequencyHz;
  final int midi;
  final String originalKey;
  final String source;
  final int velocity;
}
