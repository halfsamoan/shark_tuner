# toauner 출시 준비 마스터 플랜 (Phase 8)

핵심 기능 구현은 끝났다. 이 문서는 남은 **실기기 검증 · Figma 마감 · iOS · 출시 품질** 작업을 지휘하는 마스터 플랜이다. 세부 계약은 각 트랙이 가리키는 문서를 따른다. 이 플랜은 `docs/ui-plan.md`(UI 우선순위) · `docs/design-playbook.md`(디자인 규범) · `docs/platform-readiness.md`(플랫폼 게이트) · `docs/figma-gap-analysis.md`(Figma)와 함께 읽는다.

## 현재 상태 (2026-07-14, 검증됨)

- 게이트 전체 그린: 포맷·정적분석 무경고·5개 패키지 테스트·S1 합성·실기타 코퍼스 리포트 통과(`tool/check.ps1` exit 0).
- 구현 완료: P0/P1 UI, M2A 페그 안내, M2B 장력·게이지, M2C 안정성 진단, FFT MPM, 마이크 폴백, TalkBack, wakelock, 온디바이스 프라이버시 노출.
- 지난 코드 리뷰의 확정 결함이 테스트와 함께 처리됨: 옥타브 sanity가 "진짜 한 옥타브 낮은 D3를 콜드스타트에서 타깃으로 승격하지 않음" 테스트, previous-stable 앵커 침묵 후 만료 테스트, FFT MPM 패리티 락, 라이브 튜너 드롭아웃 하드닝.
- 디자인 플레이북 §2.2의 새 토큰 시스템은 Flutter `TerminalTheme`와 49개 Figma Variables까지 반영됐다. 남은 Track C 작업은 실제 사용처 감사와 Figma foundations 검증이다.
- 출시 카탈로그 20곡은 전량 사람 승인·2소스 검증 상태이며, 별도의 확장 후보는 30곡이다.

## 사람(사용자)만 할 수 있는 의존성 — 이게 없으면 해당 트랙 진행 불가

| 의존성 | 막는 트랙 | 필요 이유 |
|---|---|---|
| 실기타를 폰 앞에서 직접 피킹 | A(안정성 실검증), B(자동 현 전환·페그 재검증) | 코덱스는 소리를 못 냄. 방 소음이 아닌 진짜 현 신호 필요 |
| G1 WAV 코퍼스(다운튜닝 실기타) | A 정밀도 상한 검증 | 저음현 안정성은 실녹음만 검증 가능 |
| macOS + Xcode + 실제 iPhone | D(iOS 전체) | Windows에서 iOS 네이티브 빌드·오디오 검증 불가 |
| Google Play 개발자 계정($25, 심사 며칠) | E(출시) | 클로즈드 트랙·릴리스 등록 |
| Figma Starter MCP 제한 해제 | C(Figma 제작 재개) | 컴포넌트·화면 제작 |
| 앱 이름 최종 확정("toauner" 가칭) | E(스토어 등록) | 스토어 리스팅 |

---

## Track A — 튜닝 안정성 실기기 검증 (M2C 마감)

세부: `docs/stability-diagnosis.md`. M2C 앱 흐름은 구현됨 — 남은 건 **실기타로 지표를 검증**하는 것.

1. 동일 현 5회 피킹 재현성: peakRms 정규화 후 어택 오버슈트 σ < 30% 확인(스펙 기준).
2. 어택 오버슈트·정착 시간·드리프트 결과를 리포트로 검토, `docs/user-guitar-corpus-*.md` 형식으로 기록.
3. **필요 시 toauner 자체 PCM 저장 기능 추가** — M2C 정밀 검증과 향후 D1/실기기 코퍼스 수집을 위해 UNPROCESSED 원본을 앱에서 저장(사용자 옵트인, 기기 내 저장, 공유 없음). 미검증 앱 오디오를 정확도 게이트로 승격 금지.
- 게이트: 5회 피킹 재현성 통과 + 원인 가설이 관측값과 UI/데이터에서 분리(단정 금지).

