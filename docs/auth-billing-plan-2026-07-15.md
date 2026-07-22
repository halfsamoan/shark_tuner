---
release_status: draft
doc_owner: TBD
last_reviewed: 2026-07-15
---

# 로그인 · 결제 아키텍처 계약 — 2026-07-15

이 문서는 SharkTune의 인증·결제·권한(entitlement) 구현 계약이다. `C:\toauner\AGENTS.md`가 최상위이며, UI는 `C:\toauner\docs\design-playbook.md`와 `C:\toauner\docs\ui-plan.md`를, 릴리스 게이트는 `C:\toauner\docs\release-readiness.md`를 따른다. 권한 상태의 정의·수명·오프라인 규칙은 이 문서가 코드측 단일 기준이다. 사용자 명시 결정이 이 문서보다 우선한다.

이 문서는 계획서다. 구현 코드는 포함하지 않으며, 등장하는 시그니처는 이름을 고정하기 위한 예시다. 실행 주체는 이 대화의 기억이 없는 에이전트라고 가정하고, 모든 경로는 절대 경로로 적는다.

전제(이미 결정된 사항, 재논의하지 않는다): 튜너는 30초 유틸리티이고 수익화 자산은 2,000곡 카탈로그·BPM·연습 루프·악기 관리 이력이다. 튜닝 정확도는 절대 유료화하지 않는다. 튜닝 화면에는 광고를 넣지 않는다.

## 범위와 경계

- 이 문서는 무엇을 유료로 팔 것인지, 그 권한을 어떻게 표현·저장·판정할 것인지, 그리고 로그인이 필요한 시점이 언제인지를 정한다.
- 이 문서는 가격을 확정하지 않는다. §4.6의 모든 금액은 **검증 필요**이며 사용자 결정 대상이다.
- 이 문서는 광고를 다루지 않는다. 광고 SDK는 이 계획의 범위 밖이며, §10 `하지 말 것`의 금지 항목으로만 등장한다.
- 이 문서는 서버를 구축하지 않는다. §6은 서버를 **연기하는 방법**의 명세이고, 서버가 불가피해지는 정확한 조건만 정의한다.
- 검증되지 않은 사실은 `[검증 필요]`로 표기한다. 이 표기는 후속 문서·커밋 메시지로 그대로 전달한다. `[검증 필요]` 항목을 근거로 아키텍처를 확정하지 않는다. **버전·라이선스·정책 수치는 이 저장소 안에서 확인할 수 없으므로 원칙적으로 전부 `[검증 필요]`다.** 확인 절차는 §4.5에 있다.

---

## 0. 이 개정판이 뒤집은 것 (이전 초안을 읽은 사람만 볼 것)

| 항목 | 이전 초안 | 이번 판 | 근거 |
| --- | --- | --- | --- |
| v1 상품 구성 | 월간·연간·평생 동시 출시 | **평생(비소모성) 단독 출시.** 구독은 §4.3의 조건이 풀릴 때까지 연기 | `in_app_purchase`의 `PurchaseDetails`에 만료 시각이 없다 (§2.5) |
| 업셀 위치 | `_TuneCompleteSheet` 안의 조용한 행 | **튜닝 화면 전체에서 제거.** 곡 상세·설정으로 이동 | 그 시트는 `isDismissible: false, enableDrag: false`다 (§3.3) |
| 권한 상태 기계 위치 | `packages/tuner_domain/` | **`app/lib/src/entitlement/`** | `AGENTS.md:14`는 tuner_domain을 *내용*으로 정의한다 (§2.3) |
| 60일 유예의 근거 | "Play보다 엄격하면 안 되므로" | **의도적으로 Play보다 관대한 제품 결정** | account hold 구간에서 Play는 권한을 박탈한다 (§2.6) |
| 커밋 11 (`license_audit` 허용) | 존재 | **삭제** | `license_audit.ps1`에 허용 목록이 없다 (§9) |
| 골든 재생성 | 업셀 행이 골든을 무효화 | **무효화하지 않는다.** 골든은 완료 시트를 렌더하지 않는다 | `_GoldenTunerEngine.states => const Stream.empty()` (§7.6) |
| 통신판매업 신고 | 첫 유료 릴리스의 차단 항목 | **면제 가능성이 높다.** 차단 항목은 사업자등록(BRN) | 전자상거래법 제12조 제1항 단서 (§7.5) |

---

## 1. Phase 0 — 이 앱에 로그인이 필요한가

### 1.1 결론

**필요하지 않다. v1은 로그인 없이 출시한다.** 게스트 우선(guest-first)이 기본값이고, 로그인은 기능이 아니라 §1.3의 트리거가 실제로 발생했을 때만 도입하는 부채다.

### 1.2 근거

- Apple App Store Review Guideline **5.1.1(v)**: *"If your app doesn't include significant account-based features, let people use it without a login."* 기타 튜너에는 significant account-based features가 없다. **로그인 강제 자체가 리젝 사유가 된다.**
- Guideline **4.8**은 서드파티 소셜 로그인을 주 계정 수단으로 제공하는 순간 발동한다. 로그인이 없으면 4.8도, Sign in with Apple 의무도, 인앱 계정 삭제 의무(5.1.1(v))도 발생하지 않는다.
- 개인정보보호법 제22조의2(아동의 개인정보 보호) 노출은 수집을 시작해야 발생한다. 이메일·프로필을 수집하지 않으면 만14세 미만 법정대리인 동의 문제가 발생하지 않는다. §7.4 참조.
- 스토어 영수증 기반 복원(Play 계정 / Apple ID)이 이미 존재한다. 기기 교체 시나리오는 **앱 계정 없이** 스토어 계정이 해결한다. Apple Guideline 3.1.1은 한 걸음 더 나아가 복원 메커니즘을 **요구**한다 — §2.7의 평생 권한 절대 규칙은 제품 원칙이자 스토어 의무다.
- 동기화 대상 데이터의 실제 크기는 킬로바이트 단위 JSON이다. §1.4 참조. 이 페이로드는 서버·계정·PIPA 노출을 정당화하지 못한다.
- `C:\toauner\app\pubspec.yaml`의 의존성은 `audioplayers`, `path_provider`, `flutter`, 그리고 4개 로컬 path 패키지가 전부다(확인됨). 로그인은 이 앱의 **첫 네트워크 스택·첫 서버·첫 회전 대상 비밀키**를 동시에 들여온다.

Apple 가이드라인 인용문은 이 저장소 밖의 문서다. 문구 변경 가능성이 있으므로 `[검증 필요 — developer.apple.com/app-store/review/guidelines/ 현행 원문 대조]`로 취급한다. 단 §1.1의 결론은 §1.4의 페이로드 표만으로도 독립적으로 성립하므로, 인용문이 바뀌어도 결론은 흔들리지 않는다.

### 1.3 로그인이 정당화되는 트리거 조건

아래 조건이 **관측된 사실로** 성립할 때만 로그인 도입을 재검토한다. 예상·희망은 트리거가 아니다.

| # | 트리거 | 측정 방법 | 상태 |
| --- | --- | --- | --- |
| T1 | 기기 간 동기화 요청이 지원 문의의 유의미한 비중을 차지한다 | 스토어 리뷰·문의 채널의 실제 카운트 | 미발생 |
| T2 | 연습 이력(`tuning_history`, `string_care`) 유실 신고가 반복 발생한다 | 문의 카운트 | 미발생 |
| T3 | 사용자가 **직접 만든** 데이터(셋리스트, 연습 루프 마크)가 재입력 불가능한 규모로 커진다 | 셋리스트 평균 항목 수 | 기능 미존재 |
| T4 | 웹/데스크톱 등 스토어 계정으로 복원 불가능한 플랫폼이 생긴다 | 제품 결정 | 미발생 |
| T5 | 스토어 영수증으로 복원 불가능한 결제 경로(웹 결제 등)가 생긴다 | 제품 결정 | 미발생 |

**T1~T5 중 어느 것도 성립하지 않으면 로그인을 만들지 않는다.** T1·T2만 성립하는 경우의 정답은 로그인이 아니라 §6.2의 내보내기/가져오기다.

### 1.4 동기화 가치 평가 (로그인 없이 잃는 것)

