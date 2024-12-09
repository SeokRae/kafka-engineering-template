#!/bin/bash

# Kafka 토픽 전체 조회 및 삭제 스크립트

# Kafka 브로커 연결 상태 확인
echo "[Step 1] Kafka 브로커 연결 상태 확인 중..."
for broker in kafka1 kafka2 kafka3; do
  echo "실행 중: docker exec -it $broker kafka-broker-api-versions --bootstrap-server $broker:9092"
  docker exec -it $broker kafka-broker-api-versions --bootstrap-server $broker:9092 > /dev/null
  if [ $? -ne 0 ]; then
    echo "❌ $broker 브로커 연결에 실패했습니다."
    exit 1
  fi
done
echo "✅ Kafka 브로커가 정상적으로 연결되었습니다."

# 모든 토픽 조회 및 삭제
echo "[Step 2] Kafka 토픽 전체 조회 및 삭제 중..."
echo "실행 중: docker exec -it kafka1 kafka-topics --list --bootstrap-server kafka1:9092"
all_topics=$(docker exec -it kafka1 kafka-topics --list --bootstrap-server kafka1:9092 | tr -d '\r' | tr '\n' ' ')
for topic in $all_topics; do
  if [ "$topic" != "__consumer_offsets" ]; then
    echo "실행 중: docker exec -it kafka1 kafka-topics --delete --topic $topic --bootstrap-server kafka1:9092"
    docker exec -it kafka1 kafka-topics --delete --topic $topic --bootstrap-server kafka1:9092
    if [ $? -ne 0 ]; then
      echo "❌ Kafka 토픽 삭제에 실패했습니다: $topic"
      exit 1
    fi
    echo "✅ Kafka 토픽이 정상적으로 삭제되었습니다: $topic"
  fi
done

echo "🎉 모든 Kafka 토픽이 성공적으로 삭제되었습니다."
