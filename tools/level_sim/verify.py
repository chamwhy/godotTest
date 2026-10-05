"""설계 의도 검증기 — 누에고치를 '무엇이' 죽일 수 있는지 전수조사.

절제(ablation) 검증은 '막는 물체'에 쓸 수 없다(없애면 길이 열려 버린다).
그래서 도달 가능한 모든 전이를 훑어서, 각 누에고치가 실제로
플레이어의 직접 타격으로 죽을 수 있는지 / 상자를 통해서만 죽는지를 판정한다.
"""
import sys
from collections import deque
from sim import Game, load


def check(path, quiet=False):
    g = Game(load(path))
    start = g.initial()
    seen, q = {start}, deque([start])
    killers = {cid: set() for cid in g.cocoon_ids}
    clearers = set()
    while q:
        s = q.popleft()
        if s[5] or s[3] or s[4]:
            continue
        for k in "UDLR":
            ns, kills, cby = g.step_ex(s, k)
            if cby: clearers.add(cby)
            # 낙하/사망으로 끝난 전이의 파괴는 해답에 기여할 수 없으므로 제외
            if ns is not None and not (ns[3] or ns[4]):
                for cid, who in kills:
                    killers[cid].add(who)
            if ns is None or ns in seen:
                continue
            seen.add(ns)
            q.append(ns)
    if not quiet:
        print(f"[{path}]  상태 {len(seen)}")
        if not g.cocoon_ids:
            print("  누에고치 없음")
        for cid in g.cocoon_ids:
            e = g.by_id[cid]
            ks = killers[cid]
            if not ks:
                verdict = "★ 파괴 불가 — 클리어 불가능!"
            elif ks == {"box"}:
                verdict = "상자만 파괴 가능 (상자 필수)"
            elif ks == {"player"}:
                verdict = "플레이어 직접 타격만"
            else:
                verdict = "플레이어/상자 둘 다 가능"
            print(f"  누에고치({e.x},{e.y}): {verdict}")
        if "box" in clearers:
            print("  ⚠ 상자가 목표 포탈을 밟아 클리어됨 (Portal 코드 버그 노출) → 배치 수정 필요")
    return killers


if __name__ == "__main__":
    for p in sys.argv[1:]:
        check(p)
