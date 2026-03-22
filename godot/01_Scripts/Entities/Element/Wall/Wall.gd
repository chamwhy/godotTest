extends Element
class_name Wall

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var destroyable := false
var min_atk := 0
#endregion

#region sprites

@export var wall_texture: Texture2D
@export var destroyable_wall_textures: Array[Texture2D]

#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true
	hitable = true
	min_atk = data.get("ma", 0)
	destroyable = min_atk != 0
	# TODO: 상태에 따른 이미지 업데이트
	update_sprite()

func update_sprite() -> void:
	if not destroyable:
		sprite2D.texture = wall_texture
	else:
		sprite2D.texture = destroyable_wall_textures[min(min_atk-1, destroyable_wall_textures.size()-1)]


func on_hit(atk_data: AtkData) -> bool:
	if not destroyable: return false
	
	if min_atk > atk_data.dmg: return false
	destroy_wall(atk_data.tick)
	return true
	

func destroy_wall(tick: int) -> void:
	InGameManager.exit_element(self, cur_position, tick)
	queue_free()
