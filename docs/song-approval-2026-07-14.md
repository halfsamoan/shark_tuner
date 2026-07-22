# 곡 카탈로그 전량 승인 — 2026-07-14

- 승인자: `project-owner`
- 승인 경로: 이 Codex 작업에서 사용자가 “모든 곡 승인”이라고 명시
- 승인 범위: `data/songs/candidates.v1.json`의 출처 감사 완료 20곡 전부
- 출시 결과: `data/songs/catalog.v1.json`
- 정책: 탭·가사·앨범 이미지 없이 곡명, 아티스트, 튜닝, 카포, 오프셋,
  독립 출처 URL과 검증 메타데이터만 포함

후보 원본은 감사 이력으로 유지하며 수정하지 않는다. 출시 카탈로그는
`packages/tuner_data/tool/promote_song_catalog.dart`로 결정적으로 생성했고 모든 곡을
`verified`, 루트를 `shippingEligible: true`로 기록한다.
