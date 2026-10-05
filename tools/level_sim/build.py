"""ASCII 스펙 → 맵 JSON 빌더.

스펙 파일 형식 (한 파일에 여러 스테이지, '---'로 구분):

    world: 2
    stage: 1
    name: cocoon
    hp: 6            # 생략 시 6 (mh는 항상 6)
    zoom: 0.7
    to: 2,0          # clear 포탈 목적지 (생략 시 world,0)
    grid:
    .....
    .P.C.
    .....
    extra: 3,1 trap atk=3      # 겹침 배치용 (선택)

기호:
    .  바닥          _  구멍
    W  벽(불괴)      w  벽 ma=1       V  벽 ma=2
    C  누에고치      B  상자
    P  플레이어      E  클리어 포탈   H  회복(+1)
    1-6 상시 고추(atk=숫자)           a-f 일회성 고추(atk=1~6)
"""
import json, sys, os

TRAP_ONCE = {c: i + 1 for i, c in enumerate("abcdef")}
SYM = {
    ".": None, "_": "HOLE",
    "W": ("wall", {}), "w": ("wall", {"ma": 1}), "V": ("wall", {"ma": 2}),
    "C": ("cocoon", {}), "B": ("moveBox", {}),
    "P": ("player", {}), "E": ("clear", {}), "H": ("healItem", {}),
}
for d in "123456":
    SYM[d] = ("trap", {"atk": int(d)})
for c, v in TRAP_ONCE.items():
    SYM[c] = ("trap", {"atk": v, "once": True})


def parse_block(text):
    meta, grid, extras = {}, [], []
    lines = text.strip("\n").split("\n")
    i = 0
    while i < len(lines):
        ln = lines[i]
        s = ln.strip()
        if s.startswith("grid:"):
            i += 1
            while i < len(lines):
                row = lines[i].rstrip()
                if not row.strip() or ":" in row:
                    break
                grid.append(row.strip())
                i += 1
            continue
        if s.startswith("extra:"):
            extras.append(s[len("extra:"):].strip())
        elif ":" in s and s:
            k, v = s.split(":", 1)
            meta[k.strip()] = v.strip()
        i += 1
    return meta, grid, extras


def build(text):
    meta, grid, extras = parse_block(text)
    h = len(grid)
    w = max(len(r) for r in grid)
    grid = [r.ljust(w, ".") for r in grid]

    tile_map, entities = [], []
    for y, row in enumerate(grid):
        trow = []
        for x, ch in enumerate(row):
            if ch not in SYM:
                raise ValueError(f"알 수 없는 기호 {ch!r} at ({x},{y})")
            v = SYM[ch]
            if v == "HOLE":
                trow.append(0)
                continue
            trow.append(1)
            if v is None:
                continue
            t, d = v
            e = {"x": x, "y": y, "obj_type": t}
            e.update(d)
            entities.append(e)
        tile_map.append(trow)

    world = int(meta["world"])
    stage = int(meta["stage"])
    hp = int(meta.get("hp", 6))
    for e in entities:
        if e["obj_type"] == "player":
            e["mh"] = int(meta.get("mh", 6))
            e["ch"] = hp
        elif e["obj_type"] == "clear":
            tw, ts = (meta.get("to", f"{world},0")).split(",")
            e["to_w"], e["to_s"] = int(tw), int(ts)

    for ex in extras:                       # "x,y type k=v k=v"
        parts = ex.split()
        xy = parts[0].split(",")
        e = {"x": int(xy[0]), "y": int(xy[1]), "obj_type": parts[1]}
        for kv in parts[2:]:
            k, v = kv.split("=")
            e[k] = (True if v == "true" else False if v == "false"
                    else int(v) if v.lstrip("-").isdigit() else v)
        entities.append(e)

    out = {
        "world": world, "stage": stage, "map_name": meta.get("name", ""),
        "tile_size_x": 256, "tile_size_y": 256,
        "map_width": w, "map_height": h,
        "zoom": float(meta.get("zoom", 0.7)),
        "padding": int(meta.get("padding", 2)),
        "tile_map": tile_map, "entities": entities,
    }
    if "offset" in meta:
        ox, oy = meta["offset"].split(",")
        out["offset"] = [int(ox), int(oy)]
    return out


def dump(obj):
    """기존 맵 파일 스타일(탭 인덴트, tile_map은 한 줄씩)로 직렬화"""
    L = ["{"]
    for k in ("world", "stage", "map_name", "tile_size_x", "tile_size_y",
              "map_width", "map_height", "zoom"):
        L.append(f'\t"{k}": {json.dumps(obj[k], ensure_ascii=False)},')
    if "offset" in obj:
        L.append(f'\t"offset": {json.dumps(obj["offset"])},')
    L.append(f'\t"padding": {obj["padding"]},')
    L.append('\t"tile_map": [')
    for row in obj["tile_map"]:
        L.append("\t\t[" + ", ".join(str(v) for v in row) + "],")
    L.append("\t],")
    L.append('\t"entities": [')
    for e in obj["entities"]:
        inner = ", ".join(f'"{k}": {json.dumps(v, ensure_ascii=False)}'
                          for k, v in e.items())
        L.append("\t\t{" + inner + "},")
    L.append("\t]")
    L.append("}")
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    spec_path, out_dir = sys.argv[1], sys.argv[2]
    blocks = open(spec_path, encoding="utf-8").read().split("\n---\n")
    for b in blocks:
        if not b.strip():
            continue
        o = build(b)
        name = "%02d_%02d.json" % (o["world"], o["stage"])
        open(os.path.join(out_dir, name), "w", encoding="utf-8").write(dump(o))
        print(f"  {name}  {o['map_name']:<14} {o['map_width']}x{o['map_height']}")
