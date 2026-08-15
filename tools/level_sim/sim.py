"""
bsk 게임 규칙 시뮬레이터 (GDScript 로직 1:1 이식)

참조:
  Unit.action_dir / action2 / move_to / attack
  Player._set_hp (emotion)
  Trap._check_pos / on_hit, HealItem._check_pos, Wall.on_hit, MoveBox.on_hit
  GridManager.can_pass / has_tile / element_entered / element_settled
"""
import json, re, sys
from collections import deque

DIRS = {"U": (0, -1), "D": (0, 1), "L": (-1, 0), "R": (1, 0)}


def load(path):
    txt = open(path, encoding="utf-8").read()
    txt = re.sub(r",(\s*[}\]])", r"\1", txt)  # trailing comma 제거
    return json.loads(txt)


class Ent:
    __slots__ = ("id", "type", "x", "y", "d")

    def __init__(self, i, d):
        self.id = i
        self.type = d["obj_type"]
        self.x = d["x"]
        self.y = d["y"]
        self.d = d


class Game:
    def __init__(self, raw):
        self.tiles = raw["tile_map"]
        self.h = len(self.tiles)
        self.w = len(self.tiles[0])
        self.ents = []
        self.player_ent = None
        for i, d in enumerate(raw["entities"]):
            e = Ent(i, d)
            if e.type == "player":
                self.player_ent = e
            self.ents.append(e)
        self.max_hp = self.player_ent.d.get("mh", 1)

    def initial(self):
        p = self.player_ent
        boxes = tuple(sorted((e.id, e.x, e.y) for e in self.ents if e.type == "moveBox"))
        return (p.x, p.y, p.d.get("ch", self.max_hp), False, False, False, frozenset(), boxes)

    def has_tile(self, x, y):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return False
        return self.tiles[y][x] != 0

    def step(self, state, key):
        px, py, hp, dead, fallen, cleared, removed, boxes = state
        if dead or fallen or cleared:
            return None
        ctx = Ctx(self, set(removed), {b[0]: (b[1], b[2]) for b in boxes}, px, py, hp)
        ctx.player_action(DIRS[key])
        ns = ctx.snapshot()
        return None if ns == state else ns


