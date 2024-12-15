#!/bin/bash

# 카프카 브로커 목록
BROKER_LIST="kafka1 kafka2 kafka3"

# 로그 출력 함수
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 구분선 출력 함수
separator() {
    echo "============================================"
}

separator
log "Kafka Broker Status Check Script Start"
separator

# 1. 컨테이너 상태 확인
check_container_status() {
    log "1. Container Status Check Start"
    log "Goal: Verify if Kafka containers are running"
    for broker in $BROKER_LIST; do
        log "Checking container status: $broker"
        # docker inspect 명령을 사용해 컨테이너의 실행 상태를 확인
        command="docker inspect -f '{{.State.Running}}' $broker 2>/dev/null"
        log "Executing: $command"
        # Docker 컨테이너가 실행 중인지 (.State.Running) 확인
        if [ "$(docker inspect -f '{{.State.Running}}' $broker 2>/dev/null)" == "true" ]; then
            log "✅ Container $broker: Running"
        else
            log "❌ Container $broker: Not Running"
        fi
    done
    log "Result: Container status check completed"
    separator
}

# 2. 브로커 프로세스 및 포트 확인
check_broker_health() {
    log "2. Broker Health Check Start"
    log "Goal: Confirm Kafka brokers are active and responding"

    for broker in $BROKER_LIST; do
        # kafka-broker-api-versions 명령을 사용해 브로커의 활성 상태를 확인
        command="docker exec $broker kafka-broker-api-versions --bootstrap-server $broker:9092"
        log "Executing: $command"
        # kafka-broker-api-versions 명령을 통해 브로커가 요청에 응답 가능한 상태인지 확인
        if docker exec $broker kafka-broker-api-versions --bootstrap-server $broker:9092 &>/dev/null; then
            log "✅ $broker: Broker Active"
        else
            log "❌ $broker: Broker Not Responding"
        fi
    done
    log "Result: Broker health check completed"
    separator
}

# 3. 토픽 상태 확인
check_topics() {
    log "3. Topic Status Check Start"
    log "Goal: Retrieve and describe Kafka topics"
    # kafka-topics 명령을 사용해 토픽 정보를 가져옴
    command="docker exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --describe"
    log "Executing: $command"
    # Kafka 클러스터 내의 토픽 정보를 가져옴
    docker exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --describe || log "❌ Failed to retrieve topic information."
    log "Result: Topic status check completed"
    separator
}

# 4. 컨트롤러 상태 확인
check_controller() {
    log "4. Controller Status Check Start"
    log "Goal: Verify the Kafka cluster controller status"
    # kafka-metadata-quorum 명령을 사용해 컨트롤러 상태를 확인
    command="docker exec kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 describe --status"
    log "Executing: $command"
    # 컨트롤러 상태 (kafka-metadata-quorum describe --status)를 확인
    docker exec kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 describe --status || log "❌ Failed to retrieve metadata quorum information."

    # 컨트롤러 ID 확인
    log "Checking Controller ID..."
    command="docker exec kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 describe --status | grep 'LeaderId'"
    log "Executing: $command"
    controller_id=$(docker exec kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 describe --status 2>/dev/null | grep 'LeaderId')
    if [ -n "$controller_id" ]; then
        log "✅ Controller Info: $controller_id"
    else
        log "❌ Failed to get controller information"
    fi
    log "Result: Controller status check completed"
    separator
}

# 5. 디스크 사용량 확인
check_disk_space() {
    log "5. Disk Space Check Start"
    log "Goal: Check disk usage for Kafka data directories"
    for broker in $BROKER_LIST; do
        # df 명령을 사용해 데이터 디렉토리의 디스크 사용량을 확인
        command="docker exec $broker df -h /var/lib/kafka/data"
        log "Executing: $command"
        # 각 Kafka 브로커의 데이터 디렉터리 디스크 사용량 (df -h)을 확인
        docker exec $broker df -h /var/lib/kafka/data || log "❌ Failed to check disk space on $broker."
    done
    log "Result: Disk space check completed"
    separator
}

# 6. 복제 상태 확인
check_replication() {
    log "6. Replication Status Check Start"
    log "Goal: Verify replication status and check for under-replicated partitions"
    # kafka-topics 명령을 사용해 클러스터의 토픽 목록을 가져옴
    command="docker exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list"
    log "Executing: $command"
    topics=$(docker exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --list 2>/dev/null)

    if [ -z "$topics" ]; then
        log "ℹ️ No topics found in the cluster"
    else
        log "Found topics: $topics"

        log "Checking under-replicated partitions..."
        # kafka-topics 명령을 사용해 under-replicated 파티션 확인
        command="docker exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --describe --under-replicated-partitions"
        log "Executing: $command"
        # Under-replicated 파티션을 확인하여 Kafka 클러스터의 복제 안정성을 평가
        under_replicated=$(docker exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --describe --under-replicated-partitions 2>/dev/null)
        if [ -z "$under_replicated" ]; then
            log "✅ No under-replicated partitions found (Good)"
        else
            log "⚠️ Found under-replicated partitions:"
            echo "$under_replicated"
        fi

        log "Checking ISR status for all topics..."
        # kafka-topics 명령을 사용해 ISR 정보를 확인
        command="docker exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --describe"
        log "Executing: $command"
        isr_status=$(docker exec kafka1 kafka-topics --bootstrap-server kafka1:9092 --describe 2>/dev/null | grep -E "Leader|Isr")
        if [ -z "$isr_status" ]; then
            log "ℹ️ No ISR information available"
        else
            log "ISR Status:"
            echo "$isr_status"
        fi
    fi
    log "Result: Replication status check completed"
    separator
}

# 메인 실행 함수
main() {
    check_container_status
    check_broker_health
    check_topics
    check_controller
    check_disk_space
    check_replication

    log "All checks completed"
    separator
}

# 스크립트 실행
main
