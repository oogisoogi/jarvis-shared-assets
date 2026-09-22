#!/usr/bin/env bash
# 공개 용어 게이트 뮤턴트 — 이 저장소 트리 사본에 금지 형태를 일부러 심으면 게이트가 붉어지는가.
# 쓰는 법: bash tests/scrub-mutant.sh   · rc 0 = 심은 줄마다 적중 + 게이트 rc 1 · 심기 전 사본은 rc 0
# ★심을 글은 이 파일에 통째로 적지 않는다(적으면 이 파일 자신이 적중한다) — 조각을 이어 붙이거나
#   비공개 목록에서 꺼낸다. 비공개 목록이 없으면 구조 패턴만 심고, 그 사실을 출력한다.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SB="$(mktemp -d)"; trap 'rm -rf "${SB}"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }
LISTS=(--terms "${REPO}/tests/public-terms.txt")
PRIV="${REPO}/.public-terms-private.txt"
[ -f "${PRIV}" ] && LISTS+=(--terms "${PRIV}")

T="${SB}/tree"; mkdir -p "${T}"
(cd "${REPO}" && git ls-files -z --cached --others --exclude-standard | xargs -0 -I{} sh -c 'mkdir -p "$1/$(dirname "$2")" && cp "$2" "$1/$2"' _ "${T}" {})
rm -f "${T}/tests/public-terms.txt" "${T}/tests/public-terms-allow.txt"   # 목록은 원본 경로로 넘긴다

out="$(bash "${REPO}/tests/public-terms-check.sh" --root "${T}" "${LISTS[@]}" --allow "${REPO}/tests/public-terms-allow.txt" 2>&1)"; rc=$?
[ "${rc}" = "0" ]; ck "[기준] 심기 전 사본 = 적중 0 (rc 0)" $? "rc=${rc} · $(printf '%s' "${out}" | tail -1)"

python3 - "${T}/planted.md" "${PRIV}" <<'PY'
import os, re, sys
dst, priv = sys.argv[1], sys.argv[2]
samples = [
    "경로 /Us" + "ers/some" + "one/work",
    "주소 sur" + "face:" + "412",
    "표식 [mas" + "ter#" + "a1b2c3d4]",
    "주소 dev" + "@" + "corp-mail.io",
]
if os.path.isfile(priv):
    for line in open(priv, encoding="utf-8"):
        s = line.strip()
        if s and not s.startswith("#") and re.escape(s) == s:
            samples.append("낱말 " + s)
open(dst, "w", encoding="utf-8").write("\n".join(samples) + "\n")

PY
n_plant="$(grep -c '' "${T}/planted.md")"
out="$(bash "${REPO}/tests/public-terms-check.sh" --root "${T}" "${LISTS[@]}" --allow "${REPO}/tests/public-terms-allow.txt" 2>&1)"; rc=$?
[ "${rc}" = "1" ]; ck "[M-plant] 심은 뒤 게이트 rc 1" $? "rc=${rc}"
n_hit="$(printf '%s\n' "${out}" | grep -c '적중 planted.md:')"
[ "${n_hit}" = "${n_plant}" ]; ck "[M-plant] 심은 ${n_plant}줄 전부 적중" $? "적중 ${n_hit}줄"
[ -f "${PRIV}" ] && echo "  (비공개 목록 사용: 예)" || echo "  (비공개 목록 없음 — 구조 패턴 4종만 심었다)"
echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
