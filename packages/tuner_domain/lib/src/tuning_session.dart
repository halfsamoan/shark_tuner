import 'dart:math' as math;

import 'tuning_definition.dart';

final class AutomaticStringSelectorConfig {
  const AutomaticStringSelectorConfig({
    this.maximumDeviationCents = 200,
    this.switchAdvantageCents = 25,
    this.switchConfirmationFrames = 2,
  }) : assert(maximumDeviationCents > 0),
       assert(switchAdvantageCents >= 0),
       assert(switchConfirmationFrames > 0);

  final double maximumDeviationCents;
  final double switchAdvantageCents;
  final int switchConfirmationFrames;
}

final class StringSelection {
  const StringSelection({
    required this.target,
    required this.targetFrequencyHz,
    required this.cents,
  });

  final TuningString target;
  final double targetFrequencyHz;
  final double cents;
}

/// Chooses a physical string while requiring repeated evidence before a switch.
final class AutomaticStringSelector {
  AutomaticStringSelector({
    this.config = const AutomaticStringSelectorConfig(),
  });

  final AutomaticStringSelectorConfig config;
  String? _tuningKey;
  TuningString? _selected;
  int? _pendingStringNumber;
  int _pendingFrames = 0;

  StringSelection? update({
    required double frequencyHz,
    required TuningDefinition tuning,
  }) {
    if (!frequencyHz.isFinite || frequencyHz <= 0) {
      throw ArgumentError.value(frequencyHz, 'frequencyHz');
    }
    final tuningKey = _keyFor(tuning);
    if (_tuningKey != tuningKey) {
      reset();
      _tuningKey = tuningKey;
    }

    final nearest = _nearestTarget(frequencyHz, tuning);
    if (nearest.cents.abs() > config.maximumDeviationCents) {
      _clearPending();
      return null;
    }

    final selected = _selected;
    if (selected == null) {
      _selected = nearest.target;
      return _selectionFor(frequencyHz, nearest.target, tuning);
    }
    if (selected.stringNumber == nearest.target.stringNumber) {
      _clearPending();
      return _selectionFor(frequencyHz, selected, tuning);
    }

    final current = _selectionFor(frequencyHz, selected, tuning);
    final advantage = current.cents.abs() - nearest.cents.abs();
    if (advantage < config.switchAdvantageCents) {
      _clearPending();
      return current;
    }

    if (_pendingStringNumber == nearest.target.stringNumber) {
      _pendingFrames++;
    } else {
      _pendingStringNumber = nearest.target.stringNumber;
      _pendingFrames = 1;
    }
    if (_pendingFrames >= config.switchConfirmationFrames) {
      _selected = nearest.target;
      _clearPending();
      return _selectionFor(frequencyHz, nearest.target, tuning);
    }
    return current;
  }

  void reset() {
    _tuningKey = null;
    _selected = null;
    _clearPending();
  }

  ({TuningString target, double cents}) _nearestTarget(
    double frequencyHz,
    TuningDefinition tuning,
  ) {
    TuningString? best;
    var bestCents = double.infinity;
    for (final target in tuning.strings) {
      final targetHz = _targetFrequency(target, tuning);
      final cents = _centsFrom(frequencyHz, targetHz);
      if (cents.abs() < bestCents.abs()) {
        best = target;
        bestCents = cents;
      }
    }
    return (target: best!, cents: bestCents);
  }

  StringSelection _selectionFor(
    double frequencyHz,
    TuningString target,
    TuningDefinition tuning,
  ) {
    final targetHz = _targetFrequency(target, tuning);
    return StringSelection(
      target: target,
      targetFrequencyHz: targetHz,
      cents: _centsFrom(frequencyHz, targetHz),
    );
  }

  double _targetFrequency(TuningString target, TuningDefinition tuning) {
    return target.targetFrequencyHz(
      referenceA4Hz: tuning.referenceA4Hz,
      centsOffset: tuning.centsOffset,
    );
  }

  void _clearPending() {
    _pendingStringNumber = null;
    _pendingFrames = 0;
  }
}

final class InTuneLockConfig {
  const InTuneLockConfig({
    this.toleranceCents = 3,
    this.releaseToleranceCents = 5,
    this.holdDuration = const Duration(milliseconds: 750),
  }) : assert(toleranceCents > 0),
       assert(releaseToleranceCents >= toleranceCents);

  final double toleranceCents;
  final double releaseToleranceCents;
  final Duration holdDuration;
}

final class InTuneLockState {
  const InTuneLockState({
    required this.locked,
    required this.withinTolerance,
    required this.progress,
  });

  final bool locked;
  final bool withinTolerance;
  final double progress;
}

