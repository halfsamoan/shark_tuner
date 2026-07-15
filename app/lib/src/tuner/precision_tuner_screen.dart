import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/app_preferences.dart';
import '../app/instrument_theme.dart';
import '../device/tuner_device_control.dart';
import '../instrument_setup/instrument_profile_store.dart';
import '../settings/app_settings.dart';
import '../stability/stability_check_screen.dart';
import '../tuning_history/tuning_history_model.dart';
import '../tuning_history/tuning_history_store.dart';
import '../ui/instrument_widgets.dart';
import '../ui/instrument_bottom_sheet.dart';
import '../ui/throttled_live_region.dart';
import 'live_tuner_engine.dart';
import 'reference_tone_player.dart';
import 'stage_mode_screen.dart';
import 'tuning_guidance.dart';

part 'precision_tuner_controls.dart';
part 'precision_tuner_setup.dart';
part 'precision_tuner_panels.dart';

enum TunerSkin { standard, clipping }

class PrecisionTunerScreen extends StatefulWidget {
  const PrecisionTunerScreen({
    super.key,
    required this.catalog,
    required this.tunerEngineFactory,
    required this.includeUnverifiedSongs,
    this.match,
    this.directTuning,
    this.directLabel = '바로 튜닝',
    this.openAppSettings = openToaunerAppSettings,
    this.setScreenAwake = setToaunerScreenAwake,
    this.loadInstrumentProfile = loadInstrumentPegProfile,
    this.saveInstrumentProfile = saveInstrumentPegProfile,
    this.referenceTonePlayerFactory = createReferenceTonePlayer,
    this.recordTuningHistory = recordTuningHistoryEntry,
    this.tuningHistoryNow = DateTime.now,
  }) : assert(
         (match == null) != (directTuning == null),
         'Provide exactly one of match or directTuning.',
       );

  final SongTuningMatch? match;
  final TuningDefinition? directTuning;
  final String directLabel;
  final SongCatalog catalog;
  final TunerEngineFactory tunerEngineFactory;
  final bool includeUnverifiedSongs;
  final AppSettingsLauncher openAppSettings;
  final ScreenAwakeSetter setScreenAwake;
  final InstrumentProfileLoader loadInstrumentProfile;
  final InstrumentProfileSaver saveInstrumentProfile;
  final ReferenceTonePlayerFactory referenceTonePlayerFactory;
  final TuningHistoryRecorder recordTuningHistory;
  final DateTime Function() tuningHistoryNow;

  TuningDefinition get tuning => match?.tuning ?? directTuning!;
  SongTuningRecord? get song => match?.song;
  String get sessionLabel => song?.title ?? directLabel;

  @override
  State<PrecisionTunerScreen> createState() => _PrecisionTunerScreenState();
}

class _PrecisionTunerScreenState extends State<PrecisionTunerScreen> {
  var _selectedIndex = 0;
  var _manualTarget = false;
  var _coarseMode = false;
  var _completionShown = false;
  var _historyRecorded = false;
  var _stabilityCheckOpen = false;
  var _needsMicrophonePrimer = false;
  var _checkingMicrophonePermission = true;
  var _referenceTonePlaying = false;
  var _referenceToneBusy = false;
  var _resumeInputAfterReferenceTone = false;
  var _inputSessionStarted = false;
  double? _displayCents;
  int? _celebratingStringNumber;
  InstrumentPegProfile? _instrumentProfile;
  var _instrumentProfileLoaded = false;
  final Map<int, PegDirectionMonitor> _pegDirectionMonitors = {};
  _PendingPegObservation? _pendingPegObservation;
  int? _flipSuggestedStringNumber;
  Timer? _autoAdvanceTimer;
  late final TunerEngine _engine;
  late final ReferenceTonePlayer _referenceTonePlayer;
  late final StreamSubscription<LiveTunerState> _engineSubscription;
  late final Stopwatch _tuneUpStopwatch;
  late final TuneUpProgressTracker _tuneUpTracker;
  late LiveTunerState _liveState;

