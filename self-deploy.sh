#!/bin/bash

# ======================
# Setup Environment (Java, Docker)
# ======================
echo ">>> Cloning setup script from GitHub..."
SETUP_DIR="setup-temp"
rm -rf $SETUP_DIR
git clone https://github.com/HyunwooKiim/setup.sh $SETUP_DIR

if [ ! -f "$SETUP_DIR/setup.sh" ]; then
    echo "Error: setup.sh not found in cloned repository"
    exit 1
fi

echo ">>> Running setup.sh to install Java 21 and Docker..."
cd $SETUP_DIR
chmod +x setup.sh
./setup.sh

if [ $? -ne 0 ]; then
    echo "Error: setup.sh execution failed"
    exit 1
fi

cd ..
echo ">>> Setup completed successfully!"

# setup 디렉토리 정리
rm -rf $SETUP_DIR

# ======================
# Verify Installation
# ======================
echo ""
echo ">>> Verifying installations..."

# Java 확인 (PATH 또는 /usr/bin/java 체크)
if command -v java &> /dev/null; then
    JAVA_CMD="java"
elif [ -f "/usr/bin/java" ]; then
    JAVA_CMD="/usr/bin/java"
else
    echo "Error: Java is not installed properly"
    exit 1
fi
echo "Java version:"
$JAVA_CMD -version

# Docker 확인 (PATH 또는 /usr/bin/docker 체크)
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
elif [ -f "/usr/bin/docker" ]; then
    DOCKER_CMD="/usr/bin/docker"
else
    echo "Error: Docker is not installed properly"
    exit 1
fi
echo "Docker version:"
$DOCKER_CMD --version

# Docker Compose 확인
if $DOCKER_CMD compose version &> /dev/null; then
    echo "Docker Compose version:"
    $DOCKER_CMD compose version
elif command -v docker-compose &> /dev/null; then
    echo "Docker Compose version:"
    docker-compose --version
else
    echo "Error: Docker Compose is not installed properly"
    exit 1
fi

echo ">>> All prerequisites verified successfully!"
echo ""

# ======================
# Install AWS CLI if not present
# ======================
if ! command -v aws &> /dev/null; then
    echo ">>> AWS CLI not found. Installing..."
    
    # Download AWS CLI installer
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download AWS CLI"
        exit 1
    fi
    
    # Unzip and install
    unzip -q awscliv2.zip
    sudo ./aws/install
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install AWS CLI"
        exit 1
    fi
    
    # Clean up
    rm -rf awscliv2.zip aws/
    cd - > /dev/null
    
    echo ">>> AWS CLI installed successfully!"
else
    echo ">>> AWS CLI is already installed"
fi

# Verify AWS CLI installation
aws --version
echo ""

# ======================
# Load Environment Variables
# ======================
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

# ======================
# Deploy with Docker Compose
# ======================
echo ""
echo ">>> Starting deployment with Docker Compose..."
cd $APP_DIR

# Docker Compose 실행
$DOCKER_CMD compose up -d

if [ $? -ne 0 ]; then
    echo "Error: Docker Compose up failed"
    exit 1
fi

# 컨테이너 상태 확인
echo ""
echo ">>> Checking container status..."
sleep 3
$DOCKER_CMD compose ps

# 모든 컨테이너가 running 상태인지 확인
RUNNING_COUNT=$($DOCKER_CMD compose ps --format json | jq -r '.State' | grep -c "running" || echo "0")
TOTAL_COUNT=$($DOCKER_CMD compose ps --format json | wc -l | tr -d ' ')

echo ""
if [ "$RUNNING_COUNT" -eq "$TOTAL_COUNT" ] && [ "$TOTAL_COUNT" -gt 0 ]; then
    echo "✅ Deploy 완료됨."
    echo "All $TOTAL_COUNT container(s) are running successfully!"
else
    echo "⚠️  Warning: Some containers may not be running properly"
    echo "Running: $RUNNING_COUNT / Total: $TOTAL_COUNT"
    $DOCKER_CMD compose ps
fi

cd ..
