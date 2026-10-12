"""레벨 디자인 시트 데이터 생성기.

    python3 tools/level_viewer/build.py

하는 일
  1. 엔티티 씬(.tscn) → SpriteFrames(.tres) → PNG 를 추적해 '오브젝트별 리소스' 목록을 만든다.
  2. 쓰이는 PNG 를 docs/viewer/res/ 로 복사한다 (03_Resources 아래 경로 그대로).
  3. 맵 JSON 을 읽고 tools/level_sim 으로 최단 해답·난이도 지표를 계산한다.
  4. docs/viewer/data.js (window.LEVEL_DATA) 를 쓴다.

맵을 고치거나 리소스를 바꾸면 이 스크립트를 다시 돌리면 된다. 게임 코드는 읽기만 한다.
"""
import contextlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
GODOT = os.path.join(ROOT, "godot")
MAPS = os.path.join(GODOT, "05_Data", "01_MapData")
LEGACY = os.path.join(MAPS, "legacy", "world2_v1")
OUT = os.path.join(ROOT, "docs", "viewer")

sys.path.insert(0, os.path.join(ROOT, "tools", "level_sim"))
sys.path.insert(0, HERE)
import sim            # noqa: E402
import analyze        # noqa: E402
import deadend        # noqa: E402
import verify         # noqa: E402
import hub            # noqa: E402
from descriptions import DESC, WORLDS  # noqa: E402


# ─────────────────────────────────────────── Godot 리소스 파싱
EXT_RE = re.compile(r'\[ext_resource ([^\]]*)\]')
ATTR_RE = re.compile(r'(\w+)="([^"]*)"')
NODE_RE = re.compile(r'^\[node ([^\]]*)\]\s*$')
PROP_RE = re.compile(r'^([\w/]+) = (.*)$')
EXTREF_RE = re.compile(r'ExtResource\("([^"]+)"\)')


def res_path(p):
    """res://a/b → godot/a/b 상대경로 (godot 폴더 기준)"""
    return p.replace("res://", "")


def parse_godot_file(path):
    """tscn/tres → (ext: id→(type, path), sections: [(header_attrs, props)])"""
    txt = open(os.path.join(GODOT, path), encoding="utf-8").read()
    ext = {}
    for m in EXT_RE.finditer(txt):
        a = dict(ATTR_RE.findall(m.group(1)))
        if "id" in a and "path" in a:
            ext[a["id"]] = (a.get("type", ""), res_path(a["path"]))
    sections = []
    cur = None
    for line in txt.split("\n"):
        mn = NODE_RE.match(line)
        if mn:
            cur = (dict(ATTR_RE.findall(mn.group(1))), {})
            sections.append(cur)
            continue
        if line.startswith("["):
            cur = None
            continue
        if cur is not None:
            mp = PROP_RE.match(line)
            if mp:
                cur[1][mp.group(1)] = mp.group(2)
    return ext, sections, txt


def resolve_refs(value, ext):
    """프로퍼티 값 안의 ExtResource 들을 경로 리스트로 (null 은 None)"""
    if value.startswith("Array["):
        inner = value[value.index("([") + 2: value.rindex("])")]
        out = []
        for tok in [t.strip() for t in inner.split(",") if t.strip()]:
            m = EXTREF_RE.search(tok)
            out.append(ext[m.group(1)][1] if m else None)
        return out
    m = EXTREF_RE.search(value)
    return ext[m.group(1)][1] if m else None


def sprite_frames_pngs(tres_path):
    """SpriteFrames .tres → 첫 애니메이션의 프레임 PNG 리스트"""
    ext, _, txt = parse_godot_file(tres_path)
    frames = []
    for m in re.finditer(r'"texture": ExtResource\("([^"]+)"\)', txt):
        frames.append(ext[m.group(1)][1])
    return frames


