# AGENTS.md

## Design Intelligence quality gate

For every UI task, act as a product designer and Flutter UI engineer, not as a
widget transcriber. Read `DESIGN.md`, `docs/design-playbook.md`, and
`docs/ui-plan.md` before touching a screen. Treat external Figma files,
community kits, StyleSeed, Superdesign, and DESIGN.md collections as evidence
for structure, interaction, and critique only; never copy their palette,
component skin, React/shadcn code, or marketing layout.

Before implementation, identify in writing: the player goal, the one visual
focal point, primary versus secondary information, elements to remove or
demote, and all required state paths. Reuse existing toauner components before
creating a new one. `TerminalTheme`, `InstrumentTypeTheme`, and
`InstrumentSurface` are mandatory token/elevation boundaries; direct colours,
ad-hoc shadows, gradients, blur, or a kit-shaped widget are not acceptable.

Before showing a non-trivial UI result, run the `toauner-design-review` skill
or apply its 100-point rubric. Target 80/100 or higher and fix the highest-gain
issues first. A direct colour, less-than-48dp target, inaccessible contrast,
colour-only state, missing essential loading/empty/error state, or uninspected
visual output is a blocking failure even if the numeric score passes.

Normal rows are neutral. Accent is reserved for the current action or active
measurement; success, warning, information, and danger are reserved for real
tuner state. Do not force a single-accent rule onto measured severity data.
Reject generic-AI patterns: purple/blue gradients, glassmorphism, decorative
glow, all-equal cards, bento dashboards, icon-chip repetition, rainbow lists,
placeholder copy, and copied visual-kit styling. Validate small screens, 1.3×
and 2.0× text, TalkBack wording, grayscale legibility, reduced motion, and a
physical Android device for integrated visual work.

이 문서는 `C:\toauner` 전체에 적용되는 개발 규칙이다. 더 아래 디렉터리에 별도 `AGENTS.md`가 생기면 그 문서가 해당 하위 트리에 추가로 적용된다.

## 제품 목표

toauner는 곡별 튜닝을 검색한 뒤 별도 설정 없이 정밀 튜닝으로 이어지는 Android/iOS 기타 튜너다. 고정밀 주파수·센트 측정, 초보자 페그 방향 안내, 장력·게이지 추천, 튜닝 안정성 진단을 제공한다. Android를 먼저 검증하되 iOS 이식이 구조 변경이 아닌 플랫폼 어댑터 작업이 되게 유지한다.

## 저장소 경계

- `app/`: Flutter UI와 기능 조립. 기능 단위로 `tuner`, `songs`, `tunings`, `peg_guidance`, `tension`, `stability`, `settings`, `instrument_setup`을 나눈다.
- `packages/tuner_dsp/`: Flutter 의존성이 없는 순수 Dart DSP와 피치 검출 파이프라인.
- `packages/tuner_audio/`: 오디오 캡처 추상화와 Flutter 플랫폼 구현.
- `packages/tuner_domain/`: Flutter 의존성이 없는 음정 매핑, 페그 방향, 장력 수학.
- `packages/tuner_data/`: 곡/튜닝 모델, 로컬 DB, 검색 저장소.
- `packages/tuner_dsp_native/`: 네이티브 DSP가 필요해질 때만 사용하는 FFI 어댑터.
- `data/songs/`: 검증 가능한 출처를 기록한 자체 큐레이션 곡 메타데이터. 탭과 가사는 저장하지 않는다.

두 교체 지점을 지킨다.

1. `PitchDetector`: Dart 구현과 향후 FFI 구현의 경계.
2. `AudioCapture`: Android/iOS 및 테스트 오디오 소스의 경계.

## 변경 불가 원칙

- GPL 및 GPL 파생 코드를 코드·패키지·테스트 픽스처 어느 형태로도 반입하지 않는다. 금지 예: TarsosDSP, `pitch_detector_dart`, `flutter_pitch_detection`, aubio, `mic_stream`.
- MPM/YIN은 공개 논문의 수식과 설명을 바탕으로 클린룸 구현한다. 외부 구현을 번역하거나 포팅하지 않는다.
- `tuner_dsp`와 `tuner_domain`은 Flutter를 import하지 않는다.
- 지속적인 DSP 처리는 UI isolate에서 실행하지 않는다. 단, 작고 결정적인 유닛 테스트와 벤치마크는 예외다.
- 런타임 오디오 입력은 UNPROCESSED를 먼저 시도하고, 무음/RMS 및 실제 샘플레이트 검증에 실패하면 VOICE_RECOGNITION으로 폴백한다. OEM 기본 MIC 처리에 의존하지 않는다.
- 곡 데이터는 직접 큐레이션한다. Ultimate Guitar를 스크래핑하지 않고 Songsterr를 런타임 의존성으로 사용하지 않는다.
- 정확도를 하나의 숫자로 홍보하지 않는다. 합성 신호, 녹음된 실기타, 실제 기기 라이브 입력을 분리해 측정한다.

