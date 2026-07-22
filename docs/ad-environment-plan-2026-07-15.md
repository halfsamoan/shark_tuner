# 광고 도입 환경 구축 계약 — 2026-07-15 (rev.2)

이 문서는 SharkTune에 광고를 **띄우기 위한 환경**을 만드는 구현 계약이다. 광고를 띄우는 것 자체는 이 문서의 목표가 아니다. 이 문서는 `C:\toauner\AGENTS.md`의 변경 불가 원칙을 따르고 `C:\toauner\docs\design-playbook.md`와 `C:\toauner\docs\ui-plan.md`의 토큰·상태 이름·P0 우선순위를 구현 기준으로 사용하며, 광고 관련 심(seam)·게이트·킬 스위치·배치 허용 범위의 코드측 단일 기준이다. 사용자 명시 결정이 이 문서보다 우선한다.

이 문서를 실행하는 에이전트는 이 문서만 읽고 작업할 수 있어야 한다. 모든 경로는 절대 경로로 적는다. 인용한 줄 번호는 2026-07-15 / `a9d113a` 기준이며, **줄 번호가 아니라 심볼 이름으로 위치를 다시 찾는다.** 특히 `C:\toauner\app\lib\src\songs\song_search_screen.dart`의 줄 번호는 이미 드리프트가 확인됐다(인피드 루프는 `:345-347`이 아니라 `:364-365`, 라벨은 `곡에 맞춰 튜닝`이 아니라 `곡 검색`). 인용을 신뢰하지 말고 심볼로 재확인한다.

rev.2는 네 건의 적대적 리뷰(agents-md / feasibility / kr-legal / product-trust)를 반영한 개정본이다. 리뷰가 옳았던 곳은 고쳤고, 리뷰가 틀렸던 곳은 근거를 명시해 입장을 유지했으며, 검증 불가능한 것은 삭제하지 않고 **검증 필요**로 강등했다.

---

## 범위와 경계

- 이 계약은 광고를 **서빙할 수 있는 상태**를 만든다. 광고 단가, 수익 모델, 노출량 최적화는 다루지 않는다.
- 이 계약은 곡 카탈로그를 네트워크로 옮기지 않는다. `C:\toauner\packages\tuner_data\lib\src\song_catalog.dart`의 `SongCatalog` 구현은 계속 `SqliteSongCatalog` 하나다. 곡 검색은 오프라인으로 남는다.
- 이 계약은 로그인, 계정, 결제, 분석 SDK를 도입하지 않는다.
- 이 계약은 리워드 광고를 도입하지 않는다(§11).
- 이 계약이 만드는 것은 심, 게이트, 킬 스위치, 게이트 테스트, 문서 캐스케이드다.
- 광고는 **한 번도 튜닝 정확도의 대가가 아니다.**

성공 기준은 "광고가 보인다"가 아니라 **"광고를 껐을 때 앱이 2026-07-15 이전과 구별되지 않는다"**이다.

**rev.2에서 바뀐 근본 자세:** 이전 초안은 *그렙 가능한 테스트를 그 테스트가 대변하는 계약과 동일시*했다. 네 리뷰 모두 같은 지점을 찔렀다. 이 개정본은 **자동 검사가 못 하는 것을 자동 검사인 척하지 않는다.** Verification matrix의 **수동** 열이 rev.1보다 길어진 것은 후퇴가 아니라 정직해진 것이다.

---

## 0. rev.1 대비 변경 요약 (실행 에이전트는 먼저 읽는다)

| 변경 | 이유 | 출처 |
| --- | --- | --- |
| **인터스티셜을 튜너 훅에서 호출 측으로 이동. C11 삭제** | `_showCompletion()`은 멱등하지 않다(`_completionShown`은 `.whenComplete`에서 `false`로 리셋). 게다가 훅 시점에 튜너가 최상위 라우트라 전면 광고가 튜닝 화면을 덮는다 | feasibility F3·F4, product-trust 1·2 |
| **`feat:`/`test:` 쌍을 한 커밋으로 병합** | AGENTS.md:50(테스트 우선) + :71(단일 관심사)을 동시에 만족. rev.1의 "커밋마다 초록" 규칙은 AGENTS.md에 없는 발명품이었다 | agents-md V3 |
| **C12를 3개 커밋으로 분할** | INTERNET 선언 / AD_ID 제거 / 새 검사는 각각 독립 revert 가능 | agents-md V4 |
| **라이선스 증서를 `C:\toauner\docs\native-ad-sdk-licenses.json`으로 이동** | `.gitignore:35` = `reports/`. rev.1 경로는 커밋되지 않아 C14 이후 영구 red | agents-md V1, product-trust 4 |
| **`android_merged_manifest_permissions`를 수동 열로 이동** | `check.ps1:17`은 `-SelfTest`만 돌린다. 자동 검사가 아니다 | agents-md V2, feasibility 12, product-trust 5 |
| **`android_release_internet` 판별자를 주석→`pubspec.yaml`로 변경** | 주석은 경계가 아니다. 병합기가 주입하는 INTERNET을 마커가 영구 무력화한다 | agents-md V2 |
| **APPLICATION_ID / GADApplicationIdentifier 추가** | 없으면 `MobileAdsInitProvider`가 프로세스 시작 시 크래시. `DisabledAdSource`로 막을 수 없다 | feasibility F1 |
| **`xmlns:tools` 추가** | 매니페스트 루트에 tools 네임스페이스가 없어 `tools:node="remove"`가 파싱 실패 | feasibility F2, product-trust 14 |
| **`main.dart` / `toauner_app.dart`를 커밋 표에 추가** | rev.1은 `AdScope`를 어디에도 마운트하지 않았다 | feasibility F5, product-trust 6 |
| **검색 본문을 `song_search_body.dart`로 추출(C-R)** | `song_search_screen.dart`는 홈(`_buildTuningHome`)과 검색(`_buildSongSearchBody`)을 함께 담는다. 파일 allowlist로는 §4.3의 거부 슬롯을 막을 수 없다 | agents-md V5, product-trust 7 |
| **`app\lib\src\ads\**`를 심볼 스캔에서 제외** | rev.1의 금지 심볼 집합은 심 자신의 선언 파일을 위반으로 만들었다(C5가 C3에 대해 red) | feasibility F6 |
| **Slot B(인피드) 삭제** | `ListView(children:)`는 eager build. 성공 시 인덱스 4 아래 전부가 밀린다. 성공 경로 시프트 테스트는 통과할 수 없다 | feasibility 8, product-trust 10 |
| **Slot C를 `_VerificationNotice` 아래로 이동** | 검증 고지(앱의 정직성 표면) 위에 광고를 앉히지 않는다 | product-trust 10 |
| **`app\lib\src\metronome\`를 금지 목록에 추가** | 최신 연속 오디오 표면인데 rev.1이 누락했다 | product-trust 11 |
| **Play 타깃 대상: 13-15 금지 → 16-17+18+ 또는 18+** | Play에 "14+" 브래킷이 없다. 13-15는 만 14세 미만을 포함해 PIPA 제22조의2를 발동시키고, Families(신규 신청 마감) 함정에 들어간다 | kr-legal F1 |
| **Data Safety: 기기 ID = 예/예, Location(approximate) 행 추가** | app set ID는 AD_ID 권한과 무관하게 남는다. "IP 주소"는 Play 카테고리가 아니다 | kr-legal F2·F3, product-trust 12 |
| **행태정보 고지 + 거부 방법 섹션 신설** | 2025-04-21 처리방침 작성지침은 삭제가 아니라 추가 의무를 부과한다 | kr-legal F4 |
| **국내 변호사 검토가 C16을 차단(릴리스가 아니라)** | 제3자 제공 vs 처리위탁 판단이 동의 게이트 아키텍처를 좌우한다 | kr-legal F5 |
| **Apple App Privacy Details / privacy manifest / 연령등급 추가** | rev.1의 컴플라이언스 캐스케이드는 Play 전용이었다 | kr-legal F7 |
| **UMP를 첫 프레임 이후로 밀고 타임아웃 계약 추가** | `requestConsentInfoUpdate`는 네트워크 왕복. 콜드스타트 튜닝 경로를 막으면 안 된다 | product-trust 16 |
| **골든이 배치 계약의 게이트라는 주장 삭제** | 골든은 `AdScope` 없이 튜너를 직접 렌더한다. 위반해도 바이트 동일 | agents-md V9, feasibility(검증됨) |
| **"shrinking allowlist" → "fixed allowlist"** | placement allowlist는 증가한다. playbook:149의 shrinking 계약은 마이그레이션용이며 별개 범주다 | agents-md V7 |
| **`오프라인` 상태 라벨 감사 추가** | Slot A가 실리는 바로 그 화면이 `오프라인`이라고 표시한다 | product-trust 9 |

---

## 1. Phase 0 — 코드가 아닌 선행 조건

전부 사용자 결정이다. 에이전트는 이 값들을 추측하지 않는다. `차단하는 커밋` 열은 rev.1에서 잘못 매핑돼 있었고(App ID→C11, 단위 ID→C12 — 둘 다 해당 ID를 쓰지 않는 커밋) 아래에서 실제 의존 관계로 고쳤다.

| 항목 | 필요한 결정 | 차단하는 커밋 |
| --- | --- | --- |
| AdMob 계정 | 게시자 계정 개설 및 결제 프로필 주체(개인/사업자) | C13 (프로덕션 ID 전환) |
| 사업자 등록 / 세무 | 계속·반복적 용역 제공이면 **사업소득 → 사업자등록 + 종합소득세**. 일회성이면 기타소득일 수 있다(단정하지 않는다). AdMob 수취는 외화 용역 수출 → **부가세 영세율(0%)**. **영세율은 면세가 아니다 — 납부세액이 0이어도 신고 의무는 남는다.** **세무사 확인 필수** | 릴리스 |
| Android App ID | `ca-app-pub-################~##########` | **C13의 프로덕션 전환 커밋(C13b)**. C13 자체는 Google 공개 테스트 App ID `ca-app-pub-3940256099942544~3347511713`으로 랜딩한다 |
| iOS App ID | 동일 형식. App Store Connect 등록 선행 | C13b |
| 광고 단위 ID | Slot A/C/D 각각 1개. `ca-app-pub-################/##########` | **C19, C20, C22** (rev.1은 C12로 잘못 적었다) |
| 배너 자동 새로고침 | **AdMob 콘솔에서 해당 단위의 자동 새로고침을 끈다.** 코드로 제어 불가. 켜져 있으면 §2.5의 프리페치 금지가 무의미해진다(§2.6) | C19 (수동 확인) |
| `app-ads.txt` | 게시자 도메인 필요. 스토어 등록정보의 "개발자 웹사이트" 도메인 루트에 게시. 없으면 상당수 인벤토리가 스푸핑 방지 필터에 걸린다 | 릴리스 |
| `developer_name` | `C:\toauner\docs\privacy-policy.md` 프론트매터의 `TBD` 해소 | 릴리스 |
| `privacy_contact` | 실제 수신 가능한 연락처 | 릴리스 |
| `public_url` | 지역 제한 없는 HTTPS 방침 페이지. PDF 불가 | 릴리스 |
| **Play 타깃 대상** | **16-17 + 18+ (권장 기본값)** 또는 **18+ 단독**. **13-15는 선택하지 않는다** — 근거 §6.5 | C26 (Play 등록) |
| **Apple 연령 등급** | Kids Category에 넣지 않는다. 질문지 답변 확정 | 릴리스 |
| **Apple App Privacy Details** | App Store Connect의 영양성분표. §7.9의 4개 카테고리 | 릴리스 |
| **국내 법률 검토** | PIPA 행태정보 / 제3자 제공 vs 처리위탁 / 만 14세 미만. **국내 변호사** | **C16** (§6.4) |

**`app-ads.txt`는 코드가 아니라 도메인 자산이다.** Phase 0의 유일한 금전 지출 항목이다.

**검증 필요:** AdMob이 국내 개인 게시자에게 요구하는 세무 서류의 2026년 현재 절차. rev.1은 "W-8BEN 등"이라 적었으나, 국내 게시자는 Google APAC 법인 경유 지급이 일반적이라 **미국 원천징수 서식이 애초에 해당하지 않을 수 있다.** 서식 이름을 미리 지목하지 않는다. 계정 개설 시점에 콘솔에서 직접 확인한다.

---

## 2. Phase 1 — 첫 네트워크 스택과 오프라인 무결성 계약

### 2.1 지금 상태 (검증됨)

