#!/bin/sh
# 파일 어댑터 — 다른 도구가 주기적으로 써 두는 JSON 파일을 공급원으로 쓴다(시험에도 쓴다).
# 쓰는 법: BAND_SOURCE_CMD="$PWD/adapters/file.sh /경로/usage.json"
exec cat "$1"
