#!/bin/bash

# .env 파일 로드
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

# .env 파일에서 S3 관련 변수 로드
export $(grep -v '^#' .env | xargs)

# 필수 환경 변수 확인
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$S3_BUCKET" ] || [ -z "$SERVICE_NAME" ]; then
    echo "Error: Required environment variables are missing"
    echo "Please check: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_BUCKET, SERVICE_NAME"
    exit 1
fi

# 변수 설정
SERVICE=$SERVICE_NAME
S3_PATH="s3://${S3_BUCKET}/deploy/${SERVICE}"
APP_DIR="application"
BUILD_DIR="${APP_DIR}/build"

# 기존 application 디렉토리 정리
echo "Cleaning up existing application directory..."
rm -rf $APP_DIR

# 디렉토리 생성
echo "Creating directory structure..."
mkdir -p $BUILD_DIR

# S3에서 파일 다운로드
echo "Downloading files from S3: $S3_PATH"

# docker-compose.yml 다운로드
aws s3 cp "${S3_PATH}/docker-compose.yml" "${APP_DIR}/docker-compose.yml"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download docker-compose.yml"
    exit 1
fi

# Dockerfile 다운로드
aws s3 cp "${S3_PATH}/Dockerfile" "${APP_DIR}/Dockerfile"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download Dockerfile"
    exit 1
fi

# env.txt 다운로드 후 .env로 변환
echo "Downloading env.txt..."
aws s3 cp "${S3_PATH}/env.txt" "${APP_DIR}/env.txt"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download env.txt"
    exit 1
fi

echo "Parsing env.txt to .env..."
cp "${APP_DIR}/env.txt" "${APP_DIR}/.env"
if [ $? -ne 0 ]; then
    echo "Error: Failed to parse env.txt to .env"
    exit 1
fi

# 임시 파일 삭제
rm "${APP_DIR}/env.txt"
echo ".env file created successfully"

# app.jar 다운로드
aws s3 cp "${S3_PATH}/app.jar" "${BUILD_DIR}/app.jar"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download app.jar"
    exit 1
fi

echo "All files downloaded successfully!"
echo "Directory structure:"
echo "application/"
echo "├── .env"
echo "├── docker-compose.yml"
echo "├── Dockerfile"
echo "└── build/"
echo "    └── app.jar"

# 다운로드된 파일 확인
ls -lah $APP_DIR
ls -lah $BUILD_DIR
