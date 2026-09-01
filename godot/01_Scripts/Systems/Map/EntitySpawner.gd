# EntitySpawner.gd
# ─── 역할 ────────────────────────────────────────────────────
# MapData를 받아 타일/엔티티 씬을 인스턴스화하고 apply_data를 호출한다.
# 어떤 맵인지, 왜 그리는지는 모른다. 주어진 데이터를 생성할 뿐.
# ─────────────────────────────────────────────────────────────
class_name EntitySpawner
extends RefCounted

static var isFixplayerPos := false
static var fixed_playerPos_key: int = 0

static func spawn_all(data: MapData, parent: Node2D) -> void:
	print("spawn all")
	_spawn_tiles(data, parent)
	_spawn_entities(data, parent)


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
const RANK := {"trap": 0, "wall": 1, "healItem": 2, "worldPortal": 3, "clear": 4, "moveBox": 5, "player": 6}

static func _spawn_entities(data: MapData, parent: Node2D) -> void:
	
	# object_type에 따른 순서 배열.
	# 순서를 지킴으로 object register의 중요도를 선별하기 위함.
	# 예) 무조건 unit은 trap 다음으로 해야 초기 밟음을 구현가능.
	data.entities.sort_custom(func(a, b):
		return RANK.get(a.get("obj_type", ""), 99) < RANK.get(b.get("obj_type", ""), 99)
	)
	
	for entity_data: Dictionary in data.entities:
		var type_name: String = entity_data.get("obj_type", "")
		if isFixplayerPos:
			print("isFixplayerPos")
		
		# 플레이어 위치 강제 지정 (1회성)
		if isFixplayerPos and type_name == "player":
			if StageContext.worldPortals.has(fixed_playerPos_key) \
				and entity_data.has("x") \
				and entity_data.has("y"):
				print("플레이어 위치 강제 지정 (1회성)")
				var pos: Position = StageContext.worldPortals[fixed_playerPos_key]
				entity_data = entity_data.duplicate()
				entity_data["x"] = pos.x
				entity_data["y"] = pos.y
				isFixplayerPos = false
			else:
				push_warning("EntitySpawner: player entity에 x/y 키 없음 → %s" % entity_data.keys())
		
		var scene: PackedScene = Config.EXP_RES.entityScenes.get(type_name)
		if scene == null:
			push_warning("EntitySpawner: 알 수 없는 타입 → %s" % type_name)
			continue
		print("entitySpawn: ",data.get("stage"), type_name)

		var obj: Node2D = scene.instantiate()
		parent.add_child(obj)
		if obj.has_method("apply_data"):
			obj.apply_data(entity_data)