- `C:\toauner\app\android\app\src\main\AndroidManifest.xml:1`은 정확히 `<manifest xmlns:android="http://schemas.android.com/apk/res/android">`다. **`xmlns:tools`가 없다.**
- 같은 파일 `:2`는 `android.permission.RECORD_AUDIO` **하나만** 선언한다.
- `INTERNET`은 `debug`/`profile` 매니페스트에만 있고 Flutter 툴링 전용이다.
- `C:\toauner\tool\release_readiness.ps1:151`은 main 매니페스트에 `INTERNET`이 있으면 `blocker`를 낸다. **부재가 합격 조건인 역방향 검사다.**
- `C:\toauner\app\ios\`에 **Podfile이 없다.** iOS는 한 번도 CocoaPods 통합된 적이 없다.

### 2.2 게이트가 지금 잘못 작동하는 지점

`google_mobile_ads`를 넣으면 Gradle **매니페스트 병합기**가 `INTERNET`을 AAR에서 병합 결과물에 자동 주입한다. `release_readiness.ps1`은 **소스 매니페스트만** 정규식으로 읽으므로, 광고를 실은 빌드에서도 `android_release_internet`은 계속 `pass`를 낸다. `C:\toauner\docs\play-data-safety.md:43`이 이미 이 구멍을 사람에게 떠넘겨 놓았다.

> 릴리스 병합 매니페스트에 예기치 않은 `INTERNET` 권한이 없는지 확인합니다.

이 상태를 그대로 두면 게이트가 "오프라인을 강제"에서 "오프라인이 거짓인데 오프라인이라고 주장"으로 바뀐다. **그건 게이트를 지우는 것보다 나쁘다.**

### 2.3 `tool/check.ps1`에 대한 사실 (중요, 검증됨)

`C:\toauner\tool\check.ps1:17-18`은 `release_readiness.ps1`을 **`-SelfTest`로만** 실행한다. `release_readiness.ps1:271-274`에서 자기 검사는 `Get-ReleaseFindings`를 실제 루트에 대해 부르기 **전에** 반환한다. 즉 **`release_readiness.ps1`의 어떤 finding 코드도 CI에서 실제 저장소에 대해 실행되지 않는다.** 반면 `license_audit.ps1`은 `check.ps1:23-24`에서 **실제 실행**된다.

rev.1은 이 비대칭을 정확히 서술해 놓고 §2.4에서 잊었다. rev.2는 이 사실을 설계의 출발점으로 삼는다: **`release_readiness.ps1`에 넣는 검사는 자동 검사가 아니다. 릴리스 담당자가 `-Strict`를 손으로 돌릴 때만 실행된다.**

### 2.4 게이트 재정의 — 주석이 아니라 pubspec을 판별자로 쓴다

**rev.1의 마커 주석 방식은 폐기한다.** 이유: C12 이후 main 매니페스트에 마커 주석이 영구히 존재하게 되므로, 미래의 다른 SDK가 병합기로 `INTERNET`을 주입해도 소스 매니페스트는 그대로고 마커는 이미 있으니 게이트는 영원히 `pass`다. "마커 부재" 조건이 도달 불가능해진다. **주석은 경계가 아니다.**

`android_release_internet`의 새 의미:

- main 매니페스트에 `INTERNET`이 있고 **`C:\toauner\app\pubspec.yaml`의 `dependencies:`에 `google_mobile_ads`가 없으면** `blocker`.
- 둘 다 있으면 `pass`. 둘 다 없어도 `pass`. **`google_mobile_ads`가 없는데 `INTERNET`만 있으면 여전히 `blocker`** — 즉 광고 스택을 되돌리면 매니페스트도 되돌려야 한다는 계약이 강제된다.
- 판별자가 `pubspec.yaml`인 이유: 병합기는 `pubspec.yaml`을 위조할 수 없고, 의존성 추가는 사람이 명시적으로 하는 행위이며, `license_audit.ps1`이 실제로 읽는 것과 같은 신호원이다.
- **한계(정직하게 기록한다):** 이 검사도 `check.ps1`에서 실행되지 않는다(§2.3). `-Strict` 수동 실행 시에만 동작한다. 이 검사의 가치는 릴리스 체크리스트에 있지 CI에 있지 않다.

`android_merged_manifest_permissions`를 추가하되 **자동 검사라고 부르지 않는다.**

- 병합 릴리스 매니페스트를 읽어 아래 allowlist 밖 권한이 있으면 `blocker`.
- allowlist: `android.permission.RECORD_AUDIO`, `android.permission.INTERNET`, `android.permission.ACCESS_NETWORK_STATE`.
- `com.google.android.gms.permission.AD_ID`가 병합 결과에 남아 있으면 `blocker`.
- 병합 매니페스트가 없으면 `warning`.
- **Verification matrix에서 이 항목은 수동 열이다.** `check.ps1`은 `-SelfTest`만 돌리고, 자기 검사 임시 루트에는 빌드 산출물이 없으므로 이 검사는 모든 자동 호출에서 아무도 읽지 않는 `warning`이다. 사람이 `flutter build apk --release` 직후 `-Strict`를 돌릴 때만 문다.
- `Invoke-SelfTest`의 `$expected`에 이 코드를 추가하려면 allowlist 밖 권한을 가진 병합 매니페스트 픽스처가 필요하다. 코드와 자기 검사를 **같은 커밋**에서 맞춘다.

**검증 필요:** 병합 매니페스트의 정확한 경로. AGP 버전에 따라 다르고, 루트에 `C:\toauner\build\` 디렉터리가 존재하는 것으로 보아 출력 위치가 `app\build\` 아래가 아닐 수 있다. 실행 시점에 `flutter build apk --release` 후 실제로 탐색해 확정한다. **경로를 추측해 하드코딩하지 않는다.**

`Invoke-SelfTest` 기존 픽스처(`release_readiness.ps1:227`)는 `<manifest><uses-permission android:name="android.permission.INTERNET" /></manifest>`이고 임시 루트에 `pubspec.yaml`이 없으므로, 새 의미에서도 여전히 `android_release_internet` blocker를 낸다. **픽스처는 바꾸지 않아도 된다.**

### 2.5 오프라인 무결성 계약 (이 계약의 심장)

- 튜너는 네트워크가 0인 상태에서 2026-07-15 이전과 **동일하게** 동작한다.
- 광고 로드 실패는 앱의 실패가 아니다. `C:\toauner\app\lib\src\settings\app_settings.dart:15-19`가 확립한 "플랫폼 실패는 앱 실패가 아니다" 계약과 `precision_tuner_screen.dart`의 `_recordCompletion()` try/catch 계약을 따른다.
- 광고 실패 상태는 예외가 아니라 **기본 상태**다. 사용자는 연습실·지하·무대에서 튜닝한다.
- **UMP·`MobileAds.initialize()`는 첫 프레임 이전에 절대 실행하지 않는다.** 둘 다 `unawaited`로 튜닝 경로 밖에서 돌리고 **월클럭 타임아웃**을 건다. 타임아웃은 `canRequestAds == false`와 동일하게 처리한다. 근거: `C:\toauner\app\lib\main.dart`는 이미 `await store.load()`로 `runApp`을 막고 있고, `requestConsentInfoUpdate`는 Google로 가는 네트워크 왕복이다. 캡티브 포털이나 half-open 소켓은 fast-fail이 아니라 slow-fail을 준다. `docs/design-playbook.md:8`("앱을 열자마자 자유 튜닝을 시작할 수 있고")이 이 계약의 근거다.
- **rev.1의 "마이크 세션 중 프리페치 금지" 조항은 §2.6으로 대체한다.**

이 계약은 테스트로 못 박는다. `C:\toauner\app\test\offline_integrity_test.dart`가 SDK보다 먼저 존재한다.

### 2.6 마이크 세션과 광고 — rev.1의 조항을 정직하게 다시 쓴다

rev.1은 "`_inputSessionStarted`가 `true`인 동안 프리페치를 금지한다"고 썼다. 두 리뷰가 이를 두 방향에서 반박했고 **둘 다 옳다.**

1. **강제할 배선이 없다.** `_inputSessionStarted`는 `_PrecisionTunerScreenState`의 private 필드이고 접근자가 없다(`:84,190,576,583,674`). §4.1은 튜너 라이브러리에 광고 심볼을 금지한다. 따라서 `AdGate`가 마이크 상태를 알 방법이 존재하지 않는다. rev.1의 테스트 `'the ad gate rejects a request while the microphone session is live'`는 **프로덕션 코드가 절대 세팅하지 않는 플래그에 대해서만 통과한다** — 앱이 구현하지 않는 규칙을 인증하는 테스트다. 이건 테스트가 없는 것보다 나쁘다.
2. **가드는 *우리 코드가 로드를 시작하는 것*만 막는다.** 이미 살아 있는 배너는 못 막는다. 두 튜너 진입점(`song_detail_screen.dart:142`, `song_search_screen.dart:397`)은 `Navigator.push`이므로 하위 라우트가 **살아서 마운트된 채로** 남는다. Slot A/C 배너는 튜너가 위에 있는 동안 라이브 GMA 뷰로 존속하고, GMA 배너는 **서버 측 간격으로 자동 새로고침**한다 — 라이브 바늘 아래에서 네트워크 페치 + WebView 리페인트가 플랫폼 메인 스레드에서 발생하며, 어떤 Dart 가드도 이를 볼 수 없다.

rev.1이 이 조항에 `AGENTS.md:29`를 인용한 것은 **오인용이다.** `:29`는 연속 DSP가 UI 아이솔레이트에서 돌면 안 된다는 규칙이며 광고 프리페치와 무관하다. 실제 경합 위험은 WebView가 플랫폼 메인 스레드에서 오디오 경로를 굶기는 것이고, `:29`는 이를 다루지 않는다. **인용을 삭제하고 제품 결정으로 정직하게 표기한다.**

**rev.2의 대체 계약 — 배선 가능한 것만 약속한다:**

- **`AdSurface`는 `deactivate()`에서 `AdHandle`을 `dispose()`한다** (`dispose()`가 아니라 `deactivate()`다). 튜너를 push하면 살아 있는 모든 광고 뷰가 즉시 해체된다. 이것은 라우트 생명주기만으로 강제되며 튜너 파일을 건드리지 않는다.
- 테스트: `'pushing a route over an ad surface disposes the live ad handle'` (§8.4).
- **배너 자동 새로고침은 AdMob 콘솔에서 끈다.** 저장소에서 검증 불가능하므로 Phase 0 결정 항목이자 Verification matrix의 **수동** 항목이다.
- `'the ad gate rejects a request while the microphone session is live'` 테스트는 **삭제한다.** 배선이 없는 규칙을 인증하지 않는다.

**대안으로 채택하지 않은 것:** 두 번째 no-op 훅(`TuneSessionActiveHook`)을 튜너에 추가해 마이크 상태를 노출하는 방안. `deactivate()` 해체가 같은 결과를 튜너 변경 0줄로 달성하므로 채택하지 않는다. 튜너 파일의 blast radius를 0으로 유지하는 것이 이 계약의 우선순위다.

---

## 3. Phase 2 — 광고 추상화 심

### 3.1 패키지 경계

- `packages/tuner_dsp`와 `packages/tuner_domain`에는 광고 관련 코드를 **한 줄도** 넣지 않는다(`AGENTS.md:28`).
- `packages/tuner_data`, `packages/tuner_audio`에도 넣지 않는다.
- 새 디렉터리는 `C:\toauner\app\lib\src\ads\` 하나다.

### 3.2 런타임 인터페이스

전부 `C:\toauner\app\lib\src\ads\` 아래. 아래는 예시 시그니처이며 구현이 아니다.

- `ad_placement.dart` — `enum AdPlacement { songSearchFooter, songDetailBelowVerification, sessionEndInterstitial }` (rev.1의 `songSearchInFeed`는 §4.2에서 삭제)
- `ad_source.dart`
  ```dart
  abstract interface class AdSource {
    Future<void> initialize();
    Future<AdHandle?> loadBanner(AdPlacement placement);
    Future<AdHandle?> loadInterstitial(AdPlacement placement);
    Future<void> close();
  }
  ```
  실패는 예외가 아니라 `null` 반환이다. `SongCatalog`(`song_catalog.dart:5-19`)의 `abstract interface class` + `close()` 계약을 복제한다.
- `ad_handle.dart` — `final class AdHandle` — `width`, `height`, `Widget build(BuildContext)`, `Future<void> dispose()`만 노출. `google_mobile_ads` 타입을 절대 노출하지 않는다.
- `disabled_ad_source.dart` — `final class DisabledAdSource implements AdSource` — 모든 로드가 `null`. **기본값이자 킬 스위치의 종착점.**
- `ad_gate.dart` — `final class AdGate extends ChangeNotifier` — 요청 허용 여부, 연속 실패 카운터, 인터스티셜 쿨다운, **`ConsentRequirement` 상태**를 소유한다(§6.4).
- `ad_scope.dart` — `final class AdScope extends InheritedNotifier<AdGate>` + `extension AdContext on BuildContext { AdGate get ads; }`
- `ad_surface.dart` — `class AdSurface extends StatefulWidget` — **광고를 그릴 수 있는 유일한 위젯.** `deactivate()`에서 핸들을 해체한다(§2.6).
- `ad_settings_store.dart` — `final class JsonAdSettingsStore` — 파일명 `ads.v1.json`, `.tmp` 원자 교체, `.bak` 복구.
- `ad_consent.dart` — UMP 래퍼(C16).
- `google_mobile_ads_source.dart` — **`import 'package:google_mobile_ads/google_mobile_ads.dart';`가 허용된 유일한 파일.**

### 3.3 주입 지점 (검증됨 — rev.1이 커밋 표에서 누락했던 부분)

`C:\toauner\app\lib\src\app\app_preferences.dart:223`의 `AppPreferencesScope` 패턴을 복제한다.

- **`C:\toauner\app\lib\main.dart`**에서 `AdGate`를 만들고 `ToaunerApp(adGate: ...)`로 넘긴다. **UMP·`initialize()`는 여기서 `await`하지 않는다**(§2.5).
- **`C:\toauner\app\lib\src\app\toauner_app.dart:99-101`**의 `AppPreferencesScope` **안쪽**에 `AdScope`를 중첩한다. `:96`이 `AppPreferencesScope(controller:…, child: MaterialApp(…))`를 반환하고, MaterialApp의 Navigator가 만든 라우트는 엘리먼트 트리 후손이므로 `dependOnInheritedWidgetOfExactType`이 해결된다. `precision_tuner_screen.dart:425`가 이미 같은 방식으로 `AppPreferencesScope.maybeOf`에 도달한다 — 검증된 경로다.
- `:83`의 `AnimatedBuilder`가 이미 `MaterialApp` 재빌드를 덮으므로 `InheritedNotifier`의 의존자 재빌드만으로 충분하다.
- **`ToaunerApp`의 새 필드는 전부 nullable 또는 const 기본값이어야 한다.** `C:\toauner\app\test\widget_test.dart`가 `ToaunerApp(`을 **21곳**에서 생성한다(rev.1은 "약 20곳"이라 적었다 — 정확히 21이다). 필수 파라미터를 추가하면 전부 깨진다. `toauner_app.dart:21-22`의 `preferencesController` / `initialPreferences` 쌍과 `:58-64`의 `_ownsPreferencesController` 로직을 문자 그대로 베낀다.
- 기본값은 `DisabledAdSource()`다.
- **이 두 파일은 C5의 파일 목록에 포함된다.** rev.1은 C1~C27 어디에도 이 파일들을 넣지 않아 `AdScope`가 마운트되지 않았고, C19의 `context.ads`가 debug에서 assert, release에서 `notifier!` throw가 됐다.

### 3.4 별도 저장소인 이유 (rev.1 유지 — 네 리뷰 모두 검증하고 옳다고 확인)

광고 설정을 `app_preferences.dart`에 넣지 않는다.

- `app_preferences.dart:83-85`는 `document['schemaVersion'] != _schemaVersion`이면 문서 전체를 거부하고 `:140`에서 **기본값으로 조용히 되돌린다.** `_schemaVersion = 2`로 올리면 v1 파일을 가진 사용자의 테마·허용치·햅틱·최근 검색이 업그레이드 시 전부 초기화된다. 마이그레이션 경로가 없다.
- `_replace()`(`:216-220`)는 모든 설정 변경마다 파일 전체를 쓴다. `recordRecentSearch`는 검색 키 입력마다 호출된다.
- 선례는 `C:\toauner\app\lib\src\tuning_history\tuning_history_store.dart`다. 독립 파일명, 자체 `_writeQueue`, 자체 typedef 삼종, 모듈 레벨 기본 함수. `ad_settings_store.dart`는 이 형태를 복제한다.

---

## 4. Phase 3 — 배치 계약

### 4.1 금지 표면

`C:\toauner\app\lib\src\tuner\precision_tuner_screen.dart:23-25`는 아래를 선언한다.

```dart
part 'precision_tuner_controls.dart';
part 'precision_tuner_setup.dart';
part 'precision_tuner_panels.dart';
```

**네 파일은 하나의 라이브러리다.** "튜너 파일만 안 건드리면 된다"는 파일 경계로 강제되지 않는다. 오늘 이걸 막는 린트도 테스트도 없다.

광고 심볼이 **한 개도** 나타나면 안 되는 곳:

- `C:\toauner\app\lib\src\tuner\` 전체 (위 네 파일 + `stage_mode_screen.dart`)
- `C:\toauner\app\lib\src\stability\` 전체
- **`C:\toauner\app\lib\src\metronome\` 전체** — rev.1 누락. `metronome_screen.dart` / `metronome_player.dart`는 `AudioPlayer`를 쓰는 **라이브 오디오 연습 도구**이며 최근 5개 커밋(`32c7849`…`eb86715`)에서 추가됐다. 연속 오디오 표면에 광고를 붙이지 않는다는 원칙이 튜너에 적용된다면 메트로놈에도 적용된다.

`docs/design-playbook.md:10` "한 화면의 주인공은 하나다"가 구조적 근거다.

**이 금지가 실제로 보장하는 것과 보장하지 않는 것 (정직하게):**

- **보장한다:** 우리가 작성한 Dart 코드가 이 라이브러리들 안에서 광고를 참조하는 것. `ad_placement_compliance_test.dart`가 강제한다.
- **보장하지 않는다:** SDK가 렌더하는 네이티브 전면 오버레이가 이 화면들 위에 뜨는 것. 그건 Dart AST 밖이다. **그래서 §4.4가 인터스티셜을 호출 측 라우트 복귀 이후로 옮긴다** — 심볼 테스트가 아니라 **라우트 순서**로 보장한다.

### 4.2 허용 슬롯

| 슬롯 | 위치 | 형식 | 정당화 |
| --- | --- | --- | --- |
| A | `C:\toauner\app\lib\src\songs\song_search_body.dart` (C-R에서 추출) — `_buildSongSearchBody`의 **마지막 자식**, `_results.length >= 4`일 때만 | 배너 | 결과 목록 아래. **아래에 아무것도 없으므로 성공 확장이 어떤 위젯도 밀지 않는다.** 이것이 제로 시프트가 성립하는 유일한 형태다 |
| C | `C:\toauner\app\lib\src\songs\song_detail_screen.dart` — **`_VerificationNotice` 아래** | 배너 | 폴드 아래. `SongDetailScreen`은 `StatelessWidget`이라 상태 승격 필요 없음 |
| D | 튜너 라우트 **복귀 이후**, 호출 측에서 (§4.4) | 인터스티셜 | 튜너가 스택에서 사라진 뒤에만 뜬다 |

**rev.1의 Slot A 정당화는 틀렸다 — 고친다.**
- rev.1: "스크롤 끝이라 레이아웃 시프트가 사용자 시야에 들어가지 않는다." → **거짓.** `_buildSongSearchBody`는 `_results`가 비어 있을 때 `_EmptyResults`(`:355-363`, 탭 가능한 `popularResults` 행 포함)를 렌더하고 푸터가 **즉시 시야에** 들어온다. 배너가 탭 가능한 곡 행 바로 아래에서 확장되면 오탭 표면이 된다. → **`_results.length >= 4` 조건을 앵커에 넣는다.**
- rev.1: "개발 고지 뒤." → **거짓.** 그 고지(`:367-376`)는 `if (widget.includeUnverifiedSongs)`이고 `toauner_app.dart:23`이 `!kReleaseMode`로 기본값을 준다. **릴리스에 존재하지 않는 위젯이다.** 앵커에서 삭제한다.

**rev.1의 Slot B(인피드, 4번째 결과 뒤)는 삭제한다.**
- `song_search_screen.dart:300`(및 `:220`)은 `ListView(children: [...])` — `SliverChildListDelegate`이며 **`.builder`가 아니다.** 모든 자식이 뷰포트와 무관하게 즉시 빌드된다. 인덱스 4의 `AdSurface`가 진입 즉시 요청하고, **성공하면** 0 → 50~100dp로 확장하며 인덱스 4 아래 모든 결과가 점프한다. 사용자가 그 아래로 스크롤해 있으면 엄지 밑에서 레이아웃이 튄다.
- §5.1의 "확장은 성공 시 단 한 번, 애니메이션 없이"는 시프트의 *서술*이지 완화책이 아니다.
- rev.1의 §8.4 테스트 4개는 전부 실패 경로만 본다. 성공 경로 시프트 테스트가 없는 이유는 **통과할 수 없기 때문이다.** 통과할 수 없는 테스트를 요구하는 대신 슬롯을 삭제한다.
- 부수적으로 rev.1은 "인덱스 카운터를 직접 둔다"고 했으나 `for (final match in _results)`(`:365`)에는 인덱스가 없어 `_results.indexed`가 필요했다. 슬롯 삭제로 무의미해진다.

**rev.1의 Slot C 위치(`_TensionRecommendationEntry`와 `_VerificationNotice` 사이)는 이동한다.**
- 그 위치는 `_VerificationNotice` — **이 곡의 튜닝이 검증됐는지를 말하는 앱의 정직성 표면** — 를 아래로 밀고, 유료 광고를 신뢰성 진술 바로 위에 시각적으로 앉힌다. §4.3이 "튜닝 CTA 옆" 슬롯을 거부하는 것과 같은 논리가 여기 적용되며 rev.1은 적용하지 않았다.
- **`_VerificationNotice` 아래로 옮긴다.**

### 4.3 명시적으로 거부한 슬롯

**중요 — rev.1의 강제 주장은 거짓이었다.** `song_search_screen.dart`(916줄)는 `_buildTuningHome()`(`:219`, `_QuickTunePanel`을 `:238`에서 생성)과 `_buildSongSearchBody()`(`:299`)를 **한 파일에** 담는다. rev.1은 C19에서 이 파일을 통째로 allowlist에 넣으므로 `_buildTuningHome`도 함께 허용된다 — §4.3이 거부한 바로 그 슬롯을 아무것도 기계적으로 막지 못한다. **§4.1에서 `part` 지시자에 대해 정확히 진단한 실패 모드를 한 섹션 뒤에서 재생산한 것이다.**

**해결: C-R(`refactor:`)에서 `_buildSongSearchBody`와 그 전용 자식들을 `C:\toauner\app\lib\src\songs\song_search_body.dart`로 추출한다.** Slot A는 그 파일에만 들어가고 allowlist에도 그 파일만 올라간다. `song_search_screen.dart`는 **영구히 금지 목록에 남는다.** §4.1이 이미 C11의 훅(rev.2에서는 삭제)이라는 구조적 리팩터를 같은 이유로 받아들였으므로, 이 리팩터도 정당하다. C-R은 골든 중립이며 C19보다 먼저다.

거부 슬롯 목록:

- `song_search_screen.dart` — `_QuickTunePanel`과 `곡 검색` 카드 사이. **거부.** 튜닝 CTA 바로 옆이다. 파일 경계상 튜너가 아니지만 사용자 인식상 튜너 직전이다. `docs/design-playbook.md:10`의 "홈은 자유 튜닝"이 주인공이다. **C-R 이후 이 파일 전체가 금지 목록이므로 기계적으로 강제된다.**
- `song_detail_screen.dart:110-111` — 열린 현 행과 `_MetronomeEntry` 사이. **거부.** 연습 CTA 바로 위다. **강제 수단 없음 — Verification matrix 수동 열.**
- `song_detail_screen.dart:132-158` — `bottomNavigationBar`의 `_StickyTuneBar`와 `InstrumentStatusBar` 사이. **거부.** 광고를 튜닝 CTA에 시각적으로 붙인다. **수동.**
- `song_detail_screen.dart` — `_VerificationNotice` **위**. **거부.** §4.2 참조. **수동.**
- `C:\toauner\app\lib\src\ui\tool_menu_sheet.dart:64` — **거부.** `mainAxisSize: MainAxisSize.min`(`:30`)이라 시트 높이가 광고 로드 여부에 따라 변한다. **수동.**

`song_detail_screen.dart`는 한 파일에 여러 슬롯 후보를 담으므로 파일 allowlist로 §4.3의 거부를 강제할 수 없다. **이 사실을 인정하고 수동 열에 넣는다.** 추가 리팩터를 요구하지 않는 이유: 허용 슬롯이 파일당 1개(C)뿐이고 `AdSurface` 인스턴스 수를 테스트로 셀 수 있으므로(`'song detail declares exactly one ad surface'`), 위치의 정확성만 사람이 본다.

### 4.4 인터스티셜 — 튜너 훅을 폐기하고 호출 측 라우트 복귀로 옮긴다

**rev.1의 §4.4는 사실 오류 위에 세워져 있었다. 세 리뷰가 독립적으로 같은 코드를 인용해 반박했고 전부 옳다.**

반박 1 — **`_showCompletion()`은 멱등하지 않다.** `precision_tuner_screen.dart:495-499`:
```dart
).whenComplete(() {
  if (mounted) {
    _completionShown = false;   // 가드가 해제된다
  }
});
```
`_completionShown`은 시트의 **재진입 가드**이지 세션당 1회 래치가 아니다. 시트가 닫힐 때마다 `false`가 되고, `:432`의 `if (progress.isComplete)`가 이후의 어떤 lock 이벤트에서도 `_showCompletion()`을 재발화시킨다. 진짜 1회 래치는 `_historyRecorded`(`:503-506`)이며 절대 리셋되지 않는다. rev.1은 `_recordCompletion()`을 복제할 계약으로 인용해 놓고 **엉뚱한 가드에 훅을 걸었다.**

반박 2 — **`.whenComplete`는 안정성 검사 경로에서도 발화한다.** `:490-493`:
```dart
onStabilityCheck: () {
  Navigator.of(sheetContext).pop();        // -> .whenComplete 발화
  unawaited(_openStabilityCheck());        // -> StabilityCheckScreen push
},
```
훅이 전면 광고를 `StabilityCheckScreen` push와 경합시킨다. §4.1과 §11이 명시적으로 금지하는 화면에 전면 광고가 뜬다.

반박 3 — **훅 시점에 튜너가 최상위 라우트다.** `InterstitialAd.show()`는 네이티브 전면 오버레이다. **사용자는 튜닝 화면 위의 전면 광고를 본다.** 그런데 모든 테스트는 초록이다: `ad_placement_compliance_test.dart`는 Dart 심볼을 그렙하고 튜너 라이브러리엔 심볼이 없으며, 골든은 위젯 트리를 렌더하고 플랫폼 오버레이는 거기 없다. rev.1의 §7.7은 "SDK가 렌더한 위젯은 Dart AST 밖"이라고 이미 인정해 놓고 **결과를 좌우하는 유일한 지점인 Slot D에 그 인정을 연결하지 않았다.** 훅 간접화가 산 것은 통과하는 테스트이지 그 테스트가 대변하는 계약이 아니다.

반박 4 — **마이크가 살아 있다.** 완료 시 엔진을 멈추는 코드가 없다. `_inputSessionStarted`가 `false`가 되는 곳은 `_toggleReferenceTone`(`:583`)과 `_retryInput`(`:674`)뿐이며 완료 경로에 없다. `_showCompletion()`(`:438`)은 `_engineSubscription`(`:113`)을 계속 흘린다. rev.1은 §2.5에서 "마이크 세션 중 광고 로드 금지"라 써 놓고 §4.4에서 정확히 그 시나리오를 만든다.

**rev.2의 설계 — 훅을 없앤다:**

- **C11(`feat: hand the tuner a session end hook`)을 삭제한다.** 튜너 파일은 **한 줄도** 바뀌지 않는다.
- 인터스티셜은 **호출 측에서 라우트가 복귀한 뒤** 발화한다:
  ```dart
  final result = await Navigator.of(context).push<TuneOutcome>(
    MaterialPageRoute(builder: (_) => PrecisionTunerScreen(...)),
  );
  if (!context.mounted) return;
  if (result?.completed ?? false) {
    await context.ads.maybeShowSessionEndInterstitial();
  }
  ```
- 이 시점에 튜너는 스택에서 사라졌고, 마이크 세션은 `dispose()`로 끝났으며, 광고는 곡 상세 / 검색 — **허용된 표면** — 위에 뜬다. `StabilityCheckScreen` 경합도 없다.
- **트리거 의미가 바뀐다:** rev.1은 "완료 시트가 닫힐 때", rev.2는 "튜너 라우트가 완료 결과와 함께 복귀할 때"다. 뒤로가기로 나온 경우 광고가 뜨지 않게 하려면 `Navigator.pop(result)`로 완료 신호를 넘겨야 한다. **이것은 `precision_tuner_screen.dart`의 pop 호출을 건드린다** — 광고 심볼은 아니지만 튜너 파일 변경이다. 두 선택지:
  - **(a) 채택:** 완료 신호 없이 **항상** 발화하되 로컬 쿨다운에만 의존. 튜너 변경 0. 뒤로가기 이탈에도 광고가 뜰 수 있다.
  - **(b) 검증 필요:** `_historyRecorded`를 pop 결과로 노출. 튜너 파일 1줄 변경, 광고 심볼 0. 의미상 정확하지만 §4.1의 blast radius 0 원칙과 협상이 필요하다.
  - **결정: (a)로 랜딩하고, 실기기 검증에서 뒤로가기 이탈 시 광고가 거슬리면 (b)를 별도 커밋으로 추가한다.** 쿨다운 기본값이 24시간이면 (a)의 오발화는 사실상 관찰되지 않는다.
- `maybeShowSessionEndInterstitial()`은 `AdGate`의 계약을 따른다: **모든 실패를 삼키고 계속한다.**

**두 진입점 (검증됨 — 정확히 2곳):** `C:\toauner\app\lib\src\songs\song_detail_screen.dart:142`, `C:\toauner\app\lib\src\songs\song_search_screen.dart:397`. **후자는 C-R 이후 `song_search_body.dart`로 이동할 수 있다 — 추출 시 함께 옮긴다.**

---

## 5. Phase 4 — 레이아웃 안정성 · 로드 실패 · 빈도 제한

### 5.1 계약 이름을 정직하게 고친다: "제로 레이아웃 시프트" → **"reserve-then-collapse 금지"**

rev.1은 "제로 레이아웃 시프트"라 불렀으나, 0 높이에서 성공 확장하는 것은 **surface 아래 모든 위젯에 대해 레이아웃 시프트다.** 진짜 제로 시프트는 **아래에 아무것도 없는 마지막 자식**일 때만 성립한다. rev.2는 Slot B를 삭제하고 Slot C를 `_VerificationNotice` 아래로 내려 **모든 허용 슬롯이 각 스크롤 뷰의 마지막(또는 마지막에 준하는) 위치**가 되게 만들었으므로, 이제 이름과 실체가 일치한다.

- `AdSurface`는 `onAdLoaded`가 오기 **전까지 높이 0**이다. 높이를 예약했다가 실패 시 접는 방식을 **금지한다** — 이것이 이 계약이 실제로 보장하는 것이다.
- 로드 실패 시 높이 0을 유지한다. 늘어난 적이 없으므로 접힐 일이 없다.
- 확장은 성공 시 **단 한 번**, 애니메이션 없이.
- `_loaded`는 `onAdLoaded`에서만 `true`. `onAdFailedToLoad`에서는 `ad.dispose()` 후 `false` 유지.
- `deactivate()`에서 핸들을 해체한다(§2.6).

### 5.2 로드 실패

- `LoadAdError`는 `{ String domain; int code; String message; ResponseInfo? responseInfo; }`다.
- **`code == 2`를 "사용자가 오프라인"으로 해석하지 않는다.** 정상 연결에서도 code 2가 뜨고, "unable to resolve host"가 code 0과 code 2로 일관성 없이 보고된다(googleads-mobile-flutter issue #658, #905). 앱 로직을 code로 분기하지 않는다.
- 재시도 전략은 Google이 문서화하지 않았다. **재시도하지 않는다.** 실패하면 그 화면 인스턴스에서 끝이다.
- `AdGate`는 연속 실패 3회 이후 해당 세션에서 요청을 중단한다.

### 5.3 빈도 제한

- AdMob 콘솔의 빈도 제한은 **서버 측 설정**이며 앱·광고 단위 레벨에서 설정한다. 최대 60회, 변경 반영에 최대 24시간.
- 따라서 **서버 빈도 제한은 CI에서 테스트할 수 없고 커밋으로 되돌릴 수 없다.** 우리가 통제하는 페이싱은 로컬에 구현한다.
- 로컬 쿨다운은 `ads.v1.json`에 마지막 인터스티셜 표시 시각(UTC)을 기록해 구현한다. 유닛 테스트 가능하다.
- 인터스티셜은 Slot D에서만, 쿨다운 밖에서만. **앱 시작 시 인터스티셜은 금지한다.**

**⚠️ 사용자 결정:** 쿨다운 기본값(24시간 1회 / 6시간 1회 / 인터스티셜 없이 배너만). 30초 유틸리티에 세션마다 전면 광고를 띄우면 재설치율이 아니라 삭제율을 사는 것이다. §4.4의 (a) 선택지가 성립하려면 24시간이 안전한 기본값이다.

---

## 6. Phase 5 — 동의: UMP · ATT · KR/PIPA · 만 14세 미만

### 6.1 UMP

- Google UMP SDK는 `google_mobile_ads`에 **번들되어 있다.** 별도 패키지를 추가하지 않는다.
- 인증 CMP는 **EEA + UK(2024-01-16부터)**, **스위스(2024-07-31부터)**에서 개인화 광고에 필수다.
- 미준수 시 차단이 아니라 EEA/UK 트래픽에 **Limited Ads만 서빙**된다.
- **GDPR은 스토어 등록 국가가 아니라 사용자 위치로 적용된다.** 국가 제한 없이 출시하면 EEA 사용자가 설치한다.
- 그러므로 **UMP를 첫 커밋부터 배선한다.** 다만 **§2.5의 첫 프레임 계약에 종속된다** — `runApp` 이전에 실행하지 않고, `unawaited` + 월클럭 타임아웃이며, 타임아웃은 `canRequestAds == false`로 처리한다.
- 순서: 첫 프레임 → UMP 동의 → `MobileAds.instance.initialize()` → 광고 로드. `canRequestAds()`가 `false`인 동안 `initialize()`를 부르지 않는다.
- `getPrivacyOptionsRequirementStatus()`가 요구할 때만 설정 화면에 개인정보 옵션 진입점을 노출한다. **영구적인 설정 행**이며 `docs/design-playbook.md` 변경을 수반한다(C18).

**한국에 대한 rev.1의 주장은 강등한다.** rev.1은 "한국 단독 출시에는 Google 정책·국내법 어느 쪽도 요구하지 않는다"고 단정했다. **이 문장은 §7.2가 Play에 "사용자 데이터 공유: 예 (Google에 공유)"라고 신고하는 것과 정합하지 않는다.** §6.4로 이관하고 **검증 필요**로 표기한다.

사용할 API 표면:
```
ConsentInformation.instance.requestConsentInfoUpdate(params, onSuccess, onError)
ConsentForm.loadAndShowConsentFormIfRequired(onError)
ConsentInformation.instance.canRequestAds()
ConsentInformation.instance.getPrivacyOptionsRequirementStatus()
ConsentForm.showPrivacyOptionsForm(onError)
```

### 6.2 ATT — 띄우지 않는다

- **결정: `NSUserTrackingUsageDescription`을 추가하지 않고 `requestTrackingAuthorization`을 호출하지 않는다.**
- 근거: ATT를 거부하거나 아예 묻지 않아도 광고는 계속 서빙된다. Google 문서는 SDK가 IDFA를 광고 요청에 담지 않고 컨텍스트 광고로 degrade한다고 명시한다.
- 근거: 30초 유틸리티에 시스템 추적 동의 팝업을 띄우는 것은 신뢰 대비 수익이 맞지 않는다.
- `SKAdNetworkItems` 배열도 추가하지 않는다.
- 결과: iOS 단가 하락. **검증 필요 — 음악 유틸리티 오디언스의 개인화/비개인화 단가 차이 실측치를 찾지 못했다.**
- **rev.1의 근거 하나는 틀렸다 — 고친다.** rev.1 §11: "이 키가 있으면 Apple 심사에서 문제가 된다." **거짓.** Apple은 **사용하지 않는** `NSUserTrackingUsageDescription` 키 때문에 앱을 반려하지 않는다. 강제되는 규칙은 그 **역**이다 — ATT 프롬프트 없이 추적하거나 IDFA에 접근하면 반려다. 고아 키는 노이즈이지 위반이 아니다. **정확한 진술: "우리는 추적하지 않으므로 ATT가 요구되지 않고, 따라서 이 키는 불필요하다."** 키의 부재는 no-tracking 결정의 *결과*이지 독립적인 심사 요건이 아니다.
- `C:\toauner\app\ios\Runner\Info.plist`에는 `NSMicrophoneUsageDescription`(`:29-30`)만 남는다. **단, `GADApplicationIdentifier`는 추가된다**(§6.6) — rev.1의 "하나만 남는다"는 거짓이었다.

### 6.3 Android 광고 ID — 제거한다 (효과는 rev.1보다 작게 서술한다)

- **결정: `com.google.android.gms.permission.AD_ID`를 `tools:node="remove"`로 병합에서 제거한다.**
- `play-services-ads`(GMA ≥20.4.0) 라이브러리 매니페스트가 이 권한을 자동 병합하므로, 명시적으로 제거해야 한다.
- **`C:\toauner\app\android\app\src\main\AndroidManifest.xml:1`에는 `xmlns:tools`가 없다.** 루트 요소에 `xmlns:tools="http://schemas.android.com/tools"`를 **먼저 추가하지 않으면 병합기가 unbound-prefix 오류로 실패한다.** rev.1은 이를 누락하고 해당 커밋이 초록이라고 주장했다.
- 제거하면 광고 ID가 전부 0이 된다.
- **rev.1의 세 가지 효과 주장을 강등한다:**
  - ~~"Data Safety 카드가 오늘과 거의 같게 유지되고"~~ → **거짓.** §7.2 참조. 오늘은 "데이터 수집 없음"이고, 광고 후에는 Location(approximate) + App activity + Diagnostics + **Device or other IDs**다. AD_ID 제거는 그중 한 행도 지우지 못한다(§7.2).
  - ~~"PIPA 행태정보 노출을 대부분 우회하며"~~ → **근거 없는 정량 표현.** 정확한 진술: **"AD_ID 제거는 식별자 지속성과 앱 간 결합 가능성을 낮춘다. 행태정보 처리 자체를 제거하지 않는다. IP + 앱 상호작용은 여전히 광고·분석 목적으로 Google에 전송된다. 이 조치가 PIPA상 동의 요부를 바꾸는지는 검증 필요 — 변호사 검토 대상이다."**
  - ~~"iOS ATT 문제를 무의미하게 만든다"~~ → **범주 오류.** `com.google.android.gms.permission.AD_ID`는 **Android 매니페스트 권한**이며 IDFA·ATT와 아무 관계가 없다. iOS를 지배하는 것은 §6.2의 결정이다. 이 문장은 삭제한다.
- **그래도 제거는 유지한다.** 이유: 비용(단가)이 명확하고, 이득(교차 앱 링크 가능성 축소)이 방향적으로 옳으며, 되돌리기 쉽다. 다만 **이 조치를 컴플라이언스 방패로 팔지 않는다.**

### 6.4 한국 PIPA — 검토를 C16 앞으로 당긴다

- 업계 관행은 광고 ID를 개인정보로 취급하지 않는다(재설정 가능 논리). 그러나 **해석은 업종별로 다르고**, 맥락상 식별 특성이 생기면 행태정보가 개인정보가 될 수 있다.
- 2024-01-31 PIPC의 「맞춤형 광고에 활용되는 온라인 행태정보 보호를 위한 정책 방안」은 특정 개인을 식별하지 않고 처리하는 경우 동의 없이 처리 가능하다고 밝혔다.
- **PIPC 개인정보 처리방침 작성지침이 2025-04-21 개정됐다.** rev.1은 2024-01-31에서 멈춰 이를 찾지 못했다. 이 지침은 제3자가 **자동 수집 장치로 행태정보를 수집하도록 허용하는** 처리자에게 **수집·이용·제공 및 그 거부에 관한 사항**을 처리방침에 기재하고 **정보주체의 거부권 행사 방법을 제시**할 것을 요구한다. 법 제30조 / 시행령 제31조의 공개 사항이며 **적극적 기재 의무**다. §7.1이 이를 반영한다.
- **미해결 핵심 쟁점 — 검증 필요:** Google으로의 전송이 **제3자 제공(제17조 — 별도 동의 필요)**인가 **처리위탁(제26조 — 동의 불요, 방침 공개 + 위탁계약)**인가. Google 자신의 목적 서술("advertising, analytics, and **fraud prevention**")은 독립 처리자를 시사한다. rev.1은 §6.1에서 **"한국에는 동의 게이트 불필요"라는 엔지니어링 결정을 이미 내려놓고** 이 판단을 "릴리스 전 변호사 검토"로 미뤘다. 검토 결과가 제3자 제공이면 필요한 것은 문서 수정이 아니라 **동의 게이트라는 아키텍처 변경**이다.
- **결정: 국내 변호사 검토는 릴리스가 아니라 C16을 차단한다.**
- **결정: `AdGate`는 관할 기반 동의 요구를 표현할 수 있어야 한다.** `enum ConsentRequirement { none, umpRequired, krThirdPartyConsentRequired }` 같은 형태로, KR 분기가 초기에는 no-op이더라도 자리를 만들어 둔다. 그래야 제3자 제공 판정이 **재설계가 아니라 설정 변경**이 된다.
- §6.1의 한국 문장을 다음으로 대체한다: **"UMP는 EEA/UK/CH를 커버한다. 한국이 추가적인 제3자 제공 동의를 요구하는지는 미해결이며 C16을 차단한다."**
- **검증 필요:** PIPA 행태정보의 2026년 현재 상태. PIPC가 민관협의체를 통해 개정 가이드라인을 예고했으나 확정 여부·내용을 1차 출처에서 확인하지 못했다. **웹 검색이 아니라 국내 변호사 검토를 받는다. 이 문서도, 어떤 리뷰도 그 검토를 대체하지 않는다.**

### 6.5 만 14세 미만 — Play 타깃 대상을 13-15에서 뺀다

- 개인정보보호법 제22조의2: 만 **14**세 미만 아동의 개인정보 처리에는 **법정대리인 동의**가 필요하고, 처리자가 그 동의를 **확인**해야 한다.
- 벌칙: 5년 이하 징역 또는 5천만원 이하 벌금, 또는 전체 매출의 3%까지 과징금. (1차 출처 확인됨)
- PIPC 아동·청소년 가이드라인: 아동이 이용할 것으로 **예상되는** 서비스는 프라이버시 기본값을 '높은 수준'으로 두고, 현금·아이템과 개인정보를 교환하는 설계를 피해야 한다.
- **리워드 광고는 정확히 이 경고에 해당하는 패턴이다.** → 이 계약은 리워드 광고를 도입하지 않는다.

**rev.1의 "13세 이상" 권고는 철회한다. 이것이 이 개정의 가장 중요한 수정이다.**

- rev.1은 **미국 COPPA의 임계값(13)을 한국법 분석(임계값 14)에 수입했다.** §6.5는 제22조의2의 만 **14**세를 정확히 인용해 놓고 결론에서 13을 권고했다.
- Play의 선택 가능한 브래킷은 *5세 이하 / 6-8 / 9-12 / **13-15** / 16-17 / 18세 이상*이다. **"14+" 옵션은 존재하지 않는다.** "13세 이상"을 신고한다는 것은 **13-15 브래킷 선택**이며, 이는 만 14세 미만인 한국의 13세를 명시적으로 포함한다. 즉 rev.1은 §6.5가 경고한 바로 그 제22조의2 의무를 자기 손으로 발동시키면서 법정대리인 동의 메커니즘은 **0개** 실어 보내는 구성이었다.
- 13-15는 Families 함정에도 걸린다. Google은 13-15가 "일부 지역에서 아동을 포함하는 것으로 간주될 수 있다"고 밝히고 있으며, Families 정책은 **아동을 포함하는 어떤 연령대라도** 타깃하면 Families Self-Certified Ads SDK를 요구한다.
- **🚨 Families Self-Certified Ads SDK Program은 현재 신규 신청을 받지 않는다.** 원문: *"the Google Play Families Self-Certified Ads SDK Program is currently not accepting new applicants."* (1차 출처 확인됨)
- **혼합 오디언스에는 우회로가 없다.** rev.1은 "혼합 오디언스면 중립 연령 게이트가 필요하다"고 써서 연령 게이트를 탈출구처럼 제시했다. **아니다.** Families 요건 하에서 자체 인증 SDK는 "아동 **및 연령 미상 사용자**"에게 광고를 서빙해야 하므로, 연령 미상 사용자가 아동 취급을 상속한다. 프로그램이 닫혀 있는 동안 혼합 오디언스에는 **적합한 구성이 아예 존재하지 않는다.**

**Phase 0의 선택지는 둘뿐이다:**
- **(a) 16-17 + 18+ — 권장 기본값.** 만 14세 이상이면서(제22조의2 미발동) Families/아동 범위 밖인 가장 낮은 브래킷 조합.
- **(b) 18+ 단독.** 최대 안전, 중립 연령 게이트 불필요.
- **13-15는 §11 하지 말 것에 들어간다.** 법정대리인 동의 플로우를 싣지 않는 한 선택하지 않으며, 그 플로우는 이 계약의 범위 밖이다.

아트 스타일·스토어 문구에서 아동 소구 신호를 배제한다. Play 심사는 의도가 아니라 아트 스타일·주제·스토어 문구를 본다.

Apple 쪽 쌍둥이 문제: **Guideline 5.1.4 (Kids)**는 Kids Category 앱에서 컨텍스트 광고 외의 서드파티 광고를 금지하고 IDFA·아동 식별 정보 수집을 금지한다. **SharkTune을 Kids Category에 넣지 않는다.** 연령 등급 질문지 답변은 Phase 0 항목이다.

Google의 `tagForChildDirectedTreatment` / `tagForUnderAgeOfConsent`는 폐기되고 **TFAT**(`setAgeRestrictedTreatment`)로 대체 중이다. 레거시 태그는 2026년까지 유지되고 제거는 H1 2027 예상이다. **검증 필요 — Flutter TFAT 지원 여부를 1차 출처에서 확인하지 못했다.**

### 6.6 네이티브 App ID — 없으면 앱이 죽는다 (rev.1 전면 누락)

**rev.1의 "기본값은 `DisabledAdSource()`다. 아무것도 하지 않아도 광고는 꺼져 있다"는 네이티브 계층에서 거짓이다.**

- Android GMA SDK는 `com.google.android.gms.ads.MobileAdsInitProvider`라는 **ContentProvider를 등록하며, 이는 Dart가 한 줄도 실행되기 전 프로세스 시작 시점에 동작한다.** `<application>` 안에 아래가 없으면 앱이 죽는다:
  ```xml
  <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
             android:value="ca-app-pub-…~…"/>
  ```
  오류: `java.lang.RuntimeException: Unable to get provider com.google.android.gms.ads.MobileAdsInitProvider: java.lang.IllegalStateException: Invalid application ID`
- iOS는 같은 이유로 `Info.plist`에 `GADApplicationIdentifier`를 요구한다.
- **`DisabledAdSource`는 이를 막을 수 없다 — 실행조차 되지 않는다.**
- `check.ps1`은 `melos test`(위젯 테스트)만 돌리고 `flutter build`도 실기기도 없으므로 **크래시하는 커밋에 대해서도 초록을 보고한다.** rev.1의 "커밋마다 초록"은 가장 중요한 커밋에서 공허하게 만족된다.
- **결정: `APPLICATION_ID` + `GADApplicationIdentifier`를 C13(의존성 추가)과 **같은 커밋**에 넣는다.** 둘은 하나의 계약이다 — rev.1이 C12를 하나로 묶을 때 쓴 논리가 여기 정확히 적용된다.
- **실제 AdMob 계정 이전에 C13을 랜딩하기 위해 Google 공개 테스트 App ID를 쓴다: `ca-app-pub-3940256099942544~3347511713`.** 프로덕션 ID 전환은 별도 커밋(C13b)이며 Phase 0에 종속된다.

---

## 7. Phase 6 — 컴플라이언스 캐스케이드

### 7.1 `C:\toauner\docs\privacy-policy.md` — 삭제가 아니라 **추가**다

rev.1은 이 캐스케이드를 "거짓이 되는 문장을 지우는" 작업으로만 틀 지었다. **2025-04-21 처리방침 작성지침은 적극적 기재 의무를 부과하므로 그것으로 부족하다.**

**(1) 문장 교체 (rev.1의 6개 인용은 전부 검증됐다 — 유지):**

- `:19` — `광고, 사용자 추적, 프로파일링 또는 모델 학습에 사용하지 않습니다.`
  → 마이크에 대한 진술이므로 **여전히 참이다.** 문맥 오해를 막기 위해 "마이크 오디오는" 주어를 명시한다.
- `:26` — `…광고 및 사용 분석 SDK도 포함하지 않습니다.`
  → 마지막 문장이 **거짓이 된다.** 제거한다. 앞 문장(계정·결제 없음)은 참으로 남는다.
- `:30` — `toauner는 사용자 데이터를 수집하여 제3자에게 공유하거나 판매하지 않습니다. 현재 앱은 핵심 기능을 위해 인터넷 연결을 요구하지 않습니다.`
  → 첫 문장이 **거짓이 된다.** 두 번째 문장은 참으로 남는다 — 그리고 참으로 남기는 것이 이 계약의 목표다.
- `:34` — `계정과 서버 저장 데이터가 없으므로 별도의 계정 삭제 절차는 없습니다.`
  → 이 계약 범위에서 **참으로 남는다.**
- `:38` — `서버 전송이 없으므로 마이크 오디오의 네트워크 전송 경로도 없습니다.`
  → 결론은 참이지만 **근거가 무너진다.** "경로가 없다"는 사실 진술을 "튜너 라이브러리에 광고 심볼이 없다"는 강제된 경계로 다시 쓴다.
- `:42` — `향후 클라우드 동기화, 분석, 광고… 추가한다면… 이 방침과 앱 내 고지를 갱신하고 필요한 동의를 받습니다.`
  → **이미 써 둔 의무다.** 이 Phase가 그 이행이다.

**(2) 신설 섹션 — 행태정보 (2025-04-21 작성지침):**

- **수집 주체:** Google (Google Mobile Ads SDK)
- **수집 항목:** IP 주소, 앱 상호작용(실행·탭·동영상 시청 등), 진단 정보, **app set ID**
- **목적:** 광고, 분석, 사기 방지
- **보유기간:** Google 정책에 따름 (링크)
- **거부 방법 (필수 — 구체적 경로를 적는다):**
  - Android: 설정 → 개인정보 보호 → 광고 → 광고 ID 삭제
  - 앱 내: §10 층2의 설정 토글
  - iOS: 설정 → 개인정보 보호 및 보안 → 추적 (본 앱은 추적하지 않음)

문서 전체가 아직 "toauner"로 쓰여 있다. SharkTune 리브랜드를 이 패스에서 함께 처리한다.

### 7.2 `C:\toauner\docs\play-data-safety.md` — rev.1의 표는 세 곳이 틀렸다

`:12-19`의 "현재 빌드 기준 결론" 블록이 뒤집힌다.

```
- 사용자 데이터 수집: 아니요      → 예
- 사용자 데이터 공유: 아니요      → 예 (Google)
- 계정 생성: 없음                → 없음 (유지)
- 광고 또는 분석 SDK: 없음        → 광고 SDK 있음 (google_mobile_ads)
- 핵심 기능의 서버 통신: 없음      → 없음 (유지 — 광고는 핵심 기능이 아니다)
```

**rev.1의 신고 표를 폐기하고 Play의 실제 분류 체계로 다시 쓴다.** Google의 GMA Play 데이터 공시 페이지는 **자기 데이터를 폼 카테고리에 매핑해 주지 않는다** ("use Android's guide about data types to help you determine which data types and purposes best describe the collected data") — 매핑 판단은 개발자 책임이다.

| Play 데이터 유형 | 수집 | 공유 | 목적 | rev.1 대비 |
| --- | --- | --- | --- | --- |
| **위치 → 대략적인 위치(approximate)** | 예 | 예 | 광고, 분석, 사기 방지 | **신설.** rev.1은 "IP 주소"를 유형으로 적었으나 **"IP 주소"는 Play의 선택 가능한 유형이 아니다.** Google 자신의 서술은 IP가 "기기의 대략적 위치를 추정하는 데 사용될 수 있다"이며, 이는 위치 → 대략적인 위치로 매핑된다 |
| 앱 활동 → 앱 상호작용 | 예 | 예 | 광고, 분석, 사기 방지 | 유지 |
| 앱 정보 및 성능 → 진단/비정상 종료 로그 | 예 | 예 | 광고, 분석, 사기 방지 | 유지 |
| **기기 또는 기타 ID** | **예** | **예** | 광고, 분석, 사기 방지 | **rev.1은 "아니요"였다. 거짓.** Google의 GMA Play 공시 페이지는 SDK가 "Device and Account identifiers — including Android advertising (ad) ID and **app set ID**"를 수집한다고 명시한다. **매니페스트 제거는 ad ID만 억제한다. app set ID는 AD_ID 권한에 종속되지 않으며 매니페스트 스위치가 없다.** app set ID는 기기 범위·개발자 범위 식별자로 Play의 "기기 또는 기타 ID" 카테고리에 정확히 들어간다 |

- `:35` — `1. 앱이 필수 사용자 데이터 유형을 수집하거나 공유하나요? **아니요.**` → **예.**
- `:36` — `2. 전송 중 암호화되나요?` → GMA 데이터는 전부 TLS다. **예.**
- **신설:** `3. 사용자가 데이터 삭제를 요청할 수 있나요?` — rev.1이 완전히 누락했다. GMA는 사용자 대면 삭제 경로를 제공하지 않는다. 그에 맞게 답한다.
- `:31` — `| 곡 검색어 | ... | 기기 밖 전송: 없음 |` → **참으로 남는다.** 이 계약은 카탈로그를 네트워크로 옮기지 않는다.
- `:27-31` 표의 여섯 번째 행으로 `광고 요청`을 추가한다.

**Data Safety 오신고는 그 자체로 Play 개발자 프로그램 정책 위반이며 앱 삭제 노출이 있다. 경고가 아니라 삭제로 집행된다. 이것은 미용상의 오류가 아니다.**

**§6.3의 "Data Safety 카드가 오늘과 거의 같게 유지된다"는 삭제됐다.** 오늘의 카드는 "데이터 수집 없음"이고 광고 후의 카드는 **위치(대략적) 수집을 신고하는 튜너 앱**이다. 그것은 "거의 같음"이 아니다. 이 문장이 AD_ID 제거 트레이드의 하중을 지고 있었으므로, 그 트레이드는 이제 §6.3의 축소된 근거로만 정당화된다.

### 7.3 `C:\toauner\docs\ATTRIBUTIONS.md`

- `:22-23` — `toauner uses its local in-memory byte-source playback and loop mode for reference tones; it does not use remote audio URLs.` → 이 앱의 `audioplayers` 사용에 대한 진술로는 **여전히 참이다.** 주어를 `SharkTune's reference tone player`로 좁힌다.
- 새 섹션 `## Advertising SDK`를 추가한다.