## Track B — Android 최종 실기기 QA

세부: `docs/platform-readiness.md`, `docs/six-string-usability-protocol.md`.

1. 삼성 기기에서 재검증: 마이크 폴백(UNPROCESSED→VOICE_RECOGNITION), 자동 현 전환(락 후 다른 현 튕기면 따라오는지), 페그 안내(방향·2회 반대 시 중지).
2. TalkBack 전체 튜닝 워크스루: 라이브 리전 문구, 칩·버튼 라벨, 장식 눈금 시맨틱 제외 확인.
3. 30분 연속 배터리 소모(목표 <8%) + 장시간 안정성(isolate 누수·드리프트).
4. 레이턴시 20회 세션 재개(기존 14회 표본 보강) — 픽→첫유효 p95 ≤150ms. 500ms 초과 표본도 포함하도록 수집 경로는 수정됐다.
5. 실기기 스크린샷 재촬영(`reports/device/`) → `docs/ui-plan.md` 화면별 목표 상태 + Figma 프레임과 3자 대조.
- 게이트: 비기타리스트 6현 튜닝 중앙값 ≤90초(M1 종료 기준), 삼성 폴백 경로 무결.

## Track C — 디자인 토큰 마이그레이션 + Figma 마감

세부: `docs/design-playbook.md`(갱신됨), `docs/figma-gap-analysis.md`.

