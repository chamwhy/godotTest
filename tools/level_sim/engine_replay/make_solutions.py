"""시뮬레이터 최단 해답 + 수마다 체력·위치 → JSON (Replay.gd 입력)

python3 make_solutions.py OUT.json 02_01 02_02 ...   (이름 없으면 허브를 뺀 모든 스테이지)
"""
import sys, os, json, glob
from collections import deque
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import sim

MAPS = os.path.join(HERE, "..", "..", "..", "godot", "05_Data", "01_MapData")


def shortest(g, cap=2_000_000):
    start = g.initial()
    seen, q = {start: None}, deque([start])
    while q:
        s = q.popleft()
        if s[5]:
            keys = []
            while seen[s] is not None:
                s, k = seen[s]
                keys.append(k)
            return keys[::-1]
        if len(seen) > cap:
            return None
        for k in "UDLR":
            ns = g.step(s, k)
            if ns is not None and ns not in seen:
                seen[ns] = (s, k)
                q.append(ns)
    return None


def main():
    out, names = sys.argv[1], sys.argv[2:]
    if not names:
        names = sorted(os.path.basename(p)[:5] for p in glob.glob(os.path.join(MAPS, "0*_*.json"))
                       if not p.endswith("_00.json"))
    sol = {}
    for name in names:
        raw = sim.load(os.path.join(MAPS, name + ".json"))
        g = sim.Game(raw)
        keys = shortest(g)
        if keys is None:
            print(f"{name}: 시뮬레이터에서 클리어 불가 — 건너뜀")
            continue
        s, hp, pos = g.initial(), [], []
        for k in keys:
            s = g.step(s, k) or s
            hp.append(s[2]); pos.append([s[0], s[1]])
        c = next(e for e in raw["entities"] if e["obj_type"] == "clear")
        sol[name] = {"keys": "".join(keys), "hp": hp, "pos": pos,
                     "to": [c.get("to_w", raw["world"]), c.get("to_s", 0)]}
        print(f"{name}: {len(keys)}수 {''.join(keys)}")
    json.dump(sol, open(out, "w"))


if __name__ == "__main__":
    main()
