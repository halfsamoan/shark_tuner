# SharkTune 디자인 플레이북

이 문서는 SharkTune UI의 구현 계약이다. 사용자 명시 결정이 최우선이며, 화면을 수정하기 전에 이 문서와 `docs/ui-plan.md`를 함께 읽는다. 세부 팔레트 값과 Flutter 필드 대응은 `docs/theme-system-design-2026-07-15.md`가 보완한다.

## 1. 제품 원칙

- SharkTune은 곡을 먼저 찾고, 별도 설정 없이 정밀 튜닝으로 이어지는 계측 도구다.
- 화면은 터미널을 흉내 내는 장식이 아니라 실제 악기 계기판처럼 읽혀야 한다.
- 사용자 언어를 쓴다. DSP, FTS, isolate, 후보, 검증 필요 같은 내부 용어를 릴리스 화면에 노출하지 않는다.
- 한 화면의 주인공은 하나다. 홈은 검색, 곡 상세는 튜닝 요약, 라이브 튜너는 센트 오차가 주인공이다.
- 색만으로 상태를 전달하지 않는다. 문구, 위치, 형태, TalkBack 레이블을 함께 사용한다.
- 임의 그라데이션, 큰 둥근 카드 묶음, 균일한 그림자, 장식용 아이콘 무더기, 과한 글로우는 사용하지 않는다.

## 2. 브랜드와 타이포그래피

공개 이름은 `SharkTune`이다. application ID, bundle ID, MethodChannel, 데이터베이스 파일명 같은 호환성 식별자는 기존 값을 유지한다.

폰트 역할은 다음으로 고정한다.

| 역할 | 패밀리 | 크기 / 줄높이 | 규칙 |
| --- | --- | --- | --- |
| 센트 계측값 | IBM Plex Mono | 96 / 96 | tabular figures, -0.02em |
| 음이름 | IBM Plex Mono | 52 / 56 | 중앙 계측값 |
| 화면 제목 | IBM Plex Sans KR | 28 / 36 | 한글·라틴 공통 톤 |
| 소제목 | IBM Plex Sans KR | 20 / 28 | weight 600 |
| 본문 | IBM Plex Sans KR | 16 / 24 | weight 400 |
| 캡션 | IBM Plex Sans KR | 13 / 19 | 보조 정보 |
| 상태값 | IBM Plex Mono | 11 / 14 | 라틴만 +0.04em |

- 숫자는 폭이 바뀌어도 레이아웃이 흔들리지 않아야 한다.
- 한글 본문에 모노스페이스를 사용하지 않는다.
- 합성 볼드와 시스템 폰트 폴백을 출시 상태로 두지 않는다.
- 카피는 짧게 쓴다: `조금 높음 · 4번 줄 낮추기`처럼 상태와 행동을 한 번에 말한다.

## 3. 6개 테마 계약

사용자가 설정에서 다음 여섯 테마를 선택한다.

| ID | 표시 이름 | 성격 | Brightness |
| --- | --- | --- | --- |
| `abyss` | Abyss | 기본 딥 아쿠아, 수중 계기판 | dark |
| `onyx` | Onyx | 순흑 무대·야간 | dark |
| `amber` | Amber | 따뜻한 우드 클래식 | dark |
| `violet` | Violet | 보라색 야간 계기판 | dark |
| `paper` | Paper | Solarized 계열의 유일한 일반 라이트 | light |
| `clipping` | Clipping | 브루탈리즘·글리치 실험 스킨 | dark 시스템 크롬, 전용 튜너 레이아웃 |

일반 화면에서 Clipping은 시맨틱 팔레트를 사용할 수 있지만 라이브 튜너는 `TunerSkin.clipping` 전용 구조를 쓴다. 나머지 다섯 테마는 같은 컴포넌트와 레이아웃을 유지하고 토큰만 교체한다.

### 3.1 시맨틱 색 역할

`TerminalTheme`은 브랜드 이름이 아닌 역할 이름만 가진다.

