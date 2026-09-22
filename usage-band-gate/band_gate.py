#!/usr/bin/env python3
"""band_gate.py — 계정 사용량 JSON 을 띠(band) 문자열로 바꾸는 순수 로직.

입력(stdin): 사용량 JSON 한 개. 형식은 README 「입력 계약」 절.
출력(stdout): 한 줄. 예) `acct-a:5h=ok(22%) acct-a:7d=70+(74%)`
  · 파싱 실패 = `ERR parse` 한 줄(루프가 이것도 「변화」로 올린다 — 조용히 삼키지 않는다).
  · 대상 계정이 0개 = 빈 줄(루프는 빈 줄을 무시한다).

환경을 읽지 않는다 — 설정은 인자로만 받는다(시험이 그대로 재현할 수 있게).
  --provider <이름>        이 provider 의 계정만 본다(기본 claude)
  --windows "5h 7d"        볼 창 라벨(고정 집합 · 기본 "5h 7d")
  --thresholds "60 70 80"  띠 경계 3개(오름차순 · 기본 60 70 80)

★부재 = 0(ok): 응답에 창 라벨이 없으면 0% 로 본다. 창이 리셋되는 순간 항목이 잠깐 사라졌다
  나타나는 공급원이 있어, 라벨 집합을 응답에서 가져오면 키가 흔들려 거짓 경보가 난다.
  그 대가로 「공급원이 그 창을 아예 안 준다」도 ok 로 보인다 — LIMITS 참조.
"""
import argparse
import json
import sys


def band(pct, thresholds):
    t1, t2, t3 = thresholds
    if pct >= t3:
        return "%d+" % t3
    if pct >= t2:
        return "%d+" % t2
    if pct >= t1:
        return "%d+" % t1
    return "ok"


def render(doc, provider, windows, thresholds):
    out = []
    for a in doc.get("accounts", []):
        if a.get("provider") != provider:
            continue
        seen = {}
        for r in a.get("rate", []):
            seen[str(r.get("label"))] = r.get("used_pct") or 0
        name = str(a.get("label", "?")).split("@")[0]
        for lab in windows:
            p = seen.get(lab, 0)
            out.append("%s:%s=%s(%d%%)" % (name, lab, band(p, thresholds), p))
    return " ".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--provider", default="claude")
    ap.add_argument("--windows", default="5h 7d")
    ap.add_argument("--thresholds", default="60 70 80")
    ns = ap.parse_args(argv)
    th = [float(x) for x in ns.thresholds.split()]
    if len(th) != 3 or not (th[0] < th[1] < th[2]):
        print("thresholds 는 오름차순 3개여야 한다", file=sys.stderr)
        return 2
    try:
        doc = json.load(sys.stdin)
    except Exception:
        doc = None
    if not isinstance(doc, dict):
        print("ERR parse")
        return 0
    print(render(doc, ns.provider, ns.windows.split(), th))
    return 0


if __name__ == "__main__":
    sys.exit(main())