| 아티팩트 | 라이선스 | 비고 |
| --- | --- | --- |
| `google_mobile_ads` 9.0.0 (Dart 플러그인) | **Apache-2.0** | GPL 없음. `tool/license_audit.ps1` 통과 |
| Google Mobile Ads SDK (Android/iOS 네이티브 바이너리) | **독점(proprietary)** — Google Developers Site ToS / Mobile Ads SDK Terms | 오픈소스가 아니다. 수정·재배포·역컴파일 금지. **카피레프트는 아니므로 GPL 금지 원칙과 충돌하지 않는다** |
| UMP SDK (Android 4.0.0 / iOS 3.1.0) | **독점** — GMA에 번들 | 별도 pub 패키지 없음 |
| Dart 전이 의존성 전체 | **문서에서 열거하지 않는다** | 아래 참조 |

**rev.1은 전이 의존성을 5개(`webview_flutter`, `webview_flutter_android`, `webview_flutter_wkwebview`, `meta`, 그리고 본체)로 열거했다. 부족하다.** `webview_flutter_android`와 `webview_flutter_wkwebview`는 각각 `webview_flutter_platform_interface`와 `plugin_platform_interface`를 끌고 온다. `license_audit.ps1`의 `Get-ExternalPackageLicenses`는 직접 의존성이 아니라 **`.dart_tool/package_config.json`의 모든 항목**을 순회한다. 따라서 감사 대상 집합은 rev.1이 적은 5개보다 크다.

