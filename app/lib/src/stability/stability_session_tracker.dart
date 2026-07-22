import 'package:tuner_domain/tuner_domain.dart';
import 'package:tuner_dsp/tuner_dsp.dart';

import '../tuner/live_tuner_engine.dart';

final class StabilitySessionTracker {
  StabilitySessionTracker({
    required this.stringNumber,
    this.trackDuration = const Duration(milliseconds: 2500),
    this.maximumPlucks = 5,
    this._analyzer = const PluckAnalyzer(),
  }) {
    if (stringNumber <= 0) {
      throw ArgumentError.value(stringNumber, 'stringNumber');
    }
    if (maximumPlucks < 3) {
      throw ArgumentError.value(maximumPlucks, 'maximumPlucks');
    }
  }

  final int stringNumber;
  final Duration trackDuration;
  final int maximumPlucks;
  final PluckAnalyzer _analyzer;
  final List<StabilityPluckObservation> _observations = [];
  final List<PluckPitchFrame> _frames = [];
  int? _activeOnsetSequence;
  Duration? _activeOnsetPosition;
  Duration? _lastFramePosition;
  double? _previousSteadyPitchCents;
  PluckRejectionReason? _lastRejectionReason;
  int? _heardOtherStringNumber;

  List<StabilityPluckObservation> get observations =>
      List.unmodifiable(_observations);
  int get completedPluckCount => _observations.length;
  bool get isCapturing => _activeOnsetSequence != null;
  bool get isComplete => completedPluckCount >= maximumPlucks;
  int? get heardOtherStringNumber => _heardOtherStringNumber;
  PluckRejectionReason? get lastRejectionReason => _lastRejectionReason;
  StabilityAssessment get assessment =>
      StabilityClassifier.assess(_observations);

  bool consume(LiveTunerState state) {
    var changed = false;
    final heardOther = state.heardTarget?.stringNumber;
    if (heardOther != null && heardOther != stringNumber) {
      changed = _heardOtherStringNumber != heardOther || changed;
      _heardOtherStringNumber = heardOther;
    } else if (state.freshOnset) {
      changed = _heardOtherStringNumber != null || changed;
      _heardOtherStringNumber = null;
    }

    if (state.freshOnset &&
        state.onsetPosition != null &&
        state.onsetSequence != _activeOnsetSequence) {
      changed = _finishActiveTrack() || changed;
      if (!isComplete) {
        _activeOnsetSequence = state.onsetSequence;
        _activeOnsetPosition = state.onsetPosition;
        _lastFramePosition = null;
        _frames.clear();
        changed = true;
      }
    }

    final onsetPosition = _activeOnsetPosition;
    final audioPosition = state.audioPosition;
    if (onsetPosition == null || audioPosition == null || isComplete) {
      return changed;
    }
    final elapsed = audioPosition - onsetPosition;
    if (elapsed.isNegative) {
      return changed;
    }
    if (elapsed > trackDuration) {
      return _finishActiveTrack() || changed;
    }
    if (_lastFramePosition == audioPosition) {
      return changed;
    }
    final rmsDb = state.rmsDb;
    _frames.add(
      PluckPitchFrame(
        elapsed: elapsed,
        cents: state.rawCents,
        rmsDb: rmsDb == null || !rmsDb.isFinite ? -120 : rmsDb,
        clarity: (state.rawClarity ?? 0).clamp(0, 1),
      ),
    );
    _lastFramePosition = audioPosition;
    return true;
  }

  bool finishPending() => _finishActiveTrack();

  void reset() {
    _observations.clear();
    _frames.clear();
    _activeOnsetSequence = null;
    _activeOnsetPosition = null;
    _lastFramePosition = null;
    _previousSteadyPitchCents = null;
    _lastRejectionReason = null;
    _heardOtherStringNumber = null;
  }

  bool _finishActiveTrack() {
    if (_activeOnsetSequence == null) {
      return false;
    }
    final outcome = _analyzer.analyze(_frames);
    final analysis = outcome.analysis;
    if (analysis == null) {
      _lastRejectionReason = outcome.rejectionReason;
      _observations.add(
        StabilityPluckObservation(
          stringNumber: stringNumber,
          attackOvershootCents: 0,
          settleTime: Duration.zero,
          steadyStateDriftCentsPerSecond: 0,
          interPluckDriftCents: null,
          postAdjustmentStepObserved: false,
          peakRmsDb: _peakRmsDbOrFloor(),
          confidence: 0,
          validFrameRatio: 0,
        ),
      );
    } else {
      final previous = _previousSteadyPitchCents;
      _observations.add(
        StabilityPluckObservation(
          stringNumber: stringNumber,
          attackOvershootCents: analysis.attackOvershootCents,
          settleTime: analysis.settleTime,
          steadyStateDriftCentsPerSecond:
              analysis.steadyStateDriftCentsPerSecond,
          interPluckDriftCents: previous == null
              ? null
              : analysis.steadyStatePitchCents - previous,
          postAdjustmentStepObserved: false,
          peakRmsDb: analysis.peakRmsDb,
          confidence: analysis.confidence,
          validFrameRatio: analysis.validFrameRatio,
        ),
      );
      _previousSteadyPitchCents = analysis.steadyStatePitchCents;
      _lastRejectionReason = null;
    }
    _frames.clear();
    _activeOnsetSequence = null;
    _activeOnsetPosition = null;
    _lastFramePosition = null;
    return true;
  }

  double _peakRmsDbOrFloor() {
    if (_frames.isEmpty) {
      return -120;
    }
    return _frames
        .map((frame) => frame.rmsDb)
        .reduce((left, right) => left > right ? left : right);
  }
}
