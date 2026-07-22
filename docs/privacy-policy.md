---
release_status: final
developer_name: SharkTune
privacy_contact: arego1106@gmail.com
public_url: https://sharktune-support.kimkyungmun.chatgpt.site
effective_date: 2026-07-19
---

# SharkTune 개인정보처리방침 / Privacy Policy

SharkTune는 곡별 튜닝 검색과 기타 튜닝을 제공하는 모바일 앱입니다. 이 문서는 앱이 마이크와 기기 내 데이터를 어떻게 처리하는지 설명합니다.

## 마이크 오디오

toauner는 사용자가 튜너 또는 튜닝 안정성 진단을 시작하고 운영체제의 마이크 권한을 허용한 동안에만 마이크 입력에 접근합니다. 입력된 오디오는 음높이, 센트 편차 및 튜닝 안정성 관측값을 계산하기 위해 사용자의 기기 메모리에서 실시간으로 처리됩니다.

- 마이크 오디오는 녹음 파일로 저장하지 않습니다.
- 마이크 오디오 또는 그 원본 샘플을 개발자나 제3자의 서버로 전송하지 않습니다.
- 광고, 사용자 추적, 프로파일링 또는 모델 학습에 사용하지 않습니다.
- 튜너 처리가 끝나면 해당 실시간 오디오 버퍼는 더 이상 보유하지 않습니다.

## 기기에 저장되는 정보

앱은 선택한 기타의 페그 배치와 방향 보정 같은 설정을 기기 내부에 저장할 수 있습니다. 사용자가 줄 관리 기능을 이용하면 줄 설치일, 사용자가 정한 점검 주기, 입력한 게이지와 당시 튜닝 식별자를 앱 전용 저장 공간에 기록합니다. 모든 현을 맞춘 경우 완료 시각, 걸린 시간, 튜닝 식별자·버전·이름, 현 수와 사용자가 선택한 곡명·아티스트를 튜닝 기록에 최대 100회 저장합니다. 튜닝 기록에는 오디오 원본이나 프레임별 음높이 측정값이 포함되지 않습니다. 곡명, 아티스트, 튜닝 및 카포 정보는 앱에 포함된 로컬 데이터베이스에서 검색합니다. 이 정보와 사용자의 설정은 개발자 서버로 전송되지 않습니다.

앱은 계정을 만들지 않으며, 이름·이메일 주소·전화번호·정밀 위치·연락처·결제 정보를 수집하지 않습니다. 광고 및 사용 분석 SDK도 포함하지 않습니다.

## 공유 및 판매

SharkTune는 사용자 데이터를 수집하여 제3자에게 공유하거나 판매하지 않습니다. 현재 앱은 핵심 기능을 위해 인터넷 연결을 요구하지 않습니다.

## 보관 및 삭제

마이크 오디오는 지속적으로 보관하지 않습니다. 줄 설치 기록은 앱의 줄 관리 화면에서, 튜닝 완료 기록은 앱의 튜닝 기록 화면에서 사용자가 직접 모두 삭제할 수 있습니다. 그 밖에 기기에 저장된 설정과 기록은 사용자가 앱 데이터를 삭제하거나 앱을 제거할 때 삭제됩니다. 계정과 서버 저장 데이터가 없으므로 별도의 계정 삭제 절차는 없습니다.

## 보안

마이크 처리는 운영체제의 앱 샌드박스 안에서 수행됩니다. 앱은 필요한 시점에 운영체제의 런타임 권한 절차를 통해 마이크 접근을 요청합니다. 서버 전송이 없으므로 마이크 오디오의 네트워크 전송 경로도 없습니다.

## 방침 변경

향후 클라우드 동기화, 분석, 광고, 오디오 저장 또는 전송 기능을 추가한다면 해당 기능을 배포하기 전에 이 방침과 앱 내 고지를 갱신하고 필요한 동의를 받습니다.

## 문의

개인정보 관련 문의처: `arego1106@gmail.com`.

## 출시 전 완료 항목

- `public_url`이 공개 접근 가능하고 지역 제한이 없으며 PDF가 아닌 HTTPS 페이지인지 확인합니다.
- 최종 업로드 빌드와 문서 내용이 일치하는지 검토한 뒤 `release_status: final`로 변경합니다.

정책 근거: [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311), [Google Play Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469).

---

# Privacy Policy (English)

**Effective date:** 19 July 2026
**Developer:** SharkTune
**Privacy contact:** arego1106@gmail.com

SharkTune is an offline guitar-tuning app. This policy explains how the app
handles microphone input and information stored on the device.

## Microphone audio

SharkTune accesses the microphone only while the user starts tuning or a tuning
stability check and grants the operating-system permission. Audio is processed
in real time in device memory to calculate pitch, cent deviation, and stability
observations.

- We do not save microphone audio as recordings.
- We do not send microphone audio, raw samples, or pitch frames to SharkTune or
  any third party.
- We do not use microphone audio for advertising, tracking, profiling, or model
  training.
- The real-time audio buffer is not retained after processing ends.

## Information stored on your device

The app may store an instrument's peg layout and direction calibration, string
care entries, and up to 100 tuning-completion history items in its private local
storage. Song, artist, tuning, and capo data are bundled in the app for local
search. We do not create accounts and do not collect names, email addresses,
phone numbers, precise location, contacts, payment information, or analytics.

## Sharing, deletion, and contact

SharkTune collects, sells, and shares no user data. There is no account or
server-held user data, so a separate deletion request is not required. You can
delete string-care and tuning-history records inside the app; deleting app data
or uninstalling the app removes remaining local settings. For questions, email
arego1106@gmail.com.

If a future release adds cloud sync, analytics, ads, audio storage, or data
transfer, we will update this policy and provide any required notice before that
release.
