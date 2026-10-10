"""허브 맵 순회 검사.

허브에서 '아직 안 깬 포탈'은 밟는 순간 스테이지로 끌려간다(settled 발동).
따라서 포탈 A에 가려면 그 경로 위에 다른 '안 깬 포탈'이 없어야 한다.
깬 포탈은 회색이 되어 그냥 지나다닐 수 있다(interact로만 재진입).

이 스크립트는 '실제로 모든 스테이지에 갈 수 있는가'와 '강제되는 순서'를 뽑는다.
"""
import sys
from collections import deque
from sim import load

BLOCKING = {"wall", "cocoon", "moveBox"}


def analyze(path):
    raw = load(path)
    tiles = raw["tile_map"]
    h, w = len(tiles), len(tiles[0])
    ents = raw["entities"]
    player = next(e for e in ents if e["obj_type"] == "player")
    portals = {(e["x"], e["y"]): e for e in ents if e["obj_type"] == "worldPortal"}
    blocked = {(e["x"], e["y"]) for e in ents if e["obj_type"] in BLOCKING}
    traps = {(e["x"], e["y"]): e for e in ents if e["obj_type"] == "trap"}

    def floor(p):
        x, y = p
        return 0 <= x < w and 0 <= y < h and tiles[y][x] != 0

    def reach(start, open_portals):
        """open_portals: 지나갈 수 있는 포탈 칸. 그 외 포탈은 막힌 것으로 본다."""
        seen, q = {start}, deque([start])
        while q:
            cur = q.popleft()
            for d in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                nx, ny = cur[0] + d[0], cur[1] + d[1]
                n = (nx, ny)
                if n in seen or not floor(n) or n in blocked:
                    continue
                if n in portals and n not in open_portals:
                    seen.add(n)      # 포탈은 '도달'은 되지만 더 나아갈 수 없다(끌려감)
                    continue
                seen.add(n)
                q.append(n)
        return seen

    start = (player["x"], player["y"])
    cleared, order = set(), []
    while True:
        r = reach(start, cleared)
        newly = [p for p in portals if p in r and p not in cleared]
        if not newly:
            break
        newly.sort(key=lambda p: portals[p].get("to_s", 0))
        for p in newly:
            cleared.add(p)
            order.append(portals[p].get("to_s", 0))

    allp = sorted(portals[p].get("to_s", 0) for p in portals)
    missed = [s for s in allp if s not in order]
    print(f"[{path}] {w}x{h}  포탈 {len(portals)}개")
    print(f"   도달 가능 순서: {order}")
    if missed:
        print(f"   ✗ 도달 불가 포탈: {missed}")
    else:
        print(f"   ✓ 전부 도달 가능")
    # 시작 칸 위험물
    if start in traps:
        print(f"   ⚠ 시작 칸에 고추(atk {traps[start].get('atk')}) — 스폰 즉시 피해")
    # 경로 위 함정
    r = reach(start, set(portals))
    on_path = [t for t in traps if t in r]
    if on_path:
        print(f"   허브 내 고추 {len(on_path)}개 {on_path} — 허브에서 체력이 깎인 채 스테이지 진입 가능")
    return len(missed) == 0


if __name__ == "__main__":
    for p in sys.argv[1:]:
        analyze(p)
