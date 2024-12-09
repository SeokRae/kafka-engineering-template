#!/bin/bash

# Kafka 검증 스크립트

# Kafka 브로커 연결 상태 확인
echo "[Step 1] Kafka 브로커 연결 상태 확인 중..."
for broker in kafka1 kafka2 kafka3; do
  echo "실행 중: docker exec -it ${broker} kafka-broker-api-versions --bootstrap-server ${broker}:9092"
  docker exec -it ${broker} kafka-broker-api-versions --bootstrap-server ${broker}:9092 > /dev/null
  if [ $? -ne 0 ]; then
    echo "❌ ${broker} 브로커 연결에 실패했습니다."
    exit 1
  fi
done
echo "✅ Kafka 브로커가 정상적으로 연결되었습니다."

# ==============================================================================

# 새로운 토픽 생성 및 확인
echo "[Step 2] Kafka 토픽 생성 및 확인 중..."
echo "실행 중: docker exec -it kafka1 kafka-topics --create --topic test-topic --bootstrap-server kafka1:9092 --partitions 3 --replication-factor 3"
docker exec -it kafka1 kafka-topics --create --topic test-topic --bootstrap-server kafka1:9092 --partitions 3 --replication-factor 3 2> /dev/null
if [ $? -ne 0 ]; then
  echo "❌ Kafka 토픽 생성에 실패했습니다. 이미 존재하는 토픽일 수 있습니다."
else
  echo "✅ Kafka 토픽이 정상적으로 생성되었습니다."
fi

echo "실행 중: docker exec -it kafka1 kafka-topics --list --bootstrap-server kafka1:9092"
docker exec -it kafka1 kafka-topics --list --bootstrap-server kafka1:9092 | grep test-topic
if [ $? -ne 0 ]; then
  echo "❌ Kafka 토픽이 생성되지 않았습니다."
  exit 1
fi

# ISR 상태 안정화 확인
echo "[Step 2.1] ISR 상태 확인 중..."
while true; do
  isr=$(docker exec -it kafka1 kafka-topics --describe --topic test-topic --bootstrap-server kafka1:9092 | grep "Isr")
  if [ -n "$isr" ]; then
    echo "✅ ISR 상태가 업데이트되었습니다."
    break
  fi
  echo "⏳ ISR 상태 업데이트를 기다리는 중..."
  sleep 2
done

# ==============================================================================

# 메시지 프로듀서 테스트
echo "[Step 3] 메시지 프로듀서 테스트 중..."
echo "실행 중: echo \"Hello Kafka\" | docker exec -i kafka1 kafka-console-producer --topic test-topic --bootstrap-server kafka1:9092"
echo "Hello Kafka" | docker exec -i kafka1 kafka-console-producer --topic test-topic --bootstrap-server kafka1:9092
if [ $? -ne 0 ]; then
  echo "❌ 메시지 전송에 실패했습니다."
  exit 1
fi
echo "✅ 메시지가 정상적으로 전송되었습니다."

# ==============================================================================

# 메시지 컨슈머 테스트
echo "[Step 4] 메시지 컨슈머 테스트 중..."
echo "실행 중: docker exec -it kafka2 kafka-console-consumer --topic test-topic --bootstrap-server kafka2:9092 --from-beginning --timeout-ms 5000"
docker exec -it kafka2 kafka-console-consumer --topic test-topic --bootstrap-server kafka2:9092 --from-beginning --timeout-ms 5000 | grep "Hello Kafka"
if [ $? -ne 0 ]; then
  echo "❌ 메시지 수신에 실패했습니다."
  exit 1
fi

echo "✅ 메시지가 정상적으로 수신되었습니다."

# ==============================================================================

# Kafka 컨트롤러 확인
echo "[Step 5] Kafka 컨트롤러 확인 중..."
echo "실행 중: docker exec -it kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 describe --status"

