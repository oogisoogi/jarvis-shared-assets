#!/usr/bin/env bash
# usage-band-gate 자기 시험 + 뮤턴트 — 띠 판정·변화 감지·부재 처리·파싱 실패가 기대대로인지 잰다.
# 쓰는 법: bash tests/selftest.sh   · rc 0 = 사례 전건 통과 + 뮤턴트 전부 기대한 사례에서 적색
# ⚠순서가 판정의 일부다: ①원본으로 사례 전건 초록 ②뮤턴트마다 변이 적용(정확히 1곳)을 먼저 단언
#   ③변이본 사본 폴더에서 사례를 돌려 「기대한 사례가」 붉어졌는지로 귀속한다.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SB="$(mktemp -d)"
trap 'rm -rf "${SB}"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }
FX="${DIR}/tests/fixtures"

run_cases() { # run_cases <자산 폴더> → 붉은 사례 이름을 RED 에 담는다
  local d="$1" out st
  RED=""
  one() { # one <이름> <기대 출력(정확 일치)> <명령…>
    local name="$1" want="$2"; shift 2
    out="$("$@" 2>/dev/null)"
    [ "${out}" = "${want}" ] || RED="${RED} ${name}"
  }
  one B1-low 'acct-a:5h=ok(22%) acct-a:7d=ok(6%)' python3 "$d/band_gate.py" < "${FX}/low.json"
  one B2-high 'acct-a:5h=70+(71%) acct-a:7d=80+(80%)' python3 "$d/band_gate.py" < "${FX}/high.json"
  one B3-missing-is-zero 'acct-b:5h=ok(0%) acct-b:7d=60+(65%)' python3 "$d/band_gate.py" < "${FX}/missing-window.json"
  one B4-parse-error 'ERR parse' python3 "$d/band_gate.py" < "${FX}/broken.txt"
  one B5-provider 'acct-z:5h=80+(99%) acct-z:7d=ok(0%)' python3 "$d/band_gate.py" --provider other < "${FX}/low.json"
  one B7-boundary-inclusive 'acct-c:5h=70+(70%) acct-c:7d=ok(59%)' python3 "$d/band_gate.py" < "${FX}/edge.json"
  one B6-thresholds 'acct-a:5h=20+(22%) acct-a:7d=ok(6%)' python3 "$d/band_gate.py" --thresholds "20 30 40" < "${FX}/low.json"
  # 루프: 첫 회 = 변화 1줄 · 같은 띠 안 숫자만 바뀜 = 0줄 · 띠가 바뀜 = 1줄
  st="${SB}/state-$$-${RANDOM}"
  one L1-first 'USAGE-GATE 밴드 변화: acct-a:5h=ok(22%) acct-a:7d=ok(6%)' \
    env BAND_ONCE=1 BAND_STATE="$st" BAND_SOURCE_CMD="$d/adapters/file.sh ${FX}/low.json" bash "$d/band-gate-loop.sh"
  one L2-same-band-silent '' \
    env BAND_ONCE=1 BAND_STATE="$st" BAND_SOURCE_CMD="$d/adapters/file.sh ${FX}/low-moved.json" bash "$d/band-gate-loop.sh"
  one L3-band-change 'USAGE-GATE 밴드 변화: acct-a:5h=70+(71%) acct-a:7d=80+(80%)' \
    env BAND_ONCE=1 BAND_STATE="$st" BAND_SOURCE_CMD="$d/adapters/file.sh ${FX}/high.json" bash "$d/band-gate-loop.sh"
  one L4-source-fail-surfaces 'USAGE-GATE 밴드 변화: ERR parse' \
    env BAND_ONCE=1 BAND_SOURCE_CMD="false" bash "$d/band-gate-loop.sh"
}

echo "== 사례 =="
run_cases "${DIR}"
[ -z "${RED}" ]; ck "[사례] 원본 11건 전부 기대대로" $? "붉은 사례:${RED}"

echo "== 뮤턴트 =="
mutant() { # mutant <번호> <파일> <찾을 글> <바꿀 글> <붉어져야 할 사례>
  local id="$1" rel="$2" from="$3" to="$4" expect="$5" m="${SB}/m-$1" n r
  n="$(grep -cF -- "${from}" "${DIR}/${rel}")"
  if [ "${n}" != "1" ]; then ck "[${id}] 변이 적용(찾을 글 정확히 1곳)" 1 "찾을 글이 ${n}곳이다"; return; fi
  mkdir -p "${m}"; cp -R "${DIR}/band_gate.py" "${DIR}/band-gate-loop.sh" "${DIR}/adapters" "${m}/"
  python3 - "${DIR}/${rel}" "${m}/${rel}" "${from}" "${to}" <<'PY'
import sys
src, dst, a, b = sys.argv[1:5]
t = open(src, encoding="utf-8").read()
open(dst, "w", encoding="utf-8").write(t.replace(a, b, 1))
PY
  cmp -s "${DIR}/${rel}" "${m}/${rel}"; [ $? -ne 0 ]; ck "[${id}] 변이 적용 확인" $? "사본이 원본과 같다"
  run_cases "${m}"
  case " ${RED} " in *" ${expect} "*) r=0 ;; *) r=1 ;; esac
  ck "[${id}] 기대한 사례 ${expect} 가 붉다" "${r}" "붉은 사례:${RED:- 없음}"
}
mutant M1 band_gate.py 'if pct >= t2:' 'if pct > t2:' B7-boundary-inclusive
mutant M2 band_gate.py 'p = seen.get(lab, 0)' 'p = seen.get(lab)' B3-missing-is-zero
mutant M3 band-gate-loop.sh "sed -E 's/\\([0-9.]+%\\)//g'" "cat" L2-same-band-silent
mutant M4 band_gate.py 'if a.get("provider") != provider:' 'if False:' B1-low

echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
