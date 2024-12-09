#!/bin/bash

# Kafka Docker Compose 파일 경로
COMPOSE_FILE="../docker-compose.yml"

# 타임스탬프 함수
timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Kafka 클러스터 재시작
echo "$(timestamp) - Restarting Kafka cluster..."
docker compose -f "$COMPOSE_FILE" down
docker compose -f "$COMPOSE_FILE" up -d