| 데이터 | 코드 위치 | 동기화 가치 | 판정 |
| --- | --- | --- | --- |
| 곡 즐겨찾기 / 셋리스트 / 연습 루프 마크 | 미구현 (Pro 대상) | 높음 | 내보내기/가져오기로 충분 |
| 줄 교체 이력 | `C:\toauner\app\lib\src\string_care\` | 높음 | 내보내기/가져오기로 충분 |
| 악기 프로필 | `C:\toauner\app\lib\src\instrument_setup\` | 중상 | 내보내기/가져오기로 충분 |
| 튜닝 이력 | `C:\toauner\app\lib\src\tuning_history\` | 낮음 | 기기별 보관이 오히려 정확하다 |
| 테마·톨러런스·햅틱 | `C:\toauner\app\lib\src\app\app_preferences.dart` | 낮음 | 재입력 비용 무시 가능 |
| 2,000곡 카탈로그 | `C:\toauner\packages\tuner_data\` | 없음 | 앱에 동봉된 자사 데이터다 |
| **구매 권한** | 신규 | 높음 | **스토어 영수증이 이미 해결한다** |

합계 페이로드는 킬로바이트다. 이 표가 §1.1 결론의 실질적 근거다.

---

## 2. 권한 모델 — 단일 기준

### 2.1 원칙

**권한 만료는 절대로 "네트워크에 닿지 못함"에서 추론하지 않는다.** 증거의 부재는 만료의 증거가 아니다. 이 둘을 혼동하는 것이 오프라인 우선 앱 페이월의 유일하고 결정적인 버그다.

**시계는 둘이고, 하나가 아니다.**

- `expiresAt` — 스토어가 정한 구독 종료 시각. 오프라인에서 재계산하지 않는다. **v1에서는 항상 `null`이다** — §2.5를 반드시 읽을 것.
- `lastVerifiedAt` — **언제 재확인을 시도할지**만 결정한다. **절대로 권한을 박탈하지 않는다.**

### 2.2 세 값 상태 — `unknown`은 일급 상태다

권한에는 preferences가 의도적으로 모델링하지 않는 세 번째 상태가 필요하다.

| 상태 | 의미 | 게이팅 | 카피 | 디스크 |
| --- | --- | --- | --- | --- |
| `pro` | 유효한 부여 기록이 있다 | Pro 해제 | — | 유지 |
| `free` | **파일이 존재하고 읽혔으며** 부여 기록이 없다 | Pro 잠금 | 업셀 허용 | 유지 |
| `unknown` | 파일을 읽지 못했다 (primary·`.bak` 모두 실패) | Pro 잠금 | **업셀 금지. `만료`·`무료` 금지. `구매 확인 중` + 복원 버튼만** | **절대 덮어쓰지 않는다** |

`unknown`의 두 규칙이 이 절의 전부다.

1. **`unknown`은 절대 디스크에 `free`로 기록되지 않는다.** 읽기 실패 후 새 `free` 레코드를 쓰면 손상된 파일 위에 권한 박탈을 영구화한다. `unknown`에서는 쓰기 자체를 하지 않는다. 스토어 복원이 성공해 `pro`를 얻거나, 사용자가 명시적으로 "새로 시작"을 누를 때만 쓴다.
2. **`unknown`은 fail-open 하지 않는다.** 파일을 지우면 Pro가 되는 설계는 안 된다. `unknown`은 `free`와 동일하게 잠그되 **카피와 쓰기 동작만 다르다.**

### 2.3 배치 — `tuner_domain`이 아니라 `app/lib/src/entitlement/`

순수 Dart 판정기는 `C:\toauner\app\lib\src\entitlement\entitlement_resolver.dart`에 둔다. Flutter를 import하지 않으며, 그 사실은 §8.2의 테스트가 강제한다. 저장소는 `C:\toauner\app\lib\src\entitlement\entitlement_store.dart`에 둔다.

**`C:\toauner\packages\tuner_domain\`에 넣지 않는다.** `AGENTS.md:14`는 이 패키지를 *내용*으로 정의한다: "Flutter 의존성이 없는 **음정 매핑, 페그 방향, 장력 수학**". 결제 상태 기계는 그 셋 중 어느 것도 아니다. 확인됨: `C:\toauner\packages\tuner_domain\lib\tuner_domain.dart`는 `built_in_tunings, gauge_recommendation, peg_guidance, stability_diagnosis, string_tension, tuning_definition, tuning_session`만 export하고, pubspec description은 "Flutter-independent **tuning and instrument** domain models"다. Flutter 규칙은 여기서 위험 요소가 아니다 — `packages/tuner_domain/pubspec.yaml`의 `dependencies: {}`가 Flutter import를 애초에 해석 불가로 만든다(확인됨). 위험한 것은 패키지 정의를 조용히 넓히는 쪽이다.

`tuner_domain`에 넣고 싶다면 **커밋 1에서 `AGENTS.md:14`를 근거와 함께 개정**하라. 조용한 확장은 금지한다.

### 2.4 `app_preferences.dart`에 권한 필드를 추가하지 않는다

근거는 셋이며 전부 코드에서 확인된 사실이다. (이전 초안의 "스키마 게이트" 근거는 §2.4.4로 강등했다 — 사실이지만 자초할 수 있을 뿐 강제되지 않는다.)

1. **내구성 의미가 반대다.** `app_preferences.dart:127-141`의 `load()`는 primary → `.bak` → **안전 기본값**(`:140`의 `const AppPreferences()`) 순으로 폴백한다. 테마에는 옳다. 권한에는 "파일을 못 읽음 → 기본값"이 **유료 사용자의 권한을 조용히 박탈**한다는 뜻이다. §2.2의 `unknown`이 여기에 존재할 자리가 없다.
2. **쓰기 주기가 반대다.** `app_preferences.dart:216-220`의 `_replace()`는 모든 preference 변경마다 파일 전체를 다시 쓴다. `recordRecentSearch`(`:199`)도 포함된다. 권한이 검색어 입력마다 재기록된다.
3. **신뢰 경계가 다르다.** preferences는 `getApplicationSupportDirectory()`의 평문 JSON이며 사용자가 만지도록 초대된 파일이다. 권한 캐시는 사용자가 편집할 동기가 있는 적대적 입력이다.
4. **[부가 — 강제되지 않는 위험]** `app_preferences.dart:64`가 `const _schemaVersion = 1`이고 `:83-85`가 `if (document['schemaVersion'] != _schemaVersion) throw const FormatException(...)`이다. **어떤 필드든** 추가하면서 버전을 올리면 `!=` 비교 때문에 v2 바이너리가 디스크의 v1 파일을 거부하고, `:140`의 폴백이 사용자의 테마·톨러런스·햅틱·최근 검색을 전부 초기화한다. **다만 버전 상승이 강제되는 것은 아니다** — `decodeAppPreferences`는 이름 있는 키를 읽으므로 optional 필드를 관대하게 읽으면 v1을 유지할 수 있다. 즉 이 위험은 자초 가능한 것이지 구조적인 것이 아니다. 근거 1~3이 하중을 진다.

이 스키마 게이트는 권한과 무관한 **실재하는 잠재 결함**이다. 이 계획의 범위 밖이지만 `C:\toauner\docs\ui-plan.md`의 백로그에 기록한다 — 미래에 preferences 필드를 추가하는 사람이 전 사용자의 설정을 날린다.

**따라야 할 선례: `C:\toauner\app\lib\src\tuning_history\tuning_history_store.dart`.** `_fileName = 'tuning-history.v1.json'`(`:13`), typedef 묶음(`:8-11`), `_writeQueue` 직렬화(`:21`), `.tmp` → `.bak` → rename 원자 교체(`:53-73`), 모듈 레벨 기본 함수(`:85-94`). `entitlement.v1.json`을 쓰는 `JsonEntitlementStore`를 이 **쓰기 형태 그대로** 만들되 — **읽기 폴백은 반드시 뒤집는다.** `tuning_history_store.dart:36`은 primary·backup 모두 실패 시 `TuningHistoryLedger.empty()`를 반환한다. 이력에는 옳고 권한에는 §2.2를 정면으로 위반한다. **원자적 쓰기·큐·`.bak`는 복사하고, 읽기 실패 시 기본값 반환은 복사하지 않는다.**

### 2.5 v1에서 `expiresAt`은 항상 `null`이다 — 구독은 연기한다

**이것이 이 개정판의 가장 큰 변경이다.**

`in_app_purchase`(§4.3의 권고)가 클라이언트에 주는 `PurchaseDetails`에는 **만료 시각이 없다** `[검증 필요 — pub.dev의 in_app_purchase_platform_interface `PurchaseDetails` API 문서로 필드 목록 대조]`. 노출되는 것은 `purchaseID`, `productID`, `verificationData`, `transactionDate`, `status`, `error`, `pendingCompletePurchase`뿐이다. Play Billing의 `Purchase` 객체에도 `expiryTimeMillis`가 없다 — 그 값은 서버 전용 Play Developer API(`purchases.subscriptions`)에만 존재한다.

같은 이유로 `storeConfirmed == true` 또한 클라이언트에서 얻을 수 없다. BL8의 `queryPurchases`는 **활성 구매만** 반환하므로, 빈 결과는 "만료"와 "다른 Play 계정" / "Play 스토어 로그아웃" / "애초에 구매한 적 없음"을 구분하지 못한다. §2.1의 원칙 — 증거의 부재는 만료의 증거가 아니다 — 이 바로 이 API 형태를 설명한다. 이전 초안은 `queryPurchaseHistory`가 `in_app_purchase_android` 0.5.0에서 제거되었음을 정확히 지적하고도, 그 API가 있어야만 가능한 규칙을 표에 넣었다.

**따라서 §4.3(서버 없는 `in_app_purchase`)과 구독 SKU는 양립 불가능하다.** 셋 중 하나만 참일 수 있다.

| 선택 | 결과 |
| --- | --- |
| **(a) v1은 평생 전용** | `expiresAt == null`만 존재 → 오프라인 판정이 자명해진다. 네트워크 스택 0개 유지. **이 문서의 권고.** |
| (b) RevenueCat 채택 | `expiresAt`을 얻는다. 앱 최초의 네트워크 의존성. §4.2의 위험을 진다. |
| (c) Play Developer API 서버 구축 | `expiresAt`을 얻는다. §6.2의 S3 = 되돌릴 수 없다. |

`transactionDate` + 구독 주기로 클라이언트에서 만료를 역산하는 것은 §2.1이 금지하는 "오프라인 재계산"이며, grace·hold·pause·가격 변경 아래에서 **틀린다.** 금지한다.

이 사실은 §4.6의 "평생 티어는 v1에 반드시 포함한다"를 문서가 예상했던 것보다 훨씬 강하게 입증한다. 평생은 선호가 아니라 **§4.3 아래에서 유일하게 구현 가능한 SKU**다.

### 2.6 판정 규칙 (이 표가 단일 기준이다)

**전제 조건 — 모든 행보다 먼저 평가한다:**

```
effectiveNow = now.isBefore(record.highWaterNow) ? record.highWaterNow : now
```

아래 모든 행은 `now`가 아니라 `effectiveNow`로 판정한다. (이전 초안은 시계 되감기를 표의 마지막 행으로 두어, 위에서부터 읽으면 되감긴 시계가 `now <= expiresAt` 행에 먼저 걸려 `pro`를 반환했다. 자기 표에 자기 테스트 6이 실패했다.)

`offlineGraceDuration = Duration(days: 60)`.

| 조건 | 판정 | v1 도달 가능 |
| --- | --- | --- |
| `record == null` (읽기 실패) | `unknown` | 예 |
| `expiresAt == null` (평생) | `pro`. 조건 없이, 영구히. | **예 — v1의 유일한 pro 경로** |
| 부여 기록 없음 | `free` | 예 |
| `effectiveNow <= expiresAt` | `pro` | 아니오 (§2.5) |
| `storeConfirmed == true` 이고 `effectiveNow > expiresAt` | `free` | **아니오 — 클라이언트에서 `storeConfirmed`를 얻을 수 없다 (§2.5)** |
| `storeConfirmed == false` 이고 `effectiveNow <= expiresAt + 60일` | `pro` | 아니오 |
| `storeConfirmed == false` 이고 `effectiveNow > expiresAt + 60일` | `free` | 아니오 |

**"v1 도달 가능: 아니오" 행들은 죽은 코드가 아니라 예약된 계약이다.** 구독이 도입되는 순간(선택 b 또는 c) 발효한다. §8.2의 테스트가 지금 이 행들을 전부 검증하므로, 구독 도입 시 판정기를 새로 설계하지 않는다.

**`storeConfirmed`는 3-값으로 정의한다:** `confirmedActive` / `confirmedExpired` / `unobtainable`. **`in_app_purchase` + 서버 없음 아래에서는 `confirmedExpired`를 반환할 수 있는 Billing 응답 코드가 존재하지 않는다.** 어댑터는 절대 그 값을 만들지 않으며, §8.4의 테스트가 이를 고정한다. 이 값은 (b)/(c) 경로 전용이다.

**60일의 근거 — 이것은 의도적 제품 결정이지 스토어가 강제한 값이 아니다.**

이전 초안은 "Play의 grace + account hold가 60일이니 클라이언트가 Play보다 엄격해서는 안 된다"고 썼다. **인용은 정확했고 추론은 뒤집혀 있었다.** Play의 grace period 동안에는 권한이 유지되지만, **account hold 동안 Play는 권한 박탈을 지시한다** — "the user should not have subscription entitlement". 즉 Play의 60일은 *결제 복구* 창이고 그 대부분은 사용자가 권한을 **갖지 않아야 하는** 구간이다. 만료 후 60일을 `pro`로 주는 우리 규칙은 **Play보다 관대하다.** 이전 초안은 자기 근거를 오독했다.

규칙은 유지한다. 근거를 바꾼다: **합주실·무대는 구조적으로 RF 적대 환경이며, 그것이 이 앱의 최빈 사용 환경이다(§2.8). 스토어보다 관대한 쪽을 의도적으로 택하고 그 비용을 감수한다.** `check.ps1`이 "능동적으로 거짓말한다"고 지적하는 문서가 자기 산문에서 같은 짓을 하면 안 된다.

`[검증 필요]` — Play의 account hold 기본값 자동 계산(60일 − grace) 및 시행일은 이 저장소 밖의 정책이다. 구독 SKU를 실제로 도입할 때 support.google.com에서 재확인한다. **v1은 평생 전용이므로 이 값은 v1을 차단하지 않는다.**

### 2.7 절대 규칙

- **평생 결제(`expiresAt == null`)는 어떤 경우에도 박탈하지 않는다.** TTL 없음, 재검증 없음, 예외 없음. 비소모성 상품이므로 변할 수 있는 상태가 존재하지 않는다. Apple Guideline 3.1.1이 복원 메커니즘을 요구한다는 점에서 이것은 제품 원칙이자 스토어 의무다 `[검증 필요 — 3.1.1 현행 원문]`.
- **네트워크 실패는 캐시된 권한을 절대 변경하지 않는다.** 실패는 조용히 무시하고 다음 포그라운드에 다시 시도한다.
- **`unknown`은 `free`로 디스크에 기록되지 않는다.** §2.2.
- **재검증은 기회주의적으로만 한다.** 스피너 금지, 모달 금지, 게이트 금지. 라디오를 끈 상태에서 튜너가 사용 가능 상태에 도달해야 한다. 그것이 제품이다.
- **UI에서 "오프라인"·"확인 불가"와 "만료"를 구분한다.** 네트워크가 없을 뿐인데 `구독이 만료되었습니다`를 띄우지 않는다. 유료 고객 화면의 `만료`는 스스로 만든 지원 티켓이다.
- **무결성 손실을 수용한다.** 루팅 기기에서 사용자는 `entitlement.v1.json`을 편집할 수 있다. Play Integrity API는 서버 판정 기반이므로 서버 없는 앱에는 도움이 되지 않는다. **SharkTune을 좋게 만드는 오프라인 아키텍처를, 반올림 오차 수준의 불법 복제를 쫓느라 훼손하지 않는다.**
- **권한 확인이 오디오 경로에 닿지 않는다.** `AGENTS.md`상 연속 DSP는 UI 아이솔레이트에서 돌지 않는다. `_engineSubscription`이 `LiveTunerState` 프레임을 흘리는 동안 어떤 await도 끼어들지 않는다.

### 2.8 실패 시나리오 (설계 근거)

> 사용자가 삼성 기기에서 **평생** 상품을 산다. 설계대로 로그인은 하지 않는다. 신호가 없는 합주실에서 3주간 SharkTune을 쓴다. 4일째에 네트워크 기반 권한 캐시 TTL이 만료된다. **유료 고객이 지하 합주실에서 튜너를 못 쓴다.**

기타 앱에서 이것은 가설이 아니다. **사용자의 주요 사용 환경이 곧 네트워크 권한이 깨지는 환경이다.** 엣지 케이스가 아니라 최빈 케이스다. §2.6의 규칙은 이 시나리오를 통과시키기 위해 존재한다.

### 2.9 런타임 인터페이스 (이름 고정)

- `EntitlementTier`: `free`, `pro` — *부여된 것*
- `EntitlementStatus`: `unknown`, `free`, `pro` — *UI가 보는 것*. §2.2의 표가 유일한 정의다.
- `EntitlementSource`: `none`, `playStore`, `appStore`, `promo`
- `StoreConfirmation`: `confirmedActive`, `confirmedExpired`, `unobtainable` — §2.6
- `EntitlementRecord`: `tier`, `source`, `grantedAt`, `expiresAt`(`null`이면 평생), `lastVerifiedAt`, `highWaterNow`
- `EntitlementResolver`:
  - `EntitlementStatus resolve(EntitlementRecord? record, {required DateTime now, required StoreConfirmation confirmation})` — 순수 함수. `record == null` → `unknown`.
  - `EntitlementRecord advanceClock(EntitlementRecord record, DateTime now)` — `highWaterNow`를 전진시킨 **새 레코드를 반환한다.** 저장은 하지 않는다.
- `JsonEntitlementStore`: `entitlement.v1.json`, `.tmp` 원자 교체, `.bak` 복구, **읽기 실패 시 `null` 반환(기본값 금지)**
- `EntitlementController extends ChangeNotifier` / `EntitlementScope extends InheritedNotifier<EntitlementController>` / `extension EntitlementContext on BuildContext { EntitlementController get entitlement }`

**`highWaterNow`의 소유자와 주기를 여기서 못 박는다.** `resolve()`는 순수 함수이므로 되감기 방어를 스스로 영구화할 수 없다. `EntitlementController`가 `advanceClock()`을 호출하고 그 결과를 **다음 두 시점에만** 저장한다.

1. 앱 포그라운드 진입 (`didChangeAppLifecycleState` → `resumed`)
2. 앱 백그라운드 전환 flush (`paused`)

**그 외 어떤 시점에도 쓰지 않는다.** 특히 `resolve()` 호출마다 쓰지 않는다 — 그것이 §2.4 근거 2가 `app_preferences`를 기각한 바로 그 결함이다. §8.3의 테스트 `high water mark advances at most once per foreground`가 이를 고정한다.

주입 지점은 `C:\toauner\app\lib\src\app\toauner_app.dart:99-101`의 기존 스코프 **안쪽**이다.

```
AppPreferencesScope(
  controller: _preferencesController,
  child: EntitlementScope(          // 여기
    controller: _entitlementController,
    child: MaterialApp(...)))
