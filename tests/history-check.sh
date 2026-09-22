#!/usr/bin/env bash
# 이력 칸 공개 용어 검사 — 파일 게이트는 커밋 제목·본문·작성자·커미터를 보지 않는다. push 전에 그 칸을 같은 목록으로 훑는다.
# 쓰는 법: bash tests/history-check.sh [<기준>]   · 기준 기본 = origin/main (그 뒤 커밋만 본다 — 이미 공개된 이력은 되돌릴 수 없어 대상이 아니다)
# rc 0 = 적중 0 · rc 1 = 적중 · rc 2 = 검사 대상 커밋 0개(측정 못 함 ≠ 통과)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:-origin/main}"
SB="$(mktemp -d)"; trap 'rm -rf "${SB}"' EXIT
n="$(git -C "${REPO}" rev-list --count "${BASE}..HEAD")"
[ "${n}" -gt 0 ] || { echo "검사 대상 커밋 0개(${BASE}..HEAD) — 측정 못 함"; exit 2; }
git -C "${REPO}" log --format='%B' "${BASE}..HEAD" > "${SB}/messages.txt"
git -C "${REPO}" log --format='author %an <%ae>%ncommitter %cn <%ce>' "${BASE}..HEAD" > "${SB}/identities.txt"
LISTS=(--terms "${REPO}/tests/public-terms.txt")
[ -f "${REPO}/.public-terms-private.txt" ] && LISTS+=(--terms "${REPO}/.public-terms-private.txt")
echo "이력 칸 검사: ${BASE}..HEAD 커밋 ${n}개"
bash "${REPO}/tests/public-terms-check.sh" --root "${SB}" "${LISTS[@]}" --allow "${REPO}/tests/public-terms-allow.txt"
