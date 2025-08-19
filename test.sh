### SIMPLE BLUE/GREEN DEPLOY TEST ###
# 1. BLUE 서비스 실행 상태에서 테스트 스크립트 실행
# 2. BLUE 서비스 응답만 받는 점 모니터링 후 GREEN 서비스 추가 배포
# 3. BLUE/GREEN 서비스 교차로 응답받는 점 확인 후 BLUE 서비스 제거
# *** 단일 서비스(BLUE or GREEN)만 있을 때 no-response 응답 뜨지 않게 하는 방법 확인 필요 ***

GATEWAY_URL="http://127.0.0.1:5001"
echo "▶ Gateway: $GATEWAY_URL"
echo "   (처음엔 BLUE만 응답 예상, GREEN 기동 후엔 BLUE/GREEN이 섞여 보이면 정상)"

extract() {
  echo "$1" | sed -n 's/.*"color"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

# 컬러 출력 (터미널 색)
c_blue='\033[1;34m'; c_green='\033[1;32m'; c_grey='\033[0;37m'; c_reset='\033[0m'

i=0
while :; do
  i=$((i+1))
  body="$(curl -s --max-time 1 "$GATEWAY_URL" || true)"
  if [ -z "$body" ]; then
    printf "[%03d] ${c_grey}no-response${c_reset}\n" "$i"
    sleep 0.2; continue
  fi

  color="$(extract "$body")"
  host="$(echo "$body" | sed -n 's/.*"host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  ts="$(date +%H:%M:%S)"

  case "$color" in
    blue)  printf "%s  ${c_blue}BLUE${c_reset}  (%s)\n"  "$ts" "${host:-?}" ;;
    green) printf "%s  ${c_green}GREEN${c_reset} (%s)\n" "$ts" "${host:-?}" ;;
    *)     printf "%s  ${c_grey}%s${c_reset}  (%s)\n"    "$ts" "${color:-unknown}" "${host:-?}" ;;
  esac
  sleep 0.2
done