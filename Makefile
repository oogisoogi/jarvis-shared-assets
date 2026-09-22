# make check — 공개 전 검사 일괄. 하나라도 적색이면 rc ≠ 0.
.PHONY: check pin terms-selftest terms scrub-mutant assets history
check: pin terms-selftest assets terms scrub-mutant history
	@echo "check: 전건 통과"

pin:
	@cd tests && shasum -a 256 -c VENDORED.sha256

terms-selftest:
	@bash tests/public-terms-selftest.sh

assets:
	@bash usage-band-gate/tests/selftest.sh

terms:
	@if [ -f .public-terms-private.txt ]; then echo "공개 용어 검사: 구조 패턴 + 비공개 낱말 목록"; else echo "공개 용어 검사: 구조 패턴만(비공개 낱말 목록 없음 — 낱말 검사는 이 실행에 포함되지 않았다)"; fi
	@bash tests/public-terms-check.sh

scrub-mutant:
	@bash tests/scrub-mutant.sh

history:
	@bash tests/history-check.sh
