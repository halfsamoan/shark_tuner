# 모바일 플랫폼 준비 상태

## 목적

Android에서 검증한 라이브 튜닝 구조를 유지하면서 iOS 이식이 DSP나 화면 구조 변경이 아닌 캡처·권한·기기 제어 어댑터 검증으로 끝나게 한다.

## 공통 계약

- 앱은 `AudioCapture`와 `PitchDetector` 교체 지점만 의존한다.
- 캡처는 48 kHz mono PCM16을 요청하고 실제 샘플레이트를 런타임에 확인한다.
- 지속 DSP는 별도 isolate에서 실행한다.
- 마이크 오류가 나면 스트림, isolate, 캡처 세션을 닫고 재시도 가능한 오류 상태를 표시한다.
- 튜너 화면 진입·이탈에 맞춰 화면 자동 꺼짐 방지를 켜고 해제한다.

## Android

- 입력 소스: `UNPROCESSED` 우선, 무음 프로브 실패 시 `VOICE_RECOGNITION` 폴백.
- 필수 권한: `RECORD_AUDIO`.
- 앱 설정 열기와 화면 켜짐 제어는 Android method channel로 연결돼 있다.
- 삼성 실기기에서 마이크 입력, 자동 현 전환, DSP isolate 경로를 검증했다. 기기별 D1 결과는 `docs/device-profile-2026-07-13.md`에 기록한다.

## iOS

- 입력 소스: 플랫폼 기본 입력 한 개. Android 전용 소스 이름으로 중복 재시도하지 않는다.
- 형식: PCM16, 48 kHz 요청, mono.
- 오디오 세션: 자동 Bluetooth 관리와 category option을 사용하지 않고, 전화·알림 인터럽션 이후 `pauseResume`을 요청한다.
- `NSMicrophoneUsageDescription`이 등록돼 있다.
- 앱 설정 열기와 `UIApplication.shared.isIdleTimerDisabled` 제어가 Android와 같은 Dart 계약으로 연결돼 있다.
- 백그라운드 오디오 모드는 선언하지 않는다. toauner 라이브 튜닝은 전경 기능이다.

## 출시 전 수동 게이트

Windows에서는 iOS 네이티브 빌드와 실기기 오디오를 검증할 수 없다. macOS와 Xcode가 준비되면 다음을 모두 확인한다.

1. `flutter build ios --debug --no-codesign`이 성공한다.
2. 실제 iPhone에서 최초 마이크 권한 허용, 거부, 설정 복귀 흐름이 동작한다.
3. E2~E4와 최소 한 개 다운튜닝 음에서 실제 샘플레이트, 입력 경로, 첫 유효 프레임 지연을 기록한다.
4. 전화 또는 오디오 인터럽션 이후 캡처가 재개되고 오래된 피치 앵커가 남지 않는다.
5. 화면 잠금 방지가 튜너 화면에서만 활성화되고 화면 이탈 시 해제된다.
6. 유선 또는 USB 입력 연결·해제 시 오류로 멈추지 않고 현재 입력 경로를 다시 연다.

iOS 실기기 결과는 합성 S1이나 녹음 코퍼스 G1을 대체하지 않으며, Android 결과로 iOS D1을 통과 처리하지 않는다.
