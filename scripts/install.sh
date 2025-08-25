#!/bin/bash

echo "macime 입력기를 설치합니다..."
echo ""

# 현재 스크립트의 디렉토리 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 빌드된 앱 파일 경로 (Release 폴더에서 찾기)
APP_SOURCE="$PROJECT_DIR/build/Release/macime.app"

# 설치 대상 경로
INSTALL_DIR="$HOME/Library/Input Methods"

# 1. 설치 대상 디렉토리 확인 및 생성
echo "1. 설치 디렉토리 확인 중..."
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    echo " 입력기 디렉토리 생성: $INSTALL_DIR"
else
    echo " 입력기 디렉토리 존재: $INSTALL_DIR"
fi

# 2. 기존 macime.app 제거
echo ""
echo "2. 기존 macime.app 제거 중..."
if [ -d "$INSTALL_DIR/macime.app" ]; then
    rm -rf "$INSTALL_DIR/macime.app"
    echo " 기존 macime.app 제거 완료"
else
    echo " 기존 macime.app가 없습니다"
fi

# 3. 빌드된 앱 파일 확인
echo ""
echo "3. 빌드된 앱 파일 확인 중..."
if [ ! -d "$APP_SOURCE" ]; then
    echo " 빌드된 macime.app를 찾을 수 없습니다: $APP_SOURCE"
    echo " 먼저 build_all.sh를 실행하여 앱을 빌드하세요."
    exit 1
fi
echo " 빌드된 앱 파일 확인: $APP_SOURCE"

# 4. 앱 복사
echo ""
echo "4. macime.app 설치 중..."
cp -R "$APP_SOURCE" "$INSTALL_DIR/"
if [ $? -eq 0 ]; then
    echo " macime.app 설치 완료: $INSTALL_DIR/macime.app"
else
    echo " macime.app 설치 실패"
    exit 1
fi

# 5. 권한 설정
echo ""
echo "5. 권한 설정 중..."
chmod +x "$INSTALL_DIR/macime.app/Contents/MacOS/macime"
echo " 실행 권한 설정 완료"

echo ""
echo " macime 설치 완료!"