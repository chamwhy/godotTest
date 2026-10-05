"""
bsk 게임 규칙 시뮬레이터 — GDScript 로직 1:1 이식 (origin/main 기준)

이식 대상:
  Unit.action_dir / action2 / move_to / attack / apply_on_hit
  Player._set_hp (감정 → 이동력/공격력)
  Trap._check_pos / on_hit, HealItem._check_pos
  Wall.on_hit, Cocoon.on_hit, MoveBox.on_hit
  GridManager.can_pass / has_tile / enter / step / settle
  StageContext.is_gated / notify_cocoon_destroyed, ClearPortal.active
  EntitySpawner.RANK (스폰 순서 → 스폰 시점 entered 발동)

핵심 규칙 (2025-10 시점 main):
  · 공격 조건에서 blocked가 삭제됨 → remain_atk > 0 이면 항상 공격한다.
    따라서 화남(이동력1/공격력2)은 "걸어가면서 전방 1칸을 1의 힘으로" 때린다.
  · Element.apply_data가 enter_element를 부르므로 스폰 시점에 entered가 발동한다.
  · 누에고치가 하나라도 남아 있으면 clear 포탈이 비활성.
"""
import json, re, sys
from collections import deque

DIRS = {"U": (0, -1), "D": (0, 1), "L": (-1, 0), "R": (1, 0)}
# EntitySpawner.RANK
RANK = {"trap": 0, "wall": 1, "healItem": 2, "cocoon": 3,
        "worldPortal": 10, "clear": 11, "moveBox": 20, "player": 90}
BLOCKING = {"wall", "cocoon", "moveBox"}


def load(path):
    txt = open(path, encoding="utf-8").read()
    txt = re.sub(r",(\s*[}\]])", r"\1", txt)          # trailing comma
    txt = re.sub(r"//[^\n]*", "", txt)                 # // 주석
    return json.loads(txt)


def sign(v):
    return (v > 0) - (v < 0)


def emo(hp):
    return "평온" if hp >= 4 else ("화남" if hp >= 2 else "격노")


class Ent:
    __slots__ = ("id", "type", "x", "y", "d")

    def __init__(self, i, d):
        self.id, self.type, self.d = i, d["obj_type"], d
        self.x, self.y = d.get("x", 0), d.get("y", 0)


