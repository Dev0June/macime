# macOS용 한손 입력기

뇌졸중으로 인한 장애로 한손으로만 키보드를 사용할 수 있게 되어, 한손 키보드 입력기를 개발

## 기능

- **한글 입력**: 이건구님의 한손 키보드 (libhangul 기반)
- **영어 입력**: Half-QWERTY 키보드 구현
- **한/영 전환**: Caps Lock 키

한손 키보드로 한글과 영어 모두 처리할 수 있지만, 안정성 테스트를 계속 진행 중.

## 빌드/설치

**CLI 스크립트 사용:**
- 빌드: `./Scripts/build.sh`
- 설치: `./Scripts/install.sh`

**Xcode 사용:**
1. Xcode에서 빌드: `⌘+B`
2. 빌드된 `.app` 파일을 `~/Library/Input Methods/`에 복사
3. 시스템 환경설정 > 키보드 > 입력 소스에서 추가
4. Caps Lock으로 한/영 전환