# 레벨 검증 시뮬레이터

맵 JSON을 실제 게임 규칙대로 시뮬레이션해서, 에디터를 켜지 않고도
**클리어 가능한지 / 몇 수인지 / 어떤 감정을 강제하는지**를 확인하는 도구다.

`01_Scripts`의 다음 로직을 그대로 이식했다.

- `Unit.action_dir / action2 / move_to / attack` — 이동력과 공격력이 한 자원인 규칙
- `Player._set_hp` — 체력 → 감정 → 이동력/공격력
- `Trap / HealItem / Wall / MoveBox.on_hit` — 오브젝트별 반응
- `GridManager.can_pass / has_tile`, `element_entered` / `element_settled` — 진입과 정착의 구분

## 사용법

```bash
cd godot/05_Data/01_MapData

# 최단 해답 탐색 + 턴별 재생
python3 ../../../tools/level_sim/sim.py 01_08.json

# 상태공간 전수조사 (사망/낙하 수, 클리어 시점 감정, 필수 관문 감정)
python3 ../../../tools/level_sim/analyze.py 01_08.json

# 절제 검증: 오브젝트를 하나씩 빼서 클리어 가능 여부가 바뀌는지
python3 ../../../tools/level_sim/ablate.py 01_08.json
```

## 출력 예시

```
[01_08.json] ✓ 최단 16수: U U U U R R R R D L D L L D D R
    시작 (0,4) hp=6 평온
    U → (0,3) hp=6 평온
    ...
    D → (2,3) hp=2 화남
    R → (3,4) hp=2 화남 CLEAR

  클리어 시점 HP: [2, 3] → 감정: ['화남']
  ※ 화남(hp 2~3) 상태를 거치지 않고는 클리어 불가 (필수 관문)
```

## 새 맵을 만들 때의 체크리스트

1. `sim.py` — 클리어 가능한가? 최단 수가 12~25 사이인가?
2. `analyze.py` — 의도한 감정이 실제로 강제되는가? 낙하/사망 경로가 존재하는가?
   (실패 경로가 0이면 플레이어가 배울 기회가 없는 맵이다)
3. `ablate.py` — 없어도 풀리는 오브젝트가 있는가? 있다면 노이즈이거나,
   의도적인 유혹 장치여야 한다.

## 알려진 한계

- `interaction`(탭/스페이스) 입력은 현재 게임에서 구독자가 없어 무동작이므로 모델링하지 않았다.
- 되돌리기는 시뮬레이션하지 않는다. BFS가 모든 상태를 탐색하므로 되돌리기와 등가다.
- 포탈은 코드와 동일하게 "엘리먼트 종류를 가리지 않고" 발동하도록 이식했다.
  (`Portal.gd`의 현재 동작. 상자가 목표에 멈춰도 클리어된다)
