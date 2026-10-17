"""맵 JSON → 기호 표(마크다운). 손으로 그린 지도의 오류를 없애기 위한 도구."""
import sys
from sim import load

LEGEND = {
    "player":   ("🙂",  "플레이어 시작 위치"),
    "clear":    ("🚩",  "목표 포탈 — **멈춰야** 발동. 누에고치가 남아 있으면 비활성"),
    "portal":   ("🔵",  "월드 포탈 (숫자 = 가는 스테이지, 숫자 없음 = 월드 출구)"),
    "box":      ("📦",  "상자 — 내 공격력만큼 날아가고, 날아간 거리만큼 힘이 줄어든다"),
    "gobP":     ("👺",  "고블린(순찰) — 막는다. 매 턴 바라보는 방향으로 1칸, 막히면 방향만 뒤집고 쉼. 1 맞으면 죽음"),
    "gobC":     ("😈",  "고블린(추적) — 막는다. 매 턴 플레이어 쪽으로 1칸(먼 축 우선, 동률이면 가로). 1 맞으면 죽음"),
    "cocoon":   ("🟣",  "누에고치 — 막는다. 1 이상 맞으면 파괴. **전부 부수면 목표 활성화**"),
    "heal":     ("💚",  "회복 — 체력 +n. 지나가기만 해도 발동"),
    "trap":     ("🔴",  "고추 (상시) — 숫자 = 피해량. 몇 번이든 다시 밟힌다"),
    "trap1":    ("🟡",  "고추 (일회성) — 숫자 = 피해량. 한 번 쓰면 사라진다"),
    "wallX":    ("🧱",  "벽 — 파괴 불가"),
    "wallD":    ("🟧",  "벽 — 숫자 = 부수는 데 필요한 공격력 (ma)"),
    "floor":    ("⬜",  "바닥"),
    "hole":     ("⬛",  "구멍 — 그 위에서 멈추면 낙하. 지나가는 것은 가능"),
}


def cell_for(ents, is_floor):
    def find(t):
        return next((e for e in ents if e["obj_type"] == t), None)
    if find("player"):
        return LEGEND["player"][0], "player"
    if find("clear"):
        return LEGEND["clear"][0], "clear"
    if (e := find("worldPortal")):
        n = e.get("num", e.get("to_s", ""))
        return LEGEND["portal"][0] + (str(n) if n else ""), "portal"
    if (e := find("goblin")):
        if e.get("move") == "chase":
            return LEGEND["gobC"][0], "gobC"
        arrow = {"U": "↑", "D": "↓", "L": "←", "R": "→"}.get(e.get("dir", "R"), "")
        return LEGEND["gobP"][0] + arrow, "gobP"
    if find("moveBox"):
        return LEGEND["box"][0], "box"
    if find("cocoon"):
        return LEGEND["cocoon"][0], "cocoon"
    walls = [e for e in ents if e["obj_type"] == "wall"]
    if walls:
        if any(w.get("ma", 0) == 0 for w in walls):
            return LEGEND["wallX"][0], "wallX"
        return LEGEND["wallD"][0] + str(walls[0]["ma"]), "wallD"
    if (e := find("trap")):
        key = "trap1" if e.get("once", False) else "trap"
        return LEGEND[key][0] + str(e.get("atk", 0)), key
    if (e := find("healItem")):
        h = e.get("heal", 1)
        return LEGEND["heal"][0] + (str(h) if h != 1 else ""), "heal"
    return (LEGEND["floor"][0], "floor") if is_floor else (LEGEND["hole"][0], "hole")


def render(path):
    raw = load(path)
    tiles = raw["tile_map"]
    h, w = len(tiles), len(tiles[0])
    ents = raw["entities"]
    used, grid = [], []
    for y in range(h):
        row = []
        for x in range(w):
            here = [e for e in ents if e.get("x") == x and e.get("y") == y]
            sym, key = cell_for(here, tiles[y][x] != 0)
            if key not in used:
                used.append(key)
            row.append(sym)
        grid.append(row)

    p = next((e for e in ents if e["obj_type"] == "player"), None)
    hp = p.get("ch", p.get("mh", 1)) if p else "?"
    em = "평온" if hp >= 4 else ("화남" if hp >= 2 else "격노")

    out = [f"### `{path}` — 「{raw.get('map_name','')}」  ({w}×{h}, 시작 체력 {hp} = {em})\n"]
    out.append("| |" + "|".join(f" x={x} " for x in range(w)) + "|")
    out.append("|---|" + "|".join("---" for _ in range(w)) + "|")
    for y in range(h):
        out.append(f"| **y={y}** |" + "|".join(f" {c} " for c in grid[y]) + "|")
    out.append("")
    out.append("| 기호 | 뜻 |")
    out.append("|---|---|")
    for key in used:
        sym, desc = LEGEND[key]
        out.append(f"| {sym} | {desc} |")
    return "\n".join(out)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(render(p)); print()