- 표면: `backgroundSunken`, `backgroundCanvas`, `backgroundPanel`, `backgroundRaised`, `backgroundHeader`
- 구조: `lineHairline`, `gridTick`
- 상호작용: `accent`, `accentEdge`, `onAccent`
- 상태: `successFlood`, `successHold`, `warning`, `warningStroke`, `information`, `danger`, `onDanger`
- 텍스트: `ink`, `inkSecondary`, `textSecondary`
- 재질: `surfaceHighlight`, `surfaceGroundLine`

`danger`는 실패·오류, `warning`은 주의·조정 필요에만 사용하며 서로 같은 값이나 별칭이 될 수 없다. 라이브 화면은 `context.terminal`, `context.instrumentType`을 사용한다. 화면 파일에 직접 `Color(0x...)`를 선언하지 않는다.

### 3.2 대비와 재질

- 본문·캡션·상태 텍스트: 배경 대비 4.5:1 이상.
- 큰 텍스트와 정보성 비텍스트: 3:1 이상.
- `gridTick`과 장식용 hairline은 정보를 단독 전달하지 않는 경우만 3:1 미만을 허용한다.
- 그림자와 양각·음각 표현은 `InstrumentSurface` 한 곳에서만 만든다.
- 다크 테마의 깊이는 표면 램프, 1px hairline, 위쪽 highlight와 아래쪽 ground line으로 표현한다.
- Paper는 밝기 방향을 반전하고 얕은 웜 섀도우를 허용한다.
- bloom은 미터 니들, lock 순간, 활성 칩처럼 실제 발광원에만 제한한다.

## 4. 화면 위계

### 홈과 검색

- 검색 필드를 첫 위계로 둔다. 거대한 `바로 튜닝` 카드는 제거한다.
- 헤더에는 워드마크와 라벨이 있는 `도구` 버튼만 둔다.
- 도구 bottom sheet는 메트로놈, 튜닝 기록, 줄 관리, 설정, 개인정보를 텍스트 행으로 노출한다.
- 검색은 250ms debounce, 입력 지우기, 로딩·빈 결과·오류 상태, 최근 선택 검색어 최대 5개와 전체 지우기를 제공한다.

### 곡 상세

- 제목·아티스트 → 튜닝 요약 → 현 배열 순으로 보여준다.
- 메트로놈과 장력 추천은 보조 행이다.
- 하단에는 `이 튜닝으로 시작` CTA 하나만 고정한다.

### 라이브 튜너

위계는 반드시 다음 순서다.

1. 센트 오차
2. 음이름
3. 목표 주파수
4. 피치 미터
5. 현 칩
6. 사용자 상태 문구

튜너 본문에는 큰 CTA나 진단 수치를 두지 않는다. DSP 수치는 debug 전용 접이식 패널로 이동한다. 첫 진입 안내는 마이크 사용, 기기 내 처리, 현을 한 번씩 튕기는 방법만 짧게 보여주고 한 번만 표시한다.

상태 이름은 코드·테스트·Figma에서 동일해야 한다.

- `NoteChip`: idle, activeAuto, activeManual, hearingOther, settling, locked, done
- `PitchMeter`: waiting, coarse, fine, wrongString, locked, complete
- `GuidanceSlot`: pluckPrompt, direction, wrongString, tooQuiet, noisy, settling
- `StatusLine`: listening, warning, error, development

잠금은 새 피킹 뒤 1초 안에 ±2 cents를 통과하면 즉시 완료한다. 빠른 경로를 놓치면 Beginner는 ±5 cents, Pro는 ±2 cents를 750ms 유지한다.

## 5. 접근성과 모션

- 모든 탭 대상은 최소 48dp다.
- TalkBack은 현, 음이름, 센트 방향, 필요한 행동을 한 문장으로 읽고 초당 1회 이하로 갱신한다.
- 1.3x에서 모든 핵심 화면을 검증하고, 튜너는 2.0x에서도 스크롤 없이 핵심 계측값이 남아야 한다.
- 사용자 `모션 줄이기`와 시스템 축소 설정을 OR로 적용한다.
- 계측 모션은 linear 또는 steps 계열 120–160ms를 기본으로 하며 bounce를 금지한다.
- 그레이스케일에서도 flat, sharp, locked, error를 문구와 위치로 구분할 수 있어야 한다.