## DSP 기준값

- 내부 샘플레이트: 48,000 Hz mono PCM.
- 지원 검출 하한: 43 Hz.
- 고역 통과 필터: 30 Hz. 70 Hz로 올리지 않는다.
- 기본 분석 창/홉: 4,096 / 1,536 samples.
- 저튜닝 분석 창: 8,192 samples.
- 후보 안정화 기본값: 신뢰도 0.9, median-of-5, EMA alpha 0.3.
- 기본 인튠 잠금: 새 피킹 후 1초 안에 안정화 추정값이 한 번이라도 ±2 cents에 들어오면 즉시 완료한다. 빠른 경로를 놓치면 ±3 cents를 750 ms 유지하는 규칙을 사용한다. 초보 모드는 연속 유지 허용치를 ±5 cents, 프로 모드는 ±1~2 cents로 둔다.
- 장력: `T = UW * (2 * L * F)^2 / 386.4`, 길이는 inch, 주파수는 Hz, 결과는 lbf.

정확도 합격/실패 조건은 `docs/accuracy-spec.md`를 단일 기준으로 삼는다. 임계값 변경은 테스트와 문서를 함께 수정한다.

## 개발 방식

- UI를 설계·수정하기 전에 `docs/design-playbook.md`와 `docs/ui-plan.md`를 읽고 토큰·상태 이름·P0 우선순위를 구현 기준으로 사용한다.
- 먼저 실패하는 작은 테스트를 추가하고 구현한다.
- 피치 정확도 변경은 합성 코퍼스와 실기타 WAV 코퍼스 결과를 각각 보고한다.
- 옥타브 오류는 평균 센트 오차에 숨기지 않고 별도 비율로 보고한다.
- 샘플레이트, 창 크기, 주파수 하한처럼 결과를 바꾸는 값은 매직 넘버로 흩뜨리지 않는다.
- 곡 검색 결과에서 튜닝 화면으로 전달되는 것은 문자열 이름이 아니라 버전이 있는 `TuningDefinition` 식별자와 스냅샷이어야 한다.
- 페그 방향은 조건문 묶음이 아닌 검증 가능한 데이터/진리표로 표현한다.
- 안정성 진단은 단정하지 않고 관측값과 "가능성"을 분리해 표시한다.

## Design Intelligence / Product Designer Mode

UI 작업에서 에이전트는 단순 Flutter 구현자가 아니라 시니어 모바일 제품 디자이너이자 UI 엔지니어로 행동한다. 제공된 Figma 선택물이나 시각 레퍼런스를 그대로 복사하지 않고, 제품 목표에 맞게 비평·선별·재구성한다.

### 제품 맥락

- toauner는 Android/iOS 네이티브 기타 튜너이며, Hz와 cent 오차의 고정밀 측정, 드롭 튜닝·저주파 현·메탈/확장현 기타, 곡별 튜닝 프리셋을 핵심으로 한다.
- 앱은 일반 음악 앱이 아니라 정밀 오디오 계기여야 한다.
- GNOME/Adwaita는 목록·설정·검색·빈 상태·차분한 위계에, Material 3는 Android 상호작용과 접근성에, toauner 고유 언어는 튜너 계기·저주파 진단·클리핑 경고·악기 데이터 표시에 쓴다.
- 시각 정체성은 Linux + macOS 계열의 차분하고 어두운 기술적 정밀함이다. 유치하거나 과도하게 광택 나지 않고, 테마 팩을 복사한 결과가 아니라 사람이 설계한 신호/오디오 도구처럼 보여야 한다.

### 키트의 역할 분리

UI 키트를 시각 테마로 섞지 않는다.

1. Adwaita/GNOME는 페이지 구조, preference/list/search row, 설정 위계, 빈 상태, 차분한 간격에만 참고한다. 기본 Adwaita 색이나 데스크톱 창 크롬은 복사하지 않는다.
2. Material 3는 최소 48dp 터치 대상, bottom sheet, text field, button, chip, slider, dialog, snackbar, 접근성 상태 같은 모바일 상호작용 규칙에만 쓴다. 앱을 일반 Google 앱처럼 만들지 않는다.
3. toauner는 tuner display, frequency readout, cent meter, confidence, low tuning mode, clipping warning, song tuning card, terminal diagnostic card의 시각 언어를 소유한다.

