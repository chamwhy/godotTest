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
