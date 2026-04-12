extends Element
class_name MapPortal

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var world := 0
var stage := 0
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = false
	world = data.get("world", 0)
	stage = data.get("stage", 0)
	
	InGameManager.element_interacted.connect(_check_pos)
	# TODO: 상태에 따른 이미지 업데이트

func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	print("map portal 발동.", cur_position.to_str(), pos.to_str())
	# 일단은 elm 상관없이 발동. 나중에 player 넣거나 아니면 몬스터가 밟는 거 자체를 기믹으로 할 수도?
	if pos.equals(cur_position):
		move_map()

func move_map() -> void:
	MapDrawer.draw_map(world,stage)
