#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

set -e
cd "$PROJECT_DIR"

echo "macime 빌드 시작..."

xcodebuild -project macime.xcodeproj \
           -scheme macime \
           -configuration Release \
           -derivedDataPath "$PROJECT_DIR/build/DerivedData" \
           SYMROOT="$PROJECT_DIR/build" \
           build

if [ $? -eq 0 ]; then
    echo "✓ 빌드 성공: $PROJECT_DIR/build/Release/macime.app"
else
    echo "❌ 빌드 실패"
    exit 1
fi