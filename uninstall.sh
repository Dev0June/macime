#!/bin/bash

echo "macime 입력기를 제거합니다..."

# macime.app 제거
if [ -d ~/Library/Input\ Methods/macime.app ]; then
    rm -rf ~/Library/Input\ Methods/macime.app
    echo "✓ macime.app 제거 완료"
else
    echo "✗ macime.app가 설치되어 있지 않습니다"
fi

echo "제거 완료!"