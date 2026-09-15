# StageContext.gd
# AutoLoad
#
# ─── 역할 ────────────────────────────────────────────────────
# "지금 어느 스테이지를 플레이 중인가"에 대한 상태.
#   · world / stage / map_name
#   · 월드 포탈 위치 기록
#   · 맵 전환 예약 및 실행 (③단계에서 StageDirector로 이관 예정)
# ─────────────────────────────────────────────────────────────
extends Node

const WORLD_ID_MULTIPLY := 100

var world := 0
var stage := 0
var map_name := ""

var worldPortals: Dictionary[int, Position] = {}

# 턴 종료 후 처리할 맵 전환 예약 (비어있으면 없음)
var _pending_map_change: Dictionary = {}


func reset() -> void:
	worldPortals = {}
	_pending_map_change = {}
	_cocoons = []      # ← 추가


func complete_stage() -> void:
	StageManager.clear_stage(world, stage)


func register_worldPortal_position(stageID: int, pos: Position) -> void:
	worldPortals[stageID] = pos


func request_map_change(changeDict: Dictionary) -> void:
	_pending_map_change = changeDict


func has_pending_map_change() -> bool:
	return not _pending_map_change.is_empty()


# flush_pending_map_change() 삭제하고 이걸로 교체:
func take_pending_map_change() -> Dictionary:
	var mc := _pending_map_change
	_pending_map_change = {}
	return mc


#region cocoon
# ─── 클리어 조건: 누에고치 전멸 ──────────────────
signal cocoons_cleared(tick: int)

var _cocoons: Array = []   # Array[Cocoon]. 맵 로드시 등록, reset()에서 비움

func register_cocoon(c) -> void:
	if c not in _cocoons:
		_cocoons.append(c)

## 누에고치 하나가 파괴된 "직후" 호출. 전멸이면 시그널.
func notify_cocoon_destroyed(tick: int) -> void:
	if _all_cocoons_cleared():
		cocoons_cleared.emit(tick)

## 등록된 누에고치가 있고, 맵에 남은 게 하나도 없으면 true.
## in_map을 스캔 → undo 스냅샷과 자동 동기화(별도 카운터 불필요).
func _all_cocoons_cleared() -> bool:
	var had := false
	for c in _cocoons:
		if not is_instance_valid(c): continue
		had = true
		if c.in_map:
			return false
	return had   # 누에고치 0마리면 false (게이트 조건 미성립)
#endregion
