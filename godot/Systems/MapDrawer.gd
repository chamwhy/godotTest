extends Node2D
class_name MapDrawer

# Tilemap과 엔티티 부모 노드
@export var tilemap_node: TileMap
@export var entity_parent: Node

# 프리팹/씬 매핑
@export var wall_scene: PackedScene
@export var player_scene: PackedScene
@export var monster_scene: PackedScene

# 타입 → 씬 매핑 (팩토리 느낌)
var entity_scenes = {}

func _ready():
	entity_scenes = {
		"Player": player_scene,
		"Wall": wall_scene,
		"Monster": monster_scene
	}

# 맵 데이터로 맵 그리기
func draw_map(map_data):
	# 1️⃣ Tilemap 그리기
	for y in range(map_data.tiles.size()):
		for x in range(map_data.tiles[y].size()):
			var tile_id = map_data.tiles[y][x]
			#tilemap_node.set_cell(x, y, tile_id)
	
	# 2️⃣ 동적 엔티티 그리기
	for entity_data in map_data.entities:
		var type_name = entity_data["type"]
		var pos = entity_data["pos"]
		
		if entity_scenes.has(type_name):
			var scene = entity_scenes[type_name]
			var instance = scene.instantiate()
			instance.position = pos * tilemap_node.cell_size  # 타일 좌표 → 월드 좌표
			entity_parent.add_child(instance)
		else:
			push_warning("Unknown entity type: %s" % type_name)
