# EntitySpawner.gd
# ─── 역할 ────────────────────────────────────────────────────
# MapData를 받아 타일/엔티티 씬을 인스턴스화하고 apply_data를 호출한다.
# 어떤 맵인지, 왜 그리는지는 모른다. 주어진 데이터를 생성할 뿐.
# ─────────────────────────────────────────────────────────────
class_name EntitySpawner
extends RefCounted


static func spawn_all(data: MapData, parent: Node2D) -> void:
	_spawn_tiles(data, parent)
	_spawn_entities(data, parent, false)  # Unit이 아닌 것 먼저
	_spawn_entities(data, parent, true)   # Unit 나중 (기존 순서 유지)


# ─────────────────────────────────────────────
# 타일
# ─────────────────────────────────────────────
static func _spawn_tiles(data: MapData, parent: Node2D) -> void:
	var scene: PackedScene = Config.EXP_RES.entityScenes.get("tile")
	if scene == null:
		push_error("EntitySpawner: tile 씬 없음")
		return

	var rows := data.tile_rows
	for y in range(rows.size()):
		var row: Array = rows[y]
		for x in range(row.size()):
			var tile_id: int = row[x]
			if tile_id == 0:
				continue

			var tile_obj: Node2D = scene.instantiate()
			parent.add_child(tile_obj)

			if tile_obj.has_method("set_surround"):
				tile_obj.set_surround(_surround_of(rows, y, x))

			if tile_obj.has_method("apply_data"):
				tile_obj.apply_data({
					"id": tile_id,
					"x": x + data.padding,
					"y": y + data.padding,
				})


static func _surround_of(rows: Array, y: int, x: int) -> Array:
	var get_at := func(sy: int, sx: int) -> int:
		if sy < 0 or sy >= rows.size(): return 0
		if sx < 0 or sx >= rows[sy].size(): return 0
		return rows[sy][sx]
	return [
		[get_at.call(y-1, x-1), get_at.call(y-1, x), get_at.call(y-1, x+1)],
		[get_at.call(y,   x-1), get_at.call(y,   x), get_at.call(y,   x+1)],
		[get_at.call(y+1, x-1), get_at.call(y+1, x), get_at.call(y+1, x+1)],
	]


# ─────────────────────────────────────────────
# 엔티티
# ─────────────────────────────────────────────
static func _spawn_entities(data: MapData, parent: Node2D, want_unit: bool) -> void:
	for entity_data: Dictionary in data.entities:
		var type_name: String = entity_data.get("obj_type", "")
		var scene: PackedScene = Config.EXP_RES.entityScenes.get(type_name)
		if scene == null:
			push_warning("EntitySpawner: 알 수 없는 타입 → %s" % type_name)
			continue

		# 인스턴스화 전에 타입 판별 (기존: 만들고 버림 → 낭비 + _ready 부작용)
		var is_unit_scene := _is_unit_type(scene)
		if is_unit_scene != want_unit:
			continue

		var obj: Node2D = scene.instantiate()
		parent.add_child(obj)
		if obj.has_method("apply_data"):
			obj.apply_data(entity_data)


# PackedScene의 루트 스크립트로 Unit 여부 판별 (인스턴스화 없이)
static func _is_unit_type(scene: PackedScene) -> bool:
	var state := scene.get_state()
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == "script":
			var script: Script = state.get_node_property_value(0, i)
			while script:
				if script.get_global_name() == "Unit":
					return true
				script = script.get_base_script()
	return false
