#!/bin/bash

echo "macime 입력기를 완전히 제거합니다..."
echo ""

# 0. 사전 확인 및 안내
echo " 제거 전 확인사항:"
echo "시스템 환경설정 > 키보드 > 입력 소스에서 macime 항목들을 먼저 삭제하세요 (-)"
echo ""

read -p "입력 소스 제거를 완료했으면 Enter를 눌러 계속하세요..."

# 1. 앱 파일 제거
echo ""
echo "1. 앱 파일 제거 중..."
if [ -d ~/Library/Input\ Methods/macime.app ]; then
    rm -rf ~/Library/Input\ Methods/macime.app
    echo "✓ macime.app 제거 완료"
else
    echo "  macime.app는 이미 제거되었습니다"
fi

# 2. 접근성 권한 제거
echo ""
echo "2. 접근성 권한 제거 중... (관리자 권한 필요)"
sudo tccutil reset Accessibility com.inputmethod.macime
echo "✓ 접근성 권한 제거 완료"

echo ""
echo " macime 완전 제거 완료!"