def script_chain(script_path):
    """스크립트의 extends 체인 (class_name 기준)"""
    classes = {}
    for dp, _, fs in os.walk(os.path.join(GODOT, "01_Scripts")):
        for f in fs:
            if f.endswith(".gd"):
                p = os.path.join(dp, f)
                t = open(p, encoding="utf-8").read()
                m = re.search(r'^class_name (\w+)', t, re.M)
                if m:
                    classes[m.group(1)] = os.path.relpath(p, GODOT)
    chain = []
    cur = script_path
    while cur:
        chain.append(cur)
        t = open(os.path.join(GODOT, cur), encoding="utf-8").read()
        m = re.search(r'^extends (\w+)', t, re.M)
        cur = classes.get(m.group(1)) if m else None
    return chain


def sfx_in(script):
    t = open(os.path.join(GODOT, script), encoding="utf-8").read()
    keys = []
    for m in re.finditer(r'play_sfx\("([^"]+)"', t):
        k = m.group(1)
        if "%d" in k:
            keys += [k.replace("%d", "1"), k.replace("%d", "2")]
        else:
            keys.append(k)
    return keys


# 오브젝트별 사람이 읽는 설명 (변형이 언제 쓰이는지는 코드 근거로 적는다)
OBJECT_INFO = {
    "player": {"name": "플레이어", "art": "흰 캐릭터 — 감정에 따라 뿔·표정이 바뀐다",
               "frames": [("frame1", "평온 (체력 4~6) · 이동 1 / 공격 1"),
                          ("frame2", "화남 (체력 2~3) · 이동 1 / 공격 2"),
                          ("frame3", "격노 (체력 1) · 이동 2 / 공격 2")],
               "code": "PlayerAnimator._on_emotion_changed — 감정이 바뀔 때 frame1/2/3 교체"},
    "trap": {"name": "함정 — 가시(상시) / 고추(일회성)", "art": "상시 = 가시(개수 = 피해량), 일회성 = 고추",
             "frames": [("trap_frames[0]", "가시 1 (atk 1, 상시)"),
                        ("trap_frames[1]", "가시 2 (atk 2, 상시)"),
                        ("trap_frames[2]", "가시 3 (atk ≥ 3, 상시) — 4 이상도 이 그림"),
                        ("once_trap_frames[0]", "고추 (once: true, 피해량 무관 한 그림)")],
             "code": "Trap.update_sprite — trap_frames[min(atk-1, 2)], once 면 once_trap_frames[0]",
             "warn": "문서들(01 규칙 문서 등)이 상시 함정을 '고추'로 불렀지만 실제 그림은 가시다. 고추 그림은 일회성 전용."},
    "wall": {"name": "벽 — 바위 / 항아리 / 기둥", "art": "ma 0 = 바위(2종 무작위), ma 1 = 항아리, ma 2+ = 기둥",
             "frames": [("random_wall_frames[0]", "바위 A (ma 0, 파괴 불가 — 무작위)"),
                        ("random_wall_frames[1]", "바위 B (ma 0, 파괴 불가 — 무작위)"),
                        ("destroyable_wall_frames[0]", "항아리 (ma 1 — 공격력 1로 파괴)"),
                        ("destroyable_wall_frames[1]", "기둥 (ma ≥ 2 — 공격력 2로 파괴)")],
             "code": "Wall.update_sprite — ma 0 이면 무작위, 아니면 destroyable_wall_frames[min(ma-1, 1)]"},
    "cocoon": {"name": "누에고치", "art": "초록 줄무늬 고치",
               "frames": [("texture", "기본 텍스처 (TextureRect)"), ("sprite_frames", "AnimatedTextureRect 프레임")],
               "code": "Cocoon — 1 이상 맞으면 파괴, 전부 깨면 실타래 활성",
               "warn": "파괴음은 항아리 소리(broken_jar)를 임시로 쓴다 — 전용 음원 필요(QA R-1)."},
    "moveBox": {"name": "상자", "art": "돌 그림(Stone)", "frames": [("sprite_frames", "상자(돌) — 3프레임")],
                "code": "MoveBox.on_hit — 맞은 힘만큼 날아가고, 날아간 거리만큼 힘이 준다"},
    "healItem": {"name": "회복", "art": "쿠키 그림(Cookie)", "frames": [("sprite_frames", "쿠키 — 3프레임")],
                 "code": "HealItem — 들어온 개체가 무엇이든 소멸 (효과는 on_heal 이 있을 때만)"},
    "clear": {"name": "목표 포탈 (실타래)", "art": "초록 실타래(wool)", "frames": [("sprite_frames", "실타래 — 3프레임")],
              "code": "ClearPortal — 누에고치가 남아 있으면 알파 0.5(꺼짐), 전부 깨지면 1.0",
              "warn": "활성화 효과음이 없다(QA R-2)."},
    "worldPortal": {"name": "월드 포탈 (허브)", "art": "초록 원형 배경 + 숫자",
                    "frames": [("sprite_frames", "포탈 배경 — 3프레임 (안 깬 곳 #8dc977, 깬 곳 #a5b3a1 틴트)"),
                               ("number_textures", "숫자 n_1~n_15 (num 0 = 숫자 없음 → 월드 출구 표시)")],
                    "code": "WorldPortal.update_sprite"},
    "tile": {"name": "바닥 타일", "art": "흰 물결 바닥 — 128×128 조각 4개를 주변 8칸에 맞춰 조립",
             "frames": [("ul_frames", "좌상 조각 (상·좌상·좌 3비트)"), ("ur_frames", "우상 조각"),
                        ("dl_frames", "좌하 조각"), ("dr_frames", "우하 조각"), ("dust_texture", "먼지 장식 (50% 확률)")],
             "code": "Tile.update_tile_sprites — 시계방향 3비트 코드로 8종 중 선택"},
}
OBJECT_ORDER = ["tile", "player", "trap", "healItem", "wall", "cocoon", "moveBox", "clear", "worldPortal"]