### 디자인 리뷰 기준

UI를 구현하기 전에 다음을 검토한다.

- 사용자가 이 화면에서 달성하려는 일과 가장 중요한 정보는 무엇인가?
- 무엇이 시각적으로 지배적이어야 하고, 무엇을 보조 정보로 내릴 수 있는가?
- 제거할 수 있는 요소는 무엇인가?
- 실제 제품처럼 보이는가, AI 생성 목업처럼 보이는가?
- 작은 Android 화면, 한 손 조작, 저조도, 소음 환경, 빠른 한눈 확인에서 작동하는가?
- 모든 터치 대상은 48dp 이상인가?
- loading, empty, error, disabled, focused, selected, warning, success 상태가 있는가?
- 간격·타이포 위계가 일관되고 Hz/cent 같은 수치가 즉시 읽히는가?

사용자 지시가 제품 사용성을 해치는 경우, 문제를 짧게 설명하고 더 나은 설계 결정을 제안한다. 사용자가 명시적으로 고집하지 않는 한 더 나은 결정을 구현한다.

### Anti-AI-Look 규칙

- Dracula, Gruvbox, Nord, Catppuccin 등 유명 테마를 이유 없이 섞거나 그대로 복사하지 않는다.
- 임의 gradient, 과도한 glassmorphism, 모든 곳의 무거운 shadow, 불일치한 radius, 장식용 blob, 무의미한 neon glow, 의미 없는 애니메이션을 금지한다.
- 텍스트가 더 명확한 곳에 아이콘을 남발하지 않는다.
- 계층 없는 빽빽한 dashboard, 모든 카드가 같은 중요도로 보이는 구성, 기본 키트/Figma 선택물의 직접 복제를 금지한다.
- 튜너를 crypto dashboard처럼 만들지 않는다.

### Design Contract와 품질 게이트

- UI 작업 전 루트 `DESIGN.md`, `docs/design-playbook.md`, `docs/ui-plan.md`를 읽는다.
  `DESIGN.md`는 화면 위계·간격·버튼 상태·금지 패턴의 프로젝트 계약이고, 정확한
  색·타입 값은 `instrument_theme.dart`의 토큰이 단일 진실의 원천이다.
- Figma/커뮤니티 키트는 구조, 상호작용, 간격, 상태를 분석하기 위한 참고일 뿐이다.
  원본의 palette, 폰트, 컴포넌트 외형, 마케팅 레이아웃을 직접 복제하지 않는다.
- 구현 전에는 사용자 목표, 첫 시선의 정보, 제거할 요소를 판단한다. 구현 뒤에는
  기본/pressed/focused/disabled/loading/empty/error/success 상태와 48dp·대비·텍스트
  확대·TalkBack·그레이스케일을 확인한다.
- gradient, gradient text, glass/backdrop blur, 장식용 glow, 균일한 큰 radius와
  shadow의 카드 반복, 의미 없는 dashboard/bento, 기본 키트 외형, 모호한 CTA를
  새 UI에 넣지 않는다. 그림자는 `InstrumentSurface`에서 실제 elevation에만 쓴다.
- 시각적 완료는 렌더·골든 또는 실기기 캡처를 직접 확인한 뒤에만 주장한다. 각 디자인
  변경은 AI 티 감사(P0/P1), 테스트, 필요 시 실기기 대조를 거친다.

### toauner 기본 시각 토큰

다른 작업이 명시적으로 바꾸지 않는 한 다음은 기본 설계 방향이다. 실제 hex 선언은 `app/lib/src/app/instrument_theme.dart`의 테마 계약에서만 관리하며, 유명 테마 색을 그대로 사용하지 않는다.

| 역할 | 기본값 |
| --- | --- |
| bgBase / bgElevated / bgCard / bgSunken | `#0B0F14` / `#111820` / `#151D26` / `#070A0E` |
| borderSubtle / borderStrong | `#26313D` / `#3A4654` |
| textMain / textSub / textMuted | `#F3F6F8` / `#9AA6B2` / `#5F6B76` |
| tuneLocked / tuneNear / tuneWarn / tuneError | `#00E5A8` / `#B7F76A` / `#FFB84D` / `#FF4F5E` |
| accentPro / accentShark | `#6C7CFF` / `#4DE1FF` |

