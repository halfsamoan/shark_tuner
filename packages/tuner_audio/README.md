# tuner_audio

toauner의 플랫폼 오디오 입력 교체 지점입니다. 현재는 캡처 계약과 필수 폴백 순서만 정의하며, Android/iOS 구현은 이 API 뒤에 추가합니다.

기본 요청은 48 kHz mono PCM16, AGC/echo cancellation/noise suppression 비활성화, `UNPROCESSED → VOICE_RECOGNITION` 순서입니다. 구현은 시작 직후 RMS와 실제 샘플레이트를 검증한 뒤 유효하지 않은 소스를 폴백해야 합니다.
