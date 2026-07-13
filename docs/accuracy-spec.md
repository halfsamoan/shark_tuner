# 피치 정확도 및 성능 규격

## 목적

`±1 cent`라는 한 숫자로 서로 다른 환경을 섞지 않는다. 합성 신호는 알고리즘의 수치 정확도를, 녹음된 실제 기타는 음색·배음·어택에 대한 강건성을, 라이브 기기는 마이크와 OEM 오디오 처리까지 포함한 제품 성능을 검증한다.

모든 결과에는 앱/코어 버전, 기기, 입력 경로, 실제 샘플레이트, 창 크기, 튜닝, 기준 측정 방법을 기록한다.

## 공통 지표

- cents error: `1200 * log2(estimatedHz / referenceHz)`.
- absolute error의 median, p95, maximum.
- octave error rate: 기준 주파수의 0.48~0.52배 또는 1.9~2.1배로 잠긴 비율.
- valid estimate rate와 lock까지 걸린 시간.
- 신호가 기준을 충족하지 못해 결과를 내지 않은 비율. 무리한 추정과 구분한다.

## Gate S1 — 결정적 합성 신호

대상은 48 kHz로 생성한 43~1,318 Hz 신호다. 테스트 주파수는 정확한 음뿐 아니라 ±3, ±17, ±49 cents 오프셋을 포함한다.

| 신호군 | 조건 | 합격 기준 |
|---|---|---|
| 순수 사인파 | 안정 구간, SNR 40 dB 이상 | median ≤ 0.5 cent, p95 ≤ 1.0 cent, max ≤ 1.0 cent, 미검출 0, octave error rate 0 |
| 배음 혼합 | 기본음이 가장 강하지 않은 기타형 배음 | median ≤ 1.0 cent, p95 ≤ 2.0 cents, octave error < 0.1% |
| 잡음/레벨 변화 | SNR 20 dB 이상, 진폭 변화 | p95 ≤ 3.0 cents 또는 명시적 no-estimate |
| 무음/비정상 입력 | 무음, NaN, 너무 짧은 창 | 유효 피치를 반환하지 않음 |

S1의 `±1 cent`는 순수 사인파 p95 기준이다. 실기타 성능을 의미하지 않는다.
순수 사인파 코퍼스는 기본 경로인 4,096 samples와 저튜닝 경로인 8,192 samples에서 각각 위 조건을 모두 통과해야 한다.

## Gate G1 — 녹음된 실제 기타 WAV

DI 신호 또는 교정된 레퍼런스 튜너로 기준을 남긴 WAV 코퍼스를 사용한다. 최소 범위는 6현 개방현, 강/약 피킹, 오래된 현/새 현, 픽업 위치, A1/F#1 저튜닝을 포함한다.

| 구간 | 안정 구간 합격 목표 |
|---|---|
| E2~E4 일반 기타 | median ≤ 1.0 cent, p95 ≤ 3.0 cents |
| 43~82 Hz 저튜닝 | median ≤ 2.0 cents, p95 ≤ 3.0 cents |
| 어택 직후 | 정확도 집계에서 제외하되 no-estimate/hold 상태가 명확해야 함 |

전체 코퍼스의 octave error 목표는 0.5% 미만이며, 현/기타/피킹별 결과를 함께 보고한다. 목표 미달 신호를 평균값으로 숨기지 않는다.

### 정보성 사용자 실기타 코퍼스

`user-guitar-samsung-sm-s926n-20260713-v1`은 휴대전화 녹음 앱과 교정되지 않은 모바일 튜너로 수집한 강건성 회귀 자료다. 기준값은 A4=440 Hz의 명목 MIDI 중심 주파수이며 서브센트 레퍼런스가 아니다. 원본 일부의 클리핑과 녹음 앱의 처리 경로도 완전히 통제되지 않았다.

따라서 이 코퍼스는 G1 게이트에 포함하지 않고 정보성으로만 보고한다. 표준/반음 내림, 현, 피킹 강도, 클리핑 유무별 valid estimate rate, octave error, 50 cents 초과 오류, 명목 음정 편차, 자기일관성을 확인할 수 있지만 `±1~3 cents` 제품 정확도나 G1 통과의 근거로 사용하지 않는다. 수집·변환·권리 정보는 `docs/user-guitar-corpus-2026-07-13.md`를 따른다.

## Gate D1 — 실제 모바일 기기 라이브 입력

조용한 방과 일반 생활 소음 환경을 분리한다. 최소 Android 기기 2대, 그중 삼성 1대를 포함한다. 각 기기에서 UNPROCESSED와 실제 폴백 경로를 기록한다.

- 조용한 방의 안정 구간: E2~E4 p95 ≤ 3 cents, 43~82 Hz p95 ≤ 5 cents 목표.
- 일반 생활 소음: 결과를 낸 프레임 p95 ≤ 5 cents 또는 신뢰도 부족 상태로 정직하게 강등.
- 실제 샘플레이트 불일치가 발견되면 보정 전에는 합격으로 처리하지 않는다.
- 픽킹부터 첫 유효 프레임, 잠금 완료까지의 지연을 정확도와 별도 지표로 기록한다.

## UI 표현 원칙

- 계산값을 0.1 cent로 표시할 수 있어도 검증된 환경 정확도보다 정밀하다고 주장하지 않는다.
- confidence나 신호 품질이 부족하면 바늘을 억지로 고정하지 않고 `신호 확인 중` 또는 `안정화 중`을 표시한다.
- 제품 문구에는 측정 환경을 붙인다. 예: `합성 기준 p95 ±1 cent`, `실기타 목표 ±1~3 cents`.

## 회귀 규칙

- 알고리즘 또는 핵심 파라미터를 바꾸는 PR은 S1 전체 결과와 G1의 고정 코퍼스 결과를 첨부한다.
- median이 좋아져도 octave error, no-estimate, 지연 중 하나가 악화되면 회귀로 검토한다.
- 실기기 결과는 CI를 대체하지 않으며, CI 합성/WAV 테스트도 실기기 검증을 대체하지 않는다.

S1 순수 사인파의 재현 가능한 수치 리포트는 다음 명령으로 생성한다.

```powershell
Set-Location packages\tuner_dsp
& ..\..\.tools\flutter\bin\dart.bat run tool\synthetic_accuracy_report.dart
```

G1 실기타 WAV는 `packages/tuner_dsp/test/fixtures/guitar/manifest.v1.json`에 등록한 뒤 다음 명령으로 강제한다. 빈 코퍼스는 `missing_corpus`로 보고하며 `--require-corpus` 사용 시 성공 처리하지 않는다.

```powershell
Set-Location packages\tuner_dsp
& ..\..\.tools\flutter\bin\dart.bat run tool\guitar_accuracy_report.dart --require-corpus
```
