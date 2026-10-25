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

## 스테이지 로드가 끝난 뒤 발생한다. 리셋·홈·월드 이동이 모두 이 경로를 지난다.
signal stage_loaded()

@export var entity_parent_name := "EntityParent"

var mapData: MapData
var _entity_parent: Node2D = null
var _error_overlay: MapErrorOverlay


func _ready() -> void:
	_error_overlay = MapErrorOverlay.new()
	add_child(_error_overlay)


# ─────────────────────────────────────────────
# 스테이지 로드 (기존 MapDrawer.draw_map 대체)
# ─────────────────────────────────────────────
func load_stage(world: int, stage: int) -> bool:
	# 개발용: 일단 빨갛게 칠하고 끝까지 가야 지운다 (중간에 끊겨도 빨갛게 남는다)
	var stage_name := "%d-%d" % [world, stage]
	_error_overlay.begin(stage_name)

	# ① 파싱 (실패 시 기존 스테이지 유지한 채 중단)
	mapData = MapLoader.load_map(world, stage)
	if mapData == null:
		_error_overlay.fail("맵 파일 읽기 실패 (%s)\n%s" % [stage_name, MapLoader.last_error])
		return false
	if not mapData.is_valid():
		_error_overlay.fail("맵 크기가 0 (%s)" % stage_name)
		return false

	# ② 기존 스테이지 해체
	unload_stage()

	if _find_entity_parent() == null:
		push_error("StageDirector: '%s' 노드를 찾을 수 없음" % entity_parent_name)
		_error_overlay.fail("'%s' 노드 없음 (%s)" % [entity_parent_name, stage_name])
		return false

	# ③ 매니저 초기화
	GridManager.init(mapData.map_width, mapData.map_height)
	StageContext.world    = mapData.world
	StageContext.stage    = mapData.stage
	StageContext.map_name = mapData.map_name

	# ④ 카메라 (이후 화면 크기가 바뀌면 카메라가 알아서 다시 맞춘다)
	MyCamera.instance.setup_map(
		mapData.tile_size_x, mapData.tile_size_y,
		mapData.map_width, mapData.map_height, mapData.zoom, mapData.offset,
		mapData.padding)

	# ⑤ 스폰
	EntitySpawner.spawn_all(mapData, _entity_parent)

	# 스폰 중 발동한 상호작용(시작 칸 칠리 등)의 시각 상태를 맞춘다
	ActionManager.settle_spawn_actions()
	# 발판은 그 위에 놓인 상자·고치가 다 스폰된 뒤에야 눌림 여부를 안다
	StageContext.sync_gate_after_spawn()
	
	# ⑥ 새 판이니 undo 히스토리 초기화
	UndoManager.clear_history()
	AudioManager.set_bgm_paused(false)
	AudioManager.play_bgm()
	# 리셋·홈·월드 이동도 전부 "맵에 들어서는" 순간이다.
	# 예전엔 GameStarter의 게임 시작 시점에만 울렸다.
	AudioManager.play_sfx("enter_stage")

	# 개발용: 보드가 실제로 깔렸는지 확인
	var problem := _check_spawned()
	if problem != "":
		_error_overlay.fail("맵 생성 이상 (%s): %s" % [stage_name, problem])
	else:
		_error_overlay.succeed()

	LogUtil.write("StageDirector: '%s' 로드 완료" % mapData.map_name)
	stage_loaded.emit()
	return true

func reload_stage() -> void:
	load_stage(mapData.world, mapData.stage)

func unload_stage() -> void:
	if _find_entity_parent() == null:
		return

	# 레지스트리를 먼저 비운다. 아래에서 노드를 즉시 해제하므로
	# 해제된 개체를 들고 있는 곳이 남으면 안 된다.
	GridManager.clear()
	PlayerRegistry.clear()
	StageContext.reset()   # worldPortals까지 함께 비운다

	for n in _entity_parent.get_children():
		_entity_parent.remove_child(n)
		# queue_free()가 아니라 free()다.
		# Trap/Chili/Cookie/Plate/Portal은 apply_data에서 GridManager의 시그널
		# (element_entered/settled)에 자신을 연결한다. 그 연결은 노드가
		# "트리에서 빠질 때"가 아니라 "해제될 때" 끊긴다. queue_free는 프레임
		# 끝에 해제되므로, 같은 프레임에 새 스테이지를 스폰하면 새 플레이어의
		# enter_element를 옛 스테이지의 칠리도 함께 받는다.
		# 시작 칸에 칠리가 있는 1-7/1-8에서 피해가 두 번 들어가 즉사했다.
		n.free()


## 깔려야 할 타일 수와 실제로 생긴 수, 플레이어 유무를 비교한다. 문제없으면 빈 문자열.
func _check_spawned() -> String:
	var expected := 0
	for row: Array in mapData.tile_rows:
		for id in row:
			if id != 0:
				expected += 1
	var tiles := 0
	for n in _entity_parent.get_children():
		# EntitySpawner와 같은 기준으로 타일을 알아본다 (Tile 타입을 직접 참조하지 않는다)
		if n.has_method("set_surround"):
			tiles += 1

	var problems := PackedStringArray()
	if tiles != expected:
		problems.append("타일 %d/%d개" % [tiles, expected])
	if PlayerRegistry.get_player() == null:
		problems.append("플레이어 없음")
	return ", ".join(problems)


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
	LogUtil.write("StageDirector - 맵 전환: ", mc.world, "-", mc.stage)
	
	if mc.get("out_of", false):
		EntitySpawner.isFixplayerPos = true
		EntitySpawner.fixed_playerPos_key = mc.get("out_of_w", 0) * StageContext.WORLD_ID_MULTIPLY \
			+ mc.get("out_of_s", 0)
	
	load_stage(mc.world, mc.stage)

	
