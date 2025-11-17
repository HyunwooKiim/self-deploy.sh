#!/bin/bash

# 현재 디렉토리 이름 가져오기
CURRENT_DIR=$(basename "$PWD")

# 현재 디렉토리 이름이 self-deploy.sh인지 확인
if [ "$CURRENT_DIR" = "self-deploy.sh" ]; then
    echo ">>> Current directory is 'self-deploy.sh'"
    echo ">>> Moving to parent directory and deleting..."
    
    # 상위 디렉토리로 이동
    cd ..
    
    # self-deploy.sh 디렉토리 삭제
    rm -rf self-deploy.sh
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully deleted 'self-deploy.sh' directory"
    else
        echo "❌ Failed to delete 'self-deploy.sh' directory"
        exit 1
    fi
else
    echo "Error: Current directory is not 'self-deploy.sh'"
    echo "Current directory: $CURRENT_DIR"
    exit 1
fi