COMMON_SFX_NOTE = "모든 개체 공통(Element): 맞을 때 hit-1 · 막힐 때 parry · 떨어질 때 falling"


def entity_scenes():
    _, _, txt = parse_godot_file("05_Data/09_Util/exported_resources.tres")
    ext, _, _ = parse_godot_file("05_Data/09_Util/exported_resources.tres")
    out = {}
    m = re.search(r'entityScenes = Dictionary\[String, PackedScene\]\(\{(.*?)\}\)', txt, re.S)
    for k, rid in re.findall(r'"(\w+)": ExtResource\("([^"]+)"\)', m.group(1)):
        out[k] = ext[rid][1]
    return out


def build_objects():
    scenes = entity_scenes()
    objects, used_png = [], set()
    for typ in OBJECT_ORDER:
        scene = scenes[typ]
        ext, sections, _ = parse_godot_file(scene)
        info = OBJECT_INFO[typ]
        script = None
        frame_sets = {}       # 프로퍼티 이름 → [ [png...], ... ] 또는 [png...]
        for hdr, props in sections:
            for k, v in props.items():
                if k == "script" and script is None:
                    script = resolve_refs(v, ext)
                ref = resolve_refs(v, ext) if "ExtResource" in v else None
                if ref is None:
                    continue
                key = k
                if key in frame_sets:
                    continue
                if isinstance(ref, list):
                    frame_sets[key] = [(sprite_frames_pngs(r) if r and r.endswith(".tres") else ([r] if r else []))
                                       for r in ref]
                    frame_sets[key + "#src"] = ref
                elif ref.endswith(".tres") and ext and any(t == "SpriteFrames" and p == ref for t, p in ext.values()):
                    frame_sets[key] = sprite_frames_pngs(ref)
                    frame_sets[key + "#src"] = ref
                elif ref.endswith(".png"):
                    frame_sets[key] = [ref]
                    frame_sets[key + "#src"] = ref
        variants = []
        for prop, label in info["frames"]:
            base = prop.split("[")[0]
            idx = int(prop.split("[")[1].rstrip("]")) if "[" in prop else None
            fs = frame_sets.get(base)
            src = frame_sets.get(base + "#src")
            if fs is None:
                continue
            if idx is not None:
                pngs, srcp = fs[idx], src[idx]
            elif fs and isinstance(fs[0], list):     # 배열 전체 (타일 조각 / 숫자)
                pngs = []
                for f in fs:
                    for p in f:
                        if p not in pngs:
                            pngs.append(p)
                srcp = "배열 %d개" % len(fs)
            else:
                pngs, srcp = fs, src
            used_png.update(pngs)
            variants.append({"label": label, "prop": prop, "src": srcp, "pngs": pngs})
        sfx_own, chain = [], []
        if script:
            chain = script_chain(script)
            for sc in chain:
                if sc.endswith(("Element.gd", "Entity.gd")):
                    continue
                for k in sfx_in(sc):
                    if k not in sfx_own:
                        sfx_own.append(k)
        if typ == "wall":
            sfx_own += ["broken_jar (항아리 파괴)", "broken_pillar (기둥 파괴)"]
        if typ == "moveBox":                      # Unit 의 사망 연출은 상자에 도달 불가 (체력 없음)
            sfx_own = [k for k in sfx_own if k != "death"]
        objects.append({
            "type": typ, "name": info["name"], "art": info["art"], "scene": scene,
            "scripts": chain, "variants": variants, "sfx": sfx_own,
            "code": info["code"], "warn": info.get("warn"),
        })
    # 뷰어가 그릴 때 쓰는 표 (타입/조건 → png 목록)
    def fs(typ, key):
        ext, sections, _ = parse_godot_file(scenes[typ])
        for hdr, props in sections:
            if key in props:
                r = resolve_refs(props[key], ext)
                if isinstance(r, list):
                    return [(sprite_frames_pngs(x) if x and x.endswith(".tres") else ([x] if x else [])) for x in r]
                return sprite_frames_pngs(r) if r.endswith(".tres") else [r]
        return None
    draw = {
        "player": fs("player", "frame1") and [fs("player", "frame1"), fs("player", "frame2"), fs("player", "frame3")],
        "trap": fs("trap", "trap_frames"), "trapOnce": fs("trap", "once_trap_frames"),
        "wallRandom": fs("wall", "random_wall_frames"), "wallBreakable": fs("wall", "destroyable_wall_frames"),
        "cocoon": fs("cocoon", "sprite_frames"), "moveBox": fs("moveBox", "sprite_frames"),
        "healItem": fs("healItem", "sprite_frames"), "clear": fs("clear", "sprite_frames"),
        "worldPortal": fs("worldPortal", "sprite_frames"), "numbers": fs("worldPortal", "number_textures"),
        "tile": {q: fs("tile", q + "_frames") for q in ("ul", "ur", "dl", "dr")},
        "dust": [x[0] for x in fs("tile", "dust_texture")],
    }
    for v in draw.values():
        for p in _flatten(v):
            used_png.add(p)
    return objects, draw, used_png