## 6. Figma 계약

정식 기준 파일은 [SharkTune UI System — 6 Themes](https://www.figma.com/design/jCX0Z6nibXQ9H6ehFpkbJr)다. 기존 `COwsi0untcn8JZi9Bggpou` 파일은 49개 변수와 10개 컴포넌트의 마이그레이션 참고용으로만 둔다.

- 컬렉션: `Primitives`, `Dimensions`, `Typography`, `Motion`, `Theme/Abyss`, `Theme/Onyx`, `Theme/Amber`, `Theme/Violet`, `Theme/Paper`, `Theme/Clipping`.
- 일반 다섯 테마는 컴포넌트의 `Theme` variant다. 30개를 넘는 세트는 역할별로 나눈다.
- Clipping 튜너는 별도 컴포넌트군이다.
- 변수 바인딩 → metadata → screenshot 순으로 검증하고 승인 이미지는 `reports/design/`에 저장한다.

Figma 호출 제한이나 외부 장애가 있을 때 Flutter 계약을 임의로 바꾸지 않는다. 제한이 해제되면 파일·라이브러리 상태를 다시 읽고 코드 토큰과 1:1로 맞춘다.

## 7. 실기기 프레임과 검증

기준 기기는 `docs/device-profile-2026-07-13.md`의 Samsung SM-S926N이다. 승인 스크린샷의 물리 프레임은 **1080×2340**이다. Flutter 골든은 같은 화면을 DPR 3으로 환산한 **360×780 logical px**을 사용한다. 412×915 프레임은 사용하지 않는다.

유지비를 통제하기 위해 자동 골든은 라이브 튜너의 세 테마만 둔다.

- Abyss: 기본 다크 계약
- Paper: light ColorScheme과 반전 재질
- Clipping: 전용 튜너 레이아웃

나머지 테마는 계산 대비 테스트와 실제 삼성 기기 스크린샷으로 검증한다. 실기기 이미지는 `reports/device/`, Figma 승인 이미지는 `reports/design/`에 둔다.

## 8. 코드 마이그레이션 계약

- 레거시 `InstrumentColors`와 정적 `InstrumentTypeTheme.standard`은 금지한다.
- 대량 전환 중에는 파일 경로 allowlist를 사용하되, 파일을 마이그레이션할 때마다 항목을 제거한다. allowlist는 증가할 수 없고 최종값은 빈 집합이다.
- `CustomPainter`와 정적 캐시는 생성자에서 `TerminalTheme`과 `InstrumentTypeTheme` 스냅샷을 받는다.
- `precision_tuner_screen.dart`는 상태 조정, 화면 조립, 패널·시트, 페인터를 분리해 한 파일에 위험이 집중되지 않게 한다.
- 공개 릴리스 문자열 감사는 홈, 검색, 곡 상세, 튜너, 도구 메뉴, 설정, 앱 정보와 개인정보 화면을 모두 렌더해 검사한다.

## 9. 완료 체크리스트

- [ ] 6테마 선택, 재시작 복원, 손상 파일·백업 복구
- [ ] 본문 4.5:1, 큰 텍스트·정보성 비텍스트 3:1 계산 통과
- [ ] 직접 색상, 레거시 정적 색·타입 참조, 화면별 BoxShadow 0건
- [ ] warning과 danger 의미·값 분리
- [ ] 검색 debounce, clear, 최근 검색, 빈 결과 복구
- [ ] 도구 메뉴와 설정의 라벨 기반 탐색
- [ ] 첫 튜너 안내 1회 표시
- [ ] TalkBack, 48dp, 1.3x·2.0x, 모션 축소, 그레이스케일
- [ ] 360×780 튜너 골든: Abyss, Paper, Clipping
- [ ] 전체 `tool/check.ps1`와 Android debug 빌드
- [ ] 삼성 실기기에서 Abyss, Paper, Clipping 촬영 후 Figma 승인 이미지와 대조
