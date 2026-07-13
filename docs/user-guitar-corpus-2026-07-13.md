# 사용자 실기타 코퍼스 세션 — 2026-07-13

## 용도와 판정 범위

세션 ID는 `user-guitar-samsung-sm-s926n-20260713-v1`이다. 통기타 개방현
19개를 사용자 제공 실기타 강건성 회귀 자료로 보존한다. 이 세션은
교정된 주파수 레퍼런스를 사용하지 않았으므로 정보성 코퍼스이며 G1
게이트, 서브센트 정확도 검증, 제품 정확도 홍보에 사용하지 않는다.

## 수집 환경

- 기기: Samsung SM-S926N
- 녹음 앱: [Voice Recorder - XVoice](https://play.google.com/store/apps/details?id=recorderpro.voicememos.audio), 패키지 `recorderpro.voicememos.audio`, 버전 미상
- 녹음 형식: 44.1 kHz, mono, PCM16
- 기준 튜너: [TarrySoft Guitar Tuner](https://play.google.com/store/apps/details?id=lior.hai.soundanalyzertest), 패키지 `lior.hai.soundanalyzertest`, 버전 미상
- 기준 설정: 기본 A4=440 Hz로 기록
- 권리: 프로젝트 제공 사용자 녹음(`project_provided_user_recording`)

원본 19개의 파일 확장자는 `.mp3`지만 파일 시그니처와 내부 포맷은 모두
RIFF/WAVE PCM16이다. 입력 판정은 확장자가 아니라 시그니처로 하며 이
불일치를 각 픽스처 provenance에 남긴다. 원본은
`datasets/user_guitar/` 아래에 수정 없이 보존하고 Git에는 포함하지
않는다.

## 라벨과 기준 주파수

한글 파일명은 자동 파싱하지 않는다. 매핑은
`packages/tuner_dsp/tool/corpus/user_guitar_session_20260713.v1.json`에
19개 모두 명시한다.

- 표준 튜닝: 13개
- 반음 내림: 6개 — E♭2, G♯2, C♯3, F♯3, B♭3, E♭4
- 피킹: hard 12개, medium 6개, soft 1개
- `E샵 82hz 강 6번줄`은 사용자 확인에 따라 E♭2/D♯2(MIDI 39,
  77.7817459 Hz)로 교정한다. 원래 82 Hz 표기는
  `sourceLabelCorrection`과 `annotatedFrequencyHz`에 보존한다.

`nominalFrequencyHz`는 MIDI와 A4=440 Hz에서 계산한 정확한 명목
주파수다. `annotatedFrequencyHz`는 파일명에 적힌 반올림 값이며,
`referenceKind`는 `uncalibrated_mobile_tuner_nominal_center`다. toauner의
자체 검출 결과를 기준 주파수로 재사용하지 않는다.

## 결정적 변환

`tool/prepare_corpus.dart --profile=ci`는 다음 순서로 ASCII 파일명의
48 kHz mono PCM16 WAV 19개를 생성한다.

1. RIFF/WAVE 시그니처 확인 및 PCM16/mono/44.1 kHz 검증
2. 에너지 상승으로 어택 탐색
3. 어택 250 ms 전부터 4.5초 추출
4. 결정적 cubic Hermite 보간으로 48 kHz 리샘플
5. 진폭 정규화 없이 PCM16 WAVE로 인코딩

분석 안정 구간은 출력의 600~4,000 ms다. E2와 E♭2는 8,192 samples,
나머지는 4,096 samples 분석 창을 사용한다. 매니페스트는 원본/출력
SHA-256, 변환 내역, 어택 위치, 현/음/MIDI/피킹, off-tuning 여부,
피크 dBFS, 클리핑 샘플 수를 기록한다.

## 알려진 데이터 품질 제한

원본 19개 중 13개에는 적어도 한 개의 full-scale 샘플이 있다. 파생
WAV에는 정규화를 적용하지 않고 클리핑 여부를 정보성 세그먼트로
유지한다. 기준 튜너가 교정되지 않았고 녹음 앱의 마이크 처리 및 AGC를
통제하지 않았기 때문에 명목 음정 편차는 앱 검출 오차와 실제 기타의
튜닝 오차를 분리하지 못한다.

`public_corpus_report.dart`는 이 세션을 표준/반음 내림, 현, 피킹 강도,
클리핑 유무별로 나눠 valid estimate rate, octave error, 50 cents 초과
오류, 명목 음정 편차, 안정 구간 자기일관성을 보고한다. M2C 어택·
오버슈트 분석과 D1 `UNPROCESSED` 라이브 입력 검증은 향후 toauner 자체
PCM 저장 경로로 별도 수집한다.
