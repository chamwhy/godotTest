extends Unit
class_name MoveBox

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true

#@export var move_speed := 1
#@export var atk_pow := 1
#@export var max_hp: int = 1

#endregion

func _set_hp(v):
	# hp가 바뀌지 않음.
	pass

func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true
	hitable = true
	# TODO: 상태에 따른 이미지 업데이트
	

func on_hit(atk_data: AtkData) -> bool:
	move_speed = atk_data.dmg
	atk_pow = atk_data.dmg
	
	var dir: Position = cur_position.subtract(atk_data.from).normalized()
	if not dir.is_zero() and dir.is_straight():
		action_dir(dir, 0)
	return true
