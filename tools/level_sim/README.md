# 레벨 검증 시뮬레이터

맵 JSON을 실제 게임 규칙대로 돌려서, 에디터를 켜지 않고도
**클리어 가능한가 / 몇 수인가 / 어떤 감정을 강제하는가 / 어떤 오브젝트가 진짜 필요한가**를
확인하는 도구다. `01_Scripts`의 로직을 1:1 이식했다.

이식 대상: `Unit.action_dir/action2/move_to/attack`, `Player._set_hp`,
`Trap/HealItem/Wall/Cocoon/MoveBox.on_hit`, `GridManager.can_pass/has_tile/enter/step/settle`,
`StageContext.is_gated`, `ClearPortal.active`, `EntitySpawner.RANK`,
`Goblin.take_turn`(순찰 반전 / 추적 축 우선순위 / 낙하 / 함정 사망).

## 사용법

```bash
cd godot/05_Data/01_MapData
export PYTHONPATH=../../../tools/level_sim
T=../../../tools/level_sim

python3 $T/sim.py 02_10.json              # 최단 해답 + 턴별 재생
python3 $T/analyze.py 02_10.json          # 상태공간/사망/낙하/필수 감정
python3 $T/analyze.py --ablate 02_10.json # 오브젝트 하나씩 제거해 영향 확인
python3 $T/verify.py 02_10.json           # 누에고치 가해자 추적 + 포탈 버그 검출
python3 $T/render.py 02_10.json           # 기호 표(마크다운)로 지도 출력
python3 $T/build.py spec.txt .            # ASCII 스펙 -> 맵 JSON 생성
```

## 새 맵 체크리스트

1. `sim.py` — 클리어 가능한가? 최단 수가 의도대로인가?
2. `analyze.py` — 의도한 감정이 **강제**되는가? 낙하/사망 경로가 존재하는가?
   (실패 경로가 0이면 플레이어가 배울 기회가 없는 맵이다)
3. `verify.py` — **상자가 필요한 누에고치가 정말 상자 전용인가?**
   그리고 **⚠ 상자가 목표 포탈을 밟아 클리어되는** 배치가 아닌가?
4. `render.py` — 지도를 눈으로 확인. 문서의 지도는 반드시 이걸로 생성한다.

## 절제(ablation) 검증의 한계

오브젝트를 빼서 보는 절제 검증은 **막는 물체(벽/상자/누에고치)에는 무의미하다.**
없애면 길이 열려서 "없어도 클리어됨"이 나온다. 그래서 `verify.py`가
도달 가능한 모든 전이를 훑어 **누에고치를 누가 죽일 수 있는지**를 따로 판정한다.
(낙하/사망으로 끝나는 전이의 파괴는 해답에 기여하지 못하므로 제외한다)

## build.py 스펙 기호

```
.  바닥          _  구멍
W  벽(불괴)      w  벽 ma=1       V  벽 ma=2
C  누에고치      B  상자
P  플레이어      E  클리어 포탈   H  회복(+1)
1-6 상시 고추(atk=숫자)           a-f 일회성 고추(atk=1~6)
^ v < >  고블린(순찰) — 글자가 바라보는 방향이 초기 진행 방향
X  고블린(추적) — 매 턴 플레이어 쪽으로 1칸
```

겹침 배치는 `extra: x,y type k=v` 줄로 쓴다. 허브 맵(월드 포탈)은 직접 JSON으로 쓴다.

## 한계

- `interaction`(탭/스페이스) 입력은 스테이지 맵에서 구독자가 없어 모델링하지 않았다.
  (허브의 "클리어된 포탈 재진입"에만 쓰인다)
- 되돌리기는 시뮬레이션하지 않는다. BFS가 모든 상태를 보므로 되돌리기와 등가다.
- `Portal`이 엘리먼트 종류를 가리지 않는 현재 동작을 **그대로** 이식했다.
  그래서 상자가 목표를 밟는 배치를 검출할 수 있다.
