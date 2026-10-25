"""맵 JSON → 기호 표(마크다운). 손으로 그린 지도의 오류를 없애기 위한 도구."""
import sys
from sim import load

LEGEND = {
    "player":   ("🙂",  "플레이어 시작 위치"),
    "clear":    ("🚩",  "목표 포탈 — **멈춰야** 발동. 누에고치가 남았거나 발판이 안 눌렸으면 비활성"),
    "portal":   ("🔵",  "월드 포탈 (숫자 = 가는 스테이지, 숫자 없음 = 월드 출구)"),
    "box":      ("📦",  "상자 — 내 공격력만큼 날아가고, 날아간 거리만큼 힘이 줄어든다"),
    "gobP":     ("👺",  "고블린(순찰) — 막는다. 매 턴 바라보는 방향으로 1칸, 막히면 방향만 뒤집고 쉼. 1 맞으면 죽음"),
    "gobC":     ("😈",  "고블린(추적) — 막는다. 매 턴 플레이어 쪽으로 1칸(먼 축 우선, 동률이면 가로). 1 맞으면 죽음"),
    "cocoon":   ("🟣",  "누에고치 — 막는다. 1 이상 맞으면 파괴. **전부 부수면 목표 활성화**"),
    "cookie":   ("🍪",  "쿠키 — 체력 +n. 지나가기만 해도 먹는다. 일회용"),
    "trap":     ("🔴",  "가시 — 숫자 = 피해량. 몇 번이든 다시 밟힌다"),
    "chili":    ("🌶️",  "칠리 — 체력 -1 (항상 1). 한 번 먹으면 사라진다. 때리면 부서진다"),
    "wall":     ("🧱",  "벽 — 파괴 불가"),
    "obstacle": ("🟧",  "장애물 — 숫자 = 부수는 데 필요한 공격력 (1 항아리, 2 기둥)"),
    "plate":    ("🔘",  "발판 — 막는 개체가 **멈춰** 있어야 눌림. 전부 눌려야 목표 활성화"),
    "floor":    ("⬜",  "바닥"),
    "hole":     ("⬛",  "구멍 — 그 위에서 멈추면 낙하. 지나가는 것은 가능"),
}


def cell_for(ents, is_floor):
    """칸 하나의 기호. 발판은 위에 무엇이 있어도 보이도록 뒤에 덧붙인다."""
    sym, key = _top_symbol(ents, is_floor)
    if any(e["obj_type"] == "plate" for e in ents):
        return (LEGEND["plate"][0], "plate") if key in ("floor", "hole") else (sym + LEGEND["plate"][0], key)
    return sym, key


def _top_symbol(ents, is_floor):
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
    if find("wall"):
        return LEGEND["wall"][0], "wall"
    if (e := find("obstacle")):
        return LEGEND["obstacle"][0] + str(e.get("ma", 1)), "obstacle"
    if (e := find("trap")):
        return LEGEND["trap"][0] + str(e.get("atk", 0)), "trap"
    if find("chili"):
        return LEGEND["chili"][0], "chili"
    if (e := find("cookie")):
        h = e.get("heal", 1)
        return LEGEND["cookie"][0] + (str(h) if h != 1 else ""), "cookie"
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
            for k in [key] + (["plate"] if any(e["obj_type"] == "plate" for e in here) else []):
                if k not in used:
                    used.append(k)
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
