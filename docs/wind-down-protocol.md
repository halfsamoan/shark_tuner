# 컨텍스트 마무리 프로토콜 (잔여 토큰 20%)

잔여 토큰이 **20%** 아래로 떨어지면 진행 중인 탐색·리팩터링을 즉시 멈추고 이 문서의 순서대로만 실행한다.
목표는 "더 많이 끝내기"가 아니라 **다음 세션이 이어받을 수 있는 상태로 봉인하기**다.

새 기능 착수 금지. 새 파일 분할 금지. 새 일괄 치환(mass replace) 금지. 리팩터링 금지.

---

## 0. 왜 이게 필요한가 (2026-07-15 실측)

검증 시점에 이 저장소는 다음 상태였다:

- 브랜치 `codex/sharktune-ui-rebuild`에 **커밋이 0건**. 테마 레지스트리, 설정 저장소, 도구 메뉴,
  IBM Plex 번들, 튜너 4분할(1,992줄 → 1,071+126+292+510)이 **전부 커밋되지 않은 워킹 트리**에만 존재.
- 즉 이 시점에 컨텍스트가 끊기면 작업물이 사라지진 않지만, 기록·되돌리기·이등분(bisect)이 모두 불가능하다.

따라서 20% 시점의 1순위는 **항상 커밋**이다. 문서 갱신이나 남은 정리보다 먼저다.

---

## 1. 커밋 (최우선, 생략 불가)

먼저 green을 확인한 뒤 커밋한다. 순서를 바꾸지 않는다.

```powershell
cd C:\toauner\app
..\.tools\flutter\bin\flutter.bat test          # 반드시 app\ 안에서 (아래 §4 함정 참조)
cd C:\toauner
.\.tools\flutter\bin\flutter.bat analyze app
```

green이면 **논리 단위로 나눠서** 커밋한다. 한 덩어리로 뭉치지 않는다:

```powershell
git add app/lib/src/app/instrument_theme.dart app/lib/src/app/app_preferences.dart app/lib/src/ui/instrument_surface.dart
git commit -m "feat: add runtime theme registry and preferences store"

git add app/lib/src/tuner/precision_tuner_*.dart
git commit -m "refactor: split precision tuner into screen/controls/setup/panels"

git add app/assets/fonts app/pubspec.yaml docs/ATTRIBUTIONS.md app/lib/src/app/bundled_font_licenses.dart app/test/bundled_font_assets_test.dart
git commit -m "feat: bundle IBM Plex Mono/Sans KR with OFL license"

git add app/test docs/design-playbook.md docs/theme-system-design-2026-07-15.md
git commit -m "test: pin theme contract via compliance gate"
```

**red이면**: 고치려 들지 말 것. 토큰이 부족하다. 실패 테스트명을 그대로 §3 인수인계 문서에 적고,
`git stash` 하지 말고 워킹 트리에 그대로 둔 채 커밋만 `wip:` 접두사로 남긴다.

```powershell
git add -A
git commit -m "wip: theme migration, <실패 테스트명> red — see docs/handoff-<날짜>.md"
```

---

## 2. 사실만 보고 (추정 금지)

마지막 응답에는 다음만 쓴다. "다 됐습니다" 같은 요약 금지.

- 통과한 테스트 수 / 전체 (예: `100/100 green`) — **실제로 돌린 명령의 출력만** 인용
- analyze 결과
- 커밋 해시 목록
- 아직 red이거나 검증 못 한 항목

부분 테스트만 돌렸다면 "일부만 돌렸다"고 명시한다. 선택 파일만 통과한 걸 전체 green이라 말하지 않는다.

---

## 3. 인수인계 문서 작성

`docs/handoff-<YYYY-MM-DD>.md` 를 만든다. 길게 쓰지 말고 아래 5줄 골격만 채운다:

```markdown
# 인수인계 <날짜>

## 지금 상태
- 브랜치 / 마지막 커밋 해시 / green|red

## 끝난 것
- (검증된 것만. 코드가 있다는 것과 검증된 것은 다르다)

## 안 끝난 것 — 다음 세션 1순위
- (파일 경로 + 줄번호까지)

## 알려진 부채
- (§5 목록에서 아직 남은 것)

## 밟으면 안 되는 지뢰
- (§4)
```

---

## 4. 이 저장소의 함정 (실측 확인됨)

**테스트는 반드시 `app\` 디렉터리 안에서 돌린다.**

```powershell
cd C:\toauner\app
..\.tools\flutter\bin\flutter.bat test        # ✅ 100/100 통과
```

저장소 루트에서 `flutter test app` 으로 돌리면 asset 번들 경로가 어긋나
`bundled_song_assets_test`, `bundled_font_assets_test` 4건이 **실제로는 멀쩡한데 실패**한다
(`Unable to load asset: "assets/songs/catalog.v1.json"`). 이걸 진짜 회귀로 오인해 고치려 들지 말 것.

analyze는 루트에서 `flutter analyze app` 으로 돌려도 정상이다.

---

## 5. 알려진 부채 (20% 시점에 고치지 말 것 — 인수인계에만 기록)

의도적으로 남긴 것들이다. 토큰 부족 상태에서 손대면 green을 깬다.

1. **불필요한 `const` 제거.** 테마 참조를 `context.terminal.` 로 바꾸는 일괄 치환 과정에서
   `const` 를 기계적으로 벗겼는데, 테마를 전혀 참조하지 않는 위젯까지 딸려 벗겨졌다:
   - `app/lib/src/songs/song_detail_screen.dart:65` — `Divider(height: 1)`
   - `app/lib/src/songs/song_search_screen.dart:574` — `Divider(height: 1)`
   - `app/lib/src/tension/tension_recommendation_screen.dart:381-382` — `shape: Border()`, `collapsedShape: Border()`
   - `app/lib/src/tension/tension_recommendation_screen.dart:408` — `Divider(height: 1)`

   `flutter_lints` 는 `prefer_const_constructors` 를 켜지 않으므로 **analyze가 절대 못 잡는다.**
   정확성 문제는 아니고 리빌드 비용만 늘어난다. 별도 커밋으로 되돌릴 것.

2. **폰트 관련 문서 잔재.** D2Coding/Pretendard가 아직 번들된 것처럼 서술된 곳:
   - `docs/figma-gap-analysis.md:22,43`
   - `docs/release-plan.md:56`

   `docs/design-playbook.md` 와 `docs/ATTRIBUTIONS.md` 는 IBM Plex로 갱신 완료.

---

## 6. 하지 말 것

- 실패를 "환경 문제"로 넘겨짚고 넘어가기 — §4에 없는 실패는 진짜 실패다
- 커밋 없이 세션 종료
- 검증 안 한 것을 완료로 보고
- 20% 시점에 새 일괄 치환 실행 (되돌릴 토큰이 없다)
- 골든 이미지 재생성 (실기기 해상도 필요, 다음 세션으로)
