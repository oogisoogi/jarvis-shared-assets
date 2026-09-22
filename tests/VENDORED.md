# 들여온 파일 (판 고정 · 제자리 수정 금지)

| 파일 | 원 저장소 | 원 커밋 | 비고 |
|---|---|---|---|
| `public-terms-check.sh` | https://github.com/oogisoogi/jarvis-install `tests/` | `f08f6d1d88b88fd639b71fa87bf2fc0b43d81a17` (저장소 HEAD `605cdc35c3abb966473a83f414a0514e399d006e` 에서 복사) | 공개 용어 검사기 |
| `public-terms-selftest.sh` | 같은 곳 | 같은 커밋 | 검사기 자체 시험 + 뮤턴트 6종 |

- 해시는 `VENDORED.sha256` 에 있고 `make check` 가 매번 대조한다. 어긋나면 적색이다.
- 고칠 것이 있으면 원 저장소에서 고치고 새 커밋으로 다시 들여온다(여기서 고치면 두 벌이 된다).
- 이 저장소가 더한 것은 목록(`public-terms.txt` · `public-terms-allow.txt`)과 `scrub-mutant.sh` 뿐이다.