docker exec -it kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 describe --status | grep 'LeaderId'
if [ $? -ne 0 ]; then
  echo "❌ Kafka 컨트롤러 확인에 실패했습니다."
  exit 1
fi

echo "✅ Kafka 컨트롤러가 정상적으로 설정되었습니다."

# ==============================================================================
# 리플리케이션 상태 확인
echo "[Step 6] Kafka 리플리케이션 상태 확인 중..."
echo "실행 중: docker exec -it kafka1 kafka-topics --describe --topic test-topic --bootstrap-server kafka1:9092"

output=$(docker exec -it kafka1 kafka-topics --describe --topic test-topic --bootstrap-server kafka1:9092)
if [ $? -ne 0 ]; then
  echo "❌ Kafka 리플리케이션 상태 확인에 실패했습니다."
  exit 1
fi

# ISR 상태 확인
if echo "$output" | grep -q "Isr: "; then
  echo "✅ Kafka 리플리케이션 상태가 정상입니다."
else
  echo "❌ ISR 상태 확인에 실패했습니다. 리플리케이션에 문제가 있을 수 있습니다."
  exit 1
fi

# ==============================================================================
# 장애 복구 테스트
echo "[Step 7] 장애 복구 테스트 중..."

# 1. Kafka 브로커 중단
BROKER_TO_STOP="kafka1"
echo "실행 중: docker stop ${broker}_TO_STOP"
docker stop ${broker}_TO_STOP
sleep 5

# 2. 리더 상태 확인
echo "실행 중: docker exec -it kafka2 kafka-topics --describe --topic test-topic --bootstrap-server kafka2:9092"
while true; do
  output=$(docker exec -it kafka2 kafka-topics --describe --topic test-topic --bootstrap-server kafka2:9092 2>/dev/null)

  if echo "$output" | grep -q 'Leader:'; then
    echo "✅ 리더가 재선출되었습니다."
    break
  fi

  echo "⏳ 리더 재선출을 기다리는 중..."
  sleep 2
done

# 3. Kafka 브로커 재시작
echo "실행 중: docker start ${broker}_TO_STOP"
docker start ${broker}_TO_STOP

