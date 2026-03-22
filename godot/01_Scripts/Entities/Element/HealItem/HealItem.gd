extends Element
class_name HealItem

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var heal_pow := 1
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = false
	
	InGameManager.element_passed.connect(_check_pos)
	InGameManager.element_entered.connect(_check_pos)
	
	# TODO: 상태에 따른 이미지 업데이트

func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	if pos.equals(cur_position):
		heal(elm, tick)
		destroy_heal_item(tick)

func heal(target: Element, tick: int) -> void:
	var new_heal_data = HealData.new(
		heal_pow,
		tick
	)
	if is_instance_valid(target) and target.has_method("on_heal"):
		target.on_heal(new_heal_data)

func destroy_heal_item(tick: int) -> void:
	InGameManager.exit_element(self, cur_position, tick)
	queue_free()
