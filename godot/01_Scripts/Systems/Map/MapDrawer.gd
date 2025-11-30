extends Node2D
class_name MapDrawer

# 엔티티 부모 노드
@export var entity_parent: Node

# 프리팹/씬 매핑
@export var wall_scene: PackedScene
@export var player_scene: PackedScene
@export var monster_scene: PackedScene
@export var tile_scene: PackedScene

# 타입 → 씬 매핑 (팩토리 느낌)
var entity_scenes = {}


func _ready():
	entity_scenes = {
		"Player": player_scene,
		"Wall": wall_scene,
		"Monster": monster_scene,
		"Tile": tile_scene
	}

#
func draw_map2(map_data: MapData):
	for entity_data in map_data.entities:
		# 1. entity 데이터 가져오rl
		var scene: PackedScene = entity_scenes.get(entity_data.obj_type, null)
		if scene == null:
			push_warning("Unknown object type: %s" % entity_data.obj_type)
			return null

		# 2. Scene 인스턴스 생성 및 부모 설정

		var obj: Node = scene.instantiate()
		entity_parent.add_child(obj)
		
		# 3. apply_data 자동 호출 (ObjectData 타입 안전성)
		if obj.has_method("apply_data"):
			obj.apply_data(entity_data)
		return obj

## JSON 파일 경로를 받아 맵 전체를 그리는 메인 함수
func draw_map(json_path: String) -> bool:
	# 1. JSON 유틸리티를 사용하여 데이터 로드
	var map_data: Dictionary = JsonParser.load_json_data(json_path)
	
	if map_data.is_empty():
		push_error("Failed to load map data from: %s" % json_path)
		return false

	# 2. **타일 데이터를 개별 오브젝트로 로드 및 배치**
	_spawn_tile_objects(map_data)
	
	# 3. 엔티티 데이터 로드 및 배치 (로직 동일)
	_spawn_entities(map_data)
	
	print("Object-based map '%s' loaded successfully." % map_data.get("map_name", "Unnamed Map"))
	return true


## 타일 데이터를 순회하며 개별 타일 오브젝트를 생성하는 함수
func _spawn_tile_objects(data: Dictionary):
	if not entity_parent:
		push_error("Tile parent node is not assigned!")
		return
		
	var tile_data_array: Array = data.get("tile_map", [])
	var scene: PackedScene = entity_scenes.get("Tile", null)
	if scene == null:
		push_warning("Unknown object type: Tile")
		return null
		
	# 2차원 배열 순회하며 타일 오브젝트 생성
	for y in range(tile_data_array.size()):
		var row: Array = tile_data_array[y]
		for x in range(row.size()):
			var tile_id: int = row[x]
			if tile_id == 0:
				continue
			
			var tile_obj: Node2D = scene.instantiate()
			entity_parent.add_child(tile_obj)
		
			# 3. apply_data 자동 호출 (ObjectData 타입 안전성)
			if tile_obj.has_method("apply_data"):
				var tile_data = {
					"id": tile_id,
					"x": x,
					"y": y
				}
				tile_obj.apply_data(tile_data)
			return tile_obj
			

## 엔티티 데이터를 순회하며 씬을 인스턴스화하고 배치하는 함수
func _spawn_entities(data: Dictionary):
	if not entity_parent:
		push_error("Entity parent node is not assigned!")
		return

	var entities_array: Array = data.get("entities", [])

	for entity_data: Dictionary in entities_array:
		var type_name: String = entity_data.get("obj_type", "")
		
		# 1. ENTITY_SCENES 딕셔너리에서 타입 이름에 맞는 씬을 가져옵니다.
		var scene: PackedScene = entity_scenes.get(type_name, null)
		if scene == null:
			push_warning("Unknown object type: %s" % type_name)
			continue # 다음 엔티티로 넘어감
		
		# 2. Scene 인스턴스 생성 및 부모 설정
		var obj: Node2D = scene.instantiate()
		entity_parent.add_child(obj)

		# 3. apply_data 자동 호출
		if obj.has_method("apply_data"):
			obj.apply_data(entity_data)