**결정: 이 표를 문서에서 손으로 열거하지 않는다.** C13에서 `flutter pub get` 후 `reports/release/dependency-licenses.json`(생성물)을 읽어 ATTRIBUTIONS 표를 **그 출력으로부터** 생성한다. 기억이나 계획서로부터 적지 않는다.

**§미해결 질문 2("서드파티 pub 표면을 대략 3배로")는 같은 이유로 과소평가다.** 실제 배수는 C13에서 `dependency-licenses.json`으로 확인한다.

### 7.4 `C:\toauner\tool\license_audit.ps1`

- `Test-ForbiddenLicenseText`(`:18-32`)의 GPL 패턴은 `google_mobile_ads`의 Apache-2.0 LICENSE를 **통과시킨다.** 그게 옳다.
- **rev.1은 잘못된 실패 조건을 방어했다.** rev.1은 GPL 패턴 오탐을 걱정했으나, `license_audit.ps1:76-86`은 **top-level `LICENSE`/`LICENCE`/`COPYING`이 없는 외부 패키지에 대해 텍스트를 읽기도 전에 `blocker`를 낸다.** `check.ps1:23`이 이 감사를 실제로 돌린다. C13을 붉게 만들 실제 조건은 패턴 3이 아니라 **LICENSE 파일 부재**다. (실무적으로 해당 패키지들은 전부 LICENSE를 싣고 있어 통과할 가능성이 높다.)
- **rev.1의 패턴 3 인용도 부정확했다.** 실제 텍스트는 `license_audit.ps1:24`의 `(?i)\b(AGPL|GPL|LGPL)-[123](?:\.0)?(?:-only|-or-later)?\b`다. 오탐 우려 자체는 유효하다 — "compatible with GPL-3.0" 같은 호환성 문구를 담은 허용적 라이선스가 blocker가 될 수 있다. 실패를 디버깅하기 전에 이 사실을 안다.
- **이 감사는 `.dart_tool/package_config.json`의 Dart 패키지만 연다(`:142`).** Gradle/Maven AAR(Play Services Ads)과 CocoaPods(`Google-Mobile-Ads-SDK`)는 **한 번도 열지 않는다.** 광고 SDK의 네이티브 전이 아티팩트 수십 개가 라이선스 검사 0회로 들어오는데 `check.ps1`은 "Dependency license audit passed"를 출력한다. **감사가 초록불을 켜는 대상은 얇은 Dart 셸이지 SDK가 아니다.**
- 새 검사: `package_config.json`에 `google_mobile_ads`가 있으면 **`C:\toauner\docs\native-ad-sdk-licenses.json`**이 존재해야 하고 각 항목이 `artifact` / `license` / `termsUrl` 세 키를 전부 가져야 한다. 없으면 `blocker`.
- **경로가 `reports/`가 아닌 이유 (rev.1의 blocking 버그):** `C:\toauner\.gitignore:35`가 `reports/`다. 확인:
  ```
  $ git check-ignore -v reports/release/native-ad-sdk-licenses.json
  .gitignore:35:reports/	reports/release/native-ad-sdk-licenses.json
  ```
  rev.1의 C13은 `git add`가 이 파일을 조용히 누락하고, C14가 그 파일을 읽는 blocker를 랜딩한다. `license_audit.ps1`은 `check.ps1:23`에서 **실제 실행**되므로, 신규 클론이나 CI에서 `google_mobile_ads`는 `package_config.json`에 있고 JSON은 없다 → `blocker` → **C14와 그 이후 모든 커밋에서 `check.ps1`이 exit 1.** 파일이 로컬에 존재하는 작성자 머신에서는 이 실패가 보이지 않는다.
  (`reports/design/figma-state-sharktune-v2.json`이 추적되는 것은 과거 누군가 `git add -f`를 썼기 때문이다. **게이트 입력에 대해 따를 선례가 아니다** — ignore된 트리 아래 강제 추가된 파일은 디렉터리를 재생성하는 누구에게나 사라진다.)
  추가로, `reports/release/`는 `license_audit.ps1:158`과 `release_readiness.ps1:291`이 **생성물을 쓰는** 곳이다. 손으로 관리하는 진실의 출처를 생성물 디렉터리에 두지 않는다. `docs/`가 `ATTRIBUTIONS.md` 옆이자 사람이 리뷰하는 자리다.