# 4. 브로커 상태 확인
sleep 5
output=$(docker exec -it kafka1 kafka-broker-api-versions --bootstrap-server kafka1:9092 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "❌ Kafka 브로커가 정상적으로 복구되지 않았습니다."
  exit 1
fi

echo "✅ Kafka 브로커가 정상적으로 복구되었습니다."

# ==============================================================================

# Kafka 토픽 삭제 테스트
echo "[Step 8] Kafka 토픽 삭제 중..."
# 삭제 대상 브로커 목록
BROKER_LIST="kafka1:9092,kafka2:9092,kafka3:9092"

# 삭제 대상 토픽 이름
TOPIC_NAME="test-topic"

# 토픽 존재 여부 확인
echo "실행 중: docker exec -it kafka1 kafka-topics --describe --topic $TOPIC_NAME --bootstrap-server ${broker}_LIST"
docker exec -it kafka1 kafka-topics --describe --topic $TOPIC_NAME --bootstrap-server ${broker}_LIST > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "❌ 토픽 '$TOPIC_NAME'이 존재하지 않습니다. 삭제를 건너뜁니다."
  exit 0
fi

# 토픽 삭제 요청
echo "실행 중: docker exec -it kafka1 kafka-topics --delete --topic $TOPIC_NAME --bootstrap-server ${broker}_LIST"
docker exec -it kafka1 kafka-topics --delete --topic $TOPIC_NAME --bootstrap-server ${broker}_LIST > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "❌ Kafka 토픽 삭제에 실패했습니다. 브로커 또는 클러스터 상태를 확인하세요."
  exit 1
fi

echo "✅ Kafka 토픽 '$TOPIC_NAME'이 정상적으로 삭제되었습니다."

# ==============================================================================
# 로그 확인 및 간소화된 요약
# 로그 확인 및 요약
echo "[Step 9] Kafka 로그 확인 및 요약 중..."

# 요약 결과를 담을 변수 초기화
log_summary=""

for broker in kafka1 kafka2 kafka3; do
  echo "[${broker} 로그 확인 중...]"

  # 오류 로그 저장
  error_logs=$(docker logs ${broker} | grep -i "error")

  if [ -n "$error_logs" ]; then
    # 주요 로그 유형 감지 및 요약 추가
    if echo "$error_logs" | grep -q "DUPLICATE_BROKER_REGISTRATION"; then
      log_summary+="\n- ${broker}: 중복 브로커 등록 발생"
    fi
    if echo "$error_logs" | grep -q "Error sending fetch request"; then
      log_summary+="\n- ${broker}: Fetch 요청 실패 발생"
    fi
    if echo "$error_logs" | grep -q "Error in response for fetch request"; then
      log_summary+="\n- ${broker}: Fetch 응답 오류 발생"
    fi
  else
    log_summary+="\n- ${broker}: 정상"
  fi
done

# 로그 요약 출력
echo ""
echo "📋 테스트 로그 요약:"
if [ -z "$log_summary" ]; then
  echo "✅ 모든 브로커가 정상 작동 중입니다."
else
  echo -e "$log_summary"
  echo "⚠️ 테스트 중 일부 문제가 발생했습니다. 위 요약 내용을 참조하세요."
fi

# ==============================================================================

# Step 10: 최종 클러스터 상태 검증
echo "[Step 10] Kafka 클러스터 상태 최종 검증 중..."
# 새 토픽 생성
FINAL_TOPIC="final-test-topic"

echo "실행 중: docker exec -it kafka1 kafka-topics --create --topic ${FINAL_TOPIC} --bootstrap-server kafka1:9092 --partitions 1 --replication-factor 1"
docker exec -it kafka1 kafka-topics --create --topic ${FINAL_TOPIC} --bootstrap-server kafka1:9092 --partitions 1 --replication-factor 1 > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "❌ 최종 검증용 토픽 생성에 실패했습니다."
  exit 1
else
  echo "✅ 최종 검증용 토픽 '${FINAL_TOPIC}'이 생성되었습니다."
fi

for broker in kafka1 kafka2 kafka3; do
  echo "[${broker} 상태 확인 중...]"

  # 브로커 API 버전 확인
  echo "실행 중: docker exec -it ${broker} kafka-broker-api-versions --bootstrap-server ${broker}:9092"
  docker exec -it ${broker} kafka-broker-api-versions --bootstrap-server ${broker}:9092 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "❌ ${broker}가 정상적으로 동작하지 않습니다."
    exit 1
  else
    echo "✅ ${broker}의 API 버전 확인 성공."
  fi

  # ISR 상태 확인
  echo "실행 중: docker exec -it ${broker} kafka-topics --describe --topic ${FINAL_TOPIC} --bootstrap-server kafka1:9092 | grep 'Isr'"
  docker exec -it ${broker} kafka-topics --describe --topic ${FINAL_TOPIC} --bootstrap-server kafka1:9092 | grep "Isr" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "❌ ${broker}의 ISR 상태가 정상적이지 않습니다."
    exit 1
  else
    echo "✅ ${broker}의 ISR 상태 확인 성공."
  fi
done

# 생성된 토픽 삭제
echo "실행 중: docker exec -it kafka1 kafka-topics --delete --topic ${FINAL_TOPIC} --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092"
docker exec -it kafka1 kafka-topics --delete --topic ${FINAL_TOPIC} --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092 > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "❌ 최종 검증용 토픽 '${FINAL_TOPIC}' 삭제에 실패했습니다."
  exit 1
else
  echo "✅ 최종 검증용 토픽 '${FINAL_TOPIC}'이 삭제되었습니다."
fi

echo "✅ Kafka 클러스터가 최종 검증되었습니다."

# ==============================================================================
echo "🎉 모든 검증이 성공적으로 완료되었습니다."
