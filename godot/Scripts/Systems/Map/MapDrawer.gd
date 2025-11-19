extends Node2D
class_name MapDrawer

# 엔티티 부모 노드
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
func draw_map(map_data: MapData):
	for entity_data in map_data.entities:
		# 1. entity 데이터 가져오기
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
