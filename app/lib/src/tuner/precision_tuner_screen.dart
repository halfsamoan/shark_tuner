import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuner_data/tuner_data.dart';
import 'package:tuner_domain/tuner_domain.dart';

import '../app/instrument_theme.dart';
import '../device/tuner_device_control.dart';
import '../instrument_setup/instrument_profile_store.dart';
import '../settings/app_settings.dart';
import '../stability/stability_check_screen.dart';
import '../ui/instrument_widgets.dart';
import '../ui/throttled_live_region.dart';
import 'live_tuner_engine.dart';
import 'reference_tone_player.dart';
import 'stage_mode_screen.dart';
import 'tuning_guidance.dart';

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
    if (granted) {
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
    final profile = await showModalBottomSheet<InstrumentPegProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: InstrumentColors.raised,
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
    unawaited(_lockHaptic());
    final progress = _tuneUpTracker.state;
    if (progress.isComplete) {
      _autoAdvanceTimer = Timer(const Duration(milliseconds: 750), () {
        if (!mounted) {
          return;
        }
        setState(() => _celebratingStringNumber = null);
        _showCompletion();
      });
      return;
    }
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 750), () {
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

  void _showCompletion() {
    if (_completionShown || !mounted) {
      return;
    }
    _completionShown = true;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: InstrumentColors.raised,
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: InstrumentColors.raised,
      isScrollControlled: true,
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
                style: InstrumentTypeTheme.standard.caption.copyWith(
                  color: InstrumentColors.information,
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
                final content = Column(
                  children: [
                    Container(
                      height: 34,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: InstrumentColors.header,
                        border: Border.all(color: InstrumentColors.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.sessionLabel.toUpperCase()}  /  ${tuning.name.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: InstrumentTypeTheme.standard.status
                                  .copyWith(
                                    color: InstrumentColors.muted,
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
                                style: InstrumentTypeTheme.standard.status,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
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
                              style: InstrumentTypeTheme.standard.status,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatMeasuredCents(presentedCents, coarse: _coarseMode),
                      textAlign: TextAlign.center,
                      style: InstrumentTypeTheme.standard.centsHero.copyWith(
                        color: lockedNow
                            ? InstrumentColors.lockHold
                            : _coarseMode
                            ? InstrumentColors.amber
                            : InstrumentColors.text,
                      ),
                    ),
                    Text(
                      guidance.headline,
                      textAlign: TextAlign.center,
                      style: InstrumentTypeTheme.standard.caption.copyWith(
                        color: lockedNow
                            ? InstrumentColors.lockHold
                            : guidance.coarse
                            ? InstrumentColors.amber
                            : InstrumentColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PitchTape(
                      cents: presentedCents,
                      locked: lockedNow,
                      status: _tapeStatus(_liveState),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _referenceTonePlaying ||
                                    _liveState.frequencyHz == null
                                ? '— Hz'
                                : '${_liveState.frequencyHz!.toStringAsFixed(2)} Hz',
                            maxLines: usesLargeText ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: InstrumentTypeTheme.standard.subhead
                                .copyWith(
                                  color: InstrumentColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _ReferenceToneControl(
                            frequencyHz: _targetHz,
                            noteLabel: _selected.label,
                            playing: _referenceTonePlaying,
                            busy: _referenceToneBusy,
                            onPressed: _toggleReferenceTone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                      style: InstrumentTypeTheme.standard.status.copyWith(
                        color: progress.isComplete
                            ? InstrumentColors.accent
                            : InstrumentColors.muted,
                      ),
                    ),
                  ],
                );
                final requiresExpandedGuidanceScroll =
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
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
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

class _ReferenceToneControl extends StatelessWidget {
  const _ReferenceToneControl({
    required this.frequencyHz,
    required this.noteLabel,
    required this.playing,
    required this.busy,
    required this.onPressed,
  });

  final double frequencyHz;
  final String noteLabel;
  final bool playing;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = playing
        ? InstrumentColors.accent
        : InstrumentColors.information;
    final action = playing ? '정지' : '재생';
    return Semantics(
      label: '$noteLabel 레퍼런스 톤 $action',
      button: true,
      enabled: !busy,
      toggled: playing,
      excludeSemantics: true,
      child: OutlinedButton(
        key: const Key('reference-tone-toggle'),
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: color,
          disabledForegroundColor: InstrumentColors.muted,
          side: BorderSide(
            color: playing
                ? InstrumentColors.phosphorEdge
                : InstrumentColors.line,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(InstrumentMetrics.radius2),
            ),
          ),
        ),
        child: Text(
          busy
              ? 'REF 준비 중'
              : playing
              ? '█ REF $noteLabel 정지'
              : 'REF ${frequencyHz.toStringAsFixed(2)} Hz',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: InstrumentTypeTheme.standard.status.copyWith(
            color: busy ? InstrumentColors.muted : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MicrophonePrimer extends StatelessWidget {
  const _MicrophonePrimer({required this.onEnable});

  final Future<void> Function() onEnable;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: InstrumentColors.canvas.withValues(alpha: 0.98),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                color: InstrumentColors.panel,
                border: Border.all(color: InstrumentColors.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InstrumentSectionLabel(
                    '마이크 사용 안내',
                    color: InstrumentColors.accent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '줄 소리를 듣고 음정을 측정해요',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '소리는 기기에서만 분석되고 저장되지 않습니다. '
                    '통화나 주변 대화를 녹음하지 않습니다.',
                    style: InstrumentTypeTheme.standard.caption.copyWith(
                      color: InstrumentColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('enable-microphone'),
                      onPressed: onEnable,
                      icon: const Icon(Icons.mic_rounded, size: 18),
                      label: const Text('마이크 사용하기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PendingPegObservation {
  const _PendingPegObservation({
    required this.stringNumber,
    required this.baselineCents,
    required this.direction,
    required this.classicalCalibration,
  });

  final int stringNumber;
  final double baselineCents;
  final PegRotationDirection direction;
  final bool classicalCalibration;
}

final class _PegDirectionPresentation {
  const _PegDirectionPresentation({
    required this.label,
    this.needsSetup = false,
    this.canVerify = false,
    this.pending = false,
    this.flipSuggested = false,
    this.classicalCalibration = false,
  });

  final String label;
  final bool needsSetup;
  final bool canVerify;
  final bool pending;
  final bool flipSuggested;
  final bool classicalCalibration;
}

enum _PegSetupLayout { split, inline, classical }

class _PegSetupSheet extends StatefulWidget {
  const _PegSetupSheet({required this.stringCount, required this.current});

  final int stringCount;
  final InstrumentPegProfile? current;

  @override
  State<_PegSetupSheet> createState() => _PegSetupSheetState();
}

class _PegSetupSheetState extends State<_PegSetupSheet> {
  late _PegSetupLayout _layout;
  late InstrumentHandedness _handedness;
  late bool _reversed;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _layout = switch (current?.layout) {
      HeadstockLayout.inline => _PegSetupLayout.inline,
      HeadstockLayout.classicalSplit => _PegSetupLayout.classical,
      _ => _PegSetupLayout.split,
    };
    _handedness = current?.handedness ?? InstrumentHandedness.right;
    _reversed = current?.orientation == HeadstockOrientation.reversed;
  }

  @override
  Widget build(BuildContext context) {
    final splitLabel = widget.stringCount == 6
        ? '3+3 헤드스톡'
        : '${(widget.stringCount + 1) ~/ 2}+${widget.stringCount ~/ 2} 헤드스톡';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InstrumentSectionLabel(
              '내 기타 페그 설정',
              color: InstrumentColors.accent,
            ),
            const SizedBox(height: 8),
            Text(
              '헤드스톡을 정면에서 봤을 때의 모양을 고르세요. 설정 전에는 안전하게 조이기·풀기만 안내합니다.',
              style: InstrumentTypeTheme.standard.caption.copyWith(
                color: InstrumentColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            const InstrumentSectionLabel('페그 배치'),
            const SizedBox(height: 6),
            _SetupChoiceRow(
              key: const Key('peg-layout-split'),
              selected: _layout == _PegSetupLayout.split,
              label: splitLabel,
              detail: '낮은 줄과 높은 줄이 양쪽으로 나뉨',
              onTap: () => setState(() => _layout = _PegSetupLayout.split),
            ),
            _SetupChoiceRow(
              key: const Key('peg-layout-inline'),
              selected: _layout == _PegSetupLayout.inline,
              label: '${widget.stringCount}인라인',
              detail: '모든 페그가 한쪽에 일렬로 배치됨',
              onTap: () => setState(() => _layout = _PegSetupLayout.inline),
            ),
            _SetupChoiceRow(
              key: const Key('peg-layout-classical'),
              selected: _layout == _PegSetupLayout.classical,
              label: '클래식 슬롯형',
              detail: '방향을 추측하지 않고 각 페그를 한 번 확인',
              onTap: () => setState(() => _layout = _PegSetupLayout.classical),
            ),
            const SizedBox(height: 14),
            const InstrumentSectionLabel('연주 방향'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _SetupChoiceRow(
                    key: const Key('peg-handed-right'),
                    selected: _handedness == InstrumentHandedness.right,
                    label: '오른손 기타',
                    onTap: () => setState(
                      () => _handedness = InstrumentHandedness.right,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SetupChoiceRow(
                    key: const Key('peg-handed-left'),
                    selected: _handedness == InstrumentHandedness.left,
                    label: '왼손 기타',
                    onTap: () =>
                        setState(() => _handedness = InstrumentHandedness.left),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('peg-reverse-headstock'),
              value: _reversed,
              onChanged: (value) => setState(() => _reversed = value),
              contentPadding: EdgeInsets.zero,
              title: Text(
                '리버스 헤드스톡',
                style: InstrumentTypeTheme.standard.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '일반 헤드스톡과 반대 방향으로 기울어진 경우만 켜세요',
                style: InstrumentTypeTheme.standard.status.copyWith(
                  color: InstrumentColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('save-peg-profile'),
                onPressed: () => Navigator.of(context).pop(_buildProfile()),
                child: const Text('이 기타로 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InstrumentPegProfile _buildProfile() {
    final orientation = _reversed
        ? HeadstockOrientation.reversed
        : HeadstockOrientation.standard;
    final layout = switch (_layout) {
      _PegSetupLayout.split => HeadstockLayout.split,
      _PegSetupLayout.inline => HeadstockLayout.inline,
      _PegSetupLayout.classical => HeadstockLayout.classicalSplit,
    };
    final current = widget.current;
    final keepOverrides =
        current?.layout == layout &&
        current?.handedness == _handedness &&
        current?.orientation == orientation;
    final windingOverrides = keepOverrides
        ? current!.windingOverrides
        : const <int, StringWinding>{};
    final directionOverrides = keepOverrides
        ? current!.directionOverrides
        : const <int, PegRotationDirection>{};
    final splitCount = (widget.stringCount + 1) ~/ 2;
    return switch (_layout) {
      _PegSetupLayout.split => InstrumentPegProfile.split(
        stringCount: widget.stringCount,
        bassSideStringCount: splitCount,
        handedness: _handedness,
        orientation: orientation,
        windingOverrides: windingOverrides,
        directionOverrides: directionOverrides,
      ),
      _PegSetupLayout.inline => InstrumentPegProfile.inline(
        stringCount: widget.stringCount,
        handedness: _handedness,
        orientation: orientation,
        windingOverrides: windingOverrides,
        directionOverrides: directionOverrides,
      ),
      _PegSetupLayout.classical => InstrumentPegProfile.classicalSplit(
        stringCount: widget.stringCount,
        bassSideStringCount: splitCount,
        handedness: _handedness,
        orientation: orientation,
        windingOverrides: windingOverrides,
        directionOverrides: directionOverrides,
      ),
    };
  }
}

class _SetupChoiceRow extends StatelessWidget {
  const _SetupChoiceRow({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final bool selected;
  final String label;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? InstrumentColors.panel : Colors.transparent,
            border: Border.all(
              color: selected ? InstrumentColors.accent : InstrumentColors.line,
            ),
          ),
          child: Row(
            children: [
              Text(
                selected ? '[×]' : '[ ]',
                style: InstrumentTypeTheme.standard.caption.copyWith(
                  color: selected
                      ? InstrumentColors.accent
                      : InstrumentColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: InstrumentTypeTheme.standard.caption.copyWith(
                        color: InstrumentColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: InstrumentTypeTheme.standard.status.copyWith(
                          color: InstrumentColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidancePanel extends StatelessWidget {
  const _GuidancePanel({
    required this.guidance,
    required this.semanticsLabel,
    required this.lockProgress,
    required this.pegDirection,
    required this.onConfigurePegGuidance,
    required this.onVerifyPegDirection,
    required this.onAcceptPegDirectionFlip,
    required this.onDismissPegDirectionFlip,
    this.offsetLabel,
  });

  final TuningGuidance guidance;
  final String semanticsLabel;
  final double lockProgress;
  final String? offsetLabel;
  final _PegDirectionPresentation pegDirection;
  final VoidCallback onConfigurePegGuidance;
  final VoidCallback onVerifyPegDirection;
  final VoidCallback onAcceptPegDirectionFlip;
  final VoidCallback onDismissPegDirectionFlip;

  @override
  Widget build(BuildContext context) {
    final completed =
        guidance.direction == TuningDirection.hold &&
        guidance.headline.contains('완료');
    final color = completed
        ? InstrumentColors.accent
        : guidance.coarse
        ? InstrumentColors.amber
        : InstrumentColors.text;
    final VoidCallback? pegAction = pegDirection.pending
        ? null
        : pegDirection.needsSetup
        ? onConfigurePegGuidance
        : pegDirection.canVerify
        ? onVerifyPegDirection
        : onConfigurePegGuidance;
    final pegActionKey = pegDirection.pending
        ? null
        : pegDirection.needsSetup
        ? const Key('configure-peg-guidance')
        : pegDirection.canVerify
        ? const Key('verify-peg-direction')
        : const Key('configure-peg-guidance');
    final pegActionLabel = pegDirection.needsSetup
        ? '설정'
        : pegDirection.canVerify
        ? pegDirection.classicalCalibration
              ? '확인 시작'
              : '방향 확인'
        : '기타 설정';
    return ThrottledLiveRegion(
      label: semanticsLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        decoration: BoxDecoration(
          color: completed
              ? InstrumentColors.lockHold.withValues(alpha: 0.08)
              : InstrumentColors.panel,
          border: Border.all(
            color: completed
                ? InstrumentColors.lockHold
                : InstrumentColors.line,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    guidance.leadingSymbol,
                    textAlign: TextAlign.center,
                    style: InstrumentTypeTheme.standard.subhead.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guidance.instruction,
                        style: InstrumentTypeTheme.standard.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!pegDirection.flipSuggested) ...[
                        const SizedBox(height: 2),
                        Semantics(
                          button: pegAction != null,
                          label: '$pegActionLabel. ${pegDirection.label}',
                          child: InkWell(
                            key: pegActionKey,
                            onTap: pegAction,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pegDirection.label,
                                      style: InstrumentTypeTheme.standard.status
                                          .copyWith(
                                            color: pegDirection.pending
                                                ? InstrumentColors.amber
                                                : InstrumentColors.muted,
                                            fontWeight: pegDirection.pending
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  if (pegAction != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '$pegActionLabel ›',
                                      style: InstrumentTypeTheme.standard.status
                                          .copyWith(
                                            color: InstrumentColors.accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (lockProgress > 0 && lockProgress < 1) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: lockProgress,
                minHeight: 3,
                color: InstrumentColors.accent,
                backgroundColor: InstrumentColors.line,
              ),
            ],
            if (offsetLabel != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  offsetLabel!,
                  style: InstrumentTypeTheme.standard.status.copyWith(
                    color: InstrumentColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (pegDirection.flipSuggested) ...[
              const SizedBox(height: 8),
              Container(height: 1, color: InstrumentColors.line),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '방향 안내를 멈췄어요',
                  style: InstrumentTypeTheme.standard.caption.copyWith(
                    color: InstrumentColors.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '안내와 반대로 두 번 움직였습니다. 이 페그만 방향을 바꿀까요?',
                  style: InstrumentTypeTheme.standard.caption.copyWith(
                    color: InstrumentColors.muted,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onDismissPegDirectionFlip,
                    child: const Text('그대로 유지'),
                  ),
                  TextButton(
                    key: const Key('accept-peg-direction-flip'),
                    onPressed: onAcceptPegDirectionFlip,
                    child: const Text('이 페그만 반대로'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TuneCompleteSheet extends StatelessWidget {
  const _TuneCompleteSheet({
    required this.tuning,
    required this.elapsed,
    required this.compatibleSongs,
    required this.onStabilityCheck,
  });

  final TuningDefinition tuning;
  final Duration elapsed;
  final Future<List<SongTuningMatch>> compatibleSongs;
  final VoidCallback onStabilityCheck;

  @override
  Widget build(BuildContext context) {
    final seconds = elapsed.inSeconds;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '✓',
              key: Key('tune-complete-glyph'),
              style: InstrumentTypeTheme.standard.title.copyWith(
                color: InstrumentColors.lockFlood,
                fontFamily: 'D2Coding',
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${tuning.strings.length}현 모두 완료!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${tuning.name} · $seconds초',
              style: const TextStyle(color: InstrumentColors.muted),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<SongTuningMatch>>(
              future: compatibleSongs,
              builder: (context, snapshot) {
                final count = snapshot.data?.length;
                return Text(
                  count == null ? '연주 가능한 곡 확인 중' : '이 튜닝으로 연주 가능한 곡 $count개',
                  style: InstrumentTypeTheme.standard.caption.copyWith(
                    color: InstrumentColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('완료'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('open-stability-check'),
                    onPressed: onStabilityCheck,
                    child: const Text('30초 안정성 검사'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsSheet extends StatelessWidget {
  const _DiagnosticsSheet({
    required this.state,
    required this.tuning,
    required this.song,
    required this.progress,
  });

  final LiveTunerState state;
  final TuningDefinition tuning;
  final SongTuningRecord? song;
  final TuneUpProgressState progress;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InstrumentSectionLabel(
              'DEV·실기기 진단',
              color: InstrumentColors.amber,
            ),
            const SizedBox(height: 10),
            DefinitionRow(label: 'DEV·입력', value: _inputDescription(state)),
            DefinitionRow(
              label: 'DEV·분석',
              value:
                  '${state.actualSampleRate ?? 48000} Hz · '
                  '${state.windowSamples ?? 4096} samples',
            ),
            DefinitionRow(
              label: 'DEV·DSP',
              value: state.processingDuration == null
                  ? 'isolate 준비'
                  : '${(state.processingDuration!.inMicroseconds / 1000).toStringAsFixed(2)} ms · isolate',
            ),
            DefinitionRow(
              label: 'DEV·첫 응답',
              value: state.pluckToFirstValidLatency == null
                  ? '픽 어택 대기'
                  : '${(state.pluckToFirstValidLatency!.inMicroseconds / 1000).toStringAsFixed(1)} ms · PCM 기준',
            ),
            DefinitionRow(
              label: 'DEV·응답 p95',
              value: state.pluckToDisplayP95Latency == null
                  ? '표본 대기 · 매번 현을 뮤트한 뒤 피킹'
                  : '${(state.pluckToDisplayP95Latency!.inMicroseconds / 1000).toStringAsFixed(1)} ms · n=${state.pluckLatencySampleCount}',
              valueColor: state.pluckToDisplayP95Latency == null
                  ? InstrumentColors.text
                  : state.pluckToDisplayP95Latency!.inMilliseconds <= 150
                  ? InstrumentColors.accent
                  : InstrumentColors.danger,
            ),
            DefinitionRow(
              label: 'DEV·튜닝 진행',
              value: _tuneUpProgressLabel(progress),
            ),
            DefinitionRow(
              label: 'DEV·곡 설정',
              value:
                  '${tuning.id}@${tuning.version} · ${_offsetLabel(tuning.centsOffset)} · capo ${song?.capoFret ?? 0}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InputErrorNotice extends StatelessWidget {
  const _InputErrorNotice({
    required this.permissionDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permissionDenied;
  final Future<void> Function() onRetry;
  final AppSettingsLauncher onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: InstrumentColors.panel,
        border: Border.all(color: InstrumentColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            permissionDenied
                ? '설정에서 마이크를 허용해 주세요.'
                : '사용 가능한 마이크 입력을 찾지 못했습니다.',
            style: InstrumentTypeTheme.standard.status.copyWith(
              color: InstrumentColors.danger,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onRetry, child: const Text('다시 시도')),
              if (permissionDenied)
                TextButton(
                  key: const Key('open-app-settings'),
                  onPressed: onOpenSettings,
                  child: const Text('설정 열기'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatMeasuredCents(double? cents, {required bool coarse}) {
  if (cents == null) {
    return '—';
  }
  if (coarse) {
    return cents > 0 ? '▼ 50¢+' : '▲ 50¢+';
  }
  final sign = cents > 0 ? '+' : '';
  return '$sign${cents.toStringAsFixed(1)}¢';
}

String _tapeStatus(LiveTunerState state) {
  return switch (state.status) {
    LiveTunerStatus.probingInput => '현을 한 번 튕기세요',
    LiveTunerStatus.permissionDenied => '마이크 권한 필요',
    LiveTunerStatus.unavailable => '입력 확인 필요',
    LiveTunerStatus.listening when state.locked => 'IN TUNE',
    LiveTunerStatus.listening when state.frequencyHz != null => '측정 중',
    _ => '신호 대기',
  };
}

String _inputDescription(LiveTunerState state) {
  return switch (state.status) {
    LiveTunerStatus.idle => '대기',
    LiveTunerStatus.probingInput => 'UNPROCESSED 확인 중 · 지금 튕기세요',
    LiveTunerStatus.permissionDenied => '권한 거부됨',
    LiveTunerStatus.unavailable => '입력 없음',
    LiveTunerStatus.listening => switch (state.selectedSource?.name) {
      'unprocessed' => 'UNPROCESSED · 처리 없음',
      'voiceRecognition' => 'VOICE_RECOGNITION · 폴백',
      _ => '마이크 · 소스 확인 중',
    },
  };
}

String _statusBarState(LiveTunerState state) {
  return switch (state.status) {
    LiveTunerStatus.idle => '준비 중',
    LiveTunerStatus.probingInput => '입력 확인 중',
    LiveTunerStatus.permissionDenied => '마이크 권한 필요',
    LiveTunerStatus.unavailable => '마이크 확인 필요',
    LiveTunerStatus.listening when state.locked => '인튠',
    LiveTunerStatus.listening => '듣는 중',
  };
}

String _offsetLabel(double cents) {
  if (cents == 0) {
    return '0 cents';
  }
  final sign = cents > 0 ? '+' : '';
  return '$sign${cents.toStringAsFixed(cents == cents.roundToDouble() ? 0 : 1)} cents';
}

String _tuneUpProgressLabel(TuneUpProgressState state) {
  final elapsed = state.elapsed;
  final minutes = elapsed.inMinutes;
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  final progress = '${state.lockedStringCount}/${state.expectedStringCount}';
  return state.isComplete
      ? '$progress · 완료 ${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$progress · ${minutes.toString().padLeft(2, '0')}:$seconds';
}

String _rotationDirectionLabel(PegRotationDirection direction) {
  return switch (direction) {
    PegRotationDirection.clockwise => '↻ 시계방향',
    PegRotationDirection.counterClockwise => '↺ 반시계방향',
  };
}

String _pegProfileLabel(InstrumentPegProfile profile) {
  final layout = switch (profile.layout) {
    HeadstockLayout.split =>
      profile.stringCount == 6
          ? '3+3'
          : '${profile.bassSideStringCount}+${profile.stringCount - profile.bassSideStringCount}',
    HeadstockLayout.inline => '${profile.stringCount}인라인',
    HeadstockLayout.classicalSplit => '클래식 슬롯형',
  };
  final hand = profile.handedness == InstrumentHandedness.right ? '오른손' : '왼손';
  final reverse = profile.orientation == HeadstockOrientation.reversed
      ? ' · 리버스'
      : '';
  return '$layout · $hand$reverse';
}
