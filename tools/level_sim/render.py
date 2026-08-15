"""맵 JSON을 기호 표(마크다운)로 렌더링한다. 손으로 그린 지도의 오류를 없애기 위한 도구."""
import sys
from sim import load

# 기호 정의 (렌더 우선순위 순서대로 검사한다)
LEGEND = {
    "player":   ("🙂",  "플레이어 시작 위치"),
    "clear":    ("🚩",  "목표 (클리어 포탈) — **멈춰야** 발동, 지나가면 발동 안 함"),
    "portal":   ("🔵",  "월드 포탈 (숫자 = 이동할 스테이지)"),
    "box":      ("📦",  "상자 — 맞은 힘만큼 날아가고, 날아간 거리만큼 힘이 줄어든다"),
    "heal":     ("💚",  "회복 아이템 — 밟으면 체력 +n. 지나가기만 해도 발동"),
    "trap":     ("🔴",  "함정 (영구) — 숫자 = 피해량. 몇 번이든 다시 밟힌다"),
    "trap1":    ("🟡",  "함정 (일회성) — 숫자 = 피해량. 한 번 쓰면 사라진다"),
    "wallX":    ("🧱",  "벽 — 파괴 불가"),
    "wallD":    ("🟧",  "벽 — 숫자 = 부수는 데 필요한 공격력 (ma)"),
    "floor":    ("⬜",  "바닥"),
    "hole":     ("⬛",  "구멍 — 그 위에서 멈추면 낙하(실패). 지나가는 건 가능"),
}


def cell_for(ents, is_floor):
    """한 칸에 겹친 엔티티들 중 가장 중요한 것을 기호로 반환"""
    def find(t):
        return next((e for e in ents if e["obj_type"] == t), None)

    if (e := find("player")):
        return LEGEND["player"][0], "player"
    if (e := find("clear")):
        return LEGEND["clear"][0], "clear"
    if (e := find("worldPortal")):
        return LEGEND["portal"][0] + str(e.get("num", e.get("to_s", ""))), "portal"
    if (e := find("moveBox")):
        return LEGEND["box"][0], "box"
    # 벽은 여러 개 겹칠 수 있다 (01_00의 데이터 오류 케이스) → 불괴가 우선
    walls = [e for e in ents if e["obj_type"] == "wall"]
    if walls:
        if any(w.get("ma", 0) == 0 for w in walls):
            return LEGEND["wallX"][0], "wallX"
        w = walls[0]
        return LEGEND["wallD"][0] + str(w.get("ma")), "wallD"
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
    used = []

    grid = []
    for y in range(h):
        row = []
        for x in range(w):
            here = [e for e in ents if e.get("x") == x and e.get("y") == y]
            sym, key = cell_for(here, tiles[y][x] != 0)
            if key not in used:
                used.append(key)
            row.append(sym)
        grid.append(row)

    player = next((e for e in ents if e["obj_type"] == "player"), None)
    hp = player.get("ch", player.get("mh", 1)) if player else "?"
    emo = "평온" if hp >= 4 else ("화남" if hp >= 2 else "격노")

    out = []
    out.append(f"### `{path}` — 「{raw.get('map_name','')}」  "
               f"({w}×{h}, 시작 체력 {hp} = {emo})\n")
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
        print(render(p))
        print()
