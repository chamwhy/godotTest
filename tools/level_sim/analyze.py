"""상태공간 전수조사 — 난이도 지표와 설계 의도 검증"""
import sys, copy
from collections import deque
from sim import Game, load, emo

TIER = lambda hp: 1 if hp <= 1 else (2 if hp <= 3 else 3)
TIER_NAME = {1: "격노", 2: "화남", 3: "평온"}


def explore(g, forbid_tier=None):
    start = g.initial()
    if forbid_tier and TIER(start[2]) == forbid_tier:
        return None, set()
    seen, q = {start}, deque([start])
    clears, dead, fallen, depth = [], 0, 0, {start: 0}
    maxd = 0
    while q:
        s = q.popleft()
        if s[5]:
            clears.append(s)
            maxd = max(maxd, depth[s])
            continue
        if s[3]:
            dead += 1; continue
        if s[4]:
            fallen += 1; continue
        for k in "UDLR":
            ns = g.step(s, k)
            if ns is None or ns in seen:
                continue
            if forbid_tier and TIER(ns[2]) == forbid_tier:
                continue
            seen.add(ns); depth[ns] = depth[s] + 1
            q.append(ns)
    return {"clears": clears, "dead": dead, "fallen": fallen,
            "states": len(seen)}, seen


def analyze(path, quiet=False):
    g = Game(load(path))
    r, _ = explore(g)
    hp_at_clear = sorted({s[2] for s in r["clears"]})
    tiers_at_clear = sorted({TIER_NAME[TIER(h)] for h in hp_at_clear})
    required = []
    for t in (1, 2, 3):
        rr, _ = explore(g, forbid_tier=t)
        if rr is None or not rr["clears"]:
            required.append(TIER_NAME[t])
    # 최단 수
    from sim import solve
    keys = solve(path, verbose=False)
    out = {
        "stage": path.replace(".json", ""),
        "name": g.raw.get("map_name", ""),
        "size": f"{g.w}x{g.h}",
        "shortest": len(keys) if keys else None,
        "states": r["states"],
        "dead": r["dead"],
        "fallen": r["fallen"],
        "clear_hp": hp_at_clear,
        "clear_tiers": tiers_at_clear,
        "required_tiers": required,
        "cocoons": len(g.cocoon_ids),
        "boxes": sum(1 for e in g.ents if e.type == "moveBox"),
    }
    if not quiet:
        print(f"[{out['stage']}] {out['name']}  {out['size']}")
        print(f"  최단 {out['shortest']}수 / 상태 {out['states']} / 사망 {out['dead']} / 낙하 {out['fallen']}")
        print(f"  클리어 감정: {out['clear_tiers']} (hp {out['clear_hp']})")
        print(f"  필수 감정 관문: {out['required_tiers'] or '없음'}")
        if out["cocoons"]: print(f"  누에고치 {out['cocoons']}개 / 상자 {out['boxes']}개")
    return out


def ablate(path):
    raw = load(path)
    base = bool(solvable(raw))
    print(f"[{path}] 원본 클리어: {base}")
    for i, e in enumerate(raw["entities"]):
        if e["obj_type"] in ("player", "clear"):
            continue
        mod = copy.deepcopy(raw)
        del mod["entities"][i]
        ok = solvable(mod)
        tag = "필수" if not ok else "없어도 클리어됨"
        extra = {k: v for k, v in e.items() if k not in ("x", "y", "obj_type")}
        print(f"   - {e['obj_type']:10s}({e.get('x')},{e.get('y')}) {str(extra):28s} → {tag}")


def solvable(raw):
    g = Game(raw)
    start = g.initial()
    seen, q = {start}, deque([start])
    while q:
        s = q.popleft()
        if s[5]:
            return True
        for k in "UDLR":
            ns = g.step(s, k)
            if ns and ns not in seen:
                seen.add(ns); q.append(ns)
    return False


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--ablate":
        for p in args[1:]:
            ablate(p)
    else:
        for p in args:
            analyze(p)
