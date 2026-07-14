# Android 릴리스 서명 절차

## 저장소 계약

- 릴리스 빌드는 디버그 인증서를 절대 사용하지 않는다.
- `app/android/key.properties`와 `.jks`/`.keystore` 파일은 Git에서 제외한다.
- 비밀 설정이 없거나 placeholder이면 `bundleRelease`를 실패시킨다. 디버그 빌드는 계속 가능하다.
- 저장소에는 필드 이름만 담은 `app/android/key.properties.example`만 둔다.

## 프로젝트 소유자가 한 번 수행할 작업

1. Android Studio에서 **Build → Generate Signed Bundle/APK → Android App Bundle → Create new**를 선택해 별도 업로드 키를 만든다. 키 유효기간은 최소 25년으로 설정한다.
2. `app/android/key.properties.example`을 `app/android/key.properties`로 복사하고 실제 업로드 키 경로·alias·암호를 입력한다.
3. `.jks` 파일과 암호를 서로 다른 안전한 장소 두 곳에 백업한다. 저장소, 채팅, 이슈, 빌드 로그에는 올리지 않는다.
4. 새 Play 앱을 만들 때 Play App Signing을 사용한다. 로컬 업로드 키는 Google이 배포 APK에 쓰는 앱 서명 키와 분리한다.

Google의 현재 공식 절차는 [Android 앱 서명](https://developer.android.com/studio/publish/app-signing)을 단일 기준으로 삼는다.

## 검증 명령

```powershell
cd C:\toauner\app
..\.tools\flutter\bin\flutter.bat build appbundle --release
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
cd ..
.\tool\release_readiness.ps1 -Strict
```

첫 명령은 서명된 AAB를 만들어야 한다. `keytool` 출력의 SHA-256 인증서 지문은 Play Console에 표시되는 업로드 인증서와 대조하되 공개 문서에 비밀값과 함께 저장하지 않는다. Strict 게이트는 개인정보처리방침과 Data Safety 검토까지 끝나기 전에는 계속 실패하는 것이 정상이다.

## 키 분실·노출 대응

Play App Signing을 사용하는 앱은 업로드 키를 잃거나 노출했을 때 Play Console의 업로드 키 재설정 절차를 이용할 수 있다. 앱 서명 키와 업로드 키를 같은 파일로 임의 통합하지 않는다. 키 교체 전후의 인증서 지문과 적용 날짜는 비공개 출시 운영 기록에 남긴다.
