#!/bin/bash

# 방법 3: kafka-topics 사용하여 간접적으로 확인
topics_result=$(docker exec -it kafka1 kafka-topics --bootstrap-server kafka1:9092 --list 2>&1)
if [ $? -eq 0 ]; then
    echo "✅ Kafka 브로커에 연결 성공. 토픽 목록:"
    echo "$topics_result"
    echo "Kafka 클러스터가 작동 중이므로 컨트롤러가 존재합니다."

    # 클러스터 상태 상세 확인
    echo "클러스터 상태 상세 정보 확인 중..."
    docker exec -it kafka1 kafka-topics --bootstrap-server kafka1:9092 --describe --topic __consumer_offsets

    exit 0
else
    echo "❌ Kafka 브로커 연결 실패. 오류 메시지:"
    echo "$topics_result"
fi
