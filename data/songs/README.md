# 곡 튜닝 시드 데이터

이 디렉터리는 사람이 검증한 곡별 튜닝 사실의 원본을 저장합니다. 탭, 코드 진행, 가사, 앨범 이미지는 포함하지 않습니다.

출시 가능한 레코드는 최소한 곡명, 아티스트, 버전이 있는 tuning id, 카포, cents offset, 출처, 확인일, 확인자를 가져야 합니다. 검증 전 레코드는 개발 빌드에서만 사용합니다.

## 현재 파일

- `research-starter-list.md`: 임시 리서치 폴더에서 보존한 89곡 후보 원문.
- `tunings.v1.json`: 첫 후보군이 참조하는 정규화된 튜닝 정의.
- `candidates.v1.json`: 검색·카포·cents offset·7/8현 흐름을 설계하기 위한 첫 20곡. 전부 `needs_human_review`이며 출시 자산이 아니다.
- `song-candidates.schema.json`: 후보 데이터 계약. `verified`로 승격하려면 독립 출처가 최소 2개 필요하다.

`researchConfidence`는 조사 당시의 메모일 뿐 출시 검증 상태가 아니다. `[V]`에서 옮긴 `web_verified`도 출처 URL·확인일·확인자를 저장하기 전에는 `verified`가 될 수 없다.
