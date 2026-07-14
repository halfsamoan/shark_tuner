---
release_status: draft
reviewed_build: TBD
reviewed_by: TBD
reviewed_date: TBD
---

# Google Play Data Safety 작성 워크시트

이 문서는 Play Console에 입력할 답변의 저장소 기준안입니다. 최종 답변은 실제 업로드 AAB와 포함된 모든 SDK를 다시 조사한 뒤 확정합니다.

## 현재 빌드 기준 결론

- 사용자 데이터 수집: 아니요
- 사용자 데이터 공유: 아니요
- 계정 생성: 없음
- 광고 또는 분석 SDK: 없음
- 핵심 기능의 서버 통신: 없음
- 마이크 접근: 있음 (`RECORD_AUDIO`), 단 기기 내 실시간 처리만 수행

Google Play은 앱이 기기 안에서만 접근·처리하고 기기 밖으로 전송하지 않는 데이터는 Data Safety의 “수집”으로 신고하지 않아도 된다고 설명합니다. toauner의 마이크 오디오는 이 기기 내 처리 범위에 해당하도록 구현되어 있습니다.

## 데이터 유형별 판단

| 데이터 유형 | 접근 | 기기 밖 전송 | 수집 | 공유 | 목적 | 보관 |
| --- | --- | --- | --- | --- | --- | --- |
| 마이크 오디오 | 사용자가 튜너를 실행하고 권한을 허용한 동안 | 없음 | 아니요 | 아니요 | 음높이·센트·안정성 계산 | 실시간 메모리 버퍼만 사용, 지속 저장 없음 |
| 기타/페그 설정 | 사용자가 앱에서 설정 | 없음 | 아니요 | 아니요 | 페그 방향 안내 | 앱의 로컬 저장소, 앱 데이터 삭제 또는 제거 시 삭제 |
| 곡 검색어 | 사용자가 검색 필드에 입력 | 없음 | 아니요 | 아니요 | 번들 로컬 곡 DB 검색 | 서버 저장 없음 |

## Play Console 답변 메모

1. 앱이 필수 사용자 데이터 유형을 수집하거나 공유하나요? **아니요.**
2. 전송 중 암호화되나요? 사용자 데이터 전송이 없어 해당 없음. Play Console의 실제 문항 흐름에 맞춰 선택합니다.
3. 사용자가 데이터 삭제를 요청할 수 있나요? 계정과 서버 수집 데이터가 없습니다. 로컬 설정은 운영체제의 앱 데이터 삭제 또는 앱 제거로 삭제됩니다.
4. 독립 보안 검토를 받았나요? **아니요**, 실제 검토를 받기 전에는 그렇다고 표시하지 않습니다.

## 최종 제출 전 재검증

- `tool/release_readiness.ps1 -Strict` 대상 빌드와 `reviewed_build`가 일치해야 합니다.
- 릴리스 병합 매니페스트에 예기치 않은 `INTERNET` 권한이 없는지 확인합니다.
- `tool/license_audit.ps1`과 전체 의존성 목록을 다시 확인하고, 새 SDK의 데이터 처리 행위를 별도로 검토합니다.
- 개인정보처리방침의 개발자 이름, 연락처, 공개 URL이 Play 스토어 등록 정보와 일치해야 합니다.
- Play Console 제출 담당자가 검토자와 날짜를 기록한 후에만 `release_status: final`로 변경합니다.

정책 근거: [Google Play Data safety form guidance](https://support.google.com/googleplay/android-developer/answer/10787469), [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311).
