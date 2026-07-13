# AGENTS.md

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
- 기본 인튠 잠금: 어택 이후 ±3 cents를 750 ms 유지. 초보 모드는 ±5 cents, 프로 모드는 ±1~2 cents.
- 장력: `T = UW * (2 * L * F)^2 / 386.4`, 길이는 inch, 주파수는 Hz, 결과는 lbf.

정확도 합격/실패 조건은 `docs/accuracy-spec.md`를 단일 기준으로 삼는다. 임계값 변경은 테스트와 문서를 함께 수정한다.

## 개발 방식

- 먼저 실패하는 작은 테스트를 추가하고 구현한다.
- 피치 정확도 변경은 합성 코퍼스와 실기타 WAV 코퍼스 결과를 각각 보고한다.
- 옥타브 오류는 평균 센트 오차에 숨기지 않고 별도 비율로 보고한다.
- 샘플레이트, 창 크기, 주파수 하한처럼 결과를 바꾸는 값은 매직 넘버로 흩뜨리지 않는다.
- 곡 검색 결과에서 튜닝 화면으로 전달되는 것은 문자열 이름이 아니라 버전이 있는 `TuningDefinition` 식별자와 스냅샷이어야 한다.
- 페그 방향은 조건문 묶음이 아닌 검증 가능한 데이터/진리표로 표현한다.
- 안정성 진단은 단정하지 않고 관측값과 "가능성"을 분리해 표시한다.

## 검증 명령

Flutter SDK 설치 후 루트에서 실행한다.

```powershell
.\tool\bootstrap.ps1
.\tool\check.ps1
```

앱 실기기 검증은 에뮬레이터가 아닌 Android 실제 기기에서 수행한다. 최소 한 대는 삼성 기기를 포함한다.

## 커밋 규칙

Conventional Commits 형식을 사용한다: `feat:`, `fix:`, `test:`, `docs:`, `refactor:`, `build:`, `ci:`, `chore:`. 서로 독립적으로 되돌릴 수 있는 변경은 한 커밋에 섞지 않는다.
