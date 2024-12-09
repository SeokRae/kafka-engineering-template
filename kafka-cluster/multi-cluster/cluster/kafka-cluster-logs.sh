#!/bin/bash

# Kafka Docker Compose 파일 경로
COMPOSE_FILE="../docker-compose.yml"

# 타임스탬프 함수
timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Kafka 클러스터 로그 확인
echo "$(timestamp) - Viewing Kafka cluster logs..."
docker compose -f "$COMPOSE_FILE" logs -f
