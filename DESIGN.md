# toauner Design Contract

이 문서는 toauner의 UI 판단을 위한 짧은 계약이다. 구현 전에는 이 문서와
`docs/design-playbook.md`를 읽는다. 정확한 Flutter 색 값과 type role은
`app/lib/src/app/instrument_theme.dart`가 단일 진실의 원천이다.

## 방향

toauner는 음악 앱이나 SaaS 대시보드가 아니라, 기타 옆에서 빠르게 읽는
정밀 오디오 계측기다. 화면은 차분하고 어두운 Linux/macOS 계열의 구조를
갖되, 계측값은 악기처럼 즉시 읽혀야 한다.

- 하나의 화면에는 하나의 분명한 초점만 둔다.
- 라이브 튜너의 우선순위는 cent 오차, 음이름, 목표 Hz, 미터, 현, 상태다.
- 곡 검색·설정·진단은 튜너의 초점을 침범하지 않는다.
- 일반 목록/설정/검색은 Adwaita식 행과 간격을 사용한다.
- 모바일 터치, 텍스트 필드, 시트, 다이얼로그는 Material 3 상호작용 규칙을
  따르되 Google 앱의 외형을 복제하지 않는다.

## 토큰과 비율

- 색은 `TerminalTheme`의 semantic role만 사용한다. 직접 색 선언은 금지한다.
- 테마는 각각 독립된 표면 관계를 가진다. 단순 반전이나 유명 팔레트 복사는
  금지한다. Abyss는 차가운 청록, Onyx는 중성 흑백, Amber는 절제된 목재색,
  Violet은 저채도 보라, Paper는 따뜻한 종이, Clipping은 의도적인 손상 신호다.
- 한 화면의 색 비율은 대체로 canvas/surface 70–85%, text/line 10–20%, accent와
  상태색 5–10%다. accent는 장식이 아니라 결정적인 행동/측정 상태에만 쓴다.
- 기본 간격은 4/8dp 리듬이다. 화면 섹션은 24–32dp, 컴포넌트 내부는 8/12/16dp를
  우선한다. 같은 간격을 기계적으로 반복하지 말고 정보 위계에 따라 압축/분리한다.
- 큰 표면은 12–16dp, 일반 버튼은 8dp, 계기판의 정밀 조작부는 2–4dp radius를 쓴다.
  radius와 그림자는 전체에 균등 적용하지 않는다.
- 일반 UI는 Pretendard 계열, 계측 숫자/Hz/cent/진단값은 JetBrains Mono다.

## 버튼과 표면

- 모든 터치 목표는 최소 48dp다.
- Primary 버튼은 accent 면, `accentEdge` 선, `onAccent` 글자를 가진다. 한 화면에서
  보통 하나만 둔다.
- Secondary/segmented 버튼은 panel 면과 hairline을 사용하며, 행동의 수를 드러내되
  primary와 경쟁하지 않는다.
- 눌림/포커스/비활성/로딩/오류 상태를 설계한다. 눌림은 짧은 tonal overlay와 선의
  변화로 표현하며, 네온 glow·튀는 확대·bounce는 쓰지 않는다.
- `InstrumentSurface`만 elevation을 표현한다. 그림자는 얕고 무채색이며 실제로
  떠야 하는 표면에만 쓴다.

## 금지 패턴

- 보라→파랑 gradient, gradient text, glassmorphism, backdrop blur, 장식용 neon glow.
- 모든 카드의 동일한 큰 radius/그림자/패딩, 의미 없는 bento·대시보드 밀도,
  아이콘을 넣은 둥근 사각형의 반복.
- 기본 테마/키트의 palette·폰트·버튼을 그대로 복제하는 것.
- 중앙 정렬 hero, 3개 동일 feature card, 장식 pill, 이모지 feature bullet,
  `시작하기 →` 같은 일반적 CTA와 과장된 마케팅 카피.
- 튜너를 crypto/dashboard처럼 보이게 하는 장식 수치, 유리 패널, 상시 애니메이션.

## 화면별 규칙

- 홈: 자유 튜닝이 첫 행동이다. 곡 검색은 명시적인 보조 흐름이다.
- 검색/라이브러리: 제목, 아티스트, 튜닝만 빠르게 읽히는 calm list row를 쓴다.
- 곡 상세: 튜닝·개방현·즉시 튜닝 CTA가 먼저며 보조 추천은 뒤로 보낸다.
- 설정: 그룹 제목과 preference row를 사용한다. debug dump처럼 나열하지 않는다.
- 빈/로딩/오류: 같은 공간을 쓰되, 다음 행동을 하나 제시한다.

## 품질 게이트

디자인 변경마다 다음 순서로 판단한다.

1. 사용자 목표, 첫 시선의 정보, 제거할 요소를 한 문장으로 적는다.
2. 상태(기본/pressed/focused/disabled/loading/empty/error/success)를 확인한다.
3. 48dp, 대비, 1.3x/2.0x 텍스트, TalkBack, 그레이스케일을 검증한다.
4. AI 티 감사: 토큰 외 색, gradient/glass, 균일 카드, 기본 키트 외형, 모호한
   카피가 없는지 확인한다.
5. Flutter 테스트·골든·실기기 캡처로 검증한다. 렌더를 보지 않고 시각적 통과를
   주장하지 않는다.

## 참고 레퍼런스의 역할

`_design_refs/`의 저장소는 코드 의존성이 아니라 검토용이다.

- avoid-ai-design: 금지 패턴과 재감사 방식
- design-md / design-system-builder-skills: 명시적 토큰·간격·컴포넌트 계약
- Tokyn: 표면 세부와 버튼 상태의 절제
- ui-craft / StyleSeed: 구현 뒤 review/polish 게이트
- brandmd: 외부 제품을 복제하지 않는 분석 보조

새 UI는 이 문서의 제품 규칙을 우선하며, 레퍼런스의 스킨이나 템플릿을 직접
반입하지 않는다.
