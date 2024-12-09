#!/bin/bash

# Kafka 컨트롤러 검증 스크립트

# Step 1: Kafka 컨트롤러 확인 - 기본 컨트롤러 정보 확인
echo "[Step 1] Kafka 컨트롤러 확인 중..."
echo "실행 중: docker exec -it kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 --describe"
controller_info=$(docker exec -it kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 --describe 2> /dev/null | grep 'LeaderId')
if [ -z "$controller_info" ]; then
  echo "❌ Kafka 컨트롤러 확인에 실패했습니다."
  exit 1
fi
echo "✅ Kafka 컨트롤러가 정상적으로 설정되었습니다."

# Step 2: Kafka 컨트롤러 상태 확인 - 컨트롤러 브로커 ID 확인
echo "[Step 2] Kafka 컨트롤러 브로커 ID 확인 중..."
echo "실행 중: docker exec -it kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 --describe"
controller_id=$(docker exec -it kafka1 kafka-metadata-quorum --bootstrap-server kafka1:9092 --describe 2> /dev/null | grep 'LeaderId' | awk '{print $2}')
if [ -z "$controller_id" ]; then
  echo "❌ Kafka 컨트롤러 브로커 ID 확인에 실패했습니다."
  exit 1
fi
echo "✅ Kafka 컨트롤러 브로커 ID: $controller_id"

# Step 3: 컨트롤러 역할을 하는 브로커의 상태 확인
echo "[Step 3] Kafka 컨트롤러 브로커 상태 확인 중..."
echo "실행 중: docker exec -it kafka$controller_id kafka-broker-api-versions --bootstrap-server kafka$controller_id:9092"
docker exec -it kafka$controller_id kafka-broker-api-versions --bootstrap-server kafka$controller_id:9092 > /dev/null
if [ $? -ne 0 ]; then
  echo "❌ 컨트롤러 브로커 ($controller_id) 상태 확인에 실패했습니다."
  exit 1
fi
echo "✅ 컨트롤러 브로커 ($controller_id)가 정상적으로 동작 중입니다."

# Step 4: 컨트롤러 로그 확인 - 오류 확인
echo "[Step 4] Kafka 컨트롤러 브로커 로그 오류 확인 중..."
echo "실행 중: docker logs kafka$controller_id | grep -i 'error'"
controller_logs=$(docker logs kafka$controller_id 2> /dev/null | grep -i 'error')
if [ -n "$controller_logs" ]; then
  echo "❌ 컨트롤러 브로커 ($controller_id)에서 오류가 발견되었습니다."
  echo "$controller_logs"
  exit 1
fi
echo "✅ 컨트롤러 브로커 ($controller_id) 로그에 오류가 없습니다."

# Step 5: 컨트롤러 리더십 전환 테스트
echo "[Step 5] Kafka 컨트롤러 리더십 전환 테스트 중..."
echo "실행 중: docker stop kafka$controller_id"
docker stop kafka$controller_id
sleep 5
echo "실행 중: docker exec -it kafka2 kafka-metadata-quorum --bootstrap-server kafka2:9092 --describe"
new_controller_id=$(docker exec -it kafka2 kafka-metadata-quorum --bootstrap-server kafka2:9092 --describe 2> /dev/null | grep 'LeaderId' | awk '{print $2}')
if [ -z "$new_controller_id" ] || [ "$new_controller_id" == "$controller_id" ]; then
  echo "❌ Kafka 컨트롤러 리더십 전환에 실패했습니다."
  docker start kafka$controller_id
  exit 1
fi
echo "✅ Kafka 컨트롤러 리더십이 브로커 $new_controller_id로 전환되었습니다."

echo "실행 중: docker start kafka$controller_id"
docker start kafka$controller_id

# Step 완료 메시지
echo "🎉 모든 Kafka 컨트롤러 검증이 성공적으로 완료되었습니다."
