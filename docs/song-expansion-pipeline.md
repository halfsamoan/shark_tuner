# 곡 데이터 확장 파이프라인

## 목적과 경계

수백~수천 곡의 정체성과 검토 우선순위를 먼저 만들되, 튜닝 사실이 검증되기 전에는 앱 출시 카탈로그에 들어가지 않게 한다. 탭, 코드 진행, 가사, 악보와 소스 페이지의 설명문은 저장하지 않는다.

## 데이터 소스 판단

- MusicBrainz core 데이터의 Recording/Artist/Release MBID와 이름은 CC0다. 그러나 MusicBrainz 웹 서비스는 비상업 무료 사용과 1초당 1회·식별 가능한 User-Agent 조건을 별도로 둔다. toauner 도구는 이 차이를 피하기 위해 라이브 API를 호출하지 않고 공식 canonical core CSV 스냅샷만 읽는다. 상업 출시 단계에서는 MetaBrainz 지원 계정 조건도 다시 확인한다.
- ListenBrainz 사용자 listen 데이터는 CC0다. 인기도는 “무엇을 먼저 검토할지” 정렬하는 용도이며 튜닝 증거가 아니다. 현재 도구는 사용자가 보존한 JSON 스냅샷만 선택적으로 읽는다.
- AcousticBrainz 데이터는 CC0지만 2022년에 수집이 끝났다. 키·BPM 같은 과거 힌트에만 쓸 수 있고 기타 튜닝 근거로 인정하지 않는다.

공식 근거: [MusicBrainz core 데이터 라이선스](https://musicbrainz.org/doc/About/Data_License), [canonical MusicBrainz 데이터](https://musicbrainz.org/doc/Canonical_MusicBrainz_data), [MusicBrainz 웹 서비스 조건](https://musicbrainz.org/doc/MusicBrainz_API), [ListenBrainz popularity API](https://listenbrainz.readthedocs.io/en/latest/users/api/popularity.html), [ListenBrainz CC0 데이터](https://listenbrainz.org/data/), [AcousticBrainz 종료·CC0 안내](https://acousticbrainz.org/).

## 단계

1. 큐레이터가 목표 곡의 정확한 녹음 버전을 고르고 Recording MBID를 `backbone-targets.schema.json` 형식으로 기록한다. 장르를 기록할 때는 그 장르 판단의 URL도 함께 저장한다.
2. `import_song_backbone.dart`가 canonical CSV를 스트리밍하며 목표 MBID만 추출한다. Recording·Artist·Release MBID를 보존하고 ListenBrainz listener/listen count가 있으면 우선순위를 붙인다.
3. 팝·록·컨트리·포크만 `guitar-6-standard@1` 기본 제안을 받지만 상태는 `default_unverified`다. 메탈·블루스·핑거스타일과 그 밖의 장르는 자동 제안 없이 예외 검토로 보낸다. 카포와 cents offset은 기본 추정하지 않는다.
4. 튜닝, 카포, cents offset의 각 주장에 대해 서로 다른 호스트 두 개가 필요하다. 최소 하나는 독립 출처여야 한다. MusicBrainz 정체성, ListenBrainz 인기도, AcousticBrainz 특성은 이 수에 포함하지 않는다.
5. Songsterr를 사용하면 `curation_oracle`로 명시하고 한 곡에 한 개만 허용한다. 이는 사람이 확인하는 보조 오라클이며 앱 런타임 피드나 스크래퍼가 아니다. Ultimate Guitar는 입력 단계와 승격 단계 모두 차단한다.
6. 2소스 게이트를 통과해도 결과는 `needs_human_review`다. 프로젝트 소유자의 명시적 승인 후에만 기존 `promote_song_catalog.dart`가 `verified` 출시 카탈로그로 승격한다.

## 실패 안전성

- MBID 형식 오류, 중복 대상, 중복 인기도 행, canonical 행 누락 시 가져오기를 실패시킨다.
- 대상 파일의 장르와 장르 출처 URL은 둘 중 하나만 쓸 수 없다.
- 결과의 `shippingEligible`은 도구 호출 인자로 바꿀 수 없고 항상 `false`다.
- 메탈을 장르 기본값으로 처리하거나 인기도를 정확성 신뢰도로 재사용하지 않는다.
- 기존 릴리스 카탈로그는 변경하지 않는다. 새 백본은 인간 검토와 승격 전 앱에 번들되지 않는다.

## 다음 데이터 작업

도구와 게이트는 준비됐지만 실제 수백 곡 MBID 대상 목록은 아직 없다. 다음 단계는 현재 89곡 스타터 목록과 인기 메탈/다운튜닝 우선순위를 Recording MBID에 사람이 매칭하고, 공식 스냅샷을 내려받아 첫 비출시 백본을 생성하는 것이다.
