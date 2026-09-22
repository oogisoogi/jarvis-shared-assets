#!/bin/sh
# 참조 어댑터 — cys 터미널의 계정 사용량 명령을 공급원으로 쓴다.
# 이 명령의 JSON 은 입력 계약(accounts[].provider·label·rate[].label·used_pct)을 그대로 만족하므로
# 변환 없이 통과시킨다. cys 계열 판본이 둘 이상 깔린 기계를 위해 이름 두 개를 차례로 시도한다.
# 다른 공급원을 붙이려면 같은 모양의 JSON 을 stdout 에 내는 스크립트를 하나 더 쓰면 된다.
cysr usage-accounts --json 2>/dev/null || cys usage-accounts --json 2>/dev/null