```

안쪽에 두는 이유: `toauner_app.dart:83-85`의 `AnimatedBuilder(animation: _preferencesController)`가 이미 `MaterialApp` 전체를 다시 그린다. `InheritedNotifier`는 `dependOnInheritedWidgetOfExactType` 소비자만 다시 그리므로 권한 변경 시 튜너 전체 리빌드를 피한다.

테스트 주입 이음매는 이미 존재한다. `toauner_app.dart:22`의 `initialPreferences`, `:35`의 `preferencesController`, `:58-64`의 `_ownsPreferencesController` 패턴을 그대로 복제해 `initialEntitlement` / `entitlementController`를 만든다. **두 필드 모두 기본값을 가져야 한다.** 필수 파라미터로 만들면 `C:\toauner\app\test\widget_test.dart`의 **21개** `ToaunerApp(` 생성 지점이 전부 깨진다. 정확한 위치는 다음 명령으로 얻는다(줄 번호를 문서에 박지 않는다 — 이전 초안의 목록은 이미 어긋나 있었다):

```powershell
Select-String -Path C:\toauner\app\test\widget_test.dart -Pattern 'ToaunerApp\('
```

---

## 3. 페이월 표면 — 무료와 Pro의 경계

### 3.1 영원히 무료 (변경 불가)

| 표면 | 코드 위치 |
| --- | --- |
| 튜너 전체와 모든 정확도 | `C:\toauner\app\lib\src\tuner\` 전체, `C:\toauner\packages\tuner_dsp\` |
| 톨러런스 모드 (`beginner` / `pro`) | `TunerToleranceMode` — **이름이 `pro`일 뿐 결제와 무관하다** |
| 6개 테마 전부 | `C:\toauner\app\lib\src\app\instrument_theme.dart` |
| 곡 검색과 곡 상세 열람 | `C:\toauner\app\lib\src\songs\song_search_screen.dart`, `song_detail_screen.dart` |
| 기본 메트로놈 (탭 템포, 박자표, 곡별 BPM 자동 적용) | `C:\toauner\app\lib\src\metronome\` |
| 30초 안정성 검사 | `C:\toauner\app\lib\src\stability\` |
| 레퍼런스 톤 | `C:\toauner\packages\tuner_audio\` |
| 스테이지 모드 | `C:\toauner\docs\stage-mode.md` |

### 3.2 `TunerToleranceMode.pro` 이름 충돌 — 차단 항목이지 열린 질문이 아니다

**이 충돌은 미래형이 아니라 현재형이다.** 확인됨: `C:\toauner\app\lib\src\app\app_preferences.dart:13-16`이 `TunerToleranceMode.pro => '프로'`를 정의하고, `C:\toauner\app\lib\src\settings\app_preferences_screen.dart:60/66`이 `mode.label`을 그대로 렌더한다. **유료 Pro 티어가 존재하는 순간, 앱의 *정확도* 설정이 설정 화면에서 '프로'라고 읽힌다.** 코드 변경 없이 "정확도를 유료화했다"는 오해가 자동 생성된다. 그 오해 하나가 §10의 첫 번째 규칙을 무력화한다.

**따라서 이것은 §12의 열린 질문이 아니라 Phase D의 선행 커밋이다(커밋 5).** 톨러런스 라벨을 `정밀`로 바꾸고(사용자가 다른 단어를 지정하면 그것을 쓴다), 결제 등급만 `Pro`로 부른다. 사용자 표기 결정을 기다리는 동안에도 **기본값 `정밀`로 커밋 5를 먼저 랜딩한다** — 현재 상태('프로')가 더 나쁘고, 라벨 변경은 독립적으로 되돌릴 수 있다.

### 3.3 업셀 트리거 지점 — 튜닝 화면에서 완전히 제거한다

**이전 초안은 `_TuneCompleteSheet` 안의 "조용한 행"을 제안했다. 그것은 틀렸다.**

확인됨: `C:\toauner\app\lib\src\tuner\precision_tuner_screen.dart`의 `_showCompletion()`이 그 시트를 **`isDismissible: false, enableDrag: false`**로 띄운다. 탭 아웃도, 드래그 다운도 없다. 유일한 탈출구는 `precision_tuner_panels.dart:384-401`의 두 버튼(`'완료'` / `'30초 안정성 검사'`)이다. **탈출하려면 반드시 개입해야 하는 모달 안의 수익화 프롬프트는, 픽셀 높이와 무관하게 기능적으로 인터스티셜이다.** 이전 초안은 앱에서 가장 차단적인 표면을 고르고서 조용한 표면을 골랐다고 믿었다. 그리고 그 표면은 §10이 성역으로 선언한 30초 보상 순간이다. §3.3이 §10을 위반했다.

**두 번째 결함:** 이전 초안은 `_completionShown` 가드가 "튜닝 1회당 정확히 한 번"을 보장한다고 썼다. 확인됨: `_completionShown`은 `.whenComplete()` 안에서 `false`로 **리셋된다.** 시트는 화면 수명 내내 매 완료마다 재무장한다(대비: `_historyRecorded`는 리셋되지 않아 실제로 화면당 1회다). 락 → 닫기 → 드리프트 → 재락 하는 사용자는 다시 본다. §3.3의 "멱등" 주장은 거짓이었다. 탈출 불가 모달 + 무제한 재무장 = 별 1개 생성기.

**결정: 업셀은 `C:\toauner\app\lib\src\tuner\`의 네 파일 어디에도 들어가지 않는다.** 튜닝 화면은 권한을 읽지 않고, Pro를 언급하지 않고, 업셀을 렌더하지 않는다. §8.3의 테스트 15가 이것을 절대 규칙으로 고정하며 **예외 목록은 존재하지 않는다.**

**대신 업셀은 사용자가 스스로 연 화면에만 놓는다:**

| 표면 | 위치 | 이유 |
| --- | --- | --- |
| 곡 상세의 연습 루프 진입점 | `C:\toauner\app\lib\src\songs\song_detail_screen.dart` | 사용자가 곡을 열었다 = 연습 의도가 관측된 사실이다 |
| 설정 화면의 Pro 항목 | `C:\toauner\app\lib\src\settings\` | 사용자가 찾아왔다 |
| 다중 악기 등록 시도 (2대째) | `C:\toauner\app\lib\src\instrument_setup\` | 경계에 정확히 닿았을 때만 |

이 배치의 부수 효과 셋: (1) §10의 allowlist 금지 규칙과 충돌하지 않는다, (2) 테스트 15가 절대 규칙이 된다, (3) 골든 재생성이 불필요해진다(§7.6 참조 — 애초에 무효화되지도 않았다).

`_recordCompletion()`의 `try { await ... } on Object { }`(오류 전부 삼킴)와 그 주석 — "로컬 이력 쓰기가 라이브 튜닝 워크플로를 절대 막지 않는다" — 은 좋은 계약이다. **권한 관련 호출은 이 계약을 그대로 채택한다.**

### 3.4 Pro — 이미 존재하는 코드에 매핑

Pro는 새 기능을 발명하지 않는다. 이미 있는 자산을 조립한다.

| Pro 기능 | 기반 코드 (이미 존재) | 추가 필요분 |
| --- | --- | --- |
| **연습 루프** — 곡 구간 반복 + 속도 램프 | `C:\toauner\app\lib\src\metronome\song_bpm.dart`, `metronome_player.dart`, `C:\toauner\app\lib\src\songs\song_detail_screen.dart` | 구간 마크 저장, 루프 재생 |
| **셋리스트 / 즐겨찾기** | `C:\toauner\packages\tuner_data\lib\src\song_catalog.dart`의 `search()` / `getById()` | 로컬 셋리스트 저장소 |
| **다중 악기 관리** — 2대 이상 등록 | `C:\toauner\app\lib\src\instrument_setup\`, `string_care\`, `tension\` | 프로필 다중화. **무료는 1대까지.** |
| **연습 통계** — 누적 시간·튜닝 추이 | `C:\toauner\app\lib\src\tuning_history\tuning_history_store.dart` (`elapsed`, `tuningId`, `songId` 이미 기록) | 집계 뷰 |
| **이력 내보내기/가져오기** | `path_provider` + 공유 시트 | 서명된 JSON blob |

**BPM 위치 정정.** 이전 초안은 "`packages/tuner_data/lib/src/song_catalog.dart` (BPM 보유)"라고 썼다. 거짓이다. 확인됨: `song_catalog.dart`는 19줄짜리 추상 인터페이스이고 BPM 참조가 0건이며, `packages/tuner_data/lib/` 전체에 `bpm` 문자열이 없다. **BPM은 `C:\toauner\app\lib\src\metronome\song_bpm.dart`에 있고**, `rootBundle`로 `assets/songs/song_bpm.v1.json`을 읽는 **Flutter 결합 앱 코드**다.

이 정정에는 유료화 직전에 고쳐야 할 결함이 딸려 있다. `song_bpm.dart`의 `loadSongBpmIndex()`는 `on Object { _cache = <String, int>{}; }`로 **모든 실패를 빈 맵으로 삼킨다.** 유료 "연습 루프 + BPM 자동 적용"이 아무 신호 없이 BPM-없음으로 조용히 열화한다. **"BPM 미상"과 "BPM 인덱스 로드 실패"를 구분하는 테스트를 붙이기 전에 이 기능을 팔지 않는다.** 커밋 12의 전제 조건이다.

### 3.5 차단 항목 — 릴리스 카탈로그가 0곡일 수 있다

`C:\toauner\docs\ui-plan.md:27`의 **P0-6**: *"⚠️ 시드 20곡 전량 미검증 → 릴리스 검색 0건 — 출시 전 20곡 인간 검증이 최우선 데이터 작업."*

`AGENTS.md:49`는 UI 작업 전에 `design-playbook.md`**와 `ui-plan.md`**를 읽고 **P0 우선순위**를 구현 기준으로 삼으라고 요구한다. 이전 초안은 playbook을 15회 인용하고 ui-plan을 0회 인용했다. 그 결과 P0-6이 §3.4·§4.6의 수익 전제를 정면으로 무너뜨린다는 사실을 놓쳤다: **릴리스 카탈로그가 0곡이면 카탈로그 파생 Pro 티어(연습 루프·셋리스트)는 팔 것이 없다.**

**규칙: 검증된 곡이 0건인 상태로 카탈로그 파생 SKU를 출시하지 않는다.** §12의 차단 항목에 넣는다. 커밋 10은 `design-playbook.md`와 `ui-plan.md`를 **함께** 갱신한다.

### 3.6 이미 무료로 출시된 기능 — 회수하지 않는다

`de494c6 feat: surface a per-song metronome on song detail`이 이미 랜딩되었다. 곡별 BPM 자동 적용이 이미 무료로 존재한다.

**이미 무료로 배포된 기능을 Pro로 옮기는 것은 기존 사용자 입장에서 회수(clawback)다.** 신뢰 우선 브랜드에서 이 비용은 크다. **결정: 곡별 BPM 자동 적용은 계속 무료(§3.1)로 두고, 연습 루프(구간 반복·속도 램프)만 Pro로 한다.** grandfather 권한 부여는 서버 없이 "기존 설치"를 신뢰성 있게 식별할 수 없으므로 사실상 불가하다. 사용자가 뒤집을 수 있으나(§12), 기본값은 이것이다.

---

## 4. 결제

### 4.1 후보 비교

**아래 표의 모든 버전·날짜·라이선스·통계는 `[검증 필요]`다.** 이 저장소 안에서 확인할 수 없고 어시스턴트의 지식 시점 이후 값이다. **§4.5의 절차로 확인하기 전에는 이 표를 근거로 아무것도 고정하지 않으며, 특히 커밋 14의 `pubspec.yaml` 버전 핀은 확인 후에만 쓴다.** §10의 자기 규칙 — "라이선스를 확인 없이 기재하지 않는다" — 은 이 표에도 적용된다.

| | `in_app_purchase` | `purchases_flutter` (RevenueCat) |
| --- | --- | --- |
| 버전 `[검증 필요]` | 3.3.0 | 10.4.1 |
| **라이선스 `[검증 필요]`** | BSD-3-Clause — GPL 무관 | MIT — GPL 무관 |
| Android impl `[검증 필요]` | `in_app_purchase_android` 0.5.1 | `purchases-android` 10.12.0 |
| Play Billing Library `[검증 필요]` | 8.0.0 | 8.3.0 |
| 추가되는 네트워크 스택 | **없음** (Play 스토어 앱과 IPC) | **`api.revenuecat.com` — 앱 최초의 네트워크 의존성** |
| **구독 `expiresAt` 획득** | **불가 (§2.5)** | 가능 |
| 영수증 검증 | 직접 구현하거나 하지 않는다 | 포함 |
| 우리 규모의 비용 `[검증 필요]` | $0 | $0 (MTR 임계 미만) |
| 고유 위험 | BL 업그레이드 트레드밀을 직접 진다 | **대시보드 오설정이 무로그인 평생 결제를 영구 파괴** |

### 4.2 RevenueCat의 결정적 위험

`[검증 필요 — RevenueCat v10 마이그레이션 문서 원문 대조]` 로그인 시스템이 없는 앱에서 1회성 상품이 대시보드에 **consumable로 잘못 설정되면 RevenueCat이 그 구매를 소비(consume)해 버리고, v10.0.0부터 사용자는 복원할 수 없다.**

이것이 치명적인 이유: `in_app_purchase_android` 0.5.0이 `queryPurchaseHistory`를 제거했고, BL8이 소비된 1회성 상품 조회를 제거했다 `[검증 필요]`. **소비된 구매를 클라이언트에서 되찾을 방법이 존재하지 않는다.**

이 실패 모드는 **저장소 밖, `C:\toauner\tool\check.ps1` 밖, 계약 테스트 밖**의 웹 대시보드 설정 하나에 걸려 있다. 코드 리뷰 게이트도, 테스트 커버리지도 없다. **무로그인 평생 티어 — §2.5에 따라 v1의 유일한 SKU — 와 정면 충돌한다.**

또한 RevenueCat 문서가 캐시 수명에 대해 자기모순이라는 보고가 있다: 캐싱 페이지 "최대 3일", CustomerInfo 페이지 무언급, 커뮤니티 "영원히". `[검증 필요 — 셋 다 참일 수 없다. RevenueCat을 채택할 경우 설계 확정 전에 지원 티켓으로 확인한다.]` 3일과 영원은 "비행기에서 동작"과 "지하철에서 유료 고객 잠금"의 차이다. §2.8이 바로 이 시나리오다.

부수 효과: RevenueCat은 `C:\toauner\docs\privacy-policy.md`, `play-data-safety.md`, `ATTRIBUTIONS.md`를 즉시 부정확하게 만든다.

### 4.3 권고

**`in_app_purchase` + 앱이 소유하는 자체 권한 캐시. v1은 평생 SKU 단독.**

§2.5가 이 선택의 대가를 명확히 한다: **`in_app_purchase` + 서버 없음 = 구독을 팔 수 없다.** 이전 초안은 RevenueCat을 "엔지니어링 답으로는 더 낫다"고 표현했으나 그것은 과소평가였다 — RevenueCat은 **자체 서버 없이 `expiresAt`을 얻는 두 방법 중 하나**다. 대신 100% 오프라인이라는 앱의 정의적 속성을 깨고, 문서 3종을 부정확하게 만들고, `check.ps1` 밖에 §4.2의 실패 모드를 만든다.

**따라서 §12.4의 질문을 다시 쓴다. 이전 판의 "네트워크 요청을 하지 않는다는 것이 제품 약속인가, 구현 세부사항인가?"는 결정을 잘못 표현했다. 진짜 결정은 이것이다:**

> **평생 전용으로 진짜 오프라인을 유지할 것인가, 구독을 팔기 위해 네트워크 의존성을 받아들일 것인가?**

이 문서의 권고는 평생 전용이다. 근거: §4.6이 유틸리티의 구독 언더인덱스를 지적하고, 튜너는 30초 유틸리티이며(전제), 평생은 §7.5의 수수료 불확실성에 대한 헤지이고, `expiresAt == null`이 §2.6의 판정을 자명하게 만든다. **사용자만 이 질문에 답할 수 있다.**

### 4.4 대체 결제 / 원스토어 — 채택하지 않는다

**대체 결제(인앱결제 강제 금지법 경로)는 우리 규모에서 순손실이다.** 스토어 수수료 11% + PG 수수료 4~6% `[검증 필요]` = 15~17%로 Play Billing의 15%와 같거나 나쁘고, PCI DSS 인증·거래 보고 인프라·PG 계약·차지백 처리·첫 네트워크 스택을 추가해서 **돈을 잃는다.**

**원스토어는 v1에서 하지 않는다.** 구독 10% `[검증 필요]`는 매력적이나, 인용 가능한 점유율 수치는 전부 **게임** 수치이고 비게임 유틸리티 점유율은 `[검증 필요/불명]`이다. 대가는 두 번째 스토어 리스팅·릴리스 파이프라인·상품 카탈로그·권한 경로, **제품과 정면 충돌하는 강제 로그인 플로우**(원스토어 IAP는 로그인 기반) `[검증 필요]`, 미검증 업로더의 `flutter_onestore_inapp` `[검증 필요 — 버전·라이선스]`, 그리고 삼성 실기기 검증 매트릭스의 2배화다.

**한국 수수료 개편: 마진 개선을 모델에 넣지 않는다.** `[검증 필요]` 한국 결제 수수료 수치는 미발표이며, 방송통신위원회의 과징금 절차도 미결이고, Google이 한국 수수료 인하를 공개 언급한 바 있다. 셋 다 이 계획을 흔들 수 있고 셋 다 우리 통제 밖이다. **한국 마진은 15% 고정으로 모델링하고, 개선은 상방으로만 취급한다.** Q4 2026에 재확인한다.

**Apple Small Business Program에 즉시 등록한다.** 이전 초안은 "SBP의 실효는 1년차 차액 전부"라고 썼다. **틀렸다.** SBP는 **비소모성 1회성 구매를 포함한 모든 수익**에 적용되고 `[검증 필요 — developer.apple.com/app-store/small-business-program/]`, **평생 SKU에는 "2년차"가 없다.** SBP 없이는 평생 상품이 **영구히 30%**다. §4.6이 평생을 v1 필수로 선언하므로, **SBP의 가치 = 1년차 구독 차액 + 평생 SKU 전량에 대한 영구 15%p**이고 후자가 더 클 개연성이 높다. §12 차단 항목으로 유지하되 근거를 평생 SKU로 바꾼다.

**Apple 한국 서드파티 결제(26%, VAT 포함 총액 기준)는 절대 쓰지 않는다** `[검증 필요 — 수치]`.

### 4.5 커밋 14 이전에 반드시 수행할 검증 절차

**어떤 버전도 확인 없이 `pubspec.yaml`에 쓰지 않는다.** 순서대로 실행한다.

1. `cd C:\toauner\app; ..\.tools\flutter\bin\flutter.bat pub add in_app_purchase` 로 해석된 실제 버전을 확보한다. §4.1의 버전이 아니라 **해석된 버전을 문서에 기록한다.**
2. `cd C:\toauner; .\tool\bootstrap.ps1` 후 `.\tool\license_audit.ps1` 을 **수정하지 않은 상태로** 실행한다. `in_app_purchase`, `in_app_purchase_android`, `in_app_purchase_storekit` 및 전이 그래프가 통과해야 한다.
3. 각 패키지의 **최상위 LICENSE 파일을 직접 읽고** SPDX 식별자를 `C:\toauner\docs\ATTRIBUTIONS.md`에 기재한다. `license_audit.ps1`이 해시하는 것이 정확히 그 파일이다.
4. **`com.android.billingclient:billing`의 라이선스를 수동 확인한다.** `[검증 필요 — Android SDK License로 추정되나 확인되지 않았다.]` **`license_audit.ps1`은 이 질문에 답하지 않는다** — 확인됨: 이 스크립트는 `.dart_tool/package_config.json`의 Dart 패키지만 열고 Gradle/Maven AAR과 CocoaPods는 절대 열지 않는다. **통과 표시는 얇은 Dart 셰임을 측정한 것이지 SDK를 측정한 것이 아니다.**
5. **AGP 9 호환성을 확인한다.** `[검증 필요]` `C:\toauner\app\android\settings.gradle.kts:22-23`이 AGP/Kotlin을 고정하고 `gradle-wrapper.properties`가 Gradle을 고정한다. `in_app_purchase_android`가 AGP 9에서 빌드되는지 이전 초안은 검사하지 않았다. **커밋 14의 첫 작업은 릴리스 Gradle 빌드다.**
6. **iOS:** In-App Purchase capability를 Xcode 프로젝트/entitlements에 추가해야 한다 `[검증 필요]`. `in_app_purchase_storekit`이 iOS 최소 버전을 올릴 수 있다 `[검증 필요 — 현재 deployment target과 대조]`. `in_app_purchase`는 ATT를 요구하지 않는다 — 확인됨: `C:\toauner\app\ios\Runner\Info.plist`에 `NSUserTrackingUsageDescription`도 `SKAdNetworkItems`도 없고, 광고 SDK가 없으므로 추가할 필요도 없다.

`license_audit.ps1`의 GPL 패턴은 정확히 다음이다(이전 초안의 인용은 부정확했다):

```
'(?im)^\s*GNU\s+(AFFERO\s+|LESSER\s+|LIBRARY\s+)?GENERAL\s+PUBLIC\s+LICENSE\s*$'
'(?i)SPDX-License-Identifier\s*:\s*(AGPL|GPL|LGPL)-'
'(?i)\b(AGPL|GPL|LGPL)-[123](?:\.0)?(?:-only|-or-later)?\b'
```

`Get-LicenseFiles`는 최상위 `LICENSE|LICENCE|COPYING`만 읽고 **소스 주석은 절대 읽지 않는다.** 따라서 오탐 위험은 라이선스 파일 산문에 국한되며, 이전 초안이 시사한 것보다 좁다.

### 4.6 상품 구성

| 상품 | 유형 | v1 | 가격 `[검증 필요 — 사용자 결정]` |
| --- | --- | --- | --- |
| **Pro 평생 (1회 결제)** | **비소모성 1회성 상품** | **포함** | ₩39,000~49,000 |
| Pro 월간 | 자동 갱신 기본 요금제 | **연기 (§2.5)** | ₩4,900 |
| Pro 연간 | 자동 갱신 기본 요금제 | **연기 (§2.5)** | ₩29,000~39,000 |

₩4,900은 한국 소비자 디지털 구독의 관측 앵커라는 보고가 있다 `[검증 필요 — 2차 출처]`. **연간/평생 비율은 전혀 검증되지 않았다.** Play 가격 실험으로 확인한다.

**평생 티어는 v1의 유일한 SKU다.** 근거를 강한 순으로:
1. **§2.5 — `in_app_purchase` + 서버 없음 아래에서 구현 가능한 유일한 SKU다.** 나머지는 취향이다.
2. 튜너는 30초 유틸리티다(전제). 1회 결제가 정직한 적합이다.
3. 유틸리티가 순수 구독 모델에 언더인덱스한다는 보고가 있다 `[검증 필요 — RevenueCat State of Subscription Apps 2026, 유틸리티 컷]`.
4. 한국 수수료 불확실성(§4.4)에 대한 헤지다. 오늘 알려진 요율로 한 번만 수수료를 낸다.
5. `expiresAt == null` = 오프라인 판정이 완전히 자명해진다(§2.6). 무로그인 설계와 완벽히 정합한다.

**무료 체험: v1에서는 넣지 않는다. 그리고 이것은 취향 문제가 아니다 — §7.3을 읽을 것.** 이전 초안은 이를 "데이터가 답할 수 없는 전략 결정"이라 불렀다. **오분류다.** 전자상거래법 개정(**시행 2025-02-14**)이 **숨은 갱신**을 명시적으로 금지하고, 유료 전환 **30일 이내 사전 동의**를 강제한다 `[검증 필요 — 법률 제20302호 원문]`. 체험은 카피 결정이 아니라 **사전 동의 플로우라는 하드 빌드 요구사항을 수입한다.** 권고는 그대로 유지한다(체험 없음 + 넉넉한 무료 티어 + 평생 옵션), 근거만 바뀐다.

하드 페이월은 적용하지 않는다. 프리미엄 대비 리텐션 우위 보고가 있으나 `[검증 필요]`, 그 수치는 코어가 게이팅 가능한 앱에서 측정된 값이다. SharkTune의 코어는 게이팅 대상이 아니다.

---

## 5. 인증 — Phase 0이 정당화한 경우에만

**§1.1에 따라 v1에서는 구현하지 않는다.** 이 절은 T1~T5 트리거 발생 시 무엇을 사게 되는지를 정확히 기록해, 미래의 결정이 정보에 근거하도록 한다. **이 절의 모든 버전·라이선스·퍼블리셔·이슈 수는 `[검증 필요]`다.**

### 5.1 후보

| 패키지 | 버전 `[검증 필요]` | 라이선스 `[검증 필요]` | 퍼블리셔 `[검증 필요]` | 판정 |
| --- | --- | --- | --- | --- |
| `google_sign_in` | 7.2.0 | BSD-3-Clause | flutter.dev (1st party) | 건전 |
| `sign_in_with_apple` | 8.1.0 | MIT | 검증됨 | 건전 |
| `kakao_flutter_sdk` | 2.0.0+1 | Apache-2.0 | developers.kakao.com | 건전 |
| `flutter_naver_login` | 2.1.1 | BSD-2-Clause | **미검증 업로더** | **이 스택에서 가장 약한 의존성** |

라이선스가 전부 GPL 무관이라는 것은 **주장이지 확인이 아니다.** 채택 시 §4.5의 절차 3(LICENSE 파일 직접 읽기)을 반드시 수행한다.

`google_sign_in` 7.0.0은 파괴적 재설계라는 보고가 있다(싱글턴화, `initialize()` await 필수, 인증/인가 분리) `[검증 필요]`. `signIn()`을 await하는 튜토리얼은 전부 v7 이전이며 컴파일되지 않는다.

**네이버가 단일 하드 블로커다.** 1st party Flutter SDK가 존재하지 않는다 `[검증 필요]`. 미검증 업로더 + 장기 미출시 + 단독 메인테이너 커뮤니티 저장소에 한국 사용자 전체의 로그인을 건다. 검수(검수요청)는 약 1주 걸리고 거절이 흔하며, **검수 통과 전에는 개발자가 등록한 네이버 ID만 로그인된다** `[검증 필요]`.

### 5.2 Firebase Custom Token — 강제되는 정확한 백엔드

Firebase Auth 네이티브 제공자에 **카카오도 네이버도 없다** `[검증 필요 — firebase.google.com 현행 제공자 목록]`. 카카오/네이버를 붙이려면 Custom Token 경로가 강제된다.

1. 클라이언트가 네이티브 SDK로 카카오/네이버 액세스 토큰을 얻는다.
2. 클라이언트가 **당신의 서버**로 보낸다.
3. 서버가 제공자 userinfo 엔드포인트로 토큰을 검증한다. **타협 불가: 클라이언트가 준 제공자 토큰을 서버 검증 없이 신뢰하면 누구나 아무 신원이나 위조할 수 있다.**
4. 서버가 **Firebase Admin SDK**로 `createCustomToken(uid)`. 서비스 계정 키가 필요하다.
5. 클라이언트가 `signInWithCustomToken()`.

**강제되는 인프라 바닥** `[검증 필요 — Firebase 요금제 페이지]`: Cloud Functions는 Blaze(종량제)가 필수이고, Spark는 함수 배포 불가 + 비-Google 아웃바운드 차단(= 카카오/네이버 토큰 검증이 정확히 그것)으로 두 번 실격이다. Blaze는 신용카드 등록과 상한 없는 청구 계정을 요구한다.

**현실적 달러 바닥: 우리 규모에서 월 ~$0. 실제 비용은 돈이 아니다:** 청구 계정, 회전·보호해야 할 서비스 계정 키, 배포된 함수, 모니터링, 장애 표면, 그리고 **상한 없는 청구 계정 위의 DoS 가능한 공개 엔드포인트.**

**Firebase OIDC (Identity Platform) 경로는 기각한다.** 카카오는 진짜 OIDC 제공자이므로 서버 없이 붙일 수 있다 `[검증 필요]`. **하지만 가격이 함정이다: 표준 제공자는 50,000 MAU까지 무료지만 OIDC/SAML은 50 MAU까지만 무료이고 이후 MAU당 약 $0.015** `[검증 필요 — Google 가격 페이지에서 확인되지 않았다. 이 수치가 이 기각의 유일한 근거이므로, 이 경로를 재검토할 때 가장 먼저 확인한다.]` 네이버는 이 경로 자체가 불가능하다(OIDC 지원 여부 `[검증 필요]`).

**Supabase Auth는 주목할 발견이다** `[검증 필요]`. 카카오를 1급 제공자로 지원하며 Flutter 경로가 문서화되어 있다 — **서버 없이 카카오 로그인이 가능하다.** 네이버는 미구현이 유일한 블로커다.

**어떤 Firebase/Supabase/Auth0 구성도 자체 서버 없이 네이버 로그인을 주지 않는다.**

### 5.3 Apple Guideline 4.8 — iOS 하드 게이트

4.8 현행 원문은 **"Sign in with Apple"을 명시하지 않는다** `[검증 필요 — 현행 원문 대조]`. 기준 기반이다: 서드파티/소셜 로그인으로 주 계정을 설정·인증하는 앱은 다음 세 조건을 갖춘 **동등한 대체 로그인 서비스**를 함께 제공해야 한다.

- 데이터 수집을 이름과 이메일 주소로 제한한다
- 계정 설정 시 사용자가 이메일 주소를 비공개로 유지할 수 있다
- 동의 없이 광고 목적으로 앱 내 상호작용을 수집하지 않는다

면제 조항 중 "자사 계정 시스템만 **독점적으로** 사용" 면제는 카카오를 추가하는 순간 증발한다.

**엄밀히 읽으면 4.8은 Sign in with Apple을 강제하지 않는다. 그러나 실무적으로 유일한 선택지다** — 카카오와 네이버는 이메일 릴레이/비공개 이메일 기능이 없어 2번 조건을 만족할 수 없다.

`sign_in_with_apple`의 iOS 네이티브 플로우는 백엔드가 필요 없다. Android 지원은 Apple 콜백 `redirectUri`를 받아 앱으로 되돌릴 서버가 필요하지만, **4.8은 App Store 정책이므로 iOS 전용 SIWA로 준수된다.**

### 5.4 로그인이 즉시 상속하는 다섯 가지 의무

1. **Sign in with Apple** (4.8)
2. **인앱 계정 삭제** (5.1.1(v)) — 게다가 Play는 **웹 접근 가능한 삭제 URL**을 요구한다 `[검증 필요]`. 스토어 리스팅 의무이지 문서 수정이 아니다.
3. **PIPA 제22조의2 만14세 미만 법정대리인 동의** — §7.4.
4. **Play Data Safety 결론 블록 전체 반전** — §7.2.
5. **앱 최초의 네트워크 스택**

---

## 6. 백엔드 결정 — 최소 서버, 또는 완전 연기

### 6.1 결론

**서버를 만들지 않는다.** 아래 단계 경로는 각 단계가 이전 단계를 되돌리지 않고 다음 단계를 가능하게 한다.

### 6.2 단계 경로

| 단계 | 내용 | 서버 | 트리거 |
| --- | --- | --- | --- |
| **S0** (v1) | 로컬 우선 권한 + 스토어 영수증 복원 + **평생 SKU 단독** | 없음 | 즉시 |
| **S1** | 사용자 주도 **내보내기/가져오기** — `path_provider` + 공유 시트로 서명된 JSON blob | 없음 | T1 또는 T2 |
| **S2** | 카카오 단독 로그인 (Supabase 내장 제공자) | 없음 (Supabase 관리형) | T3 또는 T4 |
| **S3** | Firebase Custom Token + Cloud Functions (네이버 포함) / Play Developer API | **있음** | T5, 또는 구독 SKU가 사업상 필수임이 입증될 때 (§2.5의 선택 c) |

**S1이 대부분의 경우 정답이다.** 네트워크 스택 없음, PIPA 없음, 4.8 없음, 서버 없음 — 그리고 킬로바이트짜리 연습 데이터에서 **실제로 중요한 유일한 동기화 서사인 "폰을 바꿨다"를 해결한다.**

**S3는 되돌릴 수 없다.** 서비스 계정 키, 청구 계정, 공개 엔드포인트가 생기면 §7의 문서 전부가 영구적으로 바뀐다.

---

## 7. 컴플라이언스 캐스케이드

### 7.1 결제만 추가할 때 (v1, `in_app_purchase`)

`C:\toauner\docs\privacy-policy.md` (확인됨: `release_status: draft`, `developer_name`/`privacy_contact`/`public_url`/`effective_date` 전부 `TBD`):

| 줄 | 현재 문장 | v1 결제 후 |
| --- | --- | --- |
| `:26` | `…결제 정보를 수집하지 않습니다. 광고 및 사용 분석 SDK도 포함하지 않습니다.` | **결제 정보 부분만 재작성.** 앱은 결제 정보를 수집하지 않는다 — Play/App Store가 처리한다. 이 사실을 명시적으로 서술한다. 광고 SDK 문장은 **참으로 유지된다.** |
| `:30` | `현재 앱은 핵심 기능을 위해 인터넷 연결을 요구하지 않습니다.` | **참으로 유지된다.** 튜닝은 여전히 오프라인이다. "구매 및 복원 시 스토어 앱이 통신합니다"를 추가한다. |
| `:34` | `계정과 서버 저장 데이터가 없으므로 별도의 계정 삭제 절차는 없습니다.` | **참으로 유지된다.** 로그인이 없기 때문이다. |
| `:38` | `서버 전송이 없으므로 마이크 오디오의 네트워크 전송 경로도 없습니다.` | **참으로 유지된다.** |
| `:42` | 향후 클라우드 동기화·분석·광고 추가 시 배포 **전에** 방침과 인앱 고지를 갱신하고 동의를 받는다는 사전 약속 | 이 약속을 §7.2가 발동시킨다 |
| (신규) | — | **청약철회(§7.3)** 절을 추가한다 |

`C:\toauner\docs\play-data-safety.md` (확인됨: `release_status: draft`, 메타데이터 전부 TBD):

| 줄 | 현재 | v1 결제 후 |
| --- | --- | --- |
| `:14` | `사용자 데이터 수집: 아니요` | **`[검증 필요] — 이 칸은 미결이다. §12.12를 해소하기 전에 결론을 쓰지 않는다.** 아래 참조 |
| `:17` | `광고 또는 분석 SDK: 없음` | **참으로 유지된다** |
| `:18` | `핵심 기능의 서버 통신: 없음` | **참으로 유지된다** |
| `:31` | 곡 검색어가 기기를 떠나지 않음 | **참으로 유지된다** |

**`:14`에 대한 정직한 서술.** 이전 초안은 이 칸을 "참으로 유지된다"라고 쓰면서 동시에 `[미검증]`을 붙였다. **한 칸이 참인 동시에 미검증일 수는 없고, 미검증인 칸을 §4.3의 "실질적 근거"로 인용할 수는 없다.** 양쪽 주장을 기록한다.

- **반대:** Play 가이드는 인앱결제가 있는 앱이 **Financial info 아래 Purchase history 수집을 공개해야 한다**고 서술한다 `[검증 필요]`. 결제 서비스 면제는 결제 서비스가 *처리 과정에서* 수집하는 데이터를 덮는 것이지, 앱이 구매 상태를 받아 영구화하는 것을 덮지 않는다 — `entitlement.v1.json`이 정확히 그것이다.
- **찬성:** Data Safety의 "collection"은 **기기 밖 전송**을 뜻한다. 순수 로컬 권한 캐시는 애초에 collection이 아닐 수 있다.

**§12.12를 커밋 16 전에 해소한다.** 그리고 **§4.3의 권고는 이 칸에 의존하지 않는다** — 권고는 (a) §2.5의 API 사실, (b) 첫 네트워크 스택, (c) §4.2의 미해소 캐시 TTL 모순 위에 선다. 이 칸이 뒤집혀도 §4.3은 그 셋으로 유지된다. 이전 초안처럼 이 칸을 근거로 삼지 않는다.

`C:\toauner\docs\ATTRIBUTIONS.md`: `in_app_purchase` 항목을 **§4.5의 절차 3으로 읽은 LICENSE 파일에 근거해서만** 추가한다.

**신규 — §7 전체에서 누락되어 있던 두 개의 필수 스토어 산출물** `[검증 필요 — Play Console 현행 요구사항]`:

- **Play Target audience & content 선언** — 모든 신규 앱과 모든 업데이트에 필수다. 저장소에 존재하지 않고 `release_readiness.ps1`이 검사하지 않는다.
- **IARC 콘텐츠 등급 설문** — 필수. 마찬가지로 부재.

§7.4의 "기타 튜너에 만14세 미만 사용자가 있다"는 서술이 이 선언으로 새어 들어가지 않게 한다 — 그것은 PIPA 판단의 근거이지 Target audience 선언의 근거가 아니다(§7.4의 세 시험 구분). **만 18세 이상 또는 아동 대상 설계 없음을 의도적으로 선언하고 그 근거를 기록한다.**

두 문서 모두 아직 "toauner"로 되어 있어 SharkTune 리브랜드 이전 상태다. 문서를 손대는 커밋에서 함께 정리한다.

### 7.2 로그인을 추가할 때 (v1 범위 밖)

`privacy-policy.md:26`이 거짓이 된다(로그인은 이메일을 수집한다). `:34`가 거짓이 되고 **Play의 계정 삭제 의무 + 웹 접근 가능한 삭제 URL**이 발생한다. `play-data-safety.md:14-19` 결론 블록 **전체가 뒤집힌다.** `:36`(전송 중 암호화 해당 없음), `:37`(계정 없음)도 거짓이 된다. `:27-31`의 `기기 밖 전송` 열이 **다섯 행 전부** `없음`인데 전부 갱신 대상이 된다.

`privacy-policy.md:42`가 이것을 **배포 전에** 하라고 이미 사전 약속했다.

### 7.3 전자상거래법 — 이전 초안에서 통째로 빠져 있던 두 개의 법 `[검증 필요 — 법률 원문 및 시행일]`

**(a) 숨은 갱신 금지 (다크패턴 규제).** 전자상거래법 개정(법률 제20302호, 시행 **2025-02-14**)이 여섯 가지 다크패턴을 명시적으로 금지하며 그중 하나가 **숨은 갱신**이다. 정기결제 금액이 인상되거나 무료 제공이 유료로 전환되는 경우, **변경 전 30일 이내에** 소비자 동의를 받고 해지 조건·방법을 고지해야 한다. 제재: 시정조치 + 과태료 5백만원 이하, 사안에 따라 영업정지 최대 1년.

- **금지 목록의 하나인 "취소·탈퇴 방해"는 체험이 없어도 페이월의 해지 어포던스를 구속한다.** §10에 반영한다.
- §4.6의 "체험 없음" 권고가 (a)를 우연히 회피한다. **회피는 근거가 아니다** — 미래에 체험을 넣으려는 사람은 30일 사전 동의 플로우를 함께 만들어야 한다.

**(b) 청약철회 — 전자상거래법 제17조.** 이전 초안은 ₩39,000~49,000짜리 비소모성 상품을 팔면서 법정 철회권을 한 번도 언급하지 않았다. 제17조는 계약서 수령일 또는 공급 개시일로부터 **7일**을 부여한다. 디지털 콘텐츠에서 철회권을 배제하려면 **그 사실을 명확히 표시하고 시험 사용 상품(또는 그에 준하는 것)을 제공**해야 한다 — 판매자가 일방적으로 "환불 불가"를 선언할 수 없다. **스토어 환불 창(Play 48시간)은 법정 지위가 아니며 개발자의 통신판매업자 의무를 면제하지 않는다.** Google/Apple은 통신판매중개업자다.

**§4.6의 구성이 여기서 우연히 강한 위치를 만든다: 체험을 없애고 대신 영구적이고 넉넉한 무료 티어를 유지한다.** 그 무료 티어가 제17조 제6항의 시험 사용 상품 메커니즘에 해당할 가능성이 있다. **추론하지 말고 법률 검토로 확인한다.** 노출이 가장 큰 것은 평생 SKU다.

**커밋 16은 `privacy-policy.md`에 청약철회 절을 추가한다.** 문안은 법률 검토 대상이다(§12).

### 7.4 PIPA 만14세 미만 — 세 개의 다른 시험을 섞지 않는다

**개인정보보호법 제22조의2.** §1: 만14세 미만 아동의 개인정보를 처리하려면 **법정대리인의 동의를 받고 실제로 동의했는지 확인**해야 한다. §3: 만14세 미만 대상 고지는 **이해하기 쉬운 양식과 명확하고 알기 쉬운 언어**를 써야 한다.

**벌칙: 5년 이하 징역 또는 5천만원 이하 벌금.** 이전 초안은 이를 `[미검증]`으로 표기했으나 **제71조가 제22조의2 제1항 위반을 정확히 그 수준으로 처벌한다 — 확인됨으로 상향한다.** 별도로 제75조 과태료(1천만원 이하)가 동의 방법 위반에 붙을 수 있다. **형사·행정 노출이 모두 살아 있다.** 이 항목에서 문서는 유일하게 *과소* 확신하고 있었다.

**세 시험을 구분한다 — 이전 초안이 뭉갠 지점이다:**

| 시험 | 무엇에 걸리는가 | v1 상태 |
| --- | --- | --- |
| PIPA 제22조의2 | **실제 처리**하는 개인정보 | **해당 없음 — v1은 아무것도 수집하지 않는다** |
| Play Target audience & content | **선언한 설계 의도** | 필수 산출물, 부재 (§7.1) |
| Play 리스팅 심사 | **마케팅 외관** | 아동 대상으로 보이면 반려 가능 |

"기타 튜너에는 만14세 미만 사용자층이 있다"는 서술은 **시험 1에 대한 증거이고 시험 2·3과 무관하다.** 일반적 아동 대상 태세를 확립하는 것처럼 읽히게 두지 않는다.

**악순환(시험 1이 발동할 경우):** 만14세 미만인지 알려면 나이를 물어야 한다. **네이버 네아로는 생일·연령대 필드를 지원하지 않는다** `[검증 필요]`. 카카오의 나이/생일 동의 항목은 비즈 앱 전환을 요구하고, 비즈 앱 전환은 **사업자등록번호** 또는 완료된 **휴대폰 본인인증**을 요구한다 `[검증 필요]`. 즉 **네이버/카카오 로그인은 사용자 나이를 신뢰성 있게 알려주지 못한다.** 별도 연령 게이트 + 완전한 법정대리인 동의 플로우(SMS/카드/본인인증 — 전부 서버와 유료 인증 벤더 필요)를 직접 만들거나 법적 노출을 감수해야 한다.

**v1은 아무것도 수집하지 않으므로 시험 1이 발동하지 않는다.** 이것이 §1.1 결론의 가장 강한 단일 근거다.

### 7.5 사업자등록 / 통신판매업 / VAT — **모든 것을 막는 항목**

**⚠ 이것이 전체 계획의 크리티컬 패스다. 코드 문제가 아니며 지금 시작해야 한다.**

**차단 항목은 사업자등록(BRN) 하나다. 이전 초안은 통신판매업 신고를 함께 묶었고, 그것은 아마 틀렸다.**

**(a) 사업자등록 (BRN) — 진짜 차단 항목, 양대 스토어 공통.**

- **Apple이 강제한다.** Apple은 한국에 소재한 **조직과 개인 모두**에게 Business Registration Number를 요구하고 App Store 제품 페이지에 표시하며, 근거로 전자상거래법을 명시한다 `[검증 필요 — developer.apple.com/help/app-store-connect/.../manage-korea-compliance-information/]`. **면제 경로가 없다.** 한국 세금 ID 미제공 시 제재는 **한국 스토어에서의 앱 제거 또는 지급 보류**다.
- Google Play Console은 **업체**에 사업자등록번호 + 통신판매 신고번호를 요구하고 **개인은 연락처 전화번호만** 요구한다 — 확인 필요하나 Google 한국 페이지의 서술이다 `[검증 필요]`. **이것은 Google의 콘솔 요구사항이지 한국 법이 아니다.**
- **결론: BRN은 Apple이 강제하는 하드 게이트이므로, 우리가 걱정하던 한국 기관이 아니라 *Apple*이 이 항목의 집행자다. §12의 최상위 차단 항목으로 올린다.**

**(b) 통신판매업 신고 — 면제 가능성이 높다. 차단 항목이 아니다.**

전자상거래법 제12조 제1항 단서 + 「통신판매업 신고면제 기준에 대한 고시」는 **직전 연도 거래 50회 미만** 또는 **부가가치세법상 간이과세자** 중 **어느 하나**에 해당하는 판매자를 면제한다 `[검증 필요 — 공정거래위원회 / 관할 구청 확인]`. **간이과세자로 등록한 첫 해 개인은 첫날부터 두 요건을 모두 충족한다.**

- 실행: 관할 세무서에 **앱 개발업이 간이과세 배제업종인지** 확인하고, 관할 구청에 **면제 기준**을 확인한다.
- **2년차 의무로 다이어리에 기록한다** — 50회 기준은 직전 연도 기준이므로 1년차 판매가 50건을 넘기는 순간 발효한다. 이 계획의 수익 전제가 그렇게 되기를 가정한다.
- **이전 초안의 "사업자등록 → 통신판매업 신고 → 콘솔 전환 → 출시" 순서는 거짓 전제 위에 세워졌다. 재도출한다.**
- `[검증 필요]` "Play Console 개인→개인사업자 전환": Google의 계정 분류는 개인/조직이고 개인사업자가 자명하게 조직인 것은 아니다. **확인 전에는 필수 단계로 서술하지 않는다.**

**(c) VAT — 스토어별로 모델링한다. 하나의 규칙이 아니다.**

| 스토어 | MOR | 우리(한국 거주 개발자)의 위치 |
| --- | --- | --- |
| Google Play | **아니오** (한국 거주 개발자에 대해) | **우리가 VAT 책임자다.** Google 한국 페이지: "대한민국에 거주하는 개발자에게는 대한민국 고객이 구매하는 모든 Google Play 스토어 디지털 콘텐츠에 부과되는 부가가치세(VAT)를 산정, 청구하여 납부할 책임이 있습니다." `[검증 필요 — 원문 대조]` 사업자등록번호 미제공 시 Google이 **청구 수수료에 10% VAT를 부과**한다 — 수수료 위에 세금이 얹힌다. |
| App Store | **예** (한국) `[검증 필요]` | 메커니즘이 다르다. **대칭을 가정하지 않는다.** Apple은 자사 커미션에 한국 VAT를 적용하고, NTS에서 검증된 BRN이 있어야 세금계산서를 발행한다 `[검증 필요]`. **검증된 BRN이 없으면 Apple 커미션에 대해 매입세액공제를 받을 수 없다** — §4.4의 15% 모델에 없던 실제 현금 비용이다. |

**신고 기준 — 흔한 실수:** 부가세 신고 시 **순 정산금액이 아니라 수수료 차감 전 결제총액을 매출로 신고**하고 플랫폼 수수료는 별도로 **경비** 처리해야 한다 `[검증 필요 — 2차 출처. Apple-as-MOR 경로에서는 총액/순액 문제의 형태가 다르므로 별도 확인]`. **세무사를 쓴다. 코드로 풀 문제가 아니다.**

`[검증 필요 — 추가 확인 항목]`:
- 한국 인앱 최대 가격 제한 (US$400 상당이라는 보고) — ₩49,000에서는 무관하나 기록한다.
- KRW 최소 가격 및 가격 사다리.

### 7.6 트립되는 게이트 — 그리고 트립되지 않는 게이트

**이 저장소의 자동 게이트는 이 변경에 대해 문서보다 약하다. 이 사실 자체가 발견이다.**

**7.6.1 — `release_readiness.ps1`의 finding은 `check.ps1`에서 아예 실행되지 않는다 (확인됨).**

`C:\toauner\tool\check.ps1`을 직접 읽었다. 실행하는 것은 다음이 전부다:

```
release_readiness.ps1 -SelfTest      ← 자기 테스트만. 실제 스캔 없음
license_audit.ps1 -SelfTest
license_audit.ps1                    ← 실제 스캔 있음
melos run format / analyze / test
packages\tuner_dsp의 정확도 리포트 3종
```

**`release_readiness.ps1`이 `$Root`에 대해 실행되는 곳이 없다.** 전체 스캔은 `-Strict`로 수동 실행할 때만 돌고(`C:\toauner\docs\release-readiness.md:6-7`), **`.github\workflows`가 없으므로 CI도 없다.** 이전 초안은 `android_release_internet`이 "잘못된 매니페스트를 읽는다"고 지적했지만 진실은 더 나쁘다 — **finding 전체가 게이트에서 한 번도 실행되지 않는다.**

**따라서 이전 초안의 커밋 3("`android_merged_internet`을 추가하면 SDK가 들어올 때 발화한다")은 거짓이었다.** 자기 테스트만 도는 finding은 자동 보호를 **0** 제공한다. 게다가 이전 초안은 병합 매니페스트 부재 시 non-blocker로 두어 `check.ps1`을 초록으로 유지하겠다고 했는데, 병합 매니페스트는 Gradle 릴리스 빌드 이후에만 존재하고 `check.ps1`은 Gradle을 돌리지 않는다. **일상 개발에서 절대 발화할 수 없는 게이트다.**

**정정 — 두 커밋으로 분리한다:**

- **커밋 3**은 `android_merged_internet` finding과 그 자기 테스트를 추가하고, **이것이 릴리스 시점 전용 검사임을 `docs/release-readiness.md`에 명시한다.** 자동 보호를 주장하지 않는다.
- **커밋 17**(마지막)이 `check.ps1`에 실제 `-Strict` 스캔을 추가한다. **이 커밋은 즉시 `check.ps1`을 RED로 만든다** — 확인됨: `privacy-policy.md`와 `play-data-safety.md`가 지금 `release_status: draft` + 메타데이터 전부 TBD이고, `Test-FinalReleaseDocument`가 `release_status: final`과 TBD 아닌 메타데이터를 요구한다. 따라서 **커밋 17은 커밋 16 이후에만 랜딩 가능하고, 커밋 16은 `developer_name`·`privacy_contact`·`public_url`·`effective_date`라는 사용자 결정에 막혀 있다.** §12의 차단 항목이다.

**7.6.2 — 매니페스트 검사의 정확한 형태.**

- `android_release_internet`(`release_readiness.ps1:151-156`)은 `app\android\app\src\main\AndroidManifest.xml`을 정규식 검사한다. **소스 매니페스트이지 병합 결과가 아니다.** SDK는 자체 AAR 매니페스트에 권한을 선언하고 Gradle 매니페스트 병합기가 릴리스 매니페스트에 주입한다. **게이트는 계속 `pass`를 보고하고 출하된 APK에는 권한이 들어간다.** `C:\toauner\docs\play-data-safety.md:43`이 이미 이 간극을 사람에게 배정해 두었다. **`android_release_internet`은 제거하지 않는다** — 둘은 서로 다른 질문에 답한다.
- **`android_merged_internet`은 릴리스 variant로 한정해야 한다.** 확인됨: `C:\toauner\app\android\app\src\debug\AndroidManifest.xml:6`과 `src\profile\AndroidManifest.xml:6`이 **이미 `android.permission.INTERNET`을 선언한다**(Flutter 기본 핫리로드 매니페스트). variant 한정 없이 만들면 모든 개발 빌드에서 오발화한다. 이전 초안은 "릴리스"라고만 쓰고 이 함정을 표시하지 않았다.
- **찾아야 할 문자열은 INTERNET만이 아니다.** `[검증 필요]` Play Billing AAR은 `com.android.vending.BILLING`을 주입할 개연성이 높고 INTERNET을 주입하지 않을 수 있다. **커밋 3의 검사는 두 권한을 모두 열거하고, 실제 병합 결과를 커밋 14의 첫 릴리스 빌드에서 육안 확인해 §12.11에 답한다.**
- `privacy_policy` / `play_data_safety`(`:197/200`)는 `Test-FinalReleaseDocument`(`:35-55`)로 `release_status: final`과 TBD 아닌 메타데이터만 검사한다. **산문을 읽지 않는다.**
- `dependency_license_gate`(`:206/209`)는 `license_audit.ps1`의 존재만 확인한다.

**이 비대칭이 §8이 존재하는 이유다. 진짜 계약은 산문이고, 산문은 빌드를 실패시키지 못한다.** SDK 작업을 시작하기 전에 전제를 강제 가능하게 만드는 실패하는 테스트를 먼저 쓴다(`AGENTS.md:50`). 그렇지 않으면 게이트 스택이 "오프라인을 강제한다"에서 **"오프라인이 거짓인데도 오프라인이라고 주장한다"**로 전이하고, 초록색 `check.ps1`이 다음 사람에게 **능동적으로 거짓말**하게 된다.

**7.6.3 — `design_playbook_compliance_test.dart` (확인됨).**

`:149-165`의 `_productionDartSources()`는 `app\lib`을 재귀 스캔한다. `C:\toauner\app\lib\src\entitlement\` 아래 모든 신규 파일이 **옵트인 없이** 규칙 전부의 대상이 된다. 페이월 UI가 트립시킬 것들:

- `:98-119` — **앱 전역 허용 아이콘은 단 3개**: `Icons.chevron_left_rounded`, `Icons.search_rounded`, `Icons.mic_rounded`. 확인됨: `app\lib` 전체에 존재하는 `Icons.` 심볼이 정확히 이 셋이다. 페이월의 닫기 `×`, 자물쇠, 별, 재생 아이콘 전부 실패한다. 기존 닫기 어포던스는 텍스트 `'×'`(**`song_search_screen.dart:336`** — 이전 초안의 `:316`은 오기다)를 쓴다 — **이것을 따른다.**
- `:39-57` — `LinearGradient(` / `RadialGradient(` / `SweepGradient(` 금지. 거의 모든 스톡 페이월 디자인이 이것을 쓴다.
- `:59-67` — `RegExp(r'\bColor\(0x')`는 `app\lib\src\app\instrument_theme.dart` 밖에서 금지. 브랜드 컬러 CTA는 **6개 테마 전부**의 토큰이 되어야 한다.
- `:130-140` — `fontSize:\s*[0-9]` 금지. 가격 타이포그래피는 플레이북의 명명된 역할에 매핑해야 한다.
- `:69-77` — `BoxShadow(`는 `app\lib\src\ui\instrument_surface.dart`에서만.

**`_legacyThemeAllowlist`는 이미 빈 집합이다** (확인됨: `design_playbook_compliance_test.dart:143`의 `const _legacyThemeAllowlist = <String>{};`). 이전 초안의 "allowlist를 늘리지 않는다"는 진행 중인 작업처럼 서술되었으나 실제로는 **이미 달성된 상태이며 규칙은 '빈 채로 유지한다'이다.** §10에서 정정한다.

`C:\toauner\docs\design-playbook.md`에는 페이월·구독·결제·로그인 관련 절이 **전혀 없다**(확인됨: 해당 문자열 0건). `AGENTS.md:49`가 UI는 플레이북과 ui-plan의 토큰/상태명/P0을 따르라고 요구하므로 **이 표면들은 현재 명세 불가능하다. 문서에 절이 먼저 생겨야 UI를 정당하게 쓸 수 있다.** 플레이북 `:12`는 이미 표준 업셀 어휘를 금지한다: `임의 그라데이션, 큰 둥근 카드 묶음, 균일한 그림자, 장식용 아이콘 무더기, 과한 글로우는 사용하지 않는다.`

**7.6.4 — 골든 테스트는 완료 시트를 렌더하지 않는다 (확인됨). 이전 초안의 주장은 뒤집혀 있었다.**

이전 초안은 "완료 시트 변경이 골든을 무효화하므로 재생성하라"고 썼다. **불가능하다.** `C:\toauner\app\test\precision_tuner_golden_test.dart`는 `_GoldenTunerEngine`을 주입하고 그 `states`는 `const Stream.empty()`, `current`는 `LiveTunerStatus.listening`, `lockProgress: 0.38`이다. 튜닝이 절대 완료되지 않으므로 `_showCompletion()`이 실행되지 않고 `_TuneCompleteSheet`(모달 바텀시트)는 렌더되지 않는다. 6×40ms 펌프는 *듣는 중* 상태의 튜너를 찍는다. **행을 추가해도 픽셀 diff가 0이고 §13에 거짓 체크마크가 생긴다.**

**진짜 발견은 그 역이며 더 나쁘다: `_TuneCompleteSheet`에는 픽셀 게이트가 없다.** 이전 초안은 픽셀 게이트가 없는 유일한 튜너 표면을 유일한 수익화 지점으로 골랐고, 게이트가 있다고 주장했다. §3.3이 업셀을 그 시트에서 완전히 빼면서 이 문제는 해소된다.

**커밋 계획에서 골든 재생성 단계를 삭제한다.** 완료 시트의 실제 기존 커버리지는 `C:\toauner\app\test\widget_test.dart:936-951`이다(확인됨: `'6현 모두 완료!'`, `Key('tune-complete-glyph')`, `open-stability-check`를 단언한다). 완료 시트를 건드리는 변경은 **이 파일**을 확장한다.

---

## 8. 먼저 쓸 테스트 (이름 고정)

`AGENTS.md:50`: 먼저 실패하는 작은 테스트를 추가하고 구현한다. **작업 트리에서는 테스트 우선으로 진행하되, 랜딩되는 히스토리는 저장소 관례대로 feat → test → docs 순으로 분할한다** (확인된 선례: `2315980 feat` → `e59c1d0 test` → `791a9c4 docs`, string_care·stage_mode·reference_tone 동일).

`C:\toauner\app\test\`의 관례를 따른다: `group()` 없음, `void main()` 직속 평면 `test()`, 소문자 영문 완결 문장 이름, 마침표 없음, 모킹 패키지 없음(`final class _Fake... implements ...`), 루프 실패는 `reason:`으로 식별.

테스트 실행: `cd C:\toauner\app; ..\.tools\flutter\bin\flutter.bat test`. 루트에서 `flutter test app`을 돌리면 에셋 번들 경로가 깨져 거짓 실패가 난다(`C:\toauner\docs\wind-down-protocol.md:99-110`). `flutter analyze app`은 루트에서 괜찮다.

### 8.1 `C:\toauner\app\test\no_forced_login_test.dart` — **오늘 통과해야 한다**

현재 상태를 계약으로 고정하는 게이트다. 코드 변경 없이 통과한다. `_productionDartSources()`(`design_playbook_compliance_test.dart:149-165`)와 `_workspaceRoot()`(`:167-185`) 헬퍼 패턴을 복제한다(루트 `pubspec.yaml`의 `name: toauner_workspace`를 앵커로 쓴다).

1. `production dependencies stay on the offline allowlist`
   — `C:\toauner\app\pubspec.yaml`을 읽고 의존성 이름이 허용 목록에 있는지 검사한다. 오늘의 목록: `flutter`, `audioplayers`, `path_provider`, `tuner_audio`, `tuner_data`, `tuner_domain`, `tuner_dsp`. **허용 목록은 이 테스트 안에 단일 `const` 집합으로 두고, 확장은 반드시 그 의존성을 추가하는 커밋과 같은 커밋에서만 한다.**
2. `app reaches the tuner without any account prompt`
   — `ToaunerApp` 펌프 후 튜너 도달까지 계정/로그인 위젯이 없음을 확인한다.
3. `tuner sources contain no entitlement gate`
   — `precision_tuner_screen.dart`, `precision_tuner_controls.dart`, `precision_tuner_setup.dart`, `precision_tuner_panels.dart` **4개 파일 전부**를 스캔한다.
   **금지 목록(denylist)으로 작성한다. 예외 목록은 만들지 않는다.** 검사 대상 문자열: `EntitlementScope`, `EntitlementController`, `EntitlementStatus`, `EntitlementTier`, `context.entitlement`, 그리고 대소문자 무시 `entitlement`.
   **`Pro`를 검사하지 않는다.** 확인됨: 그 4개 파일에 `Pro` 부분 문자열이 **53회** 나온다(`InstrumentPegProfile`, `InstrumentProfileLoader`, `loadInstrumentProfile`, `_pegProfileLabel`, `TuneUpProgressTracker`, `lockProgress`, `LinearProgressIndicator`, `Provide`…). 이전 초안의 이 테스트는 커밋 2에서 **RED**였다. 대소문자 무시 `entitlement`는 오늘 정확히 **0건**이다(확인됨).
   **왜 4개 전부인가:** `precision_tuner_screen.dart:23-25`가 `part 'precision_tuner_controls.dart'; part 'precision_tuner_setup.dart'; part 'precision_tuner_panels.dart';`를 선언한다(확인됨). 네 파일은 **하나의 라이브러리**이며 private 멤버를 공유한다. "튜닝 화면을 건드리지 않는다"는 파일 경계로 강제되지 않는다. 오늘 이것을 고정하는 린트나 테스트는 존재하지 않는다.
4. `no advertising sdk appears in production sources`
   — 광고는 이 계획의 범위 밖이지만, 범위 밖임을 강제 가능하게 만든다.
5. `no upsell renders between the quick tune panel and the song search label`
   — `C:\toauner\app\lib\src\songs\song_search_screen.dart`의 `:224`(퀵튠 `InstrumentSectionLabel`)와 `:244`(`InstrumentSectionLabel('곡 검색')`) 사이 영역에 광고·업셀 위젯이 없음을 확인한다.
   **정정:** 이전 초안은 이 경계를 "`곡에 맞춰 튜닝` 카드"로 지목했다. 확인됨: **그 문자열은 `app\lib` 전체에 존재하지 않는다.** 기억 없는 실행자가 찾을 수 없는 위젯으로 표시된 경계는 강제되지 않는 경계다. 구조로 다시 쓴다.

### 8.2 `C:\toauner\app\test\entitlement_resolver_test.dart` (순수 Dart 판정기, 주입 시계)

6. `lifetime entitlement never expires even ten years offline`
7. `subscription stays pro for sixty days past expiry while offline`
8. `subscription revokes at sixty one days past expiry while offline`
9. `subscription revokes at expiry once the store confirms it expired`
10. `network failure never mutates the cached entitlement record`
11. `clock rollback cannot extend a subscription past its expiry`
12. `a null record resolves to unknown and never to free`
13. `free tier never resolves to pro without a store grant`
14. `entitlement resolver source imports no flutter library`
    — `C:\toauner\app\lib\src\entitlement\entitlement_resolver.dart`를 파일로 읽어 `package:flutter` / `dart:ui` import가 없음을 단언한다. §2.3의 배치 결정을 강제 가능하게 만든다.

테스트 7~9는 v1에서 도달 불가능한 구독 경로를 검증한다(§2.6). **의도적이다** — 구독이 도입될 때 판정기를 새로 설계하지 않기 위한 예약된 계약이다.

### 8.3 `C:\toauner\app\test\entitlement_store_test.dart`

`Directory.systemTemp.createTemp('sharktune-entitlement-')` + `addTearDown(() => directory.delete(recursive: true))` + `JsonEntitlementStore(directoryProvider: () async => directory)`.

15. `entitlement store falls back to backup after primary corruption`
16. `entitlement store returns unknown instead of free when both files are unreadable`
17. `entitlement store never writes a free record over an unreadable file`
18. `entitlement store never downgrades a lifetime grant on decode failure`
19. `entitlement store serializes concurrent writes without losing a grant`
20. `high water mark advances at most once per foreground`
    — §2.9의 주기 계약을 고정한다. `resolve()`를 여러 번 호출해도 디스크 쓰기가 늘지 않음을 단언한다.
21. `entitlement flushes to disk on app lifecycle pause`

### 8.4 `C:\toauner\app\test\entitlement_gate_test.dart`

22. `tuner and every accuracy surface stay free with an empty entitlement`
23. `all six themes stay free with an empty entitlement`
24. `song search and song detail stay free with an empty entitlement`
25. `pro surfaces render an upsell instead of an error when entitlement is free`
26. `pro surfaces unlock when the entitlement scope reports pro`
27. `pro surfaces lock without an upsell when entitlement is unknown`
    — §2.2의 `unknown` 카피 규칙. `구매 확인 중` + 복원 버튼만 보이고, 업셀도 `만료`도 `무료`도 없다.
28. `paywall copy never renders 만료 while the store confirmation is unobtainable`
29. `store purchase adapter never reports confirmed expired`
    — §2.6의 계약. `in_app_purchase` 어댑터가 `StoreConfirmation.confirmedExpired`를 만들 수 없음을 고정한다.

### 8.5 `C:\toauner\app\test\song_bpm_test.dart` (커밋 12의 전제)

30. `song bpm index distinguishes an unknown song from a failed load`
    — §3.4의 결함. 오늘 `loadSongBpmIndex()`가 모든 실패를 빈 맵으로 삼킨다. 유료 연습 루프를 팔기 전에 고친다.

### 8.6 `C:\toauner\tool\release_readiness.ps1` — 신규 finding

31. **`android_merged_internet`**
    - 병합된 **릴리스** 매니페스트에서 `android.permission.INTERNET`과 `com.android.vending.BILLING`을 검사한다.
    - **debug/profile variant를 절대 검사하지 않는다.** 확인됨: `app\android\app\src\debug\AndroidManifest.xml:6`과 `src\profile\AndroidManifest.xml:6`이 이미 INTERNET을 선언한다.
    - `:227`의 자기 테스트 패턴(해당 권한을 가진 픽스처 매니페스트를 구성해 검사가 발화함을 증명)을 그대로 복제한다. `check.ps1`이 `-SelfTest`를 먼저 돌린다.
    - `:233-237`의 blocker 목록 자기 테스트를 함께 갱신한다.
    - 병합 매니페스트가 없는 환경(릴리스 빌드 전)에서는 `blocker`가 아니라 `warning`으로 보고한다. **`-Strict`에서는 blocker다** — 릴리스 시점에는 반드시 존재해야 한다.
    - **`android_release_internet`은 제거하지 않는다.**

---

## 9. 커밋 분할

각 커밋은 독립적으로 되돌릴 수 있고, **커밋 17을 제외한 각 커밋 이후 `C:\toauner\tool\check.ps1`이 초록이어야 한다.** 커밋 17은 의도적으로 게이트를 강화하며 커밋 16의 문서 확정을 전제로 한다.

커밋 본문은 2~3줄, 약 70자 하드랩, 명령형, **메커니즘 + 순진한 대안이 실패한 이유**를 적는다. 트레일러: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

### Phase A — 계약과 게이트 (SDK 없음)

| # | 커밋 | 파일 | check.ps1 |
| --- | --- | --- | --- |
| 1 | `docs: define login and billing architecture contract` | `C:\toauner\docs\login-billing-2026-07-15.md` (이 문서) | 초록 (문서만) |
| 2 | `test: pin guest-first no-login invariants` | `C:\toauner\app\test\no_forced_login_test.dart` (테스트 1~5) | 초록 — **오늘 통과한다** |
| 3 | `build: detect network permissions in the merged release manifest` | `C:\toauner\tool\release_readiness.ps1` (테스트 31); `C:\toauner\docs\release-readiness.md` (릴리스 시점 전용임을 명시) | 초록 — `-SelfTest`만 돌므로 실제 스캔 미실행 |

**커밋 3의 정직성 요구:** 커밋 메시지 본문에 "이 finding은 `check.ps1`에서 실행되지 않는다. 커밋 17이 실효화한다"를 적는다. 자동 보호를 주장하지 않는다(§7.6.1).

### Phase A' — 선행 수정 (권한과 무관, 독립 되돌리기)

| # | 커밋 | 파일 | check.ps1 |
| --- | --- | --- | --- |
| 4 | `fix: flush pending preferences on app lifecycle pause` | `C:\toauner\app\lib\src\app\toauner_app.dart` (`didChangeAppLifecycleState` 오버라이드 추가); `app_preferences.dart` (flush API); `C:\toauner\app\test\widget_test.dart` (테스트 추가) | 초록 |
| 5 | `feat: rename the precision tolerance label to 정밀` | `C:\toauner\app\lib\src\app\app_preferences.dart:13-16`; 관련 표면; 새 테스트 `no accuracy surface renders the paid tier word` | 초록 |

**커밋 4가 커밋 8과 분리되어야 하는 이유:** 확인됨 — `toauner_app.dart:50`은 이미 `WidgetsBindingObserver`를 믹스인하지만 `didChangeAccessibilityFeatures()`(`:77-79`)만 오버라이드하며 `didChangeAppLifecycleState`가 없다. `app_preferences.dart:219`의 `_pendingSave = _pendingSave.then(...)`는 체인이지 await가 아니다. **즉 오늘 이미 프로세스 사망 시 preferences 쓰기가 유실된다** — 테마·톨러런스·최근 검색에 영향을 주는, 권한과 완전히 무관한 버그다. 이전 초안은 이 수정을 권한 커밋에 묶었고, 그러면 권한을 되돌릴 때 preferences 내구성 수정도 함께 되돌아간다(`AGENTS.md:71` 위반).

**커밋 5의 근거:** §3.2. 사용자 표기 결정을 기다리지 않는다 — 현재 상태('프로')가 더 나쁘고, 라벨 변경은 독립적으로 되돌릴 수 있다. 사용자가 다른 단어를 지정하면 후속 커밋으로 바꾼다.

### Phase B — 판정기 (외부 의존성 0)

| # | 커밋 | 파일 | check.ps1 |
| --- | --- | --- | --- |
| 6 | `feat: add offline entitlement state machine` | `C:\toauner\app\lib\src\entitlement\entitlement_resolver.dart` | 초록 — 순수 Dart, Flutter import 없음 |
| 7 | `test: cover offline entitlement resolution` | `C:\toauner\app\test\entitlement_resolver_test.dart` (테스트 6~14) | 초록 |

### Phase C — 저장소와 주입

| # | 커밋 | 파일 | check.ps1 |
| --- | --- | --- | --- |
| 8 | `feat: add local entitlement store and scope` | `C:\toauner\app\lib\src\entitlement\entitlement_store.dart`, `entitlement_controller.dart`; `toauner_app.dart` (기본값 있는 필드 2개, `:99-101`에 스코프 중첩, 커밋 4의 lifecycle 훅에 권한 flush 추가); `C:\toauner\app\lib\main.dart` | 초록 — 기본값이 있으므로 `widget_test.dart`의 21개 생성 지점 무영향 |
| 9 | `test: cover entitlement store durability` | `C:\toauner\app\test\entitlement_store_test.dart` (테스트 15~21) | 초록 |

**커밋 8 필수 조건:** `entitlementController`는 nullable 기본값, `initialEntitlement`는 const 기본값. `toauner_app.dart:22` / `:35` / `:58-64` 패턴을 그대로 복제한다.

### Phase D — Pro 게이팅 UI (SDK 없음)

| # | 커밋 | 파일 | check.ps1 |
| --- | --- | --- | --- |
| 10 | `docs: define paywall and pro surface tokens` | `C:\toauner\docs\design-playbook.md` (신규 절); `C:\toauner\docs\ui-plan.md` (Pro 표면의 P0 관계, §3.5의 카탈로그 리스크, §2.4.4의 스키마 게이트 백로그) | 초록 (문서만) |
| 11 | `feat: add pro surface tokens to the theme registry` | `C:\toauner\app\lib\src\app\instrument_theme.dart` (6테마 전부에 Pro 토큰) | 초록 |
| 12 | `feat: gate pro features behind the entitlement scope` | `C:\toauner\app\lib\src\entitlement\` UI; `song_detail_screen.dart`, `settings\`, `instrument_setup\` 업셀 진입점; `song_bpm.dart` (§3.4의 실패 구분) | 초록 — 부여자는 스텁(항상 free, 디버그 오버라이드) |
| 13 | `test: cover pro gating and free-forever surfaces` | `C:\toauner\app\test\entitlement_gate_test.dart` (테스트 22~29); `C:\toauner\app\test\song_bpm_test.dart` (테스트 30) | 초록 |

**커밋 10이 커밋 11~12보다 먼저인 이유:** `AGENTS.md:49`가 UI는 `design-playbook.md`와 `ui-plan.md`의 토큰·상태명·P0을 따르라고 요구하고, 두 문서에 오늘 페이월 절이 없다. 토큰이 먼저 존재해야 UI가 정당하다. 이것은 feat → test → docs 관례의 의도적 예외이며 커밋 메시지 본문에 이유를 적는다.

**커밋 11과 12를 나눈 이유:** 테마 레지스트리의 토큰 추가는 그것을 소비하는 UI와 독립적으로 되돌릴 수 있고, 커밋 10의 문서가 서술하는 대상이 바로 토큰이다(`AGENTS.md:71`).

**커밋 12 주의:** 골든 재생성은 **하지 않는다.** §7.6.4 — 업셀이 튜너에 들어가지 않으므로 골든과 무관하고, 애초에 골든은 완료 시트를 렌더하지 않는다.

**커밋 12 차단 조건:** §3.5 — 검증된 곡이 0건이면 카탈로그 파생 Pro 표면(연습 루프·셋리스트)을 랜딩하지 않는다.

### Phase E — 스토어 연결

| # | 커밋 | 파일 | check.ps1 |
| --- | --- | --- | --- |
| 14 | `feat: add store purchase adapter behind the entitlement port` | `C:\toauner\app\pubspec.yaml` (`in_app_purchase: <§4.5로 해석한 실제 버전>`); `C:\toauner\app\lib\src\entitlement\store_purchase_adapter.dart`; `C:\toauner\app\test\no_forced_login_test.dart` (테스트 1의 허용 목록 확장); iOS In-App Purchase capability | 초록 |
| 15 | `test: cover store purchase adapter mapping` | `C:\toauner\app\test\store_purchase_adapter_test.dart` | 초록 |
| 16 | `docs: update privacy policy and data safety for in-app purchase` | `C:\toauner\docs\privacy-policy.md` (결제 + 청약철회 절, 메타데이터 확정), `play-data-safety.md`, `ATTRIBUTIONS.md` | 초록 |

**이전 초안의 커밋 11(`build: allow the store billing dependency in the license audit`)은 삭제되었다.** 확인됨: `C:\toauner\tool\license_audit.ps1`에는 **허용 목록이 존재하지 않는다.** 이 스크립트는 workspace + Flutter SDK 패키지를 건너뛰고(`:68-73`), 최상위 LICENSE가 없는 외부 패키지를 blocker로 잡고(`:76-86`), GPL 계열 마커를 blocker로 잡는다(`:88-105`). **허용할 대상이 없다.** `in_app_purchase`와 전이 의존성이 GPL 아닌 LICENSE 파일을 가지면 **스크립트 수정 0으로 통과한다.** 즉 그 커밋은 no-op이거나, 우회로를 추가하는 것 — GPL 히트에 대해서는 `AGENTS.md:26`("코드·패키지·테스트 픽스처 어느 형태로도 반입하지 않는다") 위반이고, LICENSE 부재 히트에 대해서는 실재하는 검사를 조용히 퇴역시킨다.

**커밋 14 전에 §4.5의 6단계를 전부 수행한다.** `license_audit.ps1`을 **수정하지 않은 상태로** 돌리고, 막히면 그것은 우회할 대상이 아니라 해결할 발견이다. `no_forced_login_test.dart`의 허용 목록 확장은 의존성을 추가하는 커밋과 **같은 커밋**에 둔다(같은 되돌리기 단위).

**커밋 16이 Phase E의 마지막인 이유:** `privacy-policy.md:42`가 "배포 전에" 갱신을 약속한다. 커밋 14~15는 코드일 뿐 배포가 아니다. 커밋 16 없이 릴리스 빌드를 만들지 않는다.

### Phase F — 게이트 실효화 (사용자 결정 이후에만)

| # | 커밋 | 파일 | check.ps1 |
| --- | --- | --- | --- |
| 17 | `build: run the release readiness scan in check.ps1` | `C:\toauner\tool\check.ps1` (`release_readiness.ps1 -Strict` 실제 실행 추가) | **커밋 16이 문서를 `release_status: final`로 확정한 뒤에만 초록** |

**커밋 17이 마지막이고 조건부인 이유:** §7.6.1. 오늘 `-Strict`를 켜면 `privacy_policy`와 `play_data_safety`가 즉시 blocker다(둘 다 `draft` + TBD). 그리고 그 메타데이터(`developer_name`, `privacy_contact`, `public_url`, `effective_date`)는 §12의 사업자등록·연락처 결정에 막혀 있다. **커밋 17 없이는 이 계획의 게이트 강화가 전부 상징이다.** §12의 차단 항목으로 명시한다.

**참고 — 살아 있는 위반 하나.** `a9d113a feat: rebuild SharkTune theme and core UI`는 테마 레지스트리, preferences 저장소, 튜너 4분할, 폰트, 브랜딩 에셋, 골든, 테스트, 문서를 아우르는 **단일 100개 파일 이상 커밋**이다. `C:\toauner\docs\wind-down-protocol.md:33-47`은 정확히 이 작업을 **4개의 독립 되돌리기 가능 커밋**으로 규정했었다. 이 계획은 그 블롭을 반복하지 않는다.

---

## 10. 하지 말 것

- **튜닝 정확도를 절대 유료화하지 않는다.** 톨러런스, 안정성 검사, 스테이지 모드, DSP 어느 것도 게이팅하지 않는다. `TunerToleranceMode.pro`는 결제 Pro가 아니다 — **커밋 5가 라벨을 `정밀`로 바꾸기 전에는 Pro 티어를 랜딩하지 않는다**(§3.2).
- **튜닝 화면에 광고도 업셀도 넣지 않는다.** `precision_tuner_screen.dart` / `precision_tuner_controls.dart` / `precision_tuner_setup.dart` / `precision_tuner_panels.dart` **4개 파일 전부**가 튜닝 화면이다(하나의 라이브러리). **예외 없음. allowlist 없음.** 테스트 3이 절대 규칙으로 고정한다.
- **`_TuneCompleteSheet`에 어떤 수익화 표면도 넣지 않는다.** `isDismissible: false, enableDrag: false`다 — 탈출하려면 개입해야 하는 모달이며, 픽셀 높이와 무관하게 인터스티셜이다(§3.3).
- **`_completionShown`을 빈도 제어에 쓰지 않는다.** `.whenComplete()`에서 리셋되므로 멱등이 아니다(§3.3).
- **`song_search_screen.dart:224`(퀵튠)와 `:244`(`곡 검색` 라벨) 사이에 광고·업셀을 넣지 않는다.** 튜닝 CTA에 인접하기 때문이다. 테스트 5가 강제한다.
- **로그인을 강제하지 않는다.** §1.3의 T1~T5가 관측된 사실로 성립하기 전에는 로그인 화면을 만들지 않는다. 로그인 유도 배너, 로그인 시 보상, "나중에" 버튼이 있는 모달 전부 금지한다.
- **네트워크 부재를 만료로 해석하지 않는다.** 어떤 코드 경로도 `SocketException`류에서 `free`로 전이할 수 없다.
- **`unknown`을 `free`로 디스크에 기록하지 않는다.** §2.2.
- **`unknown`에서 fail-open 하지 않는다.** 파일을 지우면 Pro가 되는 설계는 금지다.
- **평생 결제를 어떤 이유로도 박탈하지 않는다.** `expiresAt == null`은 종점이다.
- **`transactionDate`로 만료를 역산하지 않는다.** §2.5 — grace·hold·pause·가격 변경 아래에서 틀린다.
- **어댑터가 `StoreConfirmation.confirmedExpired`를 만들지 않는다.** 서버 없이 그 값을 만들 수 있는 Billing 응답 코드가 없다(§2.6).
- **유료 고객 화면에 `만료`를 띄우지 않는다** — 스토어가 실제로 만료를 확인해 준 경우를 제외하고. v1에서 그 경우는 발생할 수 없다.
- **권한 확인으로 튜너를 막지 않는다.** 스피너 없음, 게이트 없음, 스플래시 없음. 라디오를 끈 상태에서 튜너가 동작해야 한다.
- **권한 확인을 오디오 경로에 넣지 않는다.**
- **권한 필드를 `app_preferences.dart`에 추가하지 않는다.** §2.4.
- **`packages/tuner_domain`에 결제 코드를 넣지 않는다.** `AGENTS.md:14`가 이 패키지를 음정 매핑·페그 방향·장력 수학으로 정의한다. 넓히려면 커밋 1에서 근거와 함께 개정하라. 조용한 확장은 금지다(§2.3).
- **`packages/tuner_dsp`와 `packages/tuner_domain`에 Flutter를 import하지 않는다.**
- **`tuning_session.dart`의 `isComplete`에 결제 로직을 넣지 않는다.** 도메인 진실이며 Flutter를 모른다.
- **`license_audit.ps1`에 허용 목록을 만들지 않는다.** 오늘 없고, 앞으로도 없다(§9). GPL 히트는 우회 대상이 아니라 해결할 발견이다.
- **`design_playbook_compliance_test.dart`의 `_legacyThemeAllowlist`는 이미 빈 집합이다. 빈 채로 유지한다.**
- **대체 결제(인앱결제 강제 금지법 경로)를 쓰지 않는다.** §4.4대로 순손실이다.
- **Apple 한국 서드파티 결제를 쓰지 않는다.**
- **Firebase OIDC / Identity Platform 경로를 쓰지 않는다** — 단, 이 기각의 유일한 근거인 MAU 가격이 `[검증 필요]`임을 인지한다(§5.2).
- **무료 체험 → 자동 갱신 다크 패턴을 쓰지 않는다.** 취향이 아니라 법이다 — 전자상거래법의 숨은 갱신 금지(§7.3).
- **해지 어포던스를 방해하지 않는다.** "취소·탈퇴 방해"는 명시적으로 금지된 다크패턴이다(§7.3).
- **이미 무료로 배포된 기능을 회수하지 않는다.** §3.6.
- **검증된 곡이 0건인 채로 카탈로그 파생 SKU를 출시하지 않는다.** §3.5 / `ui-plan.md` P0-6.
- **라이선스를 확인 없이 기재하지 않는다.** §4.5의 절차 3으로 LICENSE 파일을 직접 읽은 뒤에만 쓴다. GPL/AGPL/LGPL은 코드·패키지·테스트 픽스처 어떤 형태로도 금지다.
- **버전 번호를 확인 없이 `pubspec.yaml`에 쓰지 않는다.** §4.5의 절차 1.
- **정확도를 단일 숫자로 광고하지 않는다.**

---

## 11. Verification matrix

**주입 시계는 릴리스 빌드에 존재하지 않는다.** 이전 초안은 "비행기 모드로 t+0 / t+61일 / t+10년 (주입 시계)"를 *삼성 실기기 수동* 행에 넣었다. 그것은 디버그 동작을 검증하는 것이지 출하 동작을 검증하지 않는다. 두 열을 분리한다.

| 계약 | 자동 (주입 시계 허용) | 수동 (삼성 실기기, 릴리스 빌드) |
| --- | --- | --- |
| 평생 권한은 만료되지 않는다 | `entitlement_resolver_test.dart: lifetime entitlement never expires even ten years offline` | 비행기 모드 콜드 런치, 구매 후 7일 경과 후 재확인 |
| 구독은 오프라인 60일을 견딘다 (예약 계약) | `entitlement_resolver_test.dart: subscription stays pro for sixty days past expiry while offline` | **해당 없음 — v1에 구독 없음 (§2.5)** |
| 시계 되감기가 구독을 연장하지 못한다 | `entitlement_resolver_test.dart: clock rollback cannot extend a subscription past its expiry` | **기기 날짜 수동 변경** (릴리스 빌드에서 가능한 유일한 시계 조작) |
| 네트워크 실패가 권한을 바꾸지 않는다 | `entitlement_resolver_test.dart: network failure never mutates the cached entitlement record` | 기내 모드에서 앱 재시작 3회 |
| 판정기가 Flutter를 모른다 | `entitlement_resolver_test.dart: entitlement resolver source imports no flutter library` | — |
| `unknown`이 `free`로 기록되지 않는다 | `entitlement_store_test.dart: entitlement store never writes a free record over an unreadable file` | `entitlement.v1.json`과 `.bak`을 adb로 손상 후 앱 실행 |
| 저장소 손상 복구 | `entitlement_store_test.dart: entitlement store falls back to backup after primary corruption` | — |
| high water 쓰기 주기 | `entitlement_store_test.dart: high water mark advances at most once per foreground` | — |
| 로그인 강제 없음 | `no_forced_login_test.dart: app reaches the tuner without any account prompt` | 콜드 인스톨 후 튜너 도달까지 계정 화면 0회 |
| 의존성 허용 목록 | `no_forced_login_test.dart: production dependencies stay on the offline allowlist` | — |
| 튜너에 권한 게이트 없음 | `no_forced_login_test.dart: tuner sources contain no entitlement gate` | 비행기 모드 + 무권한 상태에서 6현 튜닝 완주 |
| 튜닝 CTA 인접 업셀 없음 | `no_forced_login_test.dart: no upsell renders between the quick tune panel and the song search label` | 홈 화면 촬영 |
| 정확도 무료 | `entitlement_gate_test.dart: tuner and every accuracy surface stay free with an empty entitlement` | 무권한 상태 전 화면 순회 |
| `unknown` 카피 | `entitlement_gate_test.dart: pro surfaces lock without an upsell when entitlement is unknown` | 손상 파일 상태에서 Pro 화면 촬영 |
| 어댑터가 만료를 단정하지 않는다 | `entitlement_gate_test.dart: store purchase adapter never reports confirmed expired` | — |
| 완료 시트 회귀 | `widget_test.dart:936-951` (`'6현 모두 완료!'`, `tune-complete-glyph`) — **골든이 아니다 (§7.6.4)** | 완료 시트 촬영 |
| BPM 실패 구분 | `song_bpm_test.dart: song bpm index distinguishes an unknown song from a failed load` | BPM 에셋 제거 빌드에서 연습 루프 진입 |
| 병합 매니페스트 권한 | `release_readiness.ps1: android_merged_internet` (+ `-SelfTest`) — **`check.ps1`에서는 커밋 17 이후에만 실행됨** | **릴리스 APK 병합 매니페스트 육안 확인 → §12.11에 답한다** |
| 라이선스 게이트 (Dart) | `tool/license_audit.ps1` (수정 없이) | — |
| 라이선스 게이트 (네이티브) | **없음** | **`com.android.billingclient:billing` 수동 확인 — 스크립트가 열지 않는다** |
| AGP 9 호환성 | 없음 | **릴리스 Gradle 빌드 (커밋 14의 첫 작업)** |
| 페이월 UI가 플레이북을 따른다 | `design_playbook_compliance_test.dart` | 6테마 전부에서 페이월 촬영 후 플레이북 대조 |
| 튜너 골든 | `precision_tuner_golden_test.dart` (abyss/paper/clipping) — 이 계획은 이 골든을 건드리지 않는다 | — |
| 구매 → 복원 | `store_purchase_adapter_test.dart` | **Play 라이선스 테스터로 실제 평생 구매 → 앱 삭제 → 재설치 → 복원.** ⚠ 릴리스 서명 내부 트랙 업로드가 필요하며(`C:\toauner\docs\android-release-signing.md`), **§12의 차단 항목 1~3(사업자등록·세무·SBP)이 해소되기 전에는 실행할 수 없다.** |
| 사업자등록 / VAT | 없음 | **세무사 확인. 자동화 불가.** |
| 청약철회 / 숨은 갱신 | 없음 | **법률 검토. 자동화 불가.** |
| PIPA / 만14세 | 없음 | **v1은 수집이 없으므로 시험 1 해당 없음.** Target audience 선언은 별개 산출물(§7.1). |

---

## 12. 열린 질문 / 사용자 결정 대상

### 차단 항목 (지금 시작해야 한다)

1. **사업자등록 (BRN).** **양대 스토어 공통의 진짜 차단 항목이며, 집행자는 Apple이다.** Apple은 한국 소재 개인·조직 모두에게 BRN을 요구하고 미제공 시 한국 스토어 앱 제거 또는 지급 보류를 명시한다 `[검증 필요 — Apple 한국 컴플라이언스 페이지]`. 첫 유료 릴리스를 차단한다.
2. **세무사 선임.** 스토어별 VAT 모델링 — Google은 우리가 MOR가 아니고, Apple은 MOR다. 총액 기준 신고, Apple 커미션 매입세액공제(검증된 BRN 필요). 코드 문제가 아니다(§7.5).
3. **Apple Small Business Program 등록.** 무료. **근거는 1년차 구독 차액이 아니라 평생 SKU에 영구히 적용되는 15%p다**(§4.4). §4.6이 평생을 v1의 유일한 SKU로 만들었으므로 이것이 SBP 가치의 대부분이다.
4. **`privacy-policy.md` / `play-data-safety.md`의 메타데이터.** `developer_name`, `privacy_contact`, `public_url`, `effective_date`, `reviewed_by`. **커밋 16과 커밋 17이 여기에 막혀 있다.** 커밋 17 없이는 이 계획의 게이트 강화가 전부 상징이다(§7.6.1).
5. **검증된 곡 20개.** `ui-plan.md` P0-6. **0건이면 카탈로그 파생 Pro를 팔 것이 없다**(§3.5).
6. **법률 검토 — 청약철회(제17조)와 숨은 갱신 금지.** 평생 SKU의 7일 철회권 처리, 무료 티어가 시험 사용 상품에 해당하는지. **추론으로 대체하지 않는다**(§7.3).

### 통신판매업 신고 — 차단 항목에서 강등

7. **통신판매업 신고는 면제 가능성이 높다.** 전자상거래법 제12조 제1항 단서 + 면제 고시가 **직전 연도 50회 미만** 또는 **간이과세자** 중 하나면 면제한다 `[검증 필요 — 공정거래위원회 / 관할 구청]`. 1년차 간이과세자 개인은 두 요건을 모두 충족한다. **실행:** (a) 관할 세무서에 앱 개발업의 간이과세 배제업종 여부 확인, (b) 관할 구청에 면제 기준 확인, (c) **2년차 의무로 다이어리에 기록**(1년차 판매가 50건을 넘기는 순간 발효). 이전 초안의 "사업자등록 → 통신판매업 신고 → 콘솔 전환 → 출시" 순서는 재도출 대상이다.
8. **Play Console 개인→개인사업자 전환이 실제로 필요한가** `[검증 필요]`. Google의 계정 분류는 개인/조직이고 개인사업자가 자명하게 조직인 것은 아니다.

### 아키텍처 결정

9. **평생 전용으로 진짜 오프라인을 유지할 것인가, 구독을 팔기 위해 네트워크 의존성을 받아들일 것인가?**
   §2.5가 이 질문을 강제한다: `in_app_purchase` + 서버 없음 아래에서 `expiresAt`을 얻을 수 없으므로 **구독은 구현 불가능하다.** 선택은 (a) 평생 전용, (b) RevenueCat, (c) Play Developer API 서버다. **이 문서의 권고는 (a)다. 사용자만 답할 수 있다.**
   이전 판의 질문("네트워크 요청을 하지 않는다는 것이 제품 약속인가, 구현 세부사항인가?")은 결정을 잘못 표현했다 — 폐기한다.
10. **§3.6 확인 — 곡별 BPM 자동 적용을 무료로 유지하는가?** 기본값: 유지, 연습 루프만 Pro.
11. **`TunerToleranceMode.pro`의 사용자 표기.** 커밋 5의 기본값은 `정밀`이다. 다른 단어를 원하면 지정한다. **커밋 5를 기다리게 하지 않는다** — 현재의 '프로'가 더 나쁘다(§3.2).

### 가격 (전부 검증 필요, 사용자 결정)

12. **평생 ₩39,000~49,000.** v1의 유일한 SKU. Play 가격 실험 필요.
13. 월간 ₩4,900 / 연간 ₩29,000~39,000 — **§12.9가 (b) 또는 (c)로 결정될 때만 유효하다.**
14. **무료 체험을 넣을 것인가?** §4.6은 넣지 말 것을 권한다. **이것은 취향 결정이 아니다 — 체험은 전자상거래법의 30일 사전 동의 플로우를 하드 빌드 요구사항으로 수입한다**(§7.3). 이전 초안의 "데이터가 답할 수 없는 전략 결정"이라는 분류는 오분류였다.

### 외부 확인 필요 `[검증 필요]`

15. **`in_app_purchase` / `in_app_purchase_android` / `in_app_purchase_storekit`의 실제 버전과 라이선스** — §4.5의 절차 1~3. **커밋 14를 차단한다.**
16. **`com.android.billingclient:billing` 라이선스** — `license_audit.ps1`이 열지 않는다. 수동 확인. **커밋 14를 차단한다.**
17. **AGP 9 / Gradle / Kotlin 대 `in_app_purchase_android` 호환성** — 릴리스 Gradle 빌드로 확인. **커밋 14를 차단한다.**
18. **병합 릴리스 매니페스트에 실제로 주입되는 권한** — INTERNET인가, `com.android.vending.BILLING`인가, 둘 다인가. 커밋 3의 검사가 두 문자열을 모두 열거하고, 커밋 14의 첫 릴리스 빌드가 답한다. **커밋 14를 차단한다.**
19. **`in_app_purchase`가 Play Data Safety의 "구매 내역" 수집 선언을 유발하는가** — §7.1에 양쪽 주장을 기록했다. **커밋 16을 차단한다.** §4.3은 이 답에 의존하지 않는다.
20. **iOS In-App Purchase capability와 최소 iOS 버전** — §4.5의 절차 6.
21. **Play Target audience & content 선언 + IARC 콘텐츠 등급** — 둘 다 필수 산출물이고 저장소에 없고 `release_readiness.ps1`이 검사하지 않는다(§7.1).
22. **한국 결제 수수료 %** — 미발표. 방통위 과징금 절차 미결. Google의 한국 수수료 인하 공개 언급. **셋 다 우리 통제 밖이다. 현재는 15% 고정으로 모델링한다.** Q4 2026 재확인.
23. **Apple 한국 MOR 취급의 정확한 메커니즘** — Apple이 한국 MOR라는 것은 §7.5에 기록했으나, 세금계산서·매입세액공제 절차는 첫 정산 전에 Apple에 직접 확인한다. **Google과의 대칭을 가정하지 않는다.**
24. **KRW 최소 가격 / 가격 사다리 / 한국 인앱 최대 가격** — 미확인.
25. **RevenueCat 캐시 TTL: 3일 vs 영원** — 문서 자기모순 보고. **§12.9가 (b)로 결정될 경우 설계 확정 전 지원 티켓.**
26. **Firebase Identity Platform의 OIDC/SAML MAU 가격** — §5.2의 기각이 이 수치 하나에 걸려 있다. 그 경로를 재검토할 때 가장 먼저 확인한다.
27. **네이버 OIDC 지원 여부 / 네아로의 연령 필드** — 확인 불가. 전제로 설계하지 않는다.
28. **한국 소셜 로그인 점유율 (카카오 vs 네이버)** — **공개 검색에 인용 가능한 출처가 존재하지 않는다.** 카카오톡 메신저 이용률, 네이버 검색 점유율 등은 **다른 지표**이며 로그인 점유율로 세탁하지 않는다.

### 해소되어 종결된 항목

29. **PIPA 벌칙 수치 — 종결.** 제71조가 제22조의2 제1항 위반을 **5년 이하 징역 또는 5천만원 이하 벌금**으로 처벌한다. 별도로 제75조 과태료(1천만원 이하)가 동의 방법 위반에 붙는다. 이전 초안은 이 항목에서 유일하게 *과소* 확신했다. 열린 질문에서 제거한다.
30. **Apple MOR 대칭성 — 종결.** 대칭이 아니다. Apple은 한국 MOR이고 Google은(한국 거주 개발자에 대해) 아니다. §7.5에 반영됨.

---

## 13. 완료 체크리스트

- [ ] 커밋 1~16이 각각 독립적으로 되돌려지고, 각 커밋 이후 `C:\toauner\tool\check.ps1`이 초록이다
- [ ] `app/test/no_forced_login_test.dart`의 테스트 5개가 통과한다 (`Pro` 부분 문자열을 검사하지 않는다 — 53회 오탐)
- [ ] `app/test/entitlement_resolver_test.dart`의 테스트 9개가 통과하고, `entitlement_resolver.dart`에 `package:flutter` import가 0이다
- [ ] `app/test/entitlement_store_test.dart`의 테스트 7개가 통과한다
- [ ] `app/test/entitlement_gate_test.dart`의 테스트 8개가 통과한다
- [ ] `app/test/song_bpm_test.dart`가 "BPM 미상"과 "인덱스 로드 실패"를 구분한다
- [ ] `tool/release_readiness.ps1 -SelfTest`가 `android_merged_internet`을 포함해 통과하고, blocker 목록 자기 테스트가 갱신되었으며, **debug/profile variant에서 오발화하지 않는다**
- [ ] `tool/license_audit.ps1`이 **수정 없이** `in_app_purchase` 전이 그래프에서 통과한다 (허용 목록을 추가하지 않았다)
- [ ] `com.android.billingclient:billing`의 라이선스가 **수동으로** 확인되어 `docs/ATTRIBUTIONS.md`에 명시되었다
- [ ] `pubspec.yaml`의 `in_app_purchase` 버전이 **§4.5의 절차 1로 해석된 실제 값**이고, 라이선스가 **읽은 LICENSE 파일**에 근거한다
- [ ] 릴리스 Gradle 빌드가 **AGP 9에서 성공**했고, 병합 매니페스트의 실제 권한이 §12.18에 기록되었다
- [ ] `docs/design-playbook.md`와 `docs/ui-plan.md`에 페이월/Pro 절이 있고, 6개 테마(abyss, onyx, amber, violet, paper, clipping) 전부에 Pro 토큰이 선언되었다
- [ ] `app/test/design_playbook_compliance_test.dart`를 페이월 UI가 전부 통과한다 (아이콘 3개 제한 포함 — 닫기는 텍스트 `'×'`, `song_search_screen.dart:336` 참조), `_legacyThemeAllowlist`가 **여전히 빈 집합**이다
- [ ] `app/lib/src/tuner/`의 4개 파일에 `entitlement` 참조가 **0건**이고, 예외 목록이 존재하지 않는다
- [ ] 커밋 5가 톨러런스 라벨을 `정밀`(또는 사용자 지정어)로 바꿨고, 정확도 관련 표면에 결제 티어 단어가 렌더되지 않는다
- [ ] `docs/privacy-policy.md`에 **청약철회 절**이 있고, `play-data-safety.md`의 `:14` 결론이 §12.19의 답에 근거해 확정되었으며, "toauner" 잔여 표기가 정리되었다
- [ ] Play **Target audience & content 선언**과 **IARC 콘텐츠 등급**이 완료되었고, 그 근거가 기록되었다
- [ ] **삼성 실기기, 비행기 모드**에서 무권한 상태로 6현 튜닝을 완주했다 (계정 화면 0회, 스피너 0회)
- [ ] **삼성 실기기, 릴리스 빌드**에서 `entitlement.v1.json`과 `.bak`을 손상시킨 뒤 앱이 `구매 확인 중`을 표시하고 **파일을 덮어쓰지 않았다**
- [ ] **삼성 실기기**에서 Play 라이선스 테스터로 **평생** 상품 구매 → 앱 삭제 → 재설치 → 복원이 성공했다 (§12 차단 항목 1~3 해소 이후)
- [ ] **삼성 실기기, 릴리스 빌드**에서 기기 날짜를 되감아도 권한 판정이 §2.6의 `effectiveNow` 규칙과 일치한다
- [ ] 사업자등록(BRN)이 완료되어 **Play Console과 App Store Connect 양쪽**에 등록되었다
- [ ] 통신판매업 신고 **면제 여부**가 관할 구청/세무서에서 확인되었고, 해당하면 **2년차 의무로 기록**되었다
- [ ] Apple Small Business Program 등록이 완료되었다
- [ ] 검증된 곡이 **0건이 아니다** (`ui-plan.md` P0-6)
- [ ] 청약철회와 숨은 갱신 금지에 대한 **법률 검토**가 완료되었다
- [ ] §12의 차단 항목 1~6, 아키텍처 결정 9~11, 외부 확인 15~19에 답이 있다
- [ ] **커밋 17이 랜딩되어 `check.ps1`이 `release_readiness.ps1 -Strict`를 실제로 실행하고 초록이다** — 이것 없이는 이 계획의 게이트 강화가 전부 상징이다