class Ctx:
    def __init__(self, g, removed, boxes, px, py, hp):
        self.g = g
        self.removed = removed          # 소멸한 entity id (벽/일회성함정/힐/낙하박스)
        self.boxes = boxes              # id -> (x,y)
        self.px, self.py = px, py
        self.hp = hp
        self.dead = False
        self.fallen = False
        self.cleared = False

    def snapshot(self):
        boxes = tuple(sorted((i, p[0], p[1]) for i, p in self.boxes.items()))
        return (self.px, self.py, self.hp, self.dead, self.fallen,
                self.cleared, frozenset(self.removed), boxes)

    # 감정 (Player._set_hp)
    def atk_pow(self):
        return 1 if self.hp >= 4 else 2

    def move_speed(self):
        return 2 if self.hp <= 1 else 1

    def ents_at(self, x, y, mover=None):
        out = []
        for e in self.g.ents:
            if e.id in self.removed or e.type == "player":
                continue
            if e.type == "moveBox":
                bp = self.boxes.get(e.id)
                if bp is None or bp != (x, y):
                    continue
                out.append(e)
            elif (e.x, e.y) == (x, y):
                out.append(e)
        if mover != "player" and (self.px, self.py) == (x, y) \
                and not self.dead and not self.fallen:
            out.append("PLAYER")
        return out

    def blocked(self, x, y, mover):
        if not (0 <= x < self.g.w and 0 <= y < self.g.h):
            return True
        for e in self.ents_at(x, y, mover):
            if e == "PLAYER":
                return True     # player is_block = true
            if e.type in ("wall", "moveBox"):
                return True
        return False

    def on_enter(self, who, x, y):
        for e in list(self.ents_at(x, y, mover=who[0])):
            if e == "PLAYER":
                continue
            if e.type == "trap" and e.id not in self.removed:
                if who[0] == "player":
                    self.damage_player(e.d.get("atk", 0))
                # 박스: on_hit → dir=(0,0) → 아무 일 없음 (함정만 소모)
                if e.d.get("once", False):
                    self.removed.add(e.id)
            elif e.type == "healItem" and e.id not in self.removed:
                if who[0] == "player":
                    self.hp = min(self.g.max_hp, self.hp + e.d.get("heal", 1))
                self.removed.add(e.id)

    def on_settle(self, who, x, y):
        for e in self.ents_at(x, y, mover=who[0]):
            if e == "PLAYER":
                continue
            if e.type in ("clear", "worldPortal"):
                self.cleared = True

    def damage_player(self, dmg):
        self.hp -= dmg
        if self.hp <= 0:
            self.hp = 0
            self.dead = True

    def move_to(self, who, dir, spd):
        dx, dy = dir
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
            self.on_enter(who, tx, ty)
            moved += 1
            remain -= 1
        pos = (self.px, self.py) if who[0] == "player" else self.boxes[who[1]]
        if moved > 0:
            self.on_settle(who, *pos)
        return moved, blocked, pos

    def attack(self, who, power, dir, from_pos):
        tx, ty = from_pos[0] + dir[0], from_pos[1] + dir[1]
        for e in list(self.ents_at(tx, ty, mover=who[0])):
            if e == "PLAYER":
                self.damage_player(power)
                continue
            if e.id in self.removed:
                continue
            if e.type == "wall":
                ma = e.d.get("ma", 0)
                if ma != 0 and ma <= power:
                    self.removed.add(e.id)
            elif e.type == "trap":
                if e.d.get("once", False):
                    self.removed.add(e.id)   # 일회성 함정은 때려서 해제 가능
            elif e.type == "moveBox":
                bx, by = self.boxes[e.id]
                bdir = (sign(bx - from_pos[0]), sign(by - from_pos[1]))
                if bdir != (0, 0) and (bdir[0] == 0 or bdir[1] == 0):
                    self.act(("box", e.id), bdir, power, power)
            # healItem: hitable=false → 무시

    def act(self, who, dir, spd, atk):
        moved, blocked, pos = self.move_to(who, dir, spd)
        cur_atk = self.atk_pow() if who[0] == "player" else atk
        remain = cur_atk - moved
        if blocked and remain > 0:
            self.attack(who, remain, dir, pos)
        if not self.g.has_tile(*pos):
            if who[0] == "player":
                self.fallen = True
            else:
                self.removed.add(who[1])
                self.boxes.pop(who[1], None)

    def player_action(self, dir):
        self.act(("player",), dir, self.move_speed(), self.atk_pow())


def sign(v):
    return (v > 0) - (v < 0)


def emo(hp):
    return "평온" if hp >= 4 else ("화남" if hp >= 2 else "격노")


def solve(path, verbose=True):
    g = Game(load(path))
    start = g.initial()
    seen = {start: None}
    q = deque([start])
    goal = None
    while q:
        s = q.popleft()
        if s[5]:
            goal = s
            break
        for k in "UDLR":
            ns = g.step(s, k)
            if ns is None or ns in seen:
                continue
            seen[ns] = (s, k)
            q.append(ns)
    if goal is None:
        if verbose:
            print(f"[{path}] ✗ 클리어 불가 — 탐색 상태 수 {len(seen)}")
        return None
    keys = []
    cur = goal
    while seen[cur] is not None:
        prev, k = seen[cur]
        keys.append(k)
        cur = prev
    keys.reverse()
    if verbose:
        print(f"[{path}] ✓ 최단 {len(keys)}수: {' '.join(keys)}  (탐색 상태 {len(seen)})")
        replay(g, keys)
    return keys


def replay(g, keys):
    s = g.initial()
    print(f"    시작 ({s[0]},{s[1]}) hp={s[2]} {emo(s[2])}")
    for k in keys:
        s = g.step(s, k)
        print(f"    {k} → ({s[0]},{s[1]}) hp={s[2]} {emo(s[2])}"
              f"{' DEAD' if s[3] else ''}{' FALL' if s[4] else ''}"
              f"{' CLEAR' if s[5] else ''}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        solve(p)
