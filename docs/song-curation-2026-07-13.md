# 곡 시드 출처 감사 — 2026-07-13

## 상태

`data/songs/candidates.v1.json`의 20곡은 곡별로 서로 다른 URL 두 개를
저장했고, 튜닝·카포 사실이 두 출처에서 일치하는지 확인했다. 출처 확인은
Codex가 수행했다. 후보 원본은 감사 이력 보존을 위해 모든 레코드를
`needs_human_review`, 루트를 `shippingEligible: false`로 유지한다.

2026-07-14 프로젝트 소유자가 이 작업에서 **모든 곡 승인**을 명시했다.
승인 결과는 `data/songs/catalog.v1.json`에 승인자 역할
`project-owner`, 승인 날짜, 전량 승인 범위와 함께 별도로 기록한다.
출시 카탈로그의 20곡은 모두 `verified`이며 릴리스 검색에 포함된다.

## 교체 결정

기존 후보 중 다음 다섯 곡은 첫 출시 묶음에서 제외했다.

- `Purple Haze`: 스튜디오 원본과 라이브 버전의 튜닝 설명이 섞일 위험.
- `Eruption`: E-flat 기준의 정확한 양의 cents offset을 뒷받침할 강한
  독립 출처가 부족함.
- `Black Hole Sun`: Drop D에는 합의가 있지만 원본의 sharp offset을
  0 cents로 두는 것이 부정확함.
- `Walk`: D standard의 음반별 음정 offset을 정수값으로 고정할 근거가
  부족함.
- `seasons`: 카포 유무가 다른 편곡·레슨이 섞여 있음.

대신 `Highway to Hell`, `My Hero`, `Schism`, `Toxicity`,
`Here Comes the Sun`을 넣었다. `My Hero`는 아티스트 단위 요약과 달리
두 곡별 출처가 E standard로 일치하므로 곡별 근거를 우선했다.

## 사람 승인 체크리스트

프로젝트 소유자는 `candidates.v1.json`의 각 레코드에 대해 다음을
확인했고 전량 승인했다.

1. 두 URL이 서로 다른 발행처인지 확인한다.
2. 두 페이지가 저장된 `tuningId`와 `capoFret`을 직접 뒷받침하는지
   확인한다.
3. `notes`에 기록한 변형·offset 제한을 읽고 동의한다.
4. 20곡 모두 승인하고 승인자 역할과 날짜를 기록해 `verified`로
   승격한다.

탭, 코드 진행, 가사, 앨범 이미지나 출처 본문은 저장하지 않는다.
