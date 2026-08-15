"""요소별 필수성 검증: 엔티티를 하나씩 제거/변경했을 때 클리어 가능 여부가 바뀌는가"""
import copy, sys, json
from collections import deque
from sim import Game, load, DIRS


def solvable(raw):
    g = Game(raw)
    start = g.initial()
    seen = {start}
    q = deque([start])
    while q:
        s = q.popleft()
        if s[5]:
            return True
        for k in "UDLR":
            ns = g.step(s, k)
            if ns and ns not in seen:
                seen.add(ns)
                q.append(ns)
    return False


def ablate(path):
    raw = load(path)
    base = solvable(raw)
    print(f"[{path}] 원본 클리어 가능: {base}")
    for i, e in enumerate(raw["entities"]):
        if e["obj_type"] in ("player", "clear"):
            continue
        mod = copy.deepcopy(raw)
        del mod["entities"][i]
        r = solvable(mod)
        tag = "필수 (제거 시 클리어 불가)" if not r else "제거해도 클리어 가능"
        print(f"   - {e['obj_type']:9s} ({e['x']},{e['y']}) 제거 → {tag}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        ablate(p)
