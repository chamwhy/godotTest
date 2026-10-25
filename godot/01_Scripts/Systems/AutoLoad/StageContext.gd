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

## 스테이지를 깬 순간. StageManager.stage_cleared는 "처음 깼을 때"만 발생하므로
## 재도전 때도 반응해야 하는 연출(엔딩 등)은 이쪽을 구독한다.
signal stage_completed(world_id: int, stage_id: int)

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
	_cocoons = []
	_plates = []
	_clear_portal = null


func complete_stage() -> void:
	StageManager.clear_stage(world, stage)
	stage_completed.emit(world, stage)


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


#region gate
# ─── 클리어 조건: 누에고치 전멸 + 발판 전부 눌림 ──────────────────
# 스폰 순서 보장: 누에고치·발판 전부 → ClearPortal.
# 따라서 포탈이 apply_data에서 is_gated()를 물으면 이미 등록이 끝나 있다.
# 발판을 누를 상자·플레이어는 포탈보다 늦게 스폰되므로, 스폰이 다 끝난 뒤
# sync_gate_after_spawn()으로 한 번 더 맞춘다.

var _cocoons: Array = []       # Array[Cocoon]
var _plates: Array = []        # Array[Plate]
var _clear_portal = null       # ClearPortal 단일 참조 (스테이지당 하나)

func register_cocoon(c) -> void:
	if c not in _cocoons:
		_cocoons.append(c)

func register_plate(p) -> void:
	if p not in _plates:
		_plates.append(p)

func register_clear_portal(p) -> void:
	_clear_portal = p

## 이 스테이지가 누에고치·발판으로 잠겨있는가.
## 둘 다 없으면 false → 포탈은 처음부터 활성.
func is_gated() -> bool:
	return not (_all_cocoons_cleared() and _all_plates_pressed())

## 누에고치 하나가 파괴된 직후(hide_for_undo 이후) 호출.
func notify_cocoon_destroyed(tick: int) -> void:
	refresh_gate(tick)

## 조건이 바뀌었을 수 있는 순간(고치 파괴, 발판 눌림/떼짐)마다 호출.
## 포탈을 켜고 끄는 것을 연출과 함께 기록한다. 발판이 떼지면 다시 꺼진다.
func refresh_gate(tick: int) -> void:
	if not is_instance_valid(_clear_portal):
		return
	var open := not is_gated()
	if open and not _clear_portal.active:
		_clear_portal.activate(tick)
	elif not open and _clear_portal.active:
		_clear_portal.deactivate(tick)

## 스폰이 끝난 뒤 발판·포탈 상태를 놓인 그대로 맞춘다. 연출 없이 즉시.
func sync_gate_after_spawn() -> void:
	for p in _plates:
		if is_instance_valid(p):
			p.sync_pressed()
	if is_instance_valid(_clear_portal):
		_clear_portal.set_active_now(not is_gated())

## in_map 스캔 → undo 스냅샷과 자동 동기화(별도 카운터 없음).
func _all_cocoons_cleared() -> bool:
	for c in _cocoons:
		if is_instance_valid(c) and c.in_map:
			return false
	return true

func _all_plates_pressed() -> bool:
	for p in _plates:
		if is_instance_valid(p) and p.in_map and not p.pressed:
			return false
	return true
#endregion
