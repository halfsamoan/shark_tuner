# toauner

곡을 검색해 필요한 튜닝을 확인하고, 같은 흐름에서 바로 정밀 튜닝까지 마치는 Android/iOS 기타 튜너 앱입니다.

핵심 범위는 다음과 같습니다.

- 고정밀 주파수·센트 측정
- 곡별 튜닝 검색에서 정밀 튜너로 이어지는 원탭 흐름
- 초보자용 페그 방향 안내
- 튜닝별 장력·현 게이지 추천
- 튜닝 안정성 진단

Flutter 앱과 교체 가능한 DSP 코어를 모노레포로 관리합니다. MVP의 DSP는 순수 Dart 클린룸 구현이며, 네이티브 코어는 동일한 API 뒤에 선택적으로 추가합니다.

현재 계획과 품질 기준은 [제품 로드맵](docs/product-roadmap.md)과 [정확도 규격](docs/accuracy-spec.md)을 참고하세요.

## 로컬 시작

PowerShell에서 다음을 실행하면 저장소 내부 `.tools`에 Flutter stable SDK를 준비하고 Pub workspace를 구성합니다.

```powershell
.\tool\bootstrap.ps1
```

포맷, 정적 분석, 전체 테스트, 합성 정확도 리포트는 한 명령으로 실행합니다.

```powershell
.\tool\check.ps1
```

Android 앱 빌드에는 별도로 Android Studio와 Android SDK 설치 및 라이선스 동의가 필요합니다.