1. **[완료] 새 §2.2 토큰을 코드와 Figma Variables에 반영.** `TerminalTheme`와 호환 alias를 사용한다:
   - 표면: 단일색 → elevation 램프(`bg.sunken/canvas/panel/raised/header`)
   - 포스퍼: `brand.phosphor #A9E34B`(채움) / `phosphor.edge #B8F34A`(얇은 엣지만)
   - 시맨틱: `lock.flood #46D67F`(구 #33FF66 은퇴) / `lock.hold` / `warn.amber #F2A93B` / `info.teal #4FB0A6`
   - 텍스트: `ink / ink.2 / text.secondary #8CA093 / grid.tick`(구 #5A6E5E 폐기 — AA 미달)
   - 대비값은 플레이북에 계산 검증됨. 깊이는 그림자 금지·표면 휘도로(§2.5).
2. **[코드 완료]** 6단 타입 스케일 + per-size 트래킹, D2Coding/Pretendard 번들·attribution·1.3x/2.0x 테스트. Figma 폰트 렌더 검증은 남았다.
3. **AI 티 킬리스트(§11.5) + Keep/Kill(§11.6)로 전 화면 셀프 감사** — 단일 패널색·풀채도 네온·rounded-lg·중앙정렬·이중선 박스 등 제거 확인.
4. Figma(Starter 제한 해제 후): Variables=토큰 1:1, 컴포넌트 variants(§5 상태 머신 이름 동일), 주요 화면(홈/곡상세/라이브튜너) 제작 → 실기기 화면과 대조.
- 게이트: `docs/design-playbook.md` §11 QA 체크리스트 전 항목 통과, 토큰 이름 피그마=코드 일치.

## Track D — iOS 검증

세부: `docs/platform-readiness.md` "출시 전 수동 게이트" 1~6. 구조는 이미 `AudioCapture`/`PitchDetector` 교체 지점으로 iOS 어댑터 작업만 남게 설계됨. macOS/Xcode 확보 후:

1. `flutter build ios --debug --no-codesign` 성공.
2. 실제 iPhone 마이크 권한 허용/거부/설정복귀, E2~E4+다운튜닝 1음 실샘플레이트·입력경로·첫유효지연 기록.
3. 전화/오디오 인터럽션 후 캡처 재개 + 오래된 피치 앵커 없음.
4. 화면 잠금 방지 튜너 화면 한정, 유선/USB 입력 연결·해제 시 무중단 재개.

## Track E — 출시 준비

1. **자동 라이선스 감사 게이트**: CI에서 GPL 등 금지 라이선스 발견 시 빌드 실패. 릴리스 플레이버 문자열 감사(FTS5·isolate·DEVELOPMENT·검증 필요 등 파이프라인 어휘 0건).
2. **[완료] 릴리스 카탈로그 20곡 전량 사람 검증·2소스 provenance 저장.** Track F의 30개 확장 후보는 검증 전 출시 노출 금지.
3. 개인정보처리방침 + 스토어 Data Safety 문구 확정: 마이크 = 기기 내 임시 처리·수집 없음(자체 PCM 저장 옵션 추가 시 문구 갱신).
4. Android 서명·릴리스 빌드, Play Console 등록, 앱 이름 확정.
5. 클로즈드 테스트 2주 P0 결함 0 검증.

## Track F — 백로그: 편의 기능 + 곡 데이터 확장 (출시 후/병행)

경쟁 앱 조사·데이터 소스 리서치 결과. 출시 필수 아님, 로드맵 편입 후보.

**편의 기능 (우선순위순)**:
1. 줄 교체 리마인더 + 줄 나이 로그 — M2B/M2C와 인과 연결, Roadie만 하는 영역 (중)
2. 레퍼런스 톤 재생(드론+음별) — 저노력·고가치, 다운튜닝 저음 크로스체크 (소)
3. 스테이지 모드 — 이미 만든 터미널 미학을 재사용 (소)
4. 홈 위젯 + 안드로이드 퀵설정 타일 (중)
5. 튜닝 히스토리 자동 로그 → 안정성 진단에 종단 데이터 (중)
6. 스위트닝 1토글 — "고정밀 스마트" 자격 기능 (중)
- 보류: 폴리포닉(우리 저음 audience에서 부실), 메트로놈·코드(축 밖). 베이스는 1급 확장 가치.

**곡 데이터 20곡 출시 + 30곡 후보 → 수백~수천곡 (전부 사실만, 탭/가사 금지)**:
1. 백본(CC0): MusicBrainz(MBID 정체성) + ListenBrainz(인기 우선순위) + AcousticBrainz 덤프(키/템포 힌트), 로컬 호스팅.
2. 장르 디폴트 레버리지: 팝/록 85~90%는 E 스탠다드·카포 없음 → `default-unverified`로 대량 시드, 사람 시간 안 씀. 예외 장르(메탈/블루스/핑거스타일/반음다운)에만 검증 역투입.
3. 예외 검증: Wikipedia 대체튜닝 리스트 → Songsterr MIDI 배열 2차 오라클 대조 → 2소스 일치 시 verified, 출처 URL 2개.
4. 수천곡: LLM 제안 + 독립 확인 2개 게이트. 릴리스는 verified만 노출.
- 금지 소스: Ultimate Guitar·DadaGP·MuseScore(ToS/오염 provenance), Spotify audio-features(폐지). Songsterr는 런타임 금지·큐레이션 오라클만.

---

## 실행 순서 권고

1. **Track C 선행(실사용처 감사 + Figma foundations 검증)** — 토큰 코드 반영은 완료됐다. 실기기 없이 지금 가능.
2. 사용자가 실기타 준비되면 **Track A + B**(안정성 실검증 + Android QA) 동시. 스크린샷 재촬영은 토큰 반영 후.
3. **Track E-1/2**(라이선스 게이트·문자열 감사·곡 검증)는 실기기 무관, 병행 가능.
4. macOS 확보 시 **Track D**. Play 계정 확보 시 **Track E-3/4/5**.
5. **Track F**는 출시 후 또는 여유 시.

각 트랙은 독립 커밋. 코드만으로 증명 못 하는 항목(사용성·배터리·실기타 재현성·iOS 오디오)은 완료로 포장하지 말고 실측 결과와 함께 보고한다.
