# G1 실기타 WAV 코퍼스

`manifest.v1.json`에 녹음별 기준 주파수와 안정 구간을 기록하고 WAV 파일을 같은 디렉터리에 둡니다. 파일은 48 kHz, PCM signed 16-bit little-endian WAVE여야 하며 스테레오는 리포트 도구가 모노로 다운믹스합니다.

최소 코퍼스는 6현 개방현 E2~E4, 강/약 피킹, 새 현/오래된 현, 서로 다른 픽업, A1/F#1 저튜닝을 포함합니다. 어택은 정확도 구간에 넣지 말고 `stableStartMs` 이후만 지정합니다. `referenceMethod`에는 DI/교정 튜너 등 기준을 얻은 방법을 적습니다.

```powershell
Set-Location packages\tuner_dsp
& ..\..\.tools\flutter\bin\dart.bat run tool\guitar_accuracy_report.dart --require-corpus
```

빈 매니페스트는 준비 상태만 보고하며 성공으로 가장하지 않습니다. `--require-corpus`는 코퍼스가 비어 있으면 종료 코드 2를 반환합니다.
