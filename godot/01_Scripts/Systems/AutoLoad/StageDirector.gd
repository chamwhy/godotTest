# StageDirector.gd
# AutoLoad
#
# ─── 역할 ────────────────────────────────────────────────────
# 스테이지 로드/전환/해체의 흐름 제어.
#   load_stage: 로드 → 매니저 초기화 → 카메라 → 스폰 → 히스토리 클리어
#   맵 전환 예약 실행도 여기서 담당 (StageContext에서 이관)
#
# "무엇을 언제" 할지만 안다. "어떻게"는 각 담당자가 안다.
# ─────────────────────────────────────────────────────────────
extends Node

@export var entity_parent_name := "EntityParent"

var mapData: MapData
var _entity_parent: Node2D = null


# ─────────────────────────────────────────────
# 스테이지 로드 (기존 MapDrawer.draw_map 대체)
# ─────────────────────────────────────────────
func load_stage(world: int, stage: int) -> bool:
	# ① 파싱 (실패 시 기존 스테이지 유지한 채 중단)
	mapData = MapLoader.load_map(world, stage)
	if mapData == null or not mapData.is_valid():
		return false

	# ② 기존 스테이지 해체
	unload_stage()

	if _find_entity_parent() == null:
		push_error("StageDirector: '%s' 노드를 찾을 수 없음" % entity_parent_name)
		return false

	# ③ 매니저 초기화
	GridManager.init(mapData.map_width, mapData.map_height)
	StageContext.world    = mapData.world
	StageContext.stage    = mapData.stage
	StageContext.map_name = mapData.map_name

	# ④ 카메라
	MyCamera.instance.setup_map(
		mapData.tile_size_x, mapData.tile_size_y,
		mapData.map_width, mapData.map_height, mapData.zoom)

	# ⑤ 스폰
	EntitySpawner.spawn_all(mapData, _entity_parent)

	# ⑥ 새 판이니 undo 히스토리 초기화
	UndoManager.clear_history()

	print("StageDirector: '%s' 로드 완료" % mapData.map_name)
	return true


func unload_stage() -> void:
	if _find_entity_parent() == null:
		return
	for n in _entity_parent.get_children():
		_entity_parent.remove_child(n)
		n.queue_free()
	GridManager.clear()
	PlayerRegistry.clear()
	StageContext.reset()
	# worldPortals는 유지 — 맵을 넘나들며 쌓이는 월드 데이터
	# 생각해보면 리셋해야 됨. 일단 TODO


func _find_entity_parent() -> Node2D:
	var current_root = get_tree().current_scene
	_entity_parent = current_root.find_child(entity_parent_name, true)
	return _entity_parent


# ─────────────────────────────────────────────
# 맵 전환 예약 실행 (StageContext.flush에서 이관)
# ─────────────────────────────────────────────
func flush_pending_map_change() -> void:
	if not StageContext.has_pending_map_change():
		return
	var mc: Dictionary = StageContext.take_pending_map_change()
	print("StageDirector - 맵 전환: ", mc.world, "-", mc.stage)

	load_stage(mc.world, mc.stage)

	if mc.get("out_of", false):
		var key: int = mc.get("out_of_w", 0) * StageContext.WORLD_ID_MULTIPLY \
			+ mc.get("out_of_s", 0)
		var player: Player = PlayerRegistry.get_player()
		if player:
			var portal: Position = StageContext.worldPortals.get(key, player.cur_position)
			player.move_to_pos(portal)
