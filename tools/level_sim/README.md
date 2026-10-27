# 레벨 검증 시뮬레이터

맵 JSON을 실제 게임 규칙대로 돌려서, 에디터를 켜지 않고도
**클리어 가능한가 / 몇 수인가 / 어떤 감정을 강제하는가 / 어떤 오브젝트가 진짜 필요한가**를
확인하는 도구다. `01_Scripts`의 로직을 1:1 이식했다.

이식 대상: `Unit.action_dir/action2/move_to/attack`, `Player._set_hp`,
`Trap/Chili/Cookie/Wall/Obstacle/Cocoon/Stone.on_hit`, `Plate`(멈춘 무게로 눌림),
`GridManager.can_pass/has_tile/map_size_in/enter/step/settle`(맵 둘레 padding 칸 = 타일 없는 빈 칸 → 맵 밖으로 나가면 떨어진다),
`StageContext.is_gated/refresh_gate`, `ClearPortal.active`, `EntitySpawner.RANK`,
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

## 엔진 재생 검증 (`engine_replay/`)

시뮬레이터가 낸 최단 해답을 **실제 Godot 엔진**에서 한 수씩 재생해, 매 수 체력·위치가 같고
마지막 수에 클리어되는지 본다. 시뮬레이터가 엔진과 어긋나는 곳을 잡는 용도다
(2026-10-25에 이걸로 '맵 가장자리 = 벽' 오해를 찾아 고쳤다 — `docs/16_2월드_v4.md` 3절).

```bash
GODOT=/path/to/Godot_v4.7 tools/level_sim/engine_replay/run.sh            # 허브 뺀 모든 스테이지
GODOT=/path/to/Godot_v4.7 tools/level_sim/engine_replay/run.sh 02_01 02_09 # 일부만
```

게임 프로젝트를 임시 폴더에 복사해 `Replay.gd`를 오토로드로 넣고 헤드리스로 돈다. 원본 프로젝트는 건드리지 않는다.

## 새 맵 체크리스트

1. `sim.py` — 클리어 가능한가? 최단 수가 의도대로인가?
2. `analyze.py` — 의도한 감정이 **강제**되는가? 낙하/사망 경로가 존재하는가?
   (실패 경로가 0이면 플레이어가 배울 기회가 없는 맵이다)
3. `verify.py` — **돌이 필요한 누에고치가 정말 돌 전용인가?**
   그리고 **⚠ 돌이 목표 포탈을 밟아 클리어되는** 배치가 아닌가?
4. `render.py` — 지도를 눈으로 확인. 문서의 지도는 반드시 이걸로 생성한다.
5. `engine_replay/run.sh` — 실제 엔진에서도 같은 해답으로 깨지는가?

## 절제(ablation) 검증의 한계

오브젝트를 빼서 보는 절제 검증은 **막는 물체(벽/돌/누에고치)에는 무의미하다.**
없애면 길이 열려서 "없어도 클리어됨"이 나온다. 그래서 `verify.py`가
도달 가능한 모든 전이를 훑어 **누에고치를 누가 죽일 수 있는지**를 따로 판정한다.
(낙하/사망으로 끝나는 전이의 파괴는 해답에 기여하지 못하므로 제외한다)

## build.py 스펙 기호

```
.  바닥          _  구멍
W  벽(불괴)      j  장애물 항아리(ma=1)   V  장애물 기둥(ma=2)
C  누에고치      S  돌          O  발판
P  플레이어      E  클리어 포탈   H  쿠키(+1)
1-3 가시(atk=숫자)                c  칠리(항상 -1)
^ v < >  고블린(순찰) — 글자가 바라보는 방향이 초기 진행 방향
X  고블린(추적) — 매 턴 플레이어 쪽으로 1칸
```

겹침 배치는 `extra: x,y type k=v` 줄로 쓴다. 허브 맵(월드 포탈)은 직접 JSON으로 쓴다.

## 한계

- `interaction`(탭/스페이스) 입력은 스테이지 맵에서 구독자가 없어 모델링하지 않았다.
  (허브의 "클리어된 포탈 재진입"에만 쓰인다)
- 되돌리기는 시뮬레이션하지 않는다. BFS가 모든 상태를 보므로 되돌리기와 등가다.
- `Portal`이 엘리먼트 종류를 가리지 않는 현재 동작을 **그대로** 이식했다.
  그래서 돌이 목표를 밟는 배치를 검출할 수 있다.
