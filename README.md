# macOS용 한손 입력기

## 빌드

1. HangulKit 프레임워크 생성: `./Scripts/create_framework.sh`
2. Xcode에서 빌드: `⌘+B`

## 설치

1. 빌드된 `.app` 파일을 `~/Library/Input Methods/`에 복사
2. 시스템 환경설정 > 키보드 > 입력 소스에서 추가
3. Caps Lock으로 한/영 전환