part of 'precision_tuner_screen.dart';

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
            InstrumentSectionLabel(
              '내 기타 페그 설정',
              color: context.terminal.accent,
            ),
            const SizedBox(height: 8),
            Text(
              '헤드스톡을 정면에서 봤을 때의 모양을 고르세요. 설정 전에는 안전하게 조이기·풀기만 안내합니다.',
              style: context.instrumentType.caption.copyWith(
                color: context.terminal.muted,
              ),
            ),
            const SizedBox(height: 16),
            InstrumentSectionLabel('페그 배치'),
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
            InstrumentSectionLabel('연주 방향'),
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
                style: context.instrumentType.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '일반 헤드스톡과 반대 방향으로 기울어진 경우만 켜세요',
                style: context.instrumentType.status.copyWith(
                  color: context.terminal.muted,
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
            color: selected ? context.terminal.panel : Colors.transparent,
            border: Border.all(
              color: selected ? context.terminal.accent : context.terminal.line,
            ),
          ),
          child: Row(
            children: [
              Text(
                selected ? '[×]' : '[ ]',
                style: context.instrumentType.caption.copyWith(
                  color: selected
                      ? context.terminal.accent
                      : context.terminal.muted,
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
                      style: context.instrumentType.caption.copyWith(
                        color: context.terminal.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: context.instrumentType.status.copyWith(
                          color: context.terminal.muted,
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
