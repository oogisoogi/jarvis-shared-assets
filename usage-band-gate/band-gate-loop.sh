#!/usr/bin/env bash
# band-gate-loop.sh — 사용량 띠 감시 루프. 띠가 바뀔 때만 stdout 에 한 줄을 낸다.
#
# 공급원(어댑터)은 명령 하나다: BAND_SOURCE_CMD 가 사용량 JSON 을 stdout 에 내면 된다(README 「입력 계약」).
#   예) BAND_SOURCE_CMD="$PWD/adapters/cys-usage-accounts.sh" ./band-gate-loop.sh
#
# 환경:
#   BAND_SOURCE_CMD  공급원 명령(필수)            BAND_INTERVAL  폴링 간격 초(기본 300)
#   BAND_PROVIDER    볼 provider(기본 claude)     BAND_WINDOWS   창 라벨(기본 "5h 7d")
#   BAND_THRESHOLDS  띠 경계 3개(기본 "60 70 80")  BAND_ONCE=1    한 번만 돌고 끝낸다(시험·cron 용)
#   BAND_STATE       --once 모드에서 직전 키를 보관할 파일(없으면 매번 첫 회로 본다)
#
# 출력 한 줄: `USAGE-GATE 밴드 변화: <band_gate.py 출력>` — 사람이 아니라 감시자가 읽는 줄이다.
# 판정 키에서는 백분율 괄호를 지운다 — 같은 띠 안에서 숫자만 오르내리는 것은 변화가 아니다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${BAND_SOURCE_CMD:?BAND_SOURCE_CMD 가 비었다 — 공급원 명령을 지정하라(README 참조)}"
INTERVAL="${BAND_INTERVAL:-300}"
PROVIDER="${BAND_PROVIDER:-claude}"
WINDOWS="${BAND_WINDOWS:-5h 7d}"
THRESHOLDS="${BAND_THRESHOLDS:-60 70 80}"

prev=""
if [ "${BAND_ONCE:-0}" = "1" ] && [ -n "${BAND_STATE:-}" ] && [ -f "${BAND_STATE}" ]; then
  prev="$(cat "${BAND_STATE}")"
fi
while :; do
  cur=$(sh -c "${BAND_SOURCE_CMD}" 2>/dev/null \
    | python3 "${HERE}/band_gate.py" --provider "${PROVIDER}" --windows "${WINDOWS}" --thresholds "${THRESHOLDS}")
  key=$(printf '%s' "$cur" | sed -E 's/\([0-9.]+%\)//g')
  if [ -n "$cur" ] && [ "$key" != "$prev" ]; then echo "USAGE-GATE 밴드 변화: $cur"; prev="$key"; fi
  if [ "${BAND_ONCE:-0}" = "1" ]; then
    [ -n "${BAND_STATE:-}" ] && printf '%s' "$prev" > "${BAND_STATE}"
    exit 0
  fi
  sleep "${INTERVAL}"
done