- **커밋 이름을 정직하게 고친다.** rev.1의 `ci: audit native ad SDK licenses…`는 오버클레임이다. 제안된 검사는 **사람이 쓴 JSON이 존재하고 세 키를 갖는지** 볼 뿐이다. 그건 감사가 아니라 **증서(attestation)**다. → `ci: require a native ad SDK license attestation`
- **C13 이전에 실제로 그래프를 열거한다:** `./gradlew :app:dependencies --configuration releaseRuntimeClasspath`와 `pod install` + `Podfile.lock`. JSON을 그 출력으로부터 채운다. `AGENTS.md:26`은 절대적이며 "우리가 생각하는 라이선스를 적어 뒀다"는 그것을 이행하지 않는다.
- **독점 바이너리는 세 번째 범주다.** "permissive"도 "GPL 금지"도 아니다. 명시적 allowlist 항목으로 기록하고 근거를 함께 적는다. 사고로 통과시키지 않는다.

### 7.5 `C:\toauner\tool\release_readiness.ps1`

§2.4 참조. `android_release_internet` 판별자 변경(주석 → `pubspec.yaml`) + `android_merged_manifest_permissions` 추가 + `Invoke-SelfTest`의 `$expected`(`:233-237`) 갱신.

**중요한 비대칭 (이 문서에서 가장 중요한 문단):** `$expected` 목록의 finding 코드 중 광고/인증/결제가 기계적으로 건드리는 것은 **0개**다. (rev.1은 "열두 개"라 적었으나 `:233-237`의 목록은 **10개**이고, 조건부 `*_missing` 두 개를 세면 12다. 개수를 논거로 쓰므로 정정한다.) `privacy_policy`·`play_data_safety`는 `Test-FinalReleaseDocument`(`:35-55`)로 프론트매터(`release_status: final` + TBD 아닌 메타데이터)만 본다. **산문은 읽지 않는다.** "광고 SDK도 포함하지 않습니다"라고 적힌 방침을 그대로 두고 광고를 실어도 게이트는 `ready`를 낸다.

**게다가 `check.ps1`은 이 스크립트를 `-SelfTest`로만 돌린다(§2.3).** 따라서 이 스크립트의 어떤 검사도 CI에서 실제 저장소를 보지 않는다.

**자동화는 이 전제를 방어하지 않는다. 문서가 방어하고, 그 문서를 읽는 사람만이 방어한다.**

**검토했으나 채택하지 않은 것:** `check.ps1`에 `release_readiness.ps1 -Strict` 실제 실행을 추가하는 것. 별도 결정이며 별도 커밋을 요구하고, 현재 숨어 있는 blocker들(Phase 0에 따르면 `privacy_policy`·`play_data_safety` 프론트매터가 `TBD`)을 드러낸다. **이 계약의 범위 밖이며 사용자 결정 항목(§미해결 질문 10)으로 올린다.** 그 전까지 §2.4의 재정의는 **릴리스 체크리스트 항목이지 CI 게이트가 아니다** — 이 문서는 그것을 CI 게이트인 척하지 않는다.

### 7.6 `C:\toauner\app\test\app_information_screen_test.dart`

`'states the on-device microphone and offline data contract'`의 현재 단언:

```dart
expect(find.textContaining('녹음 파일로 저장하지 않습니다'), findsOneWidget);
expect(find.textContaining('서버로 보내지 않습니다'), findsOneWidget);
expect(find.textContaining('오프라인 데이터'), findsOneWidget);
```

- 세 단언 모두 **이 계약 범위에서 계속 통과한다.** 마이크는 여전히 나가지 않고, 검색은 여전히 오프라인이다.
- `C:\toauner\app\lib\src\settings\app_information_screen.dart:38`의 `'광고나 사용자 추적에 사용하지 않습니다'`는 마이크에 대한 진술이므로 참으로 남는다. 그러나 광고가 존재하는 앱에서 이 문장만 있는 것은 오해를 부른다.
- 새 `_InformationSection(label: '광고', ...)`을 추가한다. 담을 내용: 광고는 튜너·안정성 검사·무대 모드·메트로놈 화면에 나타나지 않는다 / 광고 ID를 수집하지 않는다 / 오프라인에서 광고가 없어도 모든 기능이 동작한다 / **행태정보 거부 방법**(§7.1과 일치).
- 새 테스트: `'states that ads never appear on the tuner and that accuracy is never gated'`

### 7.7 화면 문자열 감사 — rev.1 전면 누락

`C:\toauner\app\lib\src\songs\song_search_screen.dart:213`:
```dart
detail: _showSongSearch ? '${_results.length}곡 │ 오프라인' : 'MIC │ 로컬 처리',
```

**Slot A가 실리는 바로 그 화면이 상시 `오프라인`이라고 표시한다.** 앱이 `오프라인`이라 라벨링한 화면에서 네트워크 광고 요청을 쏘게 된다. rev.1의 §7.6은 `app_information_screen_test.dart`의 `'오프라인 데이터'` 단언이 살아남는다고 자축했지만, 캐스케이드는 **화면 문자열을 한 번도 감사하지 않았다** — 문서와 테스트만 봤다.

이것은 1점 리뷰 생성기다("오프라인이라면서 광고는 어떻게 뜨냐"). 다크 패턴 논란의 소지도 있다.

- **결정: 라벨을 `'${_results.length}곡 │ 곡 DB 오프라인'`으로 좁힌다.** 곡 DB가 오프라인이라는 것은 참이고 계속 참이다.
- 테스트로 고정한다: `'the song search status bar scopes the offline claim to the catalog'` (§8.7).

### 7.8 `C:\toauner\app\test\design_playbook_compliance_test.dart`

`_productionDartSources()`(`:149-165`)는 `app/lib`를 재귀 스캔한다. **`app\lib\src\ads\` 아래 모든 새 파일이 옵트인 없이 모든 규칙의 적용을 받는다.**

**rev.1은 "8개 규칙"이라 적었다. 실제로는 `:6, :25, :39, :59, :69, :79, :98, :121, :130`에 **9개** 테스트가 있다.** rev.1은 또 `:42-49`의 리터럴 hex 규칙(`0xFF101512`, `0xFF33FF66`, `0xFF5A6E5E`)을 누락했는데, 광고 UI가 걸릴 수 있는 규칙이다.

광고 UI가 걸릴 규칙:

- `:98-119` — 앱 전체에서 허용된 아이콘은 **셋뿐**: `Icons.chevron_left_rounded`, `Icons.search_rounded`, `Icons.mic_rounded`. 광고 닫기 `×`, 정보 아이콘, "sponsored" 글리프 전부 실패한다. `song_search_screen.dart:316`이 텍스트 `'×'`를 쓰는 선례를 따른다.
- `:59-67` — `RegExp(r'\bColor\(0x')`는 `instrument_theme.dart`(`:145`) 밖에서 금지.
- `:42-49` — 리터럴 hex 상수 규칙. **rev.1 누락.**
- `:130-140` — `fontSize:\s*[0-9]`는 `instrument_theme.dart` 밖에서 금지. "광고" 라벨도 명명된 타입 롤을 쓴다.
- `:69-77` — `BoxShadow(`는 `instrument_surface.dart`(`:147`) 밖에서 금지.
- `:39-57` — `LinearGradient(` / `RadialGradient(` / `SweepGradient(` 전면 금지.

**이 테스트가 못 보는 구멍:** 서드파티 광고 SDK가 렌더링하는 위젯은 `app/lib` 밖의 플랫폼 뷰다. Dart AST 밖이므로 **모든 검사를 우회한다.** 컴플라이언스 스위트는 광고 UI에 대한 방어가 아니라 **우리가 직접 만든** 광고 UI에 대한 방어다. 조용히 넘어가지 않는다.

`C:\toauner\docs\design-playbook.md`에는 광고·페이월·로그인·구매 표면 서술이 **전무하다.** `AGENTS.md:49`가 UI는 플레이북 토큰·상태 이름을 따르라고 요구하므로, **플레이북에 광고 섹션이 생기기 전에는 광고 UI를 정당하게 쓸 수 없다.** 플레이북 `:12`는 이미 표준 광고 어휘를 금지한다 — `임의 그라데이션, 큰 둥근 카드 묶음, 균일한 그림자, 장식용 아이콘 무더기, 과한 글로우는 사용하지 않는다.`

**allowlist 범주 문제 (rev.1의 자기모순):** `docs/design-playbook.md:149`는 "대량 전환 중에는 파일 경로 allowlist를 사용하되, 파일을 마이그레이션할 때마다 항목을 제거한다. **allowlist는 증가할 수 없고 최종값은 빈 집합이다.**"라고 못 박고 있고, `design_playbook_compliance_test.dart:18-22`가 `expect(_legacyThemeAllowlist, isEmpty)`로 오늘 강제한다.

rev.1의 테스트 이름은 `'ad surfaces only appear in the **shrinking** placement allowlist'`였고 "`_adVendorFiles`는 증가할 수 없다"고 썼다. **둘 다 거짓이었다** — C15가 vendor allowlist를 0→1로 늘리고, C19/C20이 placement allowlist를 늘린다. 이 allowlist들은 **설계상 영구적이며 오직 증가만 하고 비어 있지 않은 집합에서 끝난다.** 이는 playbook `:149`가 금지하는 바로 그것이다.

**해결:**
- 플레이북 `:149`의 계약은 **마이그레이션 allowlist**를 위한 것이다. **C18이 두 번째 범주 — 영구 경계 allowlist(permanent boundary allowlist) — 를 명시적으로 분리하고, 이 범주는 shrinking이 아니라 fixed-size임을 기술한다.**
- 테스트 이름을 `'ad surfaces only appear in the fixed placement allowlist'`로 바꾸고, 리터럴에 대해 `.length == N`을 단언한다. 증가가 diff가 아니라 **테스트 실패**가 되게 한다.
- **C3이 이 allowlist를 C18이 정당화하기 15커밋 전에 랜딩한다는 사실을 기록한다.** 트립와이어를 SDK보다 먼저 놓는 가치가 이 순서 역전보다 크다고 판단했다.

### 7.9 Apple 컴플라이언스 — rev.1 전면 누락

rev.1의 캐스케이드는 **Play 전용**이었다. iOS App ID를 Phase 0에 요구하고 `Info.plist`를 §6.2에서 편집하며 iOS 광고 스택을 싣는데, Apple 프라이버시 산출물은 **0개**였다.

- **App Privacy Details (영양성분표)** — App Store Connect. 신규 앱과 모든 업데이트에 필수. **서드파티 SDK가 수집하는 데이터를 포함해야 한다** ("advertising networks, third-party SDKs … whose code you've added"). §7.2와 같은 4개 카테고리.
- **Privacy manifest / SDK 서명** — 2024-05-01부터 Apple은 자주 쓰이는 서드파티 SDK에 privacy manifest와 서명을 요구하며 Google Mobile Ads는 그 목록에 있다. Google이 `PrivacyInfo.xcprivacy`를 싣지만 **앱 레벨 manifest와 required-reason API 선언은 개발자 의무로 남는다. C13에서 확인한다 — 가정하지 않는다.**
- **연령 등급 질문지** — §6.5의 Apple 쌍둥이. Guideline 5.1.4.
- 새 커밋 C25b: `docs: declare apple app privacy details for the ad stack`

### 7.10 `C:\toauner\docs\ui-plan.md` — rev.1 전면 누락 (`AGENTS.md:49` 위반)

`AGENTS.md:49`: "UI를 설계·수정하기 전에 `docs/design-playbook.md`**와** `docs/ui-plan.md`를 읽고 토큰·상태 이름·**P0 우선순위**를 구현 기준으로 사용한다."

rev.1은 design-playbook을 15회 인용하고 광고 UI를 C18 뒤로 게이팅했으나, **`docs/ui-plan.md`를 단 한 번도 언급하지 않았고 어떤 커밋도 이를 갱신하지 않는다.** 선택적 동반 문서가 아니다 — `AGENTS.md:49`가 두 파일을 함께 지명하고, **"P0 우선순위"는 ui-plan.md에만 존재한다.**

- `docs/ui-plan.md:29`의 P0-8은 **비필수 콘텐츠가 화면 공간을 차지하면 안 된다**는 명시적 계약이다. 광고는 정의상 비필수 콘텐츠다.
- `:74`가 실행 순서를 고정한다.
- `:81`은 광고 슬롯이 실리는 화면들에 대해 "릴리스 플레이버 문자열 감사 테스트 통과"를 요구한다.
- 새 커밋 C18b: `docs: place the ad surface in the ui priority plan` — 광고 슬롯이 P0/P1/P2 대비 어디에 앉는지, 그리고 **어느 것도 P0가 아님**을 기술한다.
- C19/C20 이후 `C:\toauner\app\test\release_branding_test.dart`와 `design-playbook.md:152`가 기술하는 릴리스 문자열 감사(검색·곡 상세를 렌더한다 — 둘 다 광고 호스트다)가 여전히 통과하는지 확인한다.

### 7.11 `C:\toauner\app\test\precision_tuner_golden_test.dart` — rev.1의 게이트 주장을 삭제한다

- abyss / paper / clipping 3개 테마의 픽셀 골든을 `Size(1080, 2340)` / DPR 3(→ 360×780 논리 픽셀, `design-playbook.md:136` 일치)으로 렌더한다. **이 부분은 정확하다.**
- **rev.1: "골든이 깨지면 그것은 §4.1 금지를 어겼다는 신호다. 골든 무변경 자체가 배치 계약의 회귀 게이트다." → 삭제한다. 거짓이다.**
  1. 골든 테스트는 `PrecisionTunerScreen`을 **직접** 생성하며 `AdScope` 조상이 없다(`:43-54`). 튜너에 `AdSurface`를 추가해도 `DisabledAdSource` 기본값으로 해결 → 높이 0 → **골든 바이트 동일.**
  2. 실제 소스에 배선되더라도 GMA는 플랫폼 뷰로 렌더한다. `flutter test`는 플랫폼 뷰를 렌더하지 않는다.
  - 즉 골든은 **잡는다고 주장하는 바로 그 위반에 대해 반드시 초록으로 남는다.** 가짜 게이트이며, §2.2 자신의 기준으로 게이트가 없는 것보다 나쁘다.
- **정확한 진술:** 골든의 역할은 **광고 스택 도입이 튜너 레이아웃에 대해 중립임을 확인하는 것**뿐이다. §4.1을 강제하는 것은 심볼 트립와이어 하나다.
- rev.2에서 C11이 삭제됐으므로 **튜너 파일은 아예 변경되지 않는다.** 골든은 자명하게 불변이다.

---

## 8. 먼저 작성할 테스트

테스트 이름은 그대로 쓴다. 전부 `group()` 없이 `void main()` 안의 평면 `test()` / `testWidgets()`다. 픽스처는 `final class _Fake...` 형태로 파일 하단에 `_` 접두사로 둔다. mocking 패키지를 도입하지 않는다.

**랜딩 규칙 — rev.1에서 변경됨.** rev.1은 "기능 테스트는 `feat:` 다음 커밋으로 랜딩한다"고 썼고 근거로 저장소 이력(`2315980 feat` → `e59c1d0 test` → `791a9c4 docs`)을 들었다. **그 이력은 사실이지만, 저장소 이력 자체가 `AGENTS.md:50`("먼저 실패하는 작은 테스트를 추가하고 구현한다")에 대해 비준수다. 과거의 비준수를 계속된 비준수의 근거로 인용하는 것은 논증이 아니다. AGENTS.md가 계약이고 git log는 아니다.** 게다가 rev.1이 근거로 든 "커밋마다 초록"은 **AGENTS.md에 없는 규칙**이다 — `:69-71`은 Conventional Commits와 "독립 revert 가능한 변경을 섞지 말 것"만 요구한다. 발명한 제약으로 실재하는 제약을 override한 것이다. 부수적으로 rev.1의 분리는 **독립 revert를 깬다**: C5를 되돌리면 C6의 `ad_gate_test.dart`가 삭제된 심볼을 참조해 트리가 붉어진다.

**rev.2의 규칙:**
1. **오늘 코드에 대해 이미 통과하는 트립와이어 테스트는 SDK보다 먼저 독립 `test:` 커밋으로 랜딩한다.** (C2/C3/C4 — rev.1의 이 부분은 옳았다.)
2. **새 동작을 요구하는 기능 테스트는 그 기능과 같은 커밋에 랜딩한다.** 작업 트리에서 **테스트를 먼저 쓰고 붉은 것을 확인한 뒤** 구현을 쓴다. `AGENTS.md:50`(프로세스), `:71`(단일 관심사), 초록 유지를 동시에 만족한다.

### 8.1 `C:\toauner\app\test\ad_placement_compliance_test.dart` — 트립와이어, SDK보다 먼저

- `'the precision tuner library contains no ad symbol'`
- `'the stage mode, stability, and metronome libraries contain no ad symbol'` ← rev.1에서 메트로놈 추가·이름 변경
- `'google_mobile_ads is imported only by the vendor adapter'`
- `'ad surfaces only appear in the fixed placement allowlist'` ← rev.1의 "shrinking" 삭제
- `'no production source gates tuning accuracy behind an ad'`

`design_playbook_compliance_test.dart:149-185`의 `_productionDartSources()` / `_workspaceRoot()` / `_isWorkspaceRoot()`를 복제한다. 경로는 `Platform.pathSeparator`로 만들고 위반은 `path.substring(root.path.length + 1)`로 보고한다.

**스캔 범위 — rev.1의 blocking 버그를 고친다.** rev.1의 금지 심볼 집합은 `AdSource`, `AdSurface`, `AdGate`, `AdPlacement`를 포함하면서 allowlist는 `_adVendorFiles`(vendor 파일 1개)와 미명세 "placement allowlist"뿐이었다. 그러면 **C5가 만드는 `ad_source.dart`(`AdSource` 선언), `ad_gate.dart`(`AdGate`), `ad_placement.dart`(`AdPlacement`)와 C9의 `ad_surface.dart`(`AdSurface`)가 전부 C3가 이미 랜딩한 테스트의 위반이다.** 심 자신의 홈 디렉터리에 면제가 없었다.

rev.2의 규칙 분리:

- **스캔 대상 = `app/lib` **빼기** `app\lib\src\ads\**`.**
- **vendor 심볼** (`google_mobile_ads`, `MobileAds`, `BannerAd`, `InterstitialAd`, `LoadAdError`, `ConsentInformation`, `ConsentForm`) → `_adVendorFiles`에만 허용. C3에서 `_adVendorFiles = const {'app\\lib\\src\\ads\\google_mobile_ads_source.dart'}`로 **미리 선언한다**(파일은 아직 없지만 allowlist는 확정이다). C15는 파일을 추가할 뿐 allowlist를 늘리지 않는다. `expect(_adVendorFiles.length, 1)`을 단언한다.
- **심 심볼** (`AdSource`, `AdGate`, `AdSurface`, `AdPlacement`, `AdScope`, `AdHandle`) → `app\lib\src\ads\**` ∪ `_adPlacementFiles` ∪ `_adWiringFiles`에만 허용.
  - `_adWiringFiles = const {'app\\lib\\main.dart', 'app\\lib\\src\\app\\toauner_app.dart'}` — C5에서 확정. `.length == 2` 단언.
  - `_adPlacementFiles` — C3에서 최종값을 **미리 선언한다**: `{'app\\lib\\src\\songs\\song_search_body.dart', 'app\\lib\\src\\songs\\song_detail_screen.dart'}`. `.length == 2` 단언. C19/C20은 파일에 코드를 넣을 뿐 allowlist를 늘리지 않는다. **이것이 "fixed allowlist"의 실체다.**
- 금지 라이브러리 목록: `app\lib\src\tuner\**`, `app\lib\src\stability\**`, `app\lib\src\metronome\**`, `app\lib\src\songs\song_search_screen.dart` (C-R 이후 — 홈 화면).

추가 테스트:
- `'song detail declares exactly one ad surface'` — 인스턴스 수를 센다(§4.3의 위치는 수동, 개수는 자동).

### 8.2 `C:\toauner\app\test\offline_integrity_test.dart` — 트립와이어, SDK보다 먼저

- `'the tuner completes a full session while every ad load fails'`
- `'song search returns bundled results while every ad load fails'`
- `'no ad surface reserves height while every ad load fails'`
- `'the first frame renders before consent info is requested'` ← §2.5의 콜드스타트 계약. rev.1 누락

`C:\toauner\app\test\fake_ad_source.dart`(파일명이 `_test.dart`가 아니므로 테스트로 수집되지 않는다)에 `final class AlwaysFailingAdSource implements AdSource`와 `final class ScriptedAdSource implements AdSource`를 둔다. **C2 시점에는 `AdSource`가 없으므로, C2의 페이크는 최소 인터페이스를 테스트 파일 안에 자체 선언하고 C5에서 실제 심으로 교체한다.**

rev.1의 `'the tuner golden layout is unchanged by the ad gate'`는 **삭제한다.** §7.11 참조 — 골든은 `AdScope` 없이 렌더하므로 이 테스트는 무엇도 증명하지 않는다.

### 8.3 `C:\toauner\app\test\ad_gate_test.dart`

- `'the ad gate is disabled by default'`
- `'the ad gate stays disabled until consent reports that ads may be requested'`
- `'the ad gate treats a consent timeout as consent refused'` ← §2.5. rev.1 누락
- `'the ad gate stops requesting after three consecutive load failures'`
- `'the interstitial gate rejects a second show inside the cooldown window'`

rev.1의 `'the ad gate rejects a request while the microphone session is live'`는 **삭제한다.** §2.6 참조 — 배선이 없는 규칙을 인증하지 않는다.

### 8.4 `C:\toauner\app\test\ad_surface_test.dart`

- `'ad surface occupies zero height before a load resolves'`
- `'ad surface occupies zero height after a load failure'`
- `'ad surface expands exactly once when a load succeeds'`
- `'ad surface keeps the following widget offset unchanged when the load fails'`
- `'pushing a route over an ad surface disposes the live ad handle'` ← §2.6. rev.1 누락

**성공 경로 시프트 테스트를 요구하지 않는 이유:** 허용 슬롯이 전부 각 스크롤 뷰의 마지막 위치이므로(§4.2) 아래에 밀 위젯이 없다. rev.1이 그런 테스트를 쓸 수 없었던 이유(Slot B)는 슬롯 삭제로 제거됐다. **테스트를 못 쓰는 상황이면 슬롯을 지운다 — 그 반대가 아니다.**

### 8.5 `C:\toauner\app\test\ad_settings_store_test.dart`

- `'JSON store falls back to backup after primary corruption'`
- `'ad settings load as disabled when the file is unreadable'`
- `'the store persists the last interstitial timestamp across a reload'`
- `'concurrent writes are serialized without losing the cooldown stamp'`

`Directory.systemTemp.createTemp('sharktune-ads-')` + `addTearDown(() => directory.delete(recursive: true))` + `JsonAdSettingsStore(directoryProvider: () async => directory)` 패턴을 `C:\toauner\app\test\tuning_history_store_test.dart`에서 복제한다.

### 8.6 `C:\toauner\app\test\android_manifest_permission_test.dart`

- `'the Android main manifest declares only the audited permission set'`
- `'the Android main manifest removes the advertising id permission'`
- `'the Android main manifest binds the tools namespace'` ← rev.1 누락 (§6.3)
- `'the Android main manifest declares the admob application id'` ← rev.1 누락 (§6.6)
- `'the iOS Info.plist declares no tracking usage description'`
- `'the iOS Info.plist declares the admob application identifier'` ← rev.1 누락 (§6.6)

`release_branding_test.dart:62-70`의 `_appDirectory()` 워크스페이스 탐색을 복제한다.

**rev.1의 두 테스트는 서로 모순이었다 — 고친다.** `tools:node="remove"`는 요소가 **존재할 것**을 요구한다:
```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />
```
그러면 rev.1의 `'…declares only the audited permission set'`(집합 동등성)이 추출 집합에서 `AD_ID`를 발견해 실패하고, `'…removes the advertising id permission'`은 그것이 있기를 요구한다. 둘 다 rev.1의 C12에 들어가므로 **C12는 초록일 수 없었다.**

**명세:** 집합 동등성 테스트의 추출기는 **`tools:node="remove"`를 가진 `<uses-permission>` 요소를 제외한다.** `const _auditedAndroidPermissions`를 테스트 파일 안에 선언하고 집합 동등성을 단언한다.

### 8.7 `C:\toauner\app\test\ad_consent_test.dart`

- `'ads are never initialized before consent info is requested'`
- `'the privacy options entry appears only when consent requires it'`
- `'the consent requirement enum carries a korea arm'` ← §6.4. rev.1 누락

### 8.8 `C:\toauner\app\test\app_information_screen_test.dart` — 기존 파일에 추가

- `'states that ads never appear on the tuner and that accuracy is never gated'`
- `'states how to refuse behavioural advertising data'` ← §7.1. rev.1 누락

### 8.9 `C:\toauner\app\test\song_search_screen_test.dart` (또는 해당 위치)

- `'the song search status bar scopes the offline claim to the catalog'` ← §7.7. rev.1 누락

---

## 9. 커밋 순서

전부 Conventional Commits다. 각 커밋은 독립적으로 되돌릴 수 있다. 테스트는 `C:\toauner\app`에서 실행한다(`cd C:\toauner\app; ..\.tools\flutter\bin\flutter.bat test`). 루트에서 `flutter test app`을 돌리면 에셋 번들 경로가 깨져 거짓 실패가 난다.

모든 커밋 메시지 트레일러: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

**"커밋마다 `check.ps1` 초록"은 rev.2에서 AGENTS.md 규칙이 아니라 우리가 지키려는 편의 목표로 강등한다.** `AGENTS.md:69-71`은 이를 요구하지 않는다. 이 표는 여전히 초록을 유지하도록 순서를 짜지만, **초록이 다른 AGENTS.md 규칙을 override하는 근거가 되지는 않는다**(§8 랜딩 규칙 참조). 그리고 §6.6이 보여주듯 **`check.ps1` 초록은 앱이 살아 있다는 뜻이 아니다** — `melos test`만 돌고 `flutter build`도 실기기도 없다.

| # | 커밋 | 파일 | 비고 |
| --- | --- | --- | --- |
| C1 | `docs: define the ad environment contract` | `C:\toauner\docs\ad-environment-2026-07-15.md` | 문서만 |
| C2 | `test: pin offline tuner integrity ahead of the ad stack` | `app\test\offline_integrity_test.dart`, `app\test\fake_ad_source.dart` | 페이크가 심 없이 동작하도록 최소 인터페이스를 테스트 파일 안에 둔다. 오늘 코드로 통과 |
| C3 | `test: forbid ad symbols outside the fixed allowlists` | `app\test\ad_placement_compliance_test.dart` | 광고 심볼 0개이므로 통과. **SDK보다 먼저 놓인 트립와이어.** allowlist 3종의 **최종값을 미리 선언**한다(§8.1) |
| C4 | `test: pin the audited android permission set` | `app\test\android_manifest_permission_test.dart` | 현재 집합 `{RECORD_AUDIO}` 단언. App ID / tools 네임스페이스 테스트는 아직 넣지 않는다(C12b/C13에서 추가) |
| **C-R** | `refactor: extract the song search body into its own file` | `app\lib\src\songs\song_search_screen.dart`, `app\lib\src\songs\song_search_body.dart` | **§4.3 강제의 전제.** 홈(`_buildTuningHome`)과 검색(`_buildSongSearchBody`)을 파일로 분리한다. `PrecisionTunerScreen(` 생성 지점(`:397`)이 검색 쪽이면 함께 이동. 골든 중립. 광고 코드 0 |
| C5 | `feat: add the disabled-by-default ad gate and source seam` | `app\lib\src\ads\{ad_placement,ad_source,ad_handle,disabled_ad_source,ad_gate,ad_scope}.dart`, **`app\lib\main.dart`**, **`app\lib\src\app\toauner_app.dart`**, `app\test\ad_gate_test.dart` | **rev.1이 누락한 `main.dart`/`toauner_app.dart` 포함**(§3.3). **테스트 동봉**(§8 규칙 2) — 작업 트리에서 `ad_gate_test.dart`를 먼저 붉게 만든 뒤 구현. SDK 없음. `ToaunerApp` 새 필드는 전부 nullable/const 기본값 — `widget_test.dart`의 **21개** 생성 지점을 깨지 않는다 |
| C7 | `feat: add the local ad settings store` | `app\lib\src\ads\ad_settings_store.dart`, `app\test\ad_settings_store_test.dart` | 테스트 동봉. `tuning_history_store.dart` 복제. 별도 파일 `ads.v1.json` |
| C9 | `feat: add the zero-height ad surface` | `app\lib\src\ads\ad_surface.dart`, `app\test\ad_surface_test.dart` | 테스트 동봉. `deactivate()` 해체 포함(§2.6). `DisabledAdSource` 기본이므로 높이 0 |
| C12a | `build: declare internet for the ad stack` | `app\android\app\src\main\AndroidManifest.xml`, `tool\release_readiness.ps1` | `INTERNET` 선언 + `android_release_internet` 판별자를 `pubspec.yaml`로 변경 + 자기 검사 정합. **판별자가 pubspec이므로 이 커밋 시점에 `google_mobile_ads`가 없어 게이트는 blocker를 낸다 — 그러나 `check.ps1`은 `-SelfTest`만 돌리므로 CI는 초록이고, `-Strict`는 C13에서 해소된다.** 이 창(C12a~C13)의 존재를 커밋 본문에 명시한다 |
| C12b | `build: remove the advertising id permission` | `app\android\app\src\main\AndroidManifest.xml`, `app\test\android_manifest_permission_test.dart` | **`xmlns:tools` 바인딩 + `tools:node="remove"`**(§6.3). 집합 동등성 추출기에서 `tools:node="remove"` 제외(§8.6). rev.1이 C12에 섞었던 별개 결정 — `INTERNET`을 되돌리지 않고 이것만 되돌릴 수 있다 |
| C12c | `ci: check the merged manifest permission set` | `tool\release_readiness.ps1` | `android_merged_manifest_permissions` + 자기 검사 픽스처 + `$expected`. **자동 검사가 아님을 커밋 본문에 명시한다**(§2.3) |
| C13 | `build: add google_mobile_ads 9.0.0 under the apache-2.0 plugin license` | `app\pubspec.yaml`, `pubspec.lock`, **`app\android\app\src\main\AndroidManifest.xml`**, **`app\ios\Runner\Info.plist`**, **`app\ios\Podfile`**, `C:\toauner\docs\native-ad-sdk-licenses.json`, `app\test\android_manifest_permission_test.dart` | **`APPLICATION_ID` + `GADApplicationIdentifier`를 테스트 App ID `ca-app-pub-3940256099942544~3347511713`로 동봉**(§6.6 — 없으면 프로세스 시작 크래시). **iOS 최초 CocoaPods 통합**(§10 미해결 8). `license_audit.ps1` **실제 실행**이 `check.ps1`에 있다 — LICENSE 파일 부재가 실제 실패 조건이다(§7.4). **이 커밋이 WebView 엔진을 트리에 들이는 되돌릴 가치가 있는 단위다.** JSON은 `./gradlew :app:dependencies --configuration releaseRuntimeClasspath`와 `Podfile.lock` 실제 출력으로 채운다 |
| C13b | `build: switch to the production admob application ids` | `app\android\app\src\main\AndroidManifest.xml`, `app\ios\Runner\Info.plist` | **Phase 0 종속.** 실제 App ID가 없으면 이 커밋을 시작하지 않는다 |
| C14 | `ci: require a native ad sdk license attestation` | `tool\license_audit.ps1` | **이름 정정 — "audit"이 아니라 "attestation"이다**(§7.4). `docs\native-ad-sdk-licenses.json`이 C13에서 이미 **추적되는 경로에** 존재하므로 통과. `git check-ignore`로 확인한 뒤 체크리스트를 적는다 |
| C15 | `feat: add the google_mobile_ads adapter behind the ad source seam` | `app\lib\src\ads\google_mobile_ads_source.dart` | C3의 `_adVendorFiles`가 이미 이 경로를 담고 있다 — **allowlist는 증가하지 않는다.** 기본 소스는 여전히 `DisabledAdSource` |
| C16 | `feat: gate ad requests behind ump consent` | `app\lib\src\ads\ad_consent.dart`, `app\lib\src\ads\ad_gate.dart`, `app\lib\src\ads\google_mobile_ads_source.dart`, `app\test\ad_consent_test.dart` | 테스트 동봉. **국내 변호사 검토가 이 커밋을 차단한다**(§6.4). `ConsentRequirement`에 KR 분기 자리를 만든다. `canRequestAds()`가 `false`면 `initialize()` 미호출. **첫 프레임 이후 + 타임아웃**(§2.5) |
| C18 | `docs: define the ad and consent surface in the design playbook` | `C:\toauner\docs\design-playbook.md` | 광고 라벨·컨테이너·개인정보 옵션 행의 토큰·상태 이름을 6개 테마(abyss, onyx, amber, violet, paper, clipping) 전부에 정의. **영구 경계 allowlist를 마이그레이션 allowlist(`:149`)와 별개 범주로 분리**(§7.8). **이 커밋 전에는 광고 UI를 쓰지 않는다** |
| C18b | `docs: place the ad surface in the ui priority plan` | `C:\toauner\docs\ui-plan.md` | **rev.1 전면 누락 — `AGENTS.md:49` 위반이었다**(§7.10). 광고 슬롯의 P0/P1/P2 위치와 **어느 것도 P0가 아님** |
| C19 | `feat: show the search footer ad slot` | `app\lib\src\songs\song_search_body.dart` | **Slot A만.** `_results.length >= 4` 조건(§4.2). C3의 `_adPlacementFiles`가 이미 이 경로를 담는다. **광고 단위 ID 필요(Phase 0).** **AdMob 콘솔에서 자동 새로고침 끄기 확인**(§2.6) |
| C20 | `feat: show the song detail ad slot` | `app\lib\src\songs\song_detail_screen.dart` | **Slot C — `_VerificationNotice` 아래**(§4.2). 광고 단위 ID 필요 |
| C22 | `feat: show the session end interstitial behind the local cooldown` | `app\lib\src\songs\song_detail_screen.dart`, `app\lib\src\songs\song_search_body.dart` | **Slot D — 라우트 복귀 이후**(§4.4). **튜너 파일 변경 0.** 광고 단위 ID 필요 |
| C23 | `feat: surface the ad disclosure in app information` | `app\lib\src\settings\app_information_screen.dart`, `app\test\app_information_screen_test.dart` | 테스트 동봉 |
| C24 | `fix: scope the song search offline claim to the catalog` | `app\lib\src\songs\song_search_body.dart`, `app\test\song_search_screen_test.dart` | **rev.1 전면 누락**(§7.7). `오프라인` → `곡 DB 오프라인` |
| C25 | `docs: restate the privacy policy for the ad stack` | `C:\toauner\docs\privacy-policy.md` | §7.1의 문장 교체 **+ 행태정보 신설 섹션 + 거부 방법** + SharkTune 리브랜드 |
| C25b | `docs: declare apple app privacy details for the ad stack` | `C:\toauner\docs\` (신규 또는 `platform-readiness.md`) | **rev.1 전면 누락**(§7.9) |
| C26 | `docs: redeclare play data safety for the ad stack` | `C:\toauner\docs\play-data-safety.md` | §7.2의 표. **기기 ID = 예/예, 위치(대략적) 행 추가, 삭제 요청 질문 추가** |
| C27 | `docs: attribute the advertising sdk and its terms` | `C:\toauner\docs\ATTRIBUTIONS.md` | §7.3. **전이 의존성 표는 `reports/release/dependency-licenses.json` 실제 출력으로부터 생성한다 — 손으로 열거하지 않는다** |

**삭제된 커밋:** rev.1의 C6/C8/C10/C17/C21은 각각 C5/C7/C9/C16에 병합되거나(§8 규칙 2) 슬롯 삭제로 사라졌다(C21 = Slot B). **rev.1의 C11(튜너 세션 종료 훅)은 §4.4에 따라 삭제됐다 — 튜너 파일은 이 계약 전체에서 한 줄도 바뀌지 않는다.**

**C1이 이력 관례를 어기는 이유:** 저장소 이력은 `docs:`가 항상 `feat:` 뒤에 따라온다. C1은 예외다. 이 문서가 이후 전부가 검사받는 **계약 자체**이기 때문이다.

**C12a와 C13을 붙이지 않는 이유:** `INTERNET`을 선언하는 것과 SDK를 들이는 것은 서로 다른 결정이다. C13을 되돌려도 C12a는 유지될 수 있고, 그 반대는 성립하지 않는다. 순서를 뒤집으면 SDK가 매니페스트 게이트가 준비되기 전에 들어온다. **rev.1이 C12에 섞었던 AD_ID 제거와 새 검사는 C12b/C12c로 분리했다** — 각각 독립 revert 가능하며, 커밋 제목의 "and"가 그 tell이었다(`AGENTS.md:71`).

---

## 10. 킬 스위치

광고를 **릴리스 없이** 끄는 방법. **3층이 진짜 답이다.**

| 층 | 메커니즘 | 릴리스 필요? | 반영 시간 |
| --- | --- | --- | --- |
| 1 — 빌드 타임 | `const bool.fromEnvironment('SHARKTUNE_ADS_ENABLED', defaultValue: false)`. `--dart-define`으로만 켜진다 | **예** | 다음 릴리스 |
| 2 — 사용자 | 설정 화면 토글 → `ads.v1.json` | 아니요 | 즉시 (본인만) |
| 3 — **운영자 (진짜 킬 스위치)** | **AdMob 콘솔에서 광고 단위를 일시중지한다.** SDK가 no-fill(code 3)을 반환하고 `AdSurface`는 높이 0을 유지한다 | **아니요** | **검증 필요 — 단위 일시중지 반영 시간을 1차 출처에서 확인하지 못했다. 빈도 제한 변경은 최대 24시간으로 문서화되어 있다** |
| 4 — 원격 구성 | Firebase Remote Config | 아니요 | — |

**3층이 왜 우아한가:** 앱은 이미 no-fill을 **정상 상태**로 취급한다(§5.1, §2.5). 오프라인 사용자에게 앱이 어떻게 보이는지가 곧 광고 단위를 끈 상태의 모습이다. **킬 스위치를 위해 코드를 한 줄도 더 쓰지 않는다.**

**단, 3층은 광고를 끄지 앱의 네이티브 광고 스택을 끄지 않는다.** `MobileAdsInitProvider`는 여전히 프로세스 시작 시 돌고, App ID는 여전히 매니페스트에 있고, WebView 엔진은 여전히 APK에 있다. 3층은 **광고 노출**의 킬 스위치이지 **광고 스택**의 킬 스위치가 아니다. 후자는 1층(릴리스 필요)뿐이다. rev.1은 이 구분을 하지 않았다.

**4층을 거부하는 이유:** Firebase Remote Config는 두 번째 네트워크 스택, 두 번째 SDK, 두 번째 라이선스 항목, 추가 Data Safety 표면을 뜻한다. 3층이 같은 일을 0원에 한다.

**로컬 서킷 브레이커:** `AdGate`는 연속 3회 실패 후 세션 내 요청을 중단한다.

---

## 11. 하지 말 것

각 항목은 그렙 가능한 심볼이나 파일 경로를 명시한다. 명시할 수 없다면 Verification matrix의 수동 열로 간다.

- **튜닝 화면에 광고를 넣지 않는다.** `app\lib\src\tuner\` 전체(`precision_tuner_screen.dart` + 3개 `part` 파일 + `stage_mode_screen.dart`), `app\lib\src\stability\` 전체, **`app\lib\src\metronome\` 전체**. `ad_placement_compliance_test.dart`가 Dart 심볼에 대해 강제한다. **네이티브 오버레이는 심볼 테스트가 못 막으므로 §4.4가 인터스티셜을 라우트 복귀 이후로 옮겨 라우트 순서로 강제한다.**
- **정확도를 유료화하지 않는다.** 센트 측정, 인튠 잠금 임계값, 안정성 검사, 페그 안내, 6현 완료는 광고 유무·구매 여부와 무관하다. `'no production source gates tuning accuracy behind an ad'`가 강제한다.
- **로그인을 강제하지 않는다.** 이 계약은 계정을 도입하지 않는다. `privacy-policy.md:34`를 참으로 유지하기 위해서다. 로그인이 들어오면 Google Play의 **웹 접근 가능한 계정 삭제 URL** 의무가 생긴다. (Apple Guideline 4.8은 **서드파티/소셜 로그인**에만 붙으므로 자체 계정이면 무관하다 — rev.1의 4.8 언급은 과잉 정당화였다. Play 의무 쪽이 실제 이유다.)
- **오프라인 동작을 광고에 종속시키지 않는다.** 광고 로드 실패는 앱 실패가 아니다. `offline_integrity_test.dart`가 강제한다.
- **UMP나 `MobileAds.initialize()`를 첫 프레임 이전에 실행하지 않는다.** `main.dart`에서 `await`하지 않는다. `'the first frame renders before consent info is requested'`가 강제한다.
- **리워드 광고를 도입하지 않는다.** SSV가 서버 없이는 불가능하므로 보상은 클라이언트 신뢰이고 자명하게 스푸핑된다. 그리고 PIPC 아동·청소년 가이드라인이 경고하는 "보상과 개인정보/참여의 교환" 패턴에 정확히 해당한다.
- **앱 시작 시 인터스티셜을 띄우지 않는다.**
- **Play 타깃 대상에서 13-15 브래킷을 선택하지 않는다.** 만 14세 미만을 포함해 개인정보보호법 제22조의2(법정대리인 동의·확인 의무)를 발동시키고, Families Self-Certified Ads SDK(신규 신청 마감)를 요구할 수 있다. **16-17 + 18+ 또는 18+만.**
- **SharkTune을 Apple Kids Category에 넣지 않는다.** Guideline 5.1.4.
- **곡 카탈로그를 네트워크로 옮기지 않는다.** 열면 `app_information_screen_test.dart:20`의 `'오프라인 데이터'`와 `play-data-safety.md:31`의 `곡 검색어 | 기기 밖 전송: 없음`이 동시에 거짓이 된다.
- **`tuner_dsp` / `tuner_domain`에 광고 코드를 넣지 않는다**(`AGENTS.md:28`).
- **인피드(리스트 중간) 배너를 넣지 않는다.** `ListView(children:)`는 eager build이므로 성공 시 아래 전부가 밀린다. 허용 슬롯은 각 스크롤 뷰의 마지막 위치뿐이다.
- **`_VerificationNotice` 위에 광고를 넣지 않는다.** 유료 광고를 신뢰성 진술 위에 앉히지 않는다.
- **`LoadAdError.code == 2`로 앱 로직을 분기하지 않는다.** 정상 연결에서도 뜬다.
- **광고 실패를 재시도하지 않는다.**
- **`NSUserTrackingUsageDescription`을 추가하지 않는다.** 우리는 추적하지 않으므로 ATT가 요구되지 않고 따라서 이 키가 불필요하다. **(rev.1의 근거 "있으면 심사에서 문제가 된다"는 거짓이다 — Apple은 미사용 키로 반려하지 않는다. 강제되는 것은 그 역이다.)**
- **`com.google.android.gms.permission.AD_ID`를 남기지 않는다.** `xmlns:tools` 바인딩 후 `tools:node="remove"`.
- **`docs/design-playbook.md`에 광고 섹션이 생기기 전에 광고 UI를 쓰지 않는다.** C18이 C19보다 먼저다. **`docs/ui-plan.md`도 마찬가지다**(C18b, `AGENTS.md:49`).
- **정확도를 하나의 숫자로 홍보하지 않는다**(`AGENTS.md:32`). 광고 카피에도 적용된다.
- **라이선스를 확인하지 않고 명시하지 않는다**(`AGENTS.md:26`). 모든 SDK는 ATTRIBUTIONS 항목과 `license_audit.ps1` 통과 증거를 함께 가진다. **전이 의존성은 기억이 아니라 `dependency-licenses.json` 출력에서 적는다.**
- **AD_ID 제거를 컴플라이언스 방패로 팔지 않는다.** app set ID는 남고, Data Safety의 기기 ID 행은 여전히 예/예다.

---

## Verification matrix

**rev.1 대비 수동 열이 길어졌다. 이것은 후퇴가 아니라 정직해진 것이다** — rev.1은 실행되지 않는 검사를 자동 열에 넣었다.

| 계약 | 자동 | 수동 |
| --- | --- | --- |
| 튜닝·안정성·메트로놈에 광고 심볼 없음 | `ad_placement_compliance_test.dart:'the precision tuner library contains no ad symbol'` / `'the stage mode, stability, and metronome libraries contain no ad symbol'` | — |
| **네이티브 전면 광고가 튜너를 덮지 않음** | **없음 — 플랫폼 오버레이는 Dart AST·골든 밖이다** | **삼성 실기기에서 6현 완료 → 라우트 복귀 → 광고 순서를 촬영해 확인. §4.4가 라우트 순서로 설계했으나 검증은 사람이 한다** |
| 광고 SDK 격리 | `ad_placement_compliance_test.dart:'google_mobile_ads is imported only by the vendor adapter'` + `_adVendorFiles.length == 1` | — |
| allowlist 고정 크기 | `_adPlacementFiles.length == 2`, `_adWiringFiles.length == 2` | — |
| 오프라인 무결성 | `offline_integrity_test.dart:'the tuner completes a full session while every ad load fails'` | 삼성 실기기 **비행기 모드**로 곡 검색 → 튜닝 → 완료 전 구간 |
| 콜드스타트 (첫 프레임) | `offline_integrity_test.dart:'the first frame renders before consent info is requested'` | 실기기에서 **캡티브 포털/약전계** 환경 콜드스타트 후 튜닝까지 시간 측정 |
| reserve-then-collapse 금지 | `ad_surface_test.dart:'ad surface occupies zero height after a load failure'` | 실기기 신호 불안정 구간에서 검색 결과 스크롤 중 시프트 관찰 |
| 라우트 push 시 광고 해체 | `ad_surface_test.dart:'pushing a route over an ad surface disposes the live ad handle'` | — |
| **배너 자동 새로고침 OFF** | **없음 — AdMob 콘솔은 저장소 밖이다** | **콘솔에서 각 단위의 자동 새로고침이 꺼졌는지 확인.** 켜져 있으면 라이브 바늘 아래에서 WebView가 리페인트한다 |
| 광고 기본 비활성 | `ad_gate_test.dart:'the ad gate is disabled by default'` | — |
| 동의 타임아웃 | `ad_gate_test.dart:'the ad gate treats a consent timeout as consent refused'` | — |
| 인터스티셜 쿨다운 | `ad_gate_test.dart:'the interstitial gate rejects a second show inside the cooldown window'` | 실기기에서 연속 2회 튜닝 완료 후 두 번째에 광고가 안 뜨는지 |
| 소스 권한 집합 | `android_manifest_permission_test.dart:'the Android main manifest declares only the audited permission set'` | — |
| tools 네임스페이스 / App ID | `android_manifest_permission_test.dart:'…binds the tools namespace'` / `'…declares the admob application id'` / iOS 2종 | — |
| **앱이 실제로 실행됨** | **없음 — `check.ps1`은 `melos test`만 돌린다. `flutter build`도 실기기도 없다** | **C13 직후 삼성 실기기에서 콜드 런치.** `MobileAdsInitProvider` 크래시가 여기서만 잡힌다(§6.6) |
| **병합 매니페스트 권한** | **없음 — `check.ps1:17`은 `-SelfTest`만 돌린다(§2.3)** | `flutter build apk --release` 후 `aapt dump permissions` **또는** `release_readiness.ps1 -Strict` 수동 실행 |
| **AD_ID 병합 결과 제거** | **없음 — 위와 동일** | 병합 매니페스트에서 `AD_ID` 부재 육안 확인 |
| **`android_release_internet` 재정의** | **없음 — 위와 동일. 릴리스 체크리스트 항목이다** | `release_readiness.ps1 -Strict` 수동 실행 |
| ATT 미사용 | `android_manifest_permission_test.dart:'the iOS Info.plist declares no tracking usage description'` | iOS 실기기(별도 필요 — **ATT는 Android에서 테스트 불가**) |
| Dart 라이선스 | `tool\license_audit.ps1` **실제 실행**(`check.ps1:23`) | `reports\release\dependency-licenses.json` 검토 — **ATTRIBUTIONS 표를 여기서 생성한다** |
| 네이티브 라이선스 | `license_audit.ps1`의 `docs\native-ad-sdk-licenses.json` **존재·키 검사** — **감사가 아니라 증서다** | **`./gradlew :app:dependencies --configuration releaseRuntimeClasspath` + `Podfile.lock`을 사람이 열거해 JSON에 기록한다. 자동화 없음** |
| 플레이북 준수 | `design_playbook_compliance_test.dart` **9개** 규칙 | **SDK가 렌더한 광고 픽셀은 자동 검사 밖이다. 실기기 스크린샷으로 6개 테마 육안 대조** |
| 튜너 골든 불변 | `precision_tuner_golden_test.dart` | **이것은 배치 계약의 게이트가 아니다**(§7.11). 광고 스택이 튜너 레이아웃에 중립임만 확인 |
| 화면 문자열 정합성 | `song_search_screen_test.dart:'the song search status bar scopes the offline claim to the catalog'` | 릴리스 담당자가 광고 화면의 모든 문자열을 광고 존재 사실과 대조 |
| 방침 산문 정합성 | **없음 — `release_readiness.ps1`은 프론트매터만 읽고, 그마저도 CI에서 실행되지 않는다** | 릴리스 담당자가 `privacy-policy.md`, `play-data-safety.md`를 업로드 빌드와 대조해 읽는다 |
| **Play Data Safety 정확성** | **없음** | **Google GMA Play 공시 페이지를 구현 시점에 직접 읽고 매핑한다. 오신고는 앱 삭제로 집행된다** |
| **Apple App Privacy Details** | **없음** | App Store Connect 영양성분표 + privacy manifest 확인(§7.9) |
| PIPA 준수 | **없음** | **국내 변호사 검토. C16을 차단한다. 웹 검색으로 대체하지 않는다** |
| 킬 스위치 | **없음 — AdMob 콘솔은 저장소 밖이다** | 광고 단위 일시중지 후 실기기에서 슬롯이 높이 0으로 사라지는지 확인 |

---

## 미해결 질문과 사용자 결정

에이전트가 추측해 채우지 않는다.

1. **광고를 실을 것인가.** 이 계약은 환경을 만들 뿐이며 그 자체가 권고가 아니다. 사용자 브리프의 전제("튜너는 30초 유틸리티")를 적용하면 노출량은 매우 낮다. **검증 필요 — 신뢰할 만한 국내 eCPM 데이터를 찾지 못했다.** 발견한 수치는 전부 게임 가중이고 패널이 비공개이며 두 출처가 동일 제목의 콘텐츠 팜이었다. **이 숫자들로 만든 수익 모델은 허구다.** 신뢰할 수치는 실제 출시 후 본인의 AdMob 콘솔에서만 나온다.
2. **WebView 엔진을 받아들일 것인가.** `google_mobile_ads` 9.0.0은 `meta ^1.16.0`, `webview_flutter ^4.10.0`, `webview_flutter_android ^4.10.9`, `webview_flutter_wkwebview ^3.23.4`를 직접 끌고 오며, **후자 둘이 `webview_flutter_platform_interface`와 `plugin_platform_interface`를 추가로 끌고 온다.** 현재 pub 의존성은 2개(+로컬 4개)다. **실제 배수는 C13에서 `dependency-licenses.json`으로 확인한다 — rev.1의 "대략 3배"는 과소평가다.** 100% 오프라인 튜너에 완전한 WebView 엔진을 넣는 것은 "패키지 하나 추가"가 아니다.
3. **Play 타깃 대상: 16-17+18+ 인가, 18+ 단독인가.** **13-15는 선택지가 아니다**(§6.5). 기타 튜너 + 2,000곡 카탈로그는 혼합 오디언스로 플래그될 개연성이 있다. 재분류되면 자체 인증 SDK가 필요한데 **프로그램은 닫혀 있고, 혼합 오디언스에는 적합한 구성이 존재하지 않는다.** 엔지니어링으로 우회 불가능한 정지 지점이다.
4. **인터스티셜 쿨다운 기본값.** 24시간 1회? 6시간 1회? 아예 인터스티셜 없이 배너만? **§4.4의 (a) 선택지(완료 신호 없이 항상 발화)가 성립하려면 24시간이 안전한 기본값이다.**
5. **어느 슬롯까지 켤 것인가.** **C19(Slot A)만으로 멈추는 것이 유효한 종료 상태다.** C20/C22는 선택이다.
6. **AdMob 계정 개설 주체와 사업자 등록·세무.** 부가세 **영세율 신고 의무**(납부세액 0이어도 신고)를 포함해 세무사 확인.
7. **`app-ads.txt`용 도메인.**
8. **iOS 빌드 환경.** `C:\toauner\app\ios\`에 **Podfile이 없다** — 한 번도 CocoaPods 통합된 적이 없다. C13이 최초 pod install을 강제한다. `IPHONEOS_DEPLOYMENT_TARGET = 13.0`이고 GMA iOS 13.3.0의 최소는 정확히 iOS 13.0 / Xcode 16.0 — **여유가 0이며 GMA가 한 번만 올라가도 깨진다.** 이 중 어느 것도 win32 개발 박스에서 검증 불가능하다. **누가, 어느 머신에서 확인하는가.**
9. **국내 변호사 검토 착수 여부.** **C16을 차단한다.** 제3자 제공(제17조, 별도 동의) vs 처리위탁(제26조)의 판정이 동의 게이트 아키텍처를 좌우한다(§6.4).
10. **`check.ps1`에 `release_readiness.ps1 -Strict` 실제 실행을 추가할 것인가.** 별도 결정·별도 커밋이며, 현재 숨어 있는 blocker(`privacy_policy`·`play_data_safety` 프론트매터 `TBD`)를 드러낸다. **추가하지 않으면 §2.4의 게이트 재정의는 릴리스 체크리스트 항목이지 CI 게이트가 아니다.** 이 문서는 그것을 CI 게이트인 척하지 않는다.
11. **검증 필요 — Flutter Next-Gen SDK 지원 시점.** 레거시 Android GMA v25.x는 2027-06-30 지원 중단, **2028-06-30 완전 종료**이며 종료 시 자동 no-fill로 광고가 서빙되지 않을 위험이 있다. 플러그인 9.0.0은 내부적으로 Next-Gen 1.1.0을 번들하지만 **Dart API 표면은 여전히 레거시 형태**다. Flutter Next-Gen 지원 확정 날짜를 1차 출처에서 확인하지 못했다. Google의 Flutter deprecation 표는 pub.dev가 9.0.0을 배포하는데도 6.x.x를 최신으로 표시하는 **낡은 문서다. 이 표를 기준으로 계획하지 않는다.**
12. **검증 필요 — 여기 적힌 모든 버전 번호는 계획 시점(2026-07-15) 기준이다.** 빌드 시점에 pub.dev와 공식 릴리스 노트에서 다시 확인한다. `google_mobile_ads` 9.0.0은 Flutter `>=3.38.1`, Dart `>=3.10.0 <4.0.0`, Android **minSdk 23** / **compileSdk ≥ 34**, iOS **13.0** / Xcode **16.0**을 요구한다. 설치된 **Flutter 3.44.6 / Dart 3.12.2**는 둘 다 만족하고, Flutter 3.44의 기본값은 `minSdkVersion = 24`(≥23 ✓) / `compileSdkVersion = 36`(≥34 ✓)이며 `C:\toauner\app\android\app\build.gradle.kts`가 `flutter.minSdkVersion` / `flutter.compileSdkVersion`을 쓰므로 **이 제약은 충족된다** — 그래도 C13 이전에 재확인한다.
13. **검증 필요 — AdMob 콘솔의 광고 단위 일시중지 반영 시간**(§10 3층).
14. **검증 필요 — 국내 개인 게시자의 AdMob 세무 서식.** 미국 원천징수 서식이 애초에 해당하지 않을 수 있다(Google APAC 법인 경유). 서식 이름을 미리 지목하지 않는다.

---

## 완료 체크리스트

- [ ] Phase 0 표의 결정 항목이 전부 `TBD`가 아니다. **Play 타깃 대상이 13-15가 아니다.**
- [ ] `C:\toauner\app\test\ad_placement_compliance_test.dart`가 존재하고, `_adVendorFiles.length == 1`, `_adPlacementFiles.length == 2`, `_adWiringFiles.length == 2`를 단언하며, 스캔 범위가 `app\lib` **빼기** `app\lib\src\ads\**`다.
- [ ] 금지 라이브러리 목록에 `app\lib\src\tuner\**`, `app\lib\src\stability\**`, **`app\lib\src\metronome\**`**, `app\lib\src\songs\song_search_screen.dart`가 전부 있다.
- [ ] `C:\toauner\app\lib\src\songs\song_search_body.dart`가 존재하고 `_buildTuningHome`을 담지 **않는다**(C-R).
- [ ] `C:\toauner\app\test\offline_integrity_test.dart`에 `'the first frame renders before consent info is requested'`가 있다.
- [ ] `C:\toauner\app\test\ad_surface_test.dart`가 로드 실패 시 높이 0과 **라우트 push 시 핸들 해체**를 단언한다.
- [ ] **`git check-ignore -v docs/native-ad-sdk-licenses.json`이 아무것도 반환하지 않는다**(추적 가능 경로임을 확인). `reports/`에 두지 않았다.
- [ ] `C:\toauner\docs\native-ad-sdk-licenses.json`이 존재하고 모든 항목이 `artifact` / `license` / `termsUrl`을 가지며, **`./gradlew :app:dependencies --configuration releaseRuntimeClasspath`와 `Podfile.lock`의 실제 출력으로부터 채워졌다**(기억이 아니라).
- [ ] `C:\toauner\app\android\app\src\main\AndroidManifest.xml`에 **`xmlns:tools` 바인딩**, `AD_ID` `tools:node="remove"`, **`com.google.android.gms.ads.APPLICATION_ID` meta-data**가 있다.
- [ ] `C:\toauner\app\ios\Runner\Info.plist`에 **`GADApplicationIdentifier`**가 있고 `NSUserTrackingUsageDescription`은 **없다**.
- [ ] `C:\toauner\app\ios\Podfile`이 존재하고 `pod install`이 성공했다.
- [ ] **C13 직후 삼성 실기기에서 콜드 런치가 크래시 없이 성공했다**(`MobileAdsInitProvider`).
- [ ] `tool\license_audit.ps1` 실제 실행이 통과하고, **`ATTRIBUTIONS.md`의 전이 의존성 표가 `reports\release\dependency-licenses.json` 출력으로부터 생성됐다**(손으로 열거하지 않았다).
- [ ] `C:\toauner\docs\design-playbook.md`에 광고 토큰이 6개 테마 전부에 정의됐고, **영구 경계 allowlist가 `:149`의 마이그레이션 allowlist와 별개 범주로 기술됐다**.
- [ ] **`C:\toauner\docs\ui-plan.md`에 광고 슬롯의 우선순위 위치가 기술됐고 어느 것도 P0가 아니다**(`AGENTS.md:49`).
- [ ] `C:\toauner\docs\privacy-policy.md:26`의 `광고 및 사용 분석 SDK도 포함하지 않습니다`가 제거됐고, **행태정보 섹션(수집 주체·항목·목적·보유기간)과 거부 방법이 신설됐다**(2025-04-21 작성지침).
- [ ] `C:\toauner\docs\play-data-safety.md`에서 **기기 또는 기타 ID = 예/예**(app set ID), **위치 → 대략적인 위치 행이 추가**됐고, **삭제 요청 질문에 답했으며**, `곡 검색어 | 기기 밖 전송: 없음`은 **참으로 남아 있다**.
- [ ] **Apple App Privacy Details가 §7.2와 같은 카테고리로 선언됐고, privacy manifest / required-reason API가 확인됐다**(가정하지 않았다).
- [ ] `C:\toauner\docs\ATTRIBUTIONS.md`에 `## Advertising SDK`가 있고 네이티브 바이너리가 **독점(proprietary)**으로 명시됐다.
- [ ] `song_search_body.dart`의 상태 라벨이 `오프라인`이 아니라 **`곡 DB 오프라인`**이다.
- [ ] **`app\lib\src\tuner\` 아래 어떤 파일도 이 계약에서 변경되지 않았다**(C11 삭제).
- [ ] `C:\toauner\app\test\precision_tuner_golden_test.dart`의 골든이 바뀌지 않았다. **단, 이것을 배치 계약의 게이트로 주장하지 않았다.**
- [ ] 삼성 실기기에서 비행기 모드 6현 완료를 촬영해 광고 도입 전 영상과 대조했다.
- [ ] **삼성 실기기에서 6현 완료 → 라우트 복귀 → 인터스티셜 순서를 촬영해, 전면 광고가 튜닝 화면을 덮지 않음을 확인했다**(자동 검사 불가).
- [ ] **AdMob 콘솔에서 각 배너 단위의 자동 새로고침이 꺼져 있다**(§2.6).
- [ ] AdMob 콘솔에서 광고 단위를 일시중지한 뒤 실기기에서 슬롯이 사라지는 것을 확인했다(킬 스위치 리허설).
- [ ] **국내 변호사 검토 결과가 §6.4·§6.5에 반영됐고, C16 이전에 완료됐다.**