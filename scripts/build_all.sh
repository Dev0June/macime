#!/bin/bash

echo "macime 전체 빌드를 시작합니다..."
echo ""

# 현재 스크립트의 디렉토리 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 에러 발생 시 스크립트 중단
set -e

# 1. HangulKit 프레임워크 빌드
echo "1. HangulKit 프레임워크 빌드 중..."
cd "$PROJECT_DIR"

# HangulKit이 git submodule인지 확인
if [ -d "HangulKit" ]; then
    echo "✓ HangulKit 디렉토리 확인"
    
    # HangulKit 프레임워크 빌드 스크립트 실행
    if [ -f "HangulKit/scripts/create_framework.sh" ]; then
        echo "  HangulKit 프레임워크 생성 중..."
        cd HangulKit/scripts
        ./create_framework.sh
        cd "$PROJECT_DIR"
        echo "✓ HangulKit 프레임워크 빌드 완료"
    else
        echo "❌ HangulKit/scripts/create_framework.sh를 찾을 수 없습니다"
        exit 1
    fi
else
    echo "❌ HangulKit 디렉토리를 찾을 수 없습니다"
    echo "   git submodule update --init --recursive 를 실행하세요"
    exit 1
fi

# 2. Xcode 프로젝트 빌드 (Release 모드)
echo ""
echo "2. macime Xcode 프로젝트 빌드 중 (Release 모드)..."

# 빌드 디렉토리 생성
mkdir -p "$PROJECT_DIR/build"

# Xcode 빌드 실행
xcodebuild -project macime.xcodeproj \
           -scheme macime \
           -configuration Release \
           -derivedDataPath "$PROJECT_DIR/build/DerivedData" \
           SYMROOT="$PROJECT_DIR/build" \
           DSTROOT="$PROJECT_DIR/build/dst" \
           OBJROOT="$PROJECT_DIR/build/obj" \
           build

if [ $? -eq 0 ]; then
    echo "✓ Xcode 빌드 완료"
    
    # 빌드된 앱 경로 확인
    if [ -d "$PROJECT_DIR/build/Release/macime.app" ]; then
        echo "✓ 빌드된 앱 확인: $PROJECT_DIR/build/Release/macime.app"
    else
        echo "⚠️  빌드는 성공했으나 예상 경로에서 앱을 찾을 수 없습니다"
        echo "   다음 명령으로 앱 위치를 확인하세요:"
        echo "   find $PROJECT_DIR/build -name 'macime.app' -type d"
    fi
else
    echo "❌ Xcode 빌드 실패"
    exit 1
fi

# 3. 빌드 정보 출력
echo ""
echo "🎉 macime 전체 빌드 완료!"
echo ""
echo "빌드된 파일 위치:"
echo "  macime.app: $PROJECT_DIR/build/Release/macime.app"
echo ""
echo "다음 단계:"
echo "  ./scripts/install.sh - macime을 시스템에 설치"
echo "  ./scripts/uninstall.sh - 기존 macime 제거"