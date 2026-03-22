extends Element
class_name Trap

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var atk_pow := 0
var is_once := false
#endregion

#region sprite2ds

@export var trap_textures: Array[Texture2D]
@export var once_trap_textures: Array[Texture2D]

#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = true
	atk_pow = data.get("atk", 0)
	is_once = data.get("once", false)
	
	InGameManager.element_passed.connect(_check_pos)
	InGameManager.element_entered.connect(_check_pos)
	
	# TODO: 상태에 따른 이미지 업데이트
	update_sprite()

func update_sprite() -> void:
	var cnt: int = atk_pow-1
	if is_once:
		cnt = min(cnt, once_trap_textures.size()-1)
		sprite2D.texture = once_trap_textures[cnt]
	else:
		cnt = min(cnt, trap_textures.size()-1)
		sprite2D.texture = trap_textures[cnt]


func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	if pos.equals(cur_position):
		attack(elm, tick)
		if is_once:
			destroy_trap(tick)

func attack(target: Element, tick: int) -> void:
	var new_atk_data = AtkData.new(
		atk_pow,
		cur_position,
		tick,
		false
	)
	if is_instance_valid(target) and target.hitable:
		target.on_hit(new_atk_data)

func on_hit(atk_data: AtkData) -> bool:
	if not is_once: return false
	destroy_trap(atk_data.tick)
	return true


func destroy_trap(tick: int) -> void:
	InGameManager.exit_element(self, cur_position, tick)
	queue_free()
