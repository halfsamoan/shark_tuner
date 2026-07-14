# tuner_audio

toauner의 플랫폼 오디오 입력 교체 지점입니다. 앱과 DSP는 `AudioCapture` 계약만 사용하며 Android/iOS 차이는 이 패키지 안에서 흡수합니다.

## 공통 캡처 계약

- 48 kHz mono PCM16을 요청합니다.
- AGC, echo cancellation, noise suppression을 요청 단계에서 끕니다.
- Bluetooth 경로를 자동 관리하지 않습니다. 정밀 튜닝은 기기 내장 마이크 또는 명시적으로 선택한 유선 입력을 기준으로 합니다.
- 시작 직후 PCM RMS와 플러그인이 보고한 실제 샘플레이트를 검증합니다. 요청값과 실제값이 다르면 DSP 경계에서 실제 샘플레이트를 사용합니다.
- 오디오 인터럽션 후에는 캡처를 재개하도록 요청합니다.

## 플랫폼 정책

Android는 `UNPROCESSED`를 먼저 시도하고, 무음/RMS 프로브에 실패하면 `VOICE_RECOGNITION`으로 폴백합니다. 삼성 기기의 무음 `UNPROCESSED` 경로도 이 프로브로 감지합니다.

iOS는 Android 전용 오디오 소스 이름을 재시도하지 않고 플랫폼 기본 입력을 한 번 사용합니다. `AVAudioSession` category option은 비워 두어 Bluetooth 및 스피커 경로가 암묵적으로 추가되지 않게 하고, 인터럽션 정책은 `pauseResume`으로 고정합니다.

플랫폼별 기본값은 `AudioCaptureConfig.forPlatform`에서 만들고, 앱의 `createLiveTunerEngine`이 현재 `TargetPlatform`에 맞는 설정을 주입합니다.
