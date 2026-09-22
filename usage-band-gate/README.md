# usage-band-gate — 계정 사용량 띠 감시

판: 0.1.0 (미태그) · 의존: `bash` · `python3`(표준 라이브러리만) · 공급원 명령 1개

## 무엇을 해결하나

에이전트 여러 개를 한 계정으로 돌리면 5시간·7일 사용 한도에 작업 도중 닿는다. 닿은 뒤에 알면 늦다.
이 도구는 사용량을 주기적으로 읽어 **띠(ok · 60+ · 70+ · 80+)가 바뀔 때만** 한 줄을 낸다.
숫자가 같은 띠 안에서 오르내리는 것은 알리지 않는다 — 감시자(사람 또는 다른 에이전트)가 소음 없이
「새 작업 착수 금지」「진행 중 작업만 마무리」「전부 정지」 같은 규칙을 띠에 걸 수 있게 하는 것이 목적이다.
띠에 무엇을 걸지는 이 도구가 정하지 않는다.

## 무엇이 필요하나

- `bash`, `python3`
- **공급원 명령 1개** — 아래 「입력 계약」 모양의 JSON 을 stdout 에 내는 명령. 이것이 어댑터 자리다.
  - 참조 어댑터: `adapters/cys-usage-accounts.sh` (cys 터미널의 `usage-accounts --json` 을 그대로 통과)
  - 파일 어댑터: `adapters/file.sh <경로>` (다른 도구가 써 두는 JSON 파일을 읽는다 · 시험에도 쓴다)

## 입력 계약

```json
{"accounts": [
  {"provider": "claude", "label": "acct-a@example.com",
   "rate": [{"label": "5h", "used_pct": 22.0}, {"label": "7d", "used_pct": 6.0}]}
]}
```

- `provider` 가 `--provider`(기본 `claude`)와 같은 계정만 본다.
- `label` 의 `@` 앞부분이 출력의 계정 이름이 된다.
- `rate[].label` 중 `--windows`(기본 `5h 7d`)에 있는 것만 본다. **없는 창은 0% 로 본다**(아래 한계 1).
- 다른 칸은 무시한다.

## 어떻게 붙이나

```bash
# 계속 돌리기(5분 간격). 띠가 바뀔 때만 한 줄이 나온다.
BAND_SOURCE_CMD="$PWD/usage-band-gate/adapters/cys-usage-accounts.sh" \
  bash usage-band-gate/band-gate-loop.sh

# 한 번만 돌리기(cron 등). 직전 상태는 BAND_STATE 파일에 둔다.
BAND_ONCE=1 BAND_STATE=/tmp/band.state \
BAND_SOURCE_CMD="$PWD/usage-band-gate/adapters/file.sh /path/usage.json" \
  bash usage-band-gate/band-gate-loop.sh
```

출력 예: `USAGE-GATE 밴드 변화: acct-a:5h=70+(71%) acct-a:7d=80+(80%)`

설정(환경변수): `BAND_INTERVAL`(초 · 기본 300) · `BAND_PROVIDER` · `BAND_WINDOWS` · `BAND_THRESHOLDS`(오름차순 3개 · 기본 `60 70 80`).
판정 로직만 쓰려면 `python3 band_gate.py < usage.json` (환경을 읽지 않는 순수 함수).

## 한계

1. **없는 창 = 0%(ok)**: 창이 리셋되는 순간 항목이 잠깐 빠지는 공급원에서 거짓 경보를 막으려는 선택이다.
   대가로 「공급원이 그 창을 아예 주지 않는다」도 ok 로 보인다. 공급원이 창을 주는지는 따로 확인하라.
2. **공급원 실패 = `ERR parse` 한 줄**: 명령이 실패하거나 JSON 이 아니면 그 사실을 한 번 낸다. 계속 실패하면 다시 내지 않는다(변화가 없으므로).
3. 소진 시각 예측·자동 정지는 하지 않는다. 한 줄을 낼 뿐이다.
4. 공급원 값의 신선도(언제 잰 값인가)는 공급원 책임이다. 이 도구는 받은 값을 그대로 띠로 바꾼다.

## 원본 판

우리 운영 환경의 감시 스크립트(24줄 · sha256 `0da61a2a2d1aec3e652a6783e7a0cb0cbc866cb77944d65f57b824ff11126a95` · 2026-09-23 05:35 +0900 읽음)를
판정 로직과 공급원 호출로 가른 것이다. 판정 결과는 원본과 같다(시험 고정본 4종 + 실제 공급원 응답 1회 대조 · 전부 동일).
바꾼 것: 공급원 명령·provider·창·경계값·간격을 인자/환경으로 뺐다 · 한 번만 돌리는 모드를 더했다 ·
JSON 이 객체가 아닐 때도 `ERR parse` 를 낸다(원본은 그 경우 아무것도 내지 않았다).

## 우리 환경 전제 (3줄)

- 공급원은 cys 터미널의 계정 사용량 명령이다(터미널이 보고받은 값 · 창이 돌 때만 갱신된다).
- 띠 경계 60/70/80 에는 「신규 착수 금지 / 진행 중만 마무리 / 전부 정지」 규칙을 건다.
- 출력 한 줄은 감시자 에이전트의 백그라운드 감시 도구가 받아 깨어나는 신호로 쓴다.

## 시험

`bash usage-band-gate/tests/selftest.sh` — 사례 11건 + 뮤턴트 4종(경계 포함 여부 · 없는 창 0 처리 · 같은 띠 무소음 · provider 거르기).
