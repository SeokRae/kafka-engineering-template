#!/bin/bash

# Kafka 컨테이너 목록
KAFKA_CONTAINERS=("kafka1" "kafka2" "kafka3")

# 최종 결과를 저장할 배열
RESULTS=()

echo "Kafka Topics and Partition Counts in All Containers (Step-by-Step Log):"
echo "---------------------------------------------------"

# 각 Kafka 컨테이너를 순회하면서 토픽과 파티션 수를 조회
for KAFKA_CONTAINER in "${KAFKA_CONTAINERS[@]}"; do
    echo "Checking in container: $KAFKA_CONTAINER"

    # 모든 토픽 목록을 가져오기 위한 명령어 출력 및 실행
    LIST_COMMAND="docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_CONTAINER:9092 --list"
    echo "Executing: $LIST_COMMAND"
    TOPICS=$(eval $LIST_COMMAND)

    if [[ -z "$TOPICS" ]]; then
        echo "No topics found in $KAFKA_CONTAINER."
    else
        # 각 토픽의 describe 정보를 가져오기 위한 명령어 출력 및 실행
        DESCRIBE_COMMAND="docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_CONTAINER:9092 --describe"
        echo "Executing: $DESCRIBE_COMMAND"

        # 실행 결과를 awk로 처리하여 Topic 줄과 PartitionCount를 배열에 추가
        eval $DESCRIBE_COMMAND | \
        awk -v container="$KAFKA_CONTAINER" '
            /Topic: / && /PartitionCount:/ {
                topic=$2
                partitions=$6
                result="Container: " container ", Topic: " topic ", Partitions: " partitions
                print result
                # 최종 결과 저장을 위해 result를 파일로 출력
                system("echo \"" result "\" >> /tmp/kafka_results.log")
            }
        '
    fi
    echo "---------------------------------------------------"
done

echo -e "\nSummary of Kafka Topics and Partition Counts in All Containers:"
echo "---------------------------------------------------"

# 요약 결과 출력
cat /tmp/kafka_results.log

# 임시 파일 삭제
rm /tmp/kafka_results.log