  @override
  void initState() {
    super.initState();
    _engine = widget.tunerEngineFactory();
    _referenceTonePlayer = widget.referenceTonePlayerFactory();
    _liveState = _engine.current;
    _updateDisplayCents(_liveState.cents);
    _tuneUpStopwatch = Stopwatch();
    _tuneUpTracker = TuneUpProgressTracker(
      expectedStringNumbers: widget.tuning.strings.map(
        (string) => string.stringNumber,
      ),
    );
    _engineSubscription = _engine.states.listen(_handleEngineState);
    unawaited(widget.setScreenAwake(true));
    unawaited(_loadInstrumentProfile());
    unawaited(_prepareInput());
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _tuneUpStopwatch.stop();
    unawaited(_engineSubscription.cancel());
    unawaited(_referenceTonePlayer.dispose());
    unawaited(_engine.dispose());
    unawaited(widget.setScreenAwake(false));
    super.dispose();
  }

  TuningString get _selected => widget.tuning.strings[_selectedIndex];

  double get _targetHz => _selected.targetFrequencyHz(
    referenceA4Hz: widget.tuning.referenceA4Hz,
    centsOffset: widget.tuning.centsOffset,
  );

  InstrumentPegProfile? get _activeInstrumentProfile {
    final profile = _instrumentProfile;
    return profile?.stringCount == widget.tuning.strings.length
        ? profile
        : null;
  }

  Future<void> _loadInstrumentProfile() async {
    InstrumentPegProfile? profile;
    try {
      profile = await widget.loadInstrumentProfile();
    } on Object {
      profile = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _instrumentProfile = profile;
      _instrumentProfileLoaded = true;
      _resetPegDirectionRuntime();
    });
  }

  Future<void> _prepareInput() async {
    var granted = false;
    try {
      granted = await _engine.hasMicrophonePermission();
    } on Object {
      granted = false;
    }
    if (!mounted) {
      return;
    }
    final preferences = AppPreferencesScope.maybeOf(context);
    final shouldShowFirstTunePrimer =
        preferences != null && !preferences.value.hasSeenTunerPrimer;
    if (granted && !shouldShowFirstTunePrimer) {
      setState(() => _checkingMicrophonePermission = false);
      await _startInput();
      return;
    }
    setState(() {
      _checkingMicrophonePermission = false;
      _needsMicrophonePrimer = true;
    });
  }

  Future<void> _startInput() async {
    if (!_tuneUpStopwatch.isRunning) {
      _tuneUpStopwatch.start();
    }
    await _engine.start(widget.tuning);
    _inputSessionStarted = true;
  }

  Future<void> _enableMicrophone() async {
    if (_checkingMicrophonePermission) {
      return;
    }
    AppPreferencesScope.maybeOf(context)?.markTunerPrimerSeen();
    setState(() => _needsMicrophonePrimer = false);
    await _startInput();
  }

  void _handleEngineState(LiveTunerState state) {
    if (!mounted) {
      return;
    }
    final detectedTarget = state.target;
    var newlyLocked = false;
    if (!_stabilityCheckOpen && state.locked && detectedTarget != null) {
      newlyLocked = !_tuneUpTracker.state.lockedStringNumbers.contains(
        detectedTarget.stringNumber,
      );
      _tuneUpTracker.recordLock(
        stringNumber: detectedTarget.stringNumber,
        elapsed: _tuneUpStopwatch.elapsed,
      );
    }
    _consumePendingPegObservation(state);
    setState(() {
      _liveState = state;
      _updateDisplayCents(state.cents);
      if (!_manualTarget && detectedTarget != null) {
        final index = widget.tuning.strings.indexWhere(
          (target) => target.stringNumber == detectedTarget.stringNumber,
        );
        if (index >= 0) {
          _selectedIndex = index;
        }
      }
    });
    if (newlyLocked && detectedTarget != null) {
      _celebrateLock(detectedTarget.stringNumber);
    }
  }

  void _resetPegDirectionRuntime() {
    _pegDirectionMonitors.clear();
    _pendingPegObservation = null;
    _flipSuggestedStringNumber = null;
  }

  PegDirectionMonitor _monitorFor(int stringNumber) {
    return _pegDirectionMonitors.putIfAbsent(stringNumber, () {
      return PegDirectionMonitor(
        _activeInstrumentProfile!.raisePitchDirectionForString(stringNumber),
      );
    });
  }

  void _consumePendingPegObservation(LiveTunerState state) {
    final pending = _pendingPegObservation;
    if (pending == null) {
      return;
    }
    final target = state.target;
    final cents = state.cents;
    if (target == null || target.stringNumber != pending.stringNumber) {
      _pendingPegObservation = null;
      return;
    }
    if (cents == null || !cents.isFinite) {
      return;
    }
    final delta = cents - pending.baselineCents;
    if (delta.abs() < 2) {
      return;
    }
    _pendingPegObservation = null;

    if (pending.classicalCalibration) {
      final raiseDirection = delta > 0
          ? pending.direction
          : pending.direction.opposite;
      final updated = _activeInstrumentProfile!.withDirectionOverride(
        stringNumber: pending.stringNumber,
        raisePitchDirection: raiseDirection,
      );
      _instrumentProfile = updated;
      _pegDirectionMonitors.remove(pending.stringNumber);
      unawaited(_persistInstrumentProfile(updated));
      return;
    }

    final result = _monitorFor(
      pending.stringNumber,
    ).recordAdjustment(direction: pending.direction, pitchDeltaCents: delta);
    if (result == PegDirectionMonitorState.flipSuggested) {
      _flipSuggestedStringNumber = pending.stringNumber;
    }
  }

  Future<void> _persistInstrumentProfile(InstrumentPegProfile profile) async {
    try {
      await widget.saveInstrumentProfile(profile);
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기타 설정을 저장하지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _showPegSetup() async {
    final profile = await showInstrumentBottomSheet<InstrumentPegProfile>(
      context: context,
      builder: (context) => _PegSetupSheet(
        stringCount: widget.tuning.strings.length,
        current: _activeInstrumentProfile,
      ),
    );
    if (!mounted || profile == null) {
      return;
    }
    setState(() {
      _instrumentProfile = profile;
      _instrumentProfileLoaded = true;
      _resetPegDirectionRuntime();
    });
    await _persistInstrumentProfile(profile);
  }

  PegRotationDirection? _presentedRotationDirection(TuningGuidance guidance) {
    final profile = _activeInstrumentProfile;
    if (profile == null ||
        _flipSuggestedStringNumber == _selected.stringNumber) {
      return null;
    }
    PegRotationDirection raiseDirection;
    try {
      raiseDirection = profile.raisePitchDirectionForString(
        _selected.stringNumber,
      );
    } on StateError {
      return null;
    }
    return switch (guidance.direction) {
      TuningDirection.raise => raiseDirection,
      TuningDirection.lower => raiseDirection.opposite,
      TuningDirection.hold => null,
    };
  }

  void _beginPegDirectionCheck(TuningGuidance guidance) {
    final profile = _activeInstrumentProfile;
    final cents = _liveState.cents;
    if (profile == null || cents == null || !cents.isFinite) {
      return;
    }
    final configuration = profile.configurationForString(
      _selected.stringNumber,
    );
    final classicalCalibration =
        configuration.mechanism == PegMechanism.slottedRoller &&
        configuration.directionOverride == null;
    final direction = classicalCalibration
        ? PegRotationDirection.clockwise
        : _presentedRotationDirection(guidance);
    if (direction == null) {
      return;
    }
    setState(() {
      _pendingPegObservation = _PendingPegObservation(
        stringNumber: _selected.stringNumber,
        baselineCents: cents,
        direction: direction,
        classicalCalibration: classicalCalibration,
      );
    });
  }

  void _acceptPegDirectionFlip() {
    final stringNumber = _flipSuggestedStringNumber;
    final profile = _activeInstrumentProfile;
    if (stringNumber == null || profile == null) {
      return;
    }
    final monitor = _monitorFor(stringNumber)..acceptSuggestedFlip();
    final updated = profile.withDirectionOverride(
      stringNumber: stringNumber,
      raisePitchDirection: monitor.raisePitchDirection,
    );
    setState(() {
      _instrumentProfile = updated;
      _flipSuggestedStringNumber = null;
      _pendingPegObservation = null;
    });
    unawaited(_persistInstrumentProfile(updated));
  }

  void _dismissPegDirectionFlip() {
    final stringNumber = _flipSuggestedStringNumber;
    if (stringNumber == null) {
      return;
    }
    _monitorFor(stringNumber).dismissSuggestion();
    setState(() {
      _flipSuggestedStringNumber = null;
      _pendingPegObservation = null;
    });
  }

  void _updateDisplayCents(double? cents) {
    if (cents == null || !cents.isFinite) {
      _displayCents = null;
      return;
    }
    final previous = _displayCents;
    final alpha = cents.abs() > 10 ? 0.6 : 0.3;
    _displayCents = previous == null
        ? cents
        : previous + alpha * (cents - previous);
    if (!_coarseMode && cents.abs() > 55) {
      _coarseMode = true;
    } else if (_coarseMode && cents.abs() < 45) {
      _coarseMode = false;
    }
  }

  void _celebrateLock(int stringNumber) {
    _autoAdvanceTimer?.cancel();
    setState(() => _celebratingStringNumber = stringNumber);
    if (AppPreferencesScope.maybeOf(context)?.value.hapticsEnabled ?? true) {
      unawaited(_lockHaptic());
    }
    final progress = _tuneUpTracker.state;
    final advanceDelay = _reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 750);
    if (progress.isComplete) {
      _autoAdvanceTimer = Timer(advanceDelay, () {
        if (!mounted) {
          return;
        }
        setState(() => _celebratingStringNumber = null);
        _showCompletion();
      });
      return;
    }
    _autoAdvanceTimer = Timer(advanceDelay, () {
      if (!mounted) {
        return;
      }
      final completed = _tuneUpTracker.state.lockedStringNumbers;
      final nextIndex = widget.tuning.strings.indexWhere(
        (string) => !completed.contains(string.stringNumber),
      );
      if (nextIndex < 0) {
        return;
      }
      setState(() {
        _selectedIndex = nextIndex;
        _manualTarget = false;
        _celebratingStringNumber = null;
        _displayCents = null;
      });
    });
  }

  Future<void> _lockHaptic() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
  }

  bool get _reduceMotion {
    return shouldReduceMotion(context);
  }

  void _showCompletion() {
    if (_completionShown || !mounted) {
      return;
    }
    _completionShown = true;
    unawaited(_recordCompletion());
    showInstrumentBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (sheetContext) => _TuneCompleteSheet(
        tuning: widget.tuning,
        elapsed: _tuneUpTracker.state.elapsed,
        compatibleSongs: widget.catalog.findPlayableWith(
          widget.tuning,
          includeUnverified: widget.includeUnverifiedSongs,
        ),
        onStabilityCheck: () {
          Navigator.of(sheetContext).pop();
          unawaited(_openStabilityCheck());
        },
      ),
    ).whenComplete(() {
      if (mounted) {
        _completionShown = false;
      }
    });
  }

  Future<void> _recordCompletion() async {
    if (_historyRecorded || !_tuneUpTracker.state.isComplete) {
      return;
    }
    _historyRecorded = true;
    final completedAt = widget.tuningHistoryNow().toUtc();
    final elapsed = _tuneUpTracker.state.elapsed;
    final song = widget.song;
    final entry = TuningHistoryEntry(
      id:
          '${completedAt.microsecondsSinceEpoch}-${widget.tuning.id}-'
          '${song?.id ?? 'direct'}',
      completedAtUtc: completedAt,
      tuningId: widget.tuning.id,
      tuningVersion: widget.tuning.version,
      tuningName: widget.tuning.name,
      elapsed: elapsed == Duration.zero
          ? const Duration(milliseconds: 1)
          : elapsed,
      stringCount: widget.tuning.strings.length,
      songId: song?.id,
      songTitle: song?.title,
      artist: song?.artist,
    );
    try {
      await widget.recordTuningHistory(entry);
    } on Object {
      // A local history write must never block the live tuning workflow.
    }
  }

  Future<void> _openStabilityCheck() async {
    if (_stabilityCheckOpen || !mounted) {
      return;
    }
    setState(() => _stabilityCheckOpen = true);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            StabilityCheckScreen(tuning: widget.tuning, engine: _engine),
      ),
    );
    if (mounted) {
      setState(() => _stabilityCheckOpen = false);
    }
  }

  void _toggleTarget(int index) {
    _autoAdvanceTimer?.cancel();
    setState(() {
      _pendingPegObservation = null;
      if (_manualTarget && _selectedIndex == index) {
        _manualTarget = false;
        _engine.setManualTarget(null);
      } else {
        _selectedIndex = index;
        _manualTarget = true;
        _engine.setManualTarget(_selected.stringNumber);
      }
    });
    if (_referenceTonePlaying) {
      unawaited(_switchReferenceToneToSelected());
    }
  }

  Future<void> _toggleReferenceTone() async {
    if (_referenceToneBusy) {
      return;
    }
    if (_referenceTonePlaying) {
      await _stopReferenceTone(resumeInput: true);
      return;
    }

    final resumeInput = _inputSessionStarted;
    final requestedStringNumber = _selected.stringNumber;
    final requestedFrequencyHz = _targetHz;
    setState(() => _referenceToneBusy = true);
    try {
      if (resumeInput) {
        await _engine.stop();
        _inputSessionStarted = false;
      }
      await _referenceTonePlayer.play(requestedFrequencyHz);
      if (!mounted) {
        return;
      }
      setState(() {
        _referenceToneBusy = false;
        _referenceTonePlaying = true;
        _resumeInputAfterReferenceTone = resumeInput;
      });
      if (_selected.stringNumber != requestedStringNumber) {
        unawaited(_switchReferenceToneToSelected());
      }
    } on Object {
      if (resumeInput && mounted) {
        await _startInput();
      }
      if (!mounted) {
        return;
      }
      setState(() => _referenceToneBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('레퍼런스 톤을 재생하지 못했습니다.')));
    }
  }

  Future<void> _switchReferenceToneToSelected() async {
    if (_referenceToneBusy || !_referenceTonePlaying) {
      return;
    }
    final requestedStringNumber = _selected.stringNumber;
    final requestedFrequencyHz = _targetHz;
    setState(() => _referenceToneBusy = true);
    try {
      await _referenceTonePlayer.play(requestedFrequencyHz);
      if (mounted) {
        setState(() => _referenceToneBusy = false);
        if (_selected.stringNumber != requestedStringNumber) {
          unawaited(_switchReferenceToneToSelected());
        }
      }
    } on Object {
      if (mounted) {
        setState(() => _referenceToneBusy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('선택한 음을 재생하지 못했습니다.')));
        await _stopReferenceTone(resumeInput: true);
      }
    }
  }

  Future<void> _stopReferenceTone({required bool resumeInput}) async {
    if (_referenceToneBusy) {
      return;
    }
    setState(() => _referenceToneBusy = true);
    try {
      await _referenceTonePlayer.stop();
    } on Object {
      // Capture recovery is more important than surfacing a stop error.
    }
    final shouldResume =
        resumeInput &&
        _resumeInputAfterReferenceTone &&
        !_needsMicrophonePrimer;
    if (!mounted) {
      return;
    }
    setState(() {
      _referenceToneBusy = false;
      _referenceTonePlaying = false;
      _resumeInputAfterReferenceTone = false;
    });
    if (shouldResume) {
      await _startInput();
    }
  }

  void _resumeAutoDetection() {
    if (!_manualTarget) {
      return;
    }
    setState(() => _manualTarget = false);
    _engine.setManualTarget(null);
  }

  Future<void> _retryInput() async {
    await _engine.stop();
    _inputSessionStarted = false;
    if (!mounted) {
      return;
    }
    await _startInput();
  }

  Future<void> _openStageMode() async {
    if (_referenceToneBusy || _checkingMicrophonePermission) {
      return;
    }
    if (_referenceTonePlaying) {
      await _stopReferenceTone(resumeInput: true);
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => StageModeScreen(
          engine: _engine,
          tuning: widget.tuning,
          initialTarget: _selected,
        ),
      ),
    );
  }

  void _showDiagnostics() {
    showInstrumentBottomSheet<void>(
      context: context,
      builder: (context) => _DiagnosticsSheet(
        state: _liveState,
        tuning: widget.tuning,
        song: widget.song,
        progress: _tuneUpTracker.state,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tuning = widget.tuning;
    final tunerSkin = context.sharkTuneThemeId == SharkTuneThemeId.clipping
        ? TunerSkin.clipping
        : TunerSkin.standard;
    final progress = _tuneUpTracker.state;
    final lockedNow =
        !_referenceTonePlaying &&
        _celebratingStringNumber == _selected.stringNumber;
    final presentedCents = _referenceTonePlaying ? null : _displayCents;
    final guidance = _referenceTonePlaying
        ? TuningGuidance(
            direction: TuningDirection.hold,
            headline: '${_selected.label} 레퍼런스 톤 재생 중',
            instruction: '스피커 음을 듣고 줄의 목표 높이를 익혀보세요',
            coarse: false,
            kind: GuidanceSlotKind.settling,
          )
        : lockedNow
        ? TuningGuidance(
            direction: TuningDirection.hold,
            headline: '$_celebratingStringNumber번 줄 완료',
            instruction: progress.isComplete
                ? '모든 줄이 정확히 맞았습니다'
                : '다음 줄로 이동합니다',
            coarse: false,
          )
        : guidanceForLiveInput(
            cents: presentedCents,
            rmsDb: _liveState.rmsDb,
            clarity: _liveState.clarity,
            expectedStringNumber: _selected.stringNumber,
            heardStringNumber: _liveState.heardTarget?.stringNumber,
            coarseMode: _coarseMode,
          );
    final pegDirection = _referenceTonePlaying
        ? const _PegDirectionPresentation(label: '스피커 재생 중 · 마이크 일시 중지')
        : _pegDirectionPresentation(guidance);
    final usesLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Scaffold(
      appBar: InstrumentHeaderBar(
        section: '정밀 튜너',
        showBack: true,
        actions: [
          Semantics(
            label: '무대 모드 열기',
            button: true,
            excludeSemantics: true,
            child: TextButton(
              key: const Key('open-stage-mode'),
              onPressed: _checkingMicrophonePermission ? null : _openStageMode,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                '무대',
                style: context.instrumentType.caption.copyWith(
                  color: context.terminal.information,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final coreContent = Column(
                  children: [
                    Container(
                      height: 34,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: context.terminal.header,
                        border: Border.all(color: context.terminal.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.sessionLabel.toUpperCase()}  /  ${tuning.name.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.instrumentType.status.copyWith(
                                color: context.terminal.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.includeUnverifiedSongs)
                            TextButton(
                              key: const Key('dev-diagnostics'),
                              onPressed: _showDiagnostics,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 30),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'DEV·진단',
                                style: context.instrumentType.status,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatMeasuredCents(presentedCents, coarse: _coarseMode),
                      textAlign: TextAlign.center,
                      style: context.instrumentType.centsHero.copyWith(
                        color: lockedNow
                            ? context.terminal.lockHold
                            : _coarseMode
                            ? context.terminal.amber
                            : context.terminal.text,
                      ),
                    ),
                    Text(
                      _selected.label,
                      textAlign: TextAlign.center,
                      style: context.instrumentType.noteHero.copyWith(
                        color: lockedNow
                            ? context.terminal.lockHold
                            : context.terminal.text,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: FrequencyReadout(
                            measuredHz: _referenceTonePlaying
                                ? null
                                : _liveState.frequencyHz,
                            targetHz: _targetHz,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: _ReferenceToneControl(
                            frequencyHz: _targetHz,
                            noteLabel: _selected.label,
                            playing: _referenceTonePlaying,
                            busy: _referenceToneBusy,
                            compact: true,
                            onPressed: _toggleReferenceTone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PitchTape(
                      cents: presentedCents,
                      locked: lockedNow,
                      status: _tapeStatus(_liveState),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < tuning.strings.length;
                            index++
                          ) ...[
                            TuningNoteCell(
                              label: tuning.strings[index].label,
                              stringNumber: tuning.strings[index].stringNumber,
                              active: _selectedIndex == index,
                              completed: progress.lockedStringNumbers.contains(
                                tuning.strings[index].stringNumber,
                              ),
                              onTap: () => _toggleTarget(index),
                            ),
                            if (index != tuning.strings.length - 1)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            '${_selected.label} · ${_selected.stringNumber}번 줄 · ${_targetModeLabel()}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        if (_manualTarget) ...[
                          const SizedBox(width: 6),
                          TextButton(
                            key: const Key('resume-auto-detection'),
                            onPressed: _resumeAutoDetection,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '자동 인식으로 전환',
                              style: context.instrumentType.status,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_liveState.status == LiveTunerStatus.permissionDenied ||
                        _liveState.status == LiveTunerStatus.unavailable) ...[
                      _InputErrorNotice(
                        permissionDenied:
                            _liveState.status ==
                            LiveTunerStatus.permissionDenied,
                        onRetry: _retryInput,
                        onOpenSettings: widget.openAppSettings,
                      ),
                      const SizedBox(height: 8),
                    ],
                    _GuidancePanel(
                      guidance: guidance,
                      semanticsLabel: spokenTunerStatus(
                        stringNumber: _selected.stringNumber,
                        noteLabel: _selected.label,
                        cents: presentedCents,
                        guidance: guidance,
                      ),
                      lockProgress: _liveState.lockProgress,
                      offsetLabel: tuning.centsOffset == 0
                          ? null
                          : '곡 기준 ${_offsetLabel(tuning.centsOffset)} 적용',
                      pegDirection: pegDirection,
                      onConfigurePegGuidance: _showPegSetup,
                      onVerifyPegDirection: () =>
                          _beginPegDirectionCheck(guidance),
                      onAcceptPegDirectionFlip: _acceptPegDirectionFlip,
                      onDismissPegDirectionFlip: _dismissPegDirectionFlip,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '튜닝 진행 ${progress.lockedStringCount}/${progress.expectedStringCount}',
                      style: context.instrumentType.status.copyWith(
                        color: progress.isComplete
                            ? context.terminal.accent
                            : context.terminal.muted,
                      ),
                    ),
                  ],
                );
                final content = _TunerSkinFrame(
                  skin: tunerSkin,
                  child: coreContent,
                );
                final requiresExpandedGuidanceScroll =
                    tunerSkin == TunerSkin.clipping ||
                    _manualTarget ||
                    _activeInstrumentProfile != null ||
                    pegDirection.canVerify ||
                    guidance.kind == GuidanceSlotKind.wrongString ||
                    pegDirection.flipSuggested ||
                    _liveState.status == LiveTunerStatus.permissionDenied ||
                    _liveState.status == LiveTunerStatus.unavailable;
                if (usesLargeText ||
                    constraints.maxHeight < 600 ||
                    requiresExpandedGuidanceScroll) {
                  return SingleChildScrollView(
                    reverse: pegDirection.flipSuggested,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: SizedBox(
                      width: constraints.maxWidth - 48,
                      child: content,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 9, 24, 9),
                  child: content,
                );
              },
            ),
          ),
          if (_needsMicrophonePrimer)
            Positioned.fill(
              child: _MicrophonePrimer(onEnable: _enableMicrophone),
            ),
        ],
      ),
      bottomNavigationBar: InstrumentStatusBar(
        state: _referenceTonePlaying
            ? 'REF ${_selected.label} 재생 중'
            : _statusBarState(_liveState),
        detail:
            '${tuning.name.toUpperCase()} │ A4 ${tuning.referenceA4Hz.toStringAsFixed(0)}',
        active:
            _referenceTonePlaying ||
            _liveState.status == LiveTunerStatus.listening,
      ),
    );
  }

  String _targetModeLabel() {
    if (_manualTarget) {
      return '직접 선택';
    }
    return '자동 인식';
  }

  _PegDirectionPresentation _pegDirectionPresentation(TuningGuidance guidance) {
    if (!_instrumentProfileLoaded) {
      return const _PegDirectionPresentation(label: '페그 설정 불러오는 중');
    }
    final profile = _activeInstrumentProfile;
    if (profile == null) {
      return const _PegDirectionPresentation(
        label: '내 기타를 설정하면 시계·반시계 방향도 알려드려요',
        needsSetup: true,
      );
    }
    if (_flipSuggestedStringNumber == _selected.stringNumber) {
      return const _PegDirectionPresentation(
        label: '방향 안내를 멈췄어요',
        flipSuggested: true,
      );
    }
    final pending = _pendingPegObservation;
    if (pending?.stringNumber == _selected.stringNumber) {
      return _PegDirectionPresentation(
        label: pending!.classicalCalibration
            ? '↻ 시계방향으로 아주 조금 돌린 뒤 다시 튕겨 주세요'
            : '안내 방향으로 조금 돌린 뒤 같은 줄을 다시 튕겨 주세요',
        pending: true,
      );
    }

    final configuration = profile.configurationForString(
      _selected.stringNumber,
    );
    if (configuration.mechanism == PegMechanism.slottedRoller &&
        configuration.directionOverride == null) {
      return _PegDirectionPresentation(
        label: '클래식 페그 방향 확인 · ↻ 시계방향으로 아주 조금',
        canVerify: _liveState.cents?.isFinite ?? false,
        classicalCalibration: true,
      );
    }
    final direction = _presentedRotationDirection(guidance);
    if (direction == null) {
      return _PegDirectionPresentation(
        label: '페그 설정됨 · ${_pegProfileLabel(profile)}',
      );
    }
    return _PegDirectionPresentation(
      label: '헤드스톡 정면에서 ${_rotationDirectionLabel(direction)}',
      canVerify: _liveState.cents?.isFinite ?? false,
    );
  }
}
