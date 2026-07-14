# 곡 튜닝 시드 데이터

이 디렉터리는 사람이 검증한 곡별 튜닝 사실의 원본을 저장합니다. 탭, 코드 진행, 가사, 앨범 이미지는 포함하지 않습니다.

출시 가능한 레코드는 최소한 곡명, 아티스트, 버전이 있는 tuning id, 카포, cents offset, 출처, 확인일, 확인자를 가져야 합니다. 검증 전 레코드는 개발 빌드에서만 사용합니다.

## 현재 파일

- `research-starter-list.md`: 임시 리서치 폴더에서 보존한 89곡 후보 원문.
- `tunings.v1.json`: 첫 후보군이 참조하는 정규화된 튜닝 정의.
- `candidates.v1.json`: 검색·카포·7/8현 흐름을 위한 출처 감사 후보 30곡. 기존 승인 20곡에 2026-07-14 확장 후보 10곡을 더했으며, 후보 파일 자체는 전부 `needs_human_review`로 유지한다. 출시 승인은 `catalog.v1.json`에만 기록한다.
- `song-candidates.schema.json`: 후보 데이터 계약. `verified`로 승격하려면 독립 출처가 최소 2개 필요하다.
- `catalog.v1.json`: 2026-07-14 프로젝트 소유자가 전량 승인한 출시 카탈로그. 승인 역할·날짜·범위와 20곡의 `verified` 상태를 기록한다.
- `song-catalog.schema.json`: 출시 카탈로그 계약. 전량 승인 메타데이터와 독립 출처를 강제한다.
- `backbone-targets.schema.json`: 사람이 먼저 매칭한 MusicBrainz Recording MBID와 선택적 장르 근거 URL의 입력 계약.
- `backbone.schema.json`: MusicBrainz CC0 정체성 스냅샷과 선택적 ListenBrainz 인기도를 합친 비출시 큐레이션 백본 계약. 장르 기본값은 `default_unverified`일 뿐 출시 근거가 아니다.

## 대량 큐레이션 백본

`packages/tuner_data/tool/import_song_backbone.dart`는 네트워크 요청을 하지 않는다. MusicBrainz 공식 canonical core CSV 스냅샷, 사람이 만든 MBID 대상 목록, 선택적 ListenBrainz 인기도 JSON 스냅샷을 입력으로 받아 항상 `shippingEligible: false`인 백본을 만든다.

```powershell
cd packages/tuner_data
dart run tool/import_song_backbone.dart `
  --canonical-csv C:\datasets\canonical_musicbrainz_data.csv `
  --targets-json C:\curation\backbone-targets.json `
  --popularity-json C:\curation\listenbrainz-popularity.json `
  --captured-at 2026-07-14T00:00:00Z `
  --output C:\curation\backbone.v1.json
```

팝·록·컨트리·포크의 E Standard 제안도 `default_unverified`로 격리한다. 메탈과 기타 예외 장르는 자동 기본값 없이 `exception_review_required`가 된다. 튜닝·카포·센트 오프셋은 각각 서로 다른 두 호스트의 근거가 필요하고 그중 하나는 독립 출처여야 한다. Songsterr는 한 곡당 하나의 `curation_oracle`로만 허용하며 앱 런타임에서 호출하지 않는다. Ultimate Guitar는 계속 금지한다.

`researchConfidence`는 조사 당시의 메모일 뿐 출시 검증 상태가 아니다. `[V]`에서 옮긴 `web_verified`도 출처 URL·확인일·확인자를 저장하기 전에는 `verified`가 될 수 없다.

2026-07-13 출처 감사의 교체 결정과 2026-07-14 승인 기록은
`docs/song-curation-2026-07-13.md`에 기록한다.
