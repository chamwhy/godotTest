# MapLoader.gd
# ─── 역할 ────────────────────────────────────────────────────
# 파일 경로 → MapData 변환. 그게 전부다.
# 씬 트리, 매니저, 카메라 — 아무것도 건드리지 않는다.
# 실패 시 null 반환.
# ─────────────────────────────────────────────────────────────
class_name MapLoader
extends RefCounted

const MAP_DATA_HEADER := "res://05_Data/01_MapData/"


static func load_map(world: int, stage: int) -> MapData:
	var json_path := MAP_DATA_HEADER + "%02d_%02d.json" % [world, stage]
	var raw: Dictionary = JsonParser.load_json_data(json_path)
	if raw.is_empty():
		push_error("MapLoader: 로드 실패 → %s" % json_path)
		return null

	var data := MapData.new()
	data.world       = raw.get("world", 0)
	data.stage       = raw.get("stage", 0)
	data.map_name    = raw.get("map_name", "")
	data.tile_size_x = raw.get("tile_size_x", 32)
	data.tile_size_y = raw.get("tile_size_y", 24)
	data.padding     = raw.get("padding", 0)
	data.map_width   = raw.get("map_width", 10)  + data.padding * 2
	data.map_height  = raw.get("map_height", 10) + data.padding * 2
	data.zoom        = raw.get("zoom", 0)
	data.tile_rows   = raw.get("tile_map", [])

	# 엔티티 좌표를 여기서 padding 보정 (spawner는 보정을 몰라도 됨)
	for entity_data: Dictionary in raw.get("entities", []):
		var ed := entity_data.duplicate()
		if ed.has("x"): ed["x"] += data.padding
		if ed.has("y"): ed["y"] += data.padding
		data.entities.append(ed)

	return data
