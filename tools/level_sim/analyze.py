"""맵의 상태공간 전수조사: 클리어 조건 / 실패 유형 / 필수 감정단계 확인"""
import sys
from collections import deque
from sim import Game, load, DIRS, emo


def analyze(path):
    g = Game(load(path))
    start = g.initial()
    seen = {start}
    q = deque([start])
    clear_hp, dead, fallen = set(), 0, 0
    hp_seen = set()
    while q:
        s = q.popleft()
        hp_seen.add(s[2])
        if s[5]:
            clear_hp.add(s[2])
            continue
        if s[3]:
            dead += 1
            continue
        if s[4]:
            fallen += 1
            continue
        for k in "UDLR":
            ns = g.step(s, k)
            if ns and ns not in seen:
                seen.add(ns)
                q.append(ns)
    print(f"[{path}]")
    print(f"  상태 수 {len(seen)} / 사망 상태 {dead} / 낙하 상태 {fallen}")
    print(f"  도달 가능 HP: {sorted(hp_seen)}")
    print(f"  클리어 시점 HP: {sorted(clear_hp)}"
          f" → 감정: {sorted({emo(h) for h in clear_hp})}")

    # 필수 경유 감정: 모든 클리어 경로가 특정 감정을 거치는지
    for tier, name in ((1, "격노(hp<=1)"), (2, "화남(hp 2~3)")):
        if not can_clear_avoiding(g, tier):
            print(f"  ※ {name} 상태를 거치지 않고는 클리어 불가 (필수 관문)")


def can_clear_avoiding(g, tier):
    """해당 감정 티어에 한 번도 들어가지 않고 클리어 가능한가?"""
    def t(hp):
        return 1 if hp <= 1 else (2 if hp <= 3 else 3)
    start = g.initial()
    if t(start[2]) == tier:
        return True
    seen = {start}
    q = deque([start])
    while q:
        s = q.popleft()
        if s[5]:
            return True
        for k in "UDLR":
            ns = g.step(s, k)
            if ns is None or ns in seen or t(ns[2]) == tier:
                continue
            seen.add(ns)
            q.append(ns)
    return False


if __name__ == "__main__":
    for p in sys.argv[1:]:
        analyze(p)
