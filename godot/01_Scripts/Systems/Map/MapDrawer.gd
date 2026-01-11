extends Node

const MAP_DATA_HEADER: String = "res://05_Data/01_MapData/"

@export var entity_parent_name := "EntityParent" 

var tile_size : int
var map_width : int
var map_height : int

# 타입 → 씬 매핑 (팩토리 느낌)
var entity_parent: Node2D

func _ready():
	print("MapMaker 전용 초기화 로직 실행됨.")



## JSON 파일 경로를 받아 맵 전체를 그리는 메인 함수
func draw_map(world: int, stage: int) -> bool:
	# 1. 씬 트리의 루트 노드를 기준으로 부모 노드를 동적으로 찾습니다.
	var current_root = get_tree().current_scene # 현재 로드된 씬의 루트 노드
	
	entity_parent = current_root.find_child(entity_parent_name, true)
	
	if entity_parent == null:
		print("MapMaker: 엔티티 부모 노드 '%s'를 현재 씬에서 찾을 수 없어 엔티티 로드를 건너뜁니다." % entity_parent_name)
		# 엔티티가 없어도 타일은 로드할 수 있도록 여기서는 return false 하지 않을 수 있습니다.
	
	# 1. JSON 유틸리티를 사용하여 데이터 로드
	var json_path: String = MAP_DATA_HEADER + "%02d_%02d.json" % [world, stage]
	var map_data: Dictionary = JsonParser.load_json_data(json_path)
	print(map_data)
	if map_data.is_empty():
		print("Failed to load map data from: %s" % json_path)
		return false
	
	tile_size = map_data.get("tile_size", 32)
	map_width = map_data.get("map_width", 10)
	map_height = map_data.get("map_height", 10)
	
	# 데이터에 맞는 카메라 위치 배치
	MyCamera.instance.setup_map(tile_size, map_width, map_height)
	
	# 2. **타일 데이터를 개별 오브젝트로 로드 및 배치**
	_spawn_tile_objects(map_data)
	
	# 3. 엔티티 데이터 로드 및 배치 (로직 동일)
	_spawn_entities(map_data)
	
	print("Object-based map '%s' loaded successfully." % map_data.get("map_name", "Unnamed Map"))
	return true

## 타일 데이터를 순회하며 개별 타일 오브젝트를 생성하는 함수
func _spawn_tile_objects(data: Dictionary):
	if not entity_parent:
		print("Tile parent node is not assigned!")
		return
		
	var tile_data_array: Array = data.get("tile_map", [])
	var scene: PackedScene = Config.EXP_RES.entityScenes.get("Tile")
	if scene == null:
		print("Unknown object type: Tile")
		return null
	print(tile_data_array.size())
	print(tile_data_array[0].size())
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
			else:
				print("tile has not apply data")

## 엔티티 데이터를 순회하며 씬을 인스턴스화하고 배치하는 함수
func _spawn_entities(data: Dictionary):
	if not entity_parent:
		print("Entity parent node is not assigned!")
		return

	var entities_array: Array = data.get("entities", [])

	for entity_data: Dictionary in entities_array:
		var type_name: String = entity_data.get("obj_type", "")
		
		# 1. ENTITY_SCENES 딕셔너리에서 타입 이름에 맞는 씬을 가져옵니다.
		var scene: PackedScene = Config.EXP_RES.entityScenes.get(type_name)
		if scene == null:
			print("Unknown object type: %s" % type_name)
			continue # 다음 엔티티로 넘어감
		
		# 2. Scene 인스턴스 생성 및 부모 설정
		var obj: Node2D = scene.instantiate()
		entity_parent.add_child(obj)

		# 3. apply_data 자동 호출
		if obj.has_method("apply_data"):
			obj.apply_data(entity_data)
