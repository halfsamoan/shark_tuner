# SharkTune 6-theme implementation contract — 2026-07-15

이 문서는 디자인 플레이북을 Flutter와 Figma 필드로 옮기는 구현 명세다.

## Runtime interfaces

- `SharkTuneThemeId`: `abyss`, `onyx`, `amber`, `violet`, `paper`, `clipping`
- `TunerToleranceMode`: `beginner`, `pro`
- `AppPreferences`: theme, tolerance, haptics, reduce motion, tuner primer, recent searches
- `AppPreferencesController`: `MaterialApp` 상위의 저장·복원 가능한 상태
- `JsonAppPreferencesStore`: `app-preferences.v1.json`, `.tmp` 원자 교체, `.bak` 복구

기본값은 Abyss, Beginner, 햅틱 켜짐, 사용자 모션 축소 꺼짐, 튜너 안내 미확인이다. 최근 검색은 사용자가 실제 선택한 항목만 최신순 최대 5개 저장한다.

## Theme mapping

모든 팔레트는 `app/lib/src/app/instrument_theme.dart`의 `SharkTuneThemes`에서만 선언한다. 이 파일이 hex 값의 코드측 단일 기준이다. danger 값은 다음으로 고정한다.

계측 타이포그래피는 `InstrumentTypeTheme.centsHero`와 `measurement` 역할을 통해 제공한다. cent·Hz·confidence·RMS·진단 수치는 JetBrains Mono를 사용하고, 음이름과 상태 라벨은 기존 IBM Plex 역할을 유지한다.

| Theme | danger |
| --- | --- |
| Abyss | `#FF5C72` |
| Onyx | `#E06172` |
| Amber | `#FF6B5C` |
| Violet | `#FF5555` |
| Paper | `#B3212D` |
| Clipping | `#9E0049` |

Paper만 일반 라이트 ColorScheme을 사용한다. Clipping은 밝은 충돌 팔레트 위에 전역 글리치 오버레이를 적용하고, 라이브 튜너에서 `TunerSkin.clipping`을 추가 사용한다.

## Figma components

Foundation 뒤에 다음 순서로 만든다.

1. BrandMark, AppHeader, ToolMenuRow
2. SearchField, SearchResultRow, Loading, Empty, Error
3. Button/Primary, Button/Secondary, Toggle, SettingRow, ThemeTile
4. NoteChip, CentsReadout, PitchMeter, GuidanceSlot, StatusLine
5. DefinitionRow, FirstTunePrimer
6. 자유 튜닝 홈, 사용자 정의 튜닝 편집기, 홈 검색 상태, 곡 상세, 튜너 상태, 도구 메뉴, 설정, 일반 테마 갤러리, Clipping 튜너 프레임

홈의 Figma 프레임과 Flutter 화면은 같은 짧은 카피를 사용한다: `튜닝 시작`, `기본 · 프리셋 · 내 튜닝`, `곡 검색`, `곡 튜닝 찾기`, `곡명 · 아티스트`. 곡 검색 진입은 별도 설명 카드+버튼 조합이 아니라 제목·부제·이동 표식으로 구성된 단일 48dp 이상 액션 행이다.

Starter 변수 모드 제한을 피하려고 테마별 단일 모드 컬렉션을 사용한다. 각 컴포넌트는 변수 바인딩을 확인한 뒤 metadata와 screenshot을 각각 검증한다.

## Migration safety

`design_playbook_compliance_test.dart`의 레거시 allowlist는 파일 단위로만 관리하고 감소만 허용한다. 새 직접 색상과 새 레거시 참조를 허용하기 위해 항목을 추가하지 않는다. 각 마이그레이션 단위는 formatter, analyzer, 관련 테스트를 통과해야 한다.

`precision_tuner_screen.dart`는 리빌드와 함께 분할한다. painter는 context를 직접 읽지 않고 테마와 타입 스냅샷을 생성자로 받는다. 메트로놈의 엔진과 확정된 컨트롤 흐름은 변경하지 않는다.

## Verification matrix

| Contract | Automated | Manual |
| --- | --- | --- |
| All palettes | contrast and semantic token tests | theme gallery review |
| Preferences | codec, atomic backup recovery, restart restore | cold-start check |
| Search | debounce, clear, recent, empty/error recovery | Korean input check |
| Tuner | state widgets, 360×780 goldens for Abyss/Paper/Clipping | Samsung live input |
| Accessibility | semantics, target size, text scale, reduced motion | TalkBack and grayscale |
| Release copy | rendered core-screen vocabulary audit | final copy review |
