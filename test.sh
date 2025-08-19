#!/usr/bin/env bash
# file: switch.sh
set -euo pipefail

TARGET="${1:-green}"           # green 또는 blue
PREV=""                        # 롤백용
[ "$TARGET" = "green" ] && PREV="blue" || PREV="green"

GATEWAY_URL="http://localhost:5001"
WINDOW_SEC=10                  # 전환 후 감시 시간(초)

# 0) curl 유무 체크 (게이트웨이 컨테이너는 curl 없으니 host에서 쏘면 됨)
command -v curl >/dev/null || { echo "curl not found on host"; exit 1; }

# 1) 사전 헬스체크(타겟 컨테이너 내부)
for i in {1..10}; do
  docker compose exec -T "$TARGET" sh -lc 'wget -q -O- http://localhost:5000/healthz >/dev/null || exit 1' || {
    echo "preflight failed ($TARGET)"; exit 1;
  }
  sleep 0.2
done
echo "preflight OK: $TARGET"

# 2) 백그라운드 트래픽(게이트웨이로 연속 요청)
ERRORS=0
(
  end=$((SECONDS+WINDOW_SEC+5))
  while [ $SECONDS -lt $end ]; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 1 "$GATEWAY_URL" || echo "000")
    case "$code" in
      200|204) : ;;
      *) echo "non-2xx during switch: $code"; ERRORS=$((ERRORS+1));;
    esac
    sleep 0.1
  done
) &
PID_CURL=$!

# 3) 전환: active_upstream.conf 바꿔치기
if [ "$TARGET" = "green" ]; then
  echo "server green:5000;" > ./active_upstream.conf
else
  echo "server blue:5000;" > ./active_upstream.conf
fi

# 4) 게이트웨이 무중단 리로드
docker compose exec -T gateway nginx -s reload

# 5) 전환 후 안정화 감시
sleep "$WINDOW_SEC"

# 6) 결과 평가 & 롤백
kill $PID_CURL || true
if [ "${ERRORS:-0}" -gt 0 ]; then
  echo "🔴 switch produced errors -> rolling back to $PREV ..."
  if [ "$PREV" = "green" ]; then
    echo "server green:5000;" > ./active_upstream.conf
  else
    echo "server blue:5000;" > ./active_upstream.conf
  fi
  docker compose exec -T gateway nginx -s reload
  exit 1
fi

echo "🟢 switch to $TARGET OK (no errors seen)"