class Game:
    def __init__(self, raw):
        self.raw = raw
        self.tiles = raw["tile_map"]
        self.h, self.w = len(self.tiles), len(self.tiles[0])
        # 스폰 순서 = RANK 순 (안정 정렬: 같은 랭크는 JSON 기재 순)
        ents = [Ent(i, d) for i, d in enumerate(raw["entities"])]
        self.ents = sorted(ents, key=lambda e: RANK.get(e.type, 99))
        self.by_id = {e.id: e for e in self.ents}
        self.player = next(e for e in self.ents if e.type == "player")
        self.max_hp = self.player.d.get("mh", 1)
        self.cocoon_ids = [e.id for e in self.ents if e.type == "cocoon"]
        self.has_clear = any(e.type == "clear" for e in self.ents)

    def has_tile(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.tiles[y][x] != 0

    def initial(self):
        """스폰을 실제로 실행해서 초기 상태를 만든다 (스폰 시점 entered 포함)."""
        ctx = Ctx(self, set(), {}, None, None, self.player.d.get("ch", self.max_hp))
        for e in self.ents:
            if e.type == "moveBox":
                ctx.boxes[e.id] = (e.x, e.y)
            elif e.type == "player":
                ctx.px, ctx.py = e.x, e.y
            ctx.on_enter(("player",) if e.type == "player"
                         else (("box", e.id) if e.type == "moveBox" else ("ent", e.id)),
                         e.x, e.y)
        return ctx.snapshot()

    def step(self, state, key):
        px, py, hp, dead, fallen, cleared, removed, boxes = state
        if dead or fallen or cleared:
            return None
        ctx = Ctx(self, set(removed), {b[0]: (b[1], b[2]) for b in boxes}, px, py, hp)
        ctx.player_action(DIRS[key])
        ns = ctx.snapshot()
        return None if ns == state else ns

    def step_ex(self, state, key):
        """step과 동일하지만 (새 상태, 이번 턴에 죽은 누에고치 목록)을 반환"""
        px, py, hp, dead, fallen, cleared, removed, boxes = state
        if dead or fallen or cleared:
            return None, []
        ctx = Ctx(self, set(removed), {b[0]: (b[1], b[2]) for b in boxes}, px, py, hp)
        ctx.player_action(DIRS[key])
        ns = ctx.snapshot()
        return (None if ns == state else ns), ctx.kills, ctx.cleared_by


class Ctx:
    def __init__(self, g, removed, boxes, px, py, hp):
        self.g, self.removed, self.boxes = g, removed, boxes
        self.px, self.py, self.hp = px, py, hp
        self.dead = self.fallen = self.cleared = False
        self.kills = []          # (cocoon_id, 가해자) — 검증용
        self.cleared_by = None   # 포탈을 밟은 주체 ('player' / 'box')

    def snapshot(self):
        boxes = tuple(sorted((i, p[0], p[1]) for i, p in self.boxes.items()))
        return (self.px, self.py, self.hp, self.dead, self.fallen,
                self.cleared, frozenset(self.removed), boxes)

    # ── 감정 (Player._set_hp)
    def atk_pow(self):
        return 1 if self.hp >= 4 else 2

    def move_speed(self):
        return 2 if self.hp <= 1 else 1

    # ── 누에고치 게이트 (StageContext)
    def portal_active(self):
        return all(cid in self.removed for cid in self.g.cocoon_ids)

    # ── 셀 조회
    def pos_of(self, e):
        return self.boxes.get(e.id) if e.type == "moveBox" else (e.x, e.y)

    def ents_at(self, x, y, mover):
        out = []
        for e in self.g.ents:
            if e.id in self.removed or e.type == "player":
                continue
            if self.pos_of(e) == (x, y):
                out.append(e)
        if mover != "player" and (self.px, self.py) == (x, y) \
                and not self.dead and not self.fallen:
            out.append("PLAYER")
        return out

    def blocked(self, x, y, mover):
        if not (0 <= x < self.g.w and 0 <= y < self.g.h):
            return True
        for e in self.ents_at(x, y, mover):
            if e == "PLAYER" or e.type in BLOCKING:
                return True
        return False

    # ── element_entered
    def on_enter(self, who, x, y):
        for e in list(self.ents_at(x, y, who[0])):
            if e == "PLAYER" or e.id in self.removed:
                continue
            if who[0] == "ent" and e.id == who[1]:
                continue                       # 자기 자신에게는 발동 안 함
            if e.type == "trap":
                if who[0] == "player":
                    self.damage_player(e.d.get("atk", 0))
                # 박스/기타: on_hit → dir=0 → 이동 없음. 함정만 소모됨
                if e.d.get("once", False):
                    self.removed.add(e.id)
            elif e.type == "healItem":
                if who[0] == "player":
                    self.hp = min(self.g.max_hp, self.hp + e.d.get("heal", 1))
                self.removed.add(e.id)

    # ── ClearPortal.activate -> _check_occupant
    # 포탈은 settled로만 발동하므로, 플레이어가 포탈 위에 선 채로 마지막 고치를
    # 부수면 settled가 다시 오지 않는다. 활성화 시점에 점유자를 한 번 검사한다.
    def _notify_cocoon_destroyed(self):
        if not self.portal_active():
            return
        if self.dead or self.fallen:
            return
        for e in self.g.ents:
            if e.type == "clear" and (e.x, e.y) == (self.px, self.py):
                self.cleared = True
                self.cleared_by = "player"

    # ── element_settled (포탈)
    def on_settle(self, who, x, y):
        for e in self.ents_at(x, y, who[0]):
            if e == "PLAYER":
                continue
            if e.type == "clear" and self.portal_active():
                self.cleared = True
                self.cleared_by = who[0]
            elif e.type == "worldPortal":
                self.cleared = True
                self.cleared_by = who[0]

    def damage_player(self, dmg):
        self.hp -= dmg
        if self.hp <= 0:
            self.hp = 0
            self.dead = True

    # ── Unit.move_to
    def move_to(self, who, d, spd):
        dx, dy = d
        moved, blocked = 0, False
        remain = spd
        while remain > 0:
            cx, cy = (self.px, self.py) if who[0] == "player" else self.boxes[who[1]]
            tx, ty = cx + dx, cy + dy
            if self.blocked(tx, ty, who[0]):
                blocked = True
                break
            if who[0] == "player":
                self.px, self.py = tx, ty
            else:
                self.boxes[who[1]] = (tx, ty)
            moved += 1
            remain -= 1
            self.on_enter(who, tx, ty)
        pos = (self.px, self.py) if who[0] == "player" else self.boxes[who[1]]
        if moved > 0:
            self.on_settle(who, *pos)
        return moved, blocked, pos

    # ── Unit.attack
    def attack(self, who, power, d, from_pos):
        tx, ty = from_pos[0] + d[0], from_pos[1] + d[1]
        for e in list(self.ents_at(tx, ty, who[0])):
            if e == "PLAYER":
                self.damage_player(power)
                continue
            if e.id in self.removed:
                continue
            if e.type == "wall":
                ma = e.d.get("ma", 0)
                if ma != 0 and ma <= power:
                    self.removed.add(e.id)
            elif e.type == "cocoon":
                if power >= 1:
                    self.removed.add(e.id)
                    self.kills.append((e.id, who[0]))
                    self._notify_cocoon_destroyed()
            elif e.type == "trap":
                if e.d.get("once", False):
                    self.removed.add(e.id)
            elif e.type == "moveBox":
                bx, by = self.boxes[e.id]
                bd = (sign(bx - from_pos[0]), sign(by - from_pos[1]))
                if bd != (0, 0) and (bd[0] == 0 or bd[1] == 0):
                    self.act(("box", e.id), bd, power, power)
            # healItem / clear / worldPortal: hitable = false

    # ── Unit.action2  (blocked 조건 없음!)
    def act(self, who, d, spd, atk):
        moved, blocked, pos = self.move_to(who, d, spd)
        cur_atk = self.atk_pow() if who[0] == "player" else atk
        remain = cur_atk - moved
        if remain > 0:
            self.attack(who, remain, d, pos)
        if not self.g.has_tile(*pos):
            if who[0] == "player":
                self.fallen = True
            else:
                self.removed.add(who[1])
                self.boxes.pop(who[1], None)

    def player_action(self, d):
        self.act(("player",), d, self.move_speed(), self.atk_pow())


# ─────────────────────────────── 탐색
def solve(path, verbose=True, max_states=400000):
    g = Game(load(path))
    start = g.initial()
    seen, q = {start: None}, deque([start])
    goal = None
    while q:
        s = q.popleft()
        if s[5]:
            goal = s
            break
        if len(seen) > max_states:
            break
        for k in "UDLR":
            ns = g.step(s, k)
            if ns is None or ns in seen:
                continue
            seen[ns] = (s, k)
            q.append(ns)
    if goal is None:
        if verbose:
            print(f"[{path}] ✗ 클리어 불가 — 탐색 상태 {len(seen)}")
        return None
    keys, cur = [], goal
    while seen[cur] is not None:
        prev, k = seen[cur]
        keys.append(k)
        cur = prev
    keys.reverse()
    if verbose:
        print(f"[{path}] ✓ 최단 {len(keys)}수: {' '.join(keys)}  (상태 {len(seen)})")
        replay(g, keys)
    return keys


def replay(g, keys):
    s = g.initial()
    nco = len(g.cocoon_ids)
    def coc(st):
        if not nco:
            return ""
        left = sum(1 for c in g.cocoon_ids if c not in st[6])
        return f" 고치{left}/{nco}" + ("" if left else " [포탈ON]")
    print(f"    시작 ({s[0]},{s[1]}) hp={s[2]} {emo(s[2])}{coc(s)}")
    for k in keys:
        s = g.step(s, k)
        print(f"    {k} → ({s[0]},{s[1]}) hp={s[2]} {emo(s[2])}{coc(s)}"
              f"{' DEAD' if s[3] else ''}{' FALL' if s[4] else ''}"
              f"{' CLEAR' if s[5] else ''}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        solve(p)
