# 디자인 검증 리뷰 (Claude 작성 · 코덱스가 읽고 처리)

> 작성: Claude. **이 문서는 검증·문제점 지적 전용이다. Claude는 디자인 코드를 수정하지 않았다.** (Figma 커넥터 불가 + 최종 개발 리드는 코덱스이므로 실제 수정은 코덱스가 판단·수행한다.) 기준: `docs/design-playbook.md`.

## 총평

코덱스가 플레이북 §2.2 디자인 시스템을 **1:1로 완전 구현·강제**했다. 정적 준수 테스트(`app/test/design_playbook_compliance_test.dart`)와 릴리스 어휘 위젯 테스트(`app/test/widget_test.dart`)까지 갖춰 정적으로 검증 가능한 AI 티는 대부분 이미 차단됐다. 아래는 **정적 테스트가 잡지 못하는 정성 항목**과 **커버리지 공백**만 남긴 것이다.

## 검증 완료 (문제 없음)

| 항목 | 근거 |
|---|---|
| 토큰 시스템 전체 | `instrument_theme.dart`: elevation 램프 5단(sunken/canvas/panel/raised/header) + hairline + brandPhosphor #A9E34B / phosphorEdge #B8F34A + lockFlood #46D67F / lockHold #5FD98A + warning #F2A93B/#FFB000 + info.teal #4FB0A6 + ink/inkSecondary/textSecondary/gridTick — 플레이북 §2.2 값과 정확히 일치 |
| 6역할 타입 스케일 | `InstrumentTypeTheme`: centsHero/title/subhead/body/caption/status. literal `fontSize:` 사용 정적 차단 |
| 8pt 간격 · radius0 | `InstrumentMetrics.space4~32`, radius0 |
| AI 프리미티브 차단 | 은퇴 색(#101512/#33FF66/#5A6E5E)·BoxShadow·모든 Gradient·토큰 외 `Color(0x)`·둥근 체크 아이콘·Ctrl K 전부 정적 위반 검사 |
| 이중선 박스드로잉(kitsch) | 코드 전역 `═║╔╗╠╣╬` 0건 (KILL 준수) |
| rounded-lg | 반경 16px+ 카드 0건 (KILL 준수) |
| 릴리스 어휘 유출 | 튜너·곡 플로우 렌더 트리에 FTS5/isolate/DSP/samples/DEVELOPMENT/사람 검증/DEV· 0건 강제 |
| 신규 화면 소스 어휘 | stage/string-care/history/stability/tension 화면에 금지 어휘 소스 0건 |

## 잔여 지적 (코덱스 판단·수정)

### D-1 [minor] 릴리스 어휘 스윕이 신규 화면을 커버하지 않음
- 렌더 트리 어휘 감사(`release tuner hides telemetry`, `release song flow exposes trust`)는 **튜너·곡 플로우만** 커버. 이후 추가된 **스테이지 모드·줄 관리·튜닝 히스토리 LOG·앱 정보·안정성·장력 화면**은 렌더 스윕 밖.
- 현재 이 화면들 소스에 금지 어휘는 없으나(확인됨), 회귀 방지가 없다. 
- 제안: 신규 화면 각각을 릴리스 구성으로 pump해 금지 어휘 0건을 강제하는 테스트를 기존 패턴대로 추가하거나, `_productionDartSources()` 스타일의 렌더-독립 정적 어휘 스윕으로 확장.

### D-2 [minor] 한글 문장에 `.toUpperCase()` 적용 지점 점검
- `tension_recommendation_screen.dart:84` `'현재 손에 익은 장력 감각을 ${widget.tuning.name.toUpperCase()}에서도...'` — 튜닝명만 대문자라 의도된 기계 토큰이면 OK. 단 §2.1/§7 "장식 all-caps 폐기, 기계 토큰만 획득" 기준으로 의도 확인 필요.
- `instrument_widgets.dart:126/138/164` `state/detail/label.toUpperCase()` — 상태바·섹션 라벨. 한글은 케이스 없음(무해)이나, 만약 한글 프로즈가 여기 들어오면 §7 위반. 라틴 기계 토큰에만 적용되는지 호출부 확인 권장. (정적 테스트로는 "한글에 대문자화" 구분 불가 → 코덱스 수동 확인 영역.)

### D-3 [정보] 정적 테스트가 구조적으로 못 잡는 항목 = 실기기 시각 검증 영역
아래는 코드로 판정 불가, `reports/device/` 스크린샷 대조(실기기 QA Track B)로만 확인 가능:
- elevation 램프가 실제로 **여러 표면으로 렌더**되는지(카드가 배경에서 떠 보이는지) vs 토큰만 정의되고 한 색만 쓰이는지
- 중앙정렬이 §3.4 예외(미터·히어로 게이지)에만 쓰이고 나머지는 좌측 앵커인지 (`Center(` 사용처: song_search 3, precision_tuner 6, stage/string_care/history/instrument_widgets — 각 사용처가 계기·히어로인지 화면 전체 대칭인지 시각 확인 필요)
- 스캔라인/글로우 opacity ≤6%가 실제 렌더에서 cents 판독을 방해하지 않는지
- 락 플러드가 0ms 점등→200ms 유지→150ms 페이드로, ease/bounce 없이 linear/steps인지 (모션은 정적 검사 밖)
- 폰트 스케일 1.3x/2.0x 실제 줄바꿈 (테스트는 있으나 시각 확인은 스크린샷)

### D-4 [정보] Figma foundations 대조 보류
- Figma 커넥터를 이 계정에 추가 불가 → 컴포넌트 variants·화면 대조는 제한 해제 후 코덱스가 재개. `docs/figma-gap-analysis.md` 트랙 유지.

## 결론
디자인 시스템 구현·강제는 **출시 가능 수준**이다. 남은 것은 (a) 신규 화면 어휘 회귀 테스트 1건(D-1), (b) all-caps 지점 의도 확인(D-2), (c) 실기기 시각 대조(D-3, Track B에서). 어느 것도 출시를 막지 않는다.
