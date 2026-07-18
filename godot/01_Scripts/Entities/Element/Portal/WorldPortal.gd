extends Portal
class_name WorldPortal

@export var number_sprite: Sprite2D
@export var number_textures: Array[Texture2D]

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var num := 1
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	num = data.get("num", to_stage)
	print("world-portal", number_textures[1])
	InGameManager.register_worldPortal_position(
		to_world * InGameManager.WORLD_ID_MULTIPLY + to_stage,
		cur_position
	)
	update_sprite()

func update_sprite() -> void:
	number_sprite.texture = number_textures[num]


#region animation

func _anim_move_map(tween: Tween, data: Dictionary) -> void:
	tween.tween_interval(0.0)
	# 실제 동작이 아닌 액션적인 무빙만 보여주는 섹션. 말그대로 애니메이션

#endregion
