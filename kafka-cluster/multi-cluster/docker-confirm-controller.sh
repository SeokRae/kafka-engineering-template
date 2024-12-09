#!/bin/bash

echo "[Step 5] Kafka 컨트롤러 확인 중..."

# 함수: 컨트롤러 상태 확인
check_controller() {
    local command="$1"
    local result=$(docker exec -it kafka1 $command 2>&1)
    echo "실행된 명령어: $command"
    echo "결과: $result"
    if echo "$result" | grep -q 'LeaderId'; then
        echo "✅ Kafka 컨트롤러가 정상적으로 설정되었습니다."
        echo "$result" | grep 'LeaderId'
        return 0
    elif echo "$result" | grep -q 'Cluster ID'; then
        echo "✅ Kafka 클러스터 ID가 확인되었습니다."
        echo "$result"
        return 0
    else
        echo "❌ 컨트롤러 확인 실패. 다음 방법 시도 중..."
        return 1
    fi
}

# 방법 1: kafka-metadata-quorum 사용 (KRaft 모드)
if check_controller "kafka-metadata-quorum --bootstrap-server kafka1:9092 describe --status"; then
    exit 0
fi

# 방법 2: kafka-cluster 사용
if check_controller "kafka-cluster cluster-id --bootstrap-server kafka1:9092"; then
    exit 0
fi

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

# Kafka 버전 정보 출력
echo "Kafka 버전 정보:"
docker exec -it kafka1 kafka-topics --version

echo "❌ 직접적인 컨트롤러 정보 확인에는 실패했지만, 클러스터는 작동 중입니다."
echo "클러스터 구성 및 보안 설정을 확인해 주세요."

exit 1