/// Tracks a continuous in-tune interval and keeps a wider release hysteresis.
final class InTuneLockTracker {
  InTuneLockTracker({this.config = const InTuneLockConfig()});

  final InTuneLockConfig config;
  Duration? _lastTimestamp;
  Duration? _withinSince;
  bool _locked = false;

  InTuneLockState update({required double cents, required Duration timestamp}) {
    if (!cents.isFinite) {
      throw ArgumentError.value(cents, 'cents');
    }
    final previousTimestamp = _lastTimestamp;
    if (previousTimestamp != null && timestamp < previousTimestamp) {
      throw ArgumentError.value(timestamp, 'timestamp', 'Must be monotonic.');
    }
    _lastTimestamp = timestamp;

    final absoluteCents = cents.abs();
    final withinTolerance = absoluteCents <= config.toleranceCents;
    if (_locked) {
      if (absoluteCents > config.releaseToleranceCents) {
        _locked = false;
        _withinSince = withinTolerance ? timestamp : null;
      }
    } else if (withinTolerance) {
      _withinSince ??= timestamp;
      if (timestamp - _withinSince! >= config.holdDuration) {
        _locked = true;
      }
    } else {
      _withinSince = null;
    }

    return InTuneLockState(
      locked: _locked,
      withinTolerance: withinTolerance,
      progress: _progressAt(timestamp),
    );
  }

  void reset() {
    _lastTimestamp = null;
    _withinSince = null;
    _locked = false;
  }

  double _progressAt(Duration timestamp) {
    if (_locked) {
      return 1;
    }
    final since = _withinSince;
    if (since == null) {
      return 0;
    }
    if (config.holdDuration == Duration.zero) {
      return 1;
    }
    return ((timestamp - since).inMicroseconds /
            config.holdDuration.inMicroseconds)
        .clamp(0, 1)
        .toDouble();
  }
}

final class TuneUpProgressState {
  TuneUpProgressState({
    required Set<int> lockedStringNumbers,
    required this.expectedStringCount,
    required this.elapsed,
  }) : lockedStringNumbers = Set.unmodifiable(lockedStringNumbers);

  final Set<int> lockedStringNumbers;
  final int expectedStringCount;
  final Duration elapsed;

  int get lockedStringCount => lockedStringNumbers.length;
  bool get isComplete => lockedStringCount == expectedStringCount;
}

/// Records the first in-tune lock for each physical string in one tune-up.
///
/// The caller owns the monotonic clock, allowing the same tracker to be used
/// in production with a [Stopwatch] and in deterministic usability tests.
final class TuneUpProgressTracker {
  TuneUpProgressTracker({required Iterable<int> expectedStringNumbers})
    : _expectedStringNumbers = Set.unmodifiable(expectedStringNumbers) {
    if (_expectedStringNumbers.isEmpty ||
        _expectedStringNumbers.any((number) => number <= 0)) {
      throw ArgumentError.value(
        expectedStringNumbers,
        'expectedStringNumbers',
        'Must contain positive physical string numbers.',
      );
    }
  }

  final Set<int> _expectedStringNumbers;
  final Set<int> _lockedStringNumbers = {};
  Duration _lastElapsed = Duration.zero;
  Duration? _completedElapsed;

  TuneUpProgressState get state => TuneUpProgressState(
    lockedStringNumbers: _lockedStringNumbers,
    expectedStringCount: _expectedStringNumbers.length,
    elapsed: _completedElapsed ?? _lastElapsed,
  );

  TuneUpProgressState recordLock({
    required int stringNumber,
    required Duration elapsed,
  }) {
    if (!_expectedStringNumbers.contains(stringNumber)) {
      throw ArgumentError.value(
        stringNumber,
        'stringNumber',
        'Not present in the active tuning.',
      );
    }
    if (elapsed < _lastElapsed) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Must be monotonic.');
    }
    if (_completedElapsed != null) {
      return state;
    }

    _lastElapsed = elapsed;
    _lockedStringNumbers.add(stringNumber);
    if (_lockedStringNumbers.length == _expectedStringNumbers.length) {
      _completedElapsed = elapsed;
    }
    return state;
  }
}

String _keyFor(TuningDefinition tuning) {
  final strings = tuning.strings
      .map((target) => '${target.stringNumber}:${target.midiNote}')
      .join(',');
  return '${tuning.id}@${tuning.version}/${tuning.referenceA4Hz}/'
      '${tuning.centsOffset}/$strings';
}

double _centsFrom(double frequencyHz, double referenceHz) {
  return 1200 * math.log(frequencyHz / referenceHz) / math.ln2;
}