- 일반 UI는 Pretendard 계열 또는 시스템 한글 폰트를 사용한다.
- Hz, cent, confidence, RMS, 저주파 및 진단 수치는 JetBrains Mono 또는 동등한 모노스페이스 역할을 사용한다.
- typeface를 과도하게 늘리지 않는다. 큰 수치 계측값은 한눈에 읽혀야 한다.
- 주요 카드 radius는 12–16dp, 컨트롤은 8–12dp, spacing은 4/8dp 리듬을 기본으로 한다. 화면마다 하나의 강한 focal point만 둔다.

### toauner 고유 제품 자산

다음은 키트 import가 아니라 고유 컴포넌트로 설계·유지한다.

- `TunerNeedle`, `FrequencyReadout`, `CentMeter`, `StringRail`, `TuningLockState`, `ConfidenceBadge`
- `ClippingWarningBanner`, `LowTuningModeBadge`, `StabilityRing`, `TerminalDiagnosticCard`
- `SongTuningCard`, `GaugeRecommendationCard`, `PegDirectionGuide`, `TuningPresetBottomSheet`

이들은 어두운 기술적 배경, 강한 수치 판독성, 최소한이지만 의미 있는 색, 안정/경고/오류의 명확한 상태를 공유하며 기능 없는 장식을 넣지 않는다.

### 화면별 우선순위

**메인 튜너**는 감지 음/현 → Hz → cent 오차 → 조정 방향 → confidence/stability → 현재 프리셋 → clipping/noise warning 순으로 한눈에 이해되어야 한다. 곡 라이브러리·설정·진단은 주 화면에 과적재하지 않고 카드나 bottom sheet로 내린다.

**곡 라이브러리**는 Adwaita형 차분한 검색/목록 구조를 사용한다. 행에는 아티스트, 곡명, 튜닝, 필요 시 카포·현 수·신뢰/출처 상태를 두며, 행동은 `이 곡으로 튜닝` 또는 `튜닝 적용`처럼 명확히 한다. 탭과 가사는 표시하지 않는다.

**설정**은 Audio input, Tuner behavior, Display, Instrument setup, Low tuning mode, Data and song library, About/licenses 같은 의미 있는 그룹의 preference row를 사용한다. debug dump처럼 만들지 않는다.

**진단/안정성**은 attack overshoot, settle time, drift, confidence, possible cause를 읽기 쉽게 보여준다. 원인은 `가능한 원인`, `가능성 높음`, `…일 수 있음`처럼 신중하게 말하고 단정하지 않는다.

### 구현·검증 행동

1. UI 구현 전 기존 코드와 디자인 구조를 읽고 재사용 컴포넌트를 찾는다.
2. 하드코딩 색 대신 토큰, 범용 UI와 tuner 고유 컴포넌트의 분리, 작은 Android 화면 반응형 레이아웃, 시맨틱 이름을 우선한다.
3. happy path뿐 아니라 상태와 접근성 레이블을 구현한다. 시각 목적만으로 새 의존성을 추가하지 않는다.
4. 변경 후 formatter와 관련 테스트를 실행한다.
5. 완료는 하나의 명확한 focal point, 토큰 기반 색, Android에서 사용할 수 있는 터치 대상, 실제 기타 튜닝 사용 조건, 유지보수 가능한 구현을 모두 만족해야 한다.

### Figma 처리 규칙

- Figma selection 또는 screenshot을 받으면 레이아웃 의도, 컴포넌트 역할, 간격 리듬, 타이포 위계, 상호작용 모델만 추출한다. generic한 결과는 더 나은 toauner 설계로 교정한다.
- Figma URL/노드 ID가 있으면 먼저 정확한 노드의 design context와 screenshot을 읽고, 그 뒤에만 구현한다.
- Figma의 React/Tailwind 결과는 표현 자료일 뿐이다. Flutter의 토큰·컴포넌트·상태 관리로 번역하고, 디자인 시스템 토큰이 충돌하면 toauner 계약을 우선한다.
- 링크에는 정확한 selection node가 포함되어야 한다. 여러 키트가 섞였으면 어떤 키트가 구조를 제공하는지, 어떤 키트가 상호작용을 제공하는지 식별한 뒤 시각 스킨은 toauner 토큰으로 교체한다.

## 검증 명령

Flutter SDK 설치 후 루트에서 실행한다.

```powershell
.\tool\bootstrap.ps1
.\tool\check.ps1
```

앱 실기기 검증은 에뮬레이터가 아닌 Android 실제 기기에서 수행한다. 최소 한 대는 삼성 기기를 포함한다.

## 커밋 규칙

Conventional Commits 형식을 사용한다: `feat:`, `fix:`, `test:`, `docs:`, `refactor:`, `build:`, `ci:`, `chore:`. 서로 독립적으로 되돌릴 수 있는 변경은 한 커밋에 섞지 않는다.