def _flatten(v):
    if v is None:
        return []
    if isinstance(v, str):
        return [v]
    if isinstance(v, dict):
        return [p for x in v.values() for p in _flatten(x)]
    return [p for x in v for p in _flatten(x)]


def unreferenced_images():
    hay = []
    for dp, _, fs in os.walk(GODOT):
        if "/.godot" in dp:
            continue
        for f in fs:
            if f.endswith((".tscn", ".tres", ".gd", ".godot")):
                hay.append(open(os.path.join(dp, f), encoding="utf-8", errors="ignore").read())
    hay = "\n".join(hay)
    out = []
    base = os.path.join(GODOT, "03_Resources")
    for dp, _, fs in os.walk(base):
        for f in sorted(fs):
            if f.endswith(".png"):
                rel = os.path.relpath(os.path.join(dp, f), GODOT)
                if rel not in hay:
                    out.append(rel)
    return sorted(out)


def copy_pngs(pngs):
    from PIL import Image
    sizes = {}
    for p in sorted(pngs):
        src = os.path.join(GODOT, p)
        dst = os.path.join(OUT, "res", os.path.relpath(p, "03_Resources"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        sizes[p] = list(Image.open(src).size)
    return sizes


# ─────────────────────────────────────────── 레벨
def level_path(key):
    if key.startswith("v1_"):
        k = key[3:]
        for f in os.listdir(LEGACY):
            if f.startswith(k):
                return os.path.join(LEGACY, f)
        raise FileNotFoundError(key)
    return os.path.join(MAPS, key + ".json")


def quiet(fn, *a, **kw):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        r = fn(*a, **kw)
    return r, buf.getvalue()


def build_level(key):
    path = level_path(key)
    raw = sim.load(path)
    ents = []
    for i, e in enumerate(raw["entities"]):
        d = {"id": i, "t": e["obj_type"], "x": e.get("x", 0), "y": e.get("y", 0)}
        for k in ("atk", "once", "ma", "heal", "to_w", "to_s", "num", "mh", "ch"):
            if k in e:
                d[k] = e[k]
        ents.append(d)
    w, h = len(raw["tile_map"][0]), len(raw["tile_map"])
    lv = {
        "key": key, "file": os.path.relpath(path, ROOT), "world": raw.get("world"), "stage": raw.get("stage"),
        "name": raw.get("map_name", ""), "w": w, "h": h, "zoom": raw.get("zoom"),
        "tiles": raw["tile_map"], "ents": ents, "desc": DESC.get(key, {}),
        "legacy": key.startswith("v1_"),
    }
    is_hub = any(e["obj_type"] == "worldPortal" for e in raw["entities"])
    lv["hub"] = is_hub
    lv["startHp"] = sim.Game(raw).initial()[2]   # 시작 칸의 가시/회복이 스폰 때 적용된 값
    if is_hub:
        _, text = quiet(hub.analyze, path)
        lv["hubText"] = text.strip().replace(ROOT + os.sep, "")
        missing = []
        for e in raw["entities"]:
            if e["obj_type"] == "worldPortal":
                f = os.path.join(MAPS, "%02d_%02d.json" % (e.get("to_w", 0), e.get("to_s", 0)))
                if not os.path.exists(f):
                    missing.append({"x": e["x"], "y": e["y"], "file": os.path.basename(f)})
        lv["missing"] = missing
        return lv
    keys, _ = quiet(sim.solve, path, verbose=False)
    lv["solution"] = "".join(keys or [])
    a, _ = quiet(analyze.analyze, path, quiet=True)
    (locks, alive), _ = quiet(deadend.analyze, path)
    killers, _ = quiet(verify.check, path, quiet=True)
    verdict = []
    for cid, ks in killers.items():
        e = raw["entities"][cid]
        v = ("파괴 불가" if not ks else "상자만" if ks == {"box"} else "플레이어만" if ks == {"player"} else "플레이어/상자")
        verdict.append({"x": e["x"], "y": e["y"], "by": v})
    lv["metrics"] = {
        "shortest": a["shortest"], "states": a["states"], "dead": a["dead"], "fallen": a["fallen"],
        "alive": alive, "locks": locks, "required": a["required_tiers"], "clearTiers": a["clear_tiers"],
        "cocoons": a["cocoons"], "boxes": a["boxes"], "cocoonKillers": verdict,
    }
    return lv


def main():
    objects, draw, used = build_objects()
    if os.path.isdir(os.path.join(OUT, "res")):
        shutil.rmtree(os.path.join(OUT, "res"))
    sizes = copy_pngs(used)
    worlds = []
    for wd in WORLDS:
        levels = []
        for key in wd["keys"]:
            levels.append(build_level(key))
            print("  ", key, levels[-1]["name"], levels[-1].get("solution", "(허브)"))
        worlds.append({"id": wd["id"], "title": wd["title"], "nav": wd.get("nav"), "subtitle": wd["subtitle"],
                       "legacy": wd.get("legacy", False), "levels": levels})
    try:
        commit = subprocess.check_output(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], text=True).strip()
    except Exception:
        commit = ""
    data = {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "commit": commit,
        "objects": objects, "commonSfx": COMMON_SFX_NOTE, "draw": draw, "sizes": sizes,
        "unreferenced": unreferenced_images(),
        "worlds": worlds,
    }
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "data.js"), "w", encoding="utf-8") as f:
        f.write("// 자동 생성 — tools/level_viewer/build.py. 손으로 고치지 말 것.\n")
        f.write("window.LEVEL_DATA = ")
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        f.write(";\n")
    print("wrote", os.path.relpath(os.path.join(OUT, "data.js"), ROOT),
          "/ sprites", len(sizes), "/ levels", sum(len(w["levels"]) for w in worlds))


if __name__ == "__main__":
    main()
