"""소프트락 검출 — 살아 있는데 클리어가 불가능해진 상태를 전수 계산한다.

플레이어에게 아무 피드백도 주지 않는 가장 나쁜 실패 유형이다.
(사망/낙하는 화면에 보이지만, 소프트락은 보이지 않는다)
"""
import sys
from collections import deque
from sim import Game, load, emo


def analyze(path, show=3):
    g = Game(load(path))
    start = g.initial()
    # 1) 정방향 도달 가능 상태 전부
    seen, q = {start}, deque([start])
    edges = {}
    while q:
        s = q.popleft()
        if s[3] or s[4] or s[5]:
            continue
        for k in "UDLR":
            ns = g.step(s, k)
            if ns is None:
                continue
            edges.setdefault(s, []).append((k, ns))
            if ns not in seen:
                seen.add(ns)
                q.append(ns)
    # 2) 클리어에 도달 가능한 상태를 역방향으로 전파
    rev = {}
    for s, outs in edges.items():
        for _, ns in outs:
            rev.setdefault(ns, []).append(s)
    good = set(s for s in seen if s[5])
    q = deque(good)
    while q:
        s = q.popleft()
        for p in rev.get(s, []):
            if p not in good:
                good.add(p)
                q.append(p)
    # 3) 살아 있는데 클리어 불가 = 소프트락
    alive = [s for s in seen if not (s[3] or s[4] or s[5])]
    locks = [s for s in alive if s not in good]
    print(f"[{path}] 생존상태 {len(alive)} / 소프트락 {len(locks)}"
          f" ({100.0*len(locks)/max(1,len(alive)):.0f}%)")
    # 소프트락에 처음 들어가는 전이(원인)를 분류
    causes = {}
    for s, outs in edges.items():
        if s not in good:
            continue
        for k, ns in outs:
            if ns in seen and not (ns[3] or ns[4] or ns[5]) and ns not in good:
                nco = sum(1 for c in g.cocoon_ids if c not in ns[6])
                nbx = len(ns[7])
                causes[(nco, nbx)] = causes.get((nco, nbx), 0) + 1
    if causes:
        print("   소프트락 진입 전이 (남은 고치, 남은 상자):", dict(sorted(causes.items())))
    return len(locks), len(alive)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        analyze(p)
