# SharkTune Figma handoff — 2026-07-15

정식 디자인 기준 파일은 [SharkTune UI System — 6 Themes](https://www.figma.com/design/jCX0Z6nibXQ9H6ehFpkbJr)다. 기존 `COwsi0untcn8JZi9Bggpou` 파일은 49개 변수와 10개 컴포넌트의 마이그레이션 참고 자료로만 유지한다.

## Current state

- 2026-07-15 확인 시 정식 파일과 라이브러리 조회가 Figma Starter 호출 제한으로 차단됐다.
- 같은 제한을 반복 소모하지 않기 위해 이번 실행에서는 쓰기 호출을 중단했다.
- 코드측 파운데이션, 6개 팔레트, IBM Plex 타입 역할, 컴포넌트 계약과 3개 튜너 승인 후보 이미지는 완성됐다.
- 승인 후보 프레임은 Samsung SM-S926N의 1,080×2,340 physical px, 360×780 logical px at DPR 3만 사용한다.

## Resume order

1. 호출 제한 해제 뒤 정식 파일 metadata와 published library를 한 번씩 재검사한다.
2. `Primitives`, `Dimensions`, `Typography`, `Motion`, 테마별 단일 모드 컬렉션 6개를 만든다.
3. `docs/theme-system-design-2026-07-15.md` 순서로 컴포넌트를 생성하고 변수 바인딩, metadata, screenshot을 각각 확인한다.
4. 홈·검색, 곡 상세, 튜너, 도구 메뉴, 설정 프레임을 조립한다.
5. `app/test/goldens/`의 Abyss·Paper·Clipping 튜너와 대조하고 승인 이미지를 `reports/design/`에 남긴다.

세부 토큰과 컴포넌트 목록은 `docs/design-playbook.md`, `docs/theme-system-design-2026-07-15.md`, 로컬 상태 파일 `reports/design/figma-state-sharktune-v2.json`을 따른다.
