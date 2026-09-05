extends Portal
class_name WorldPortal

@export var number_sprite: Sprite2D
@export var number_textures: Array[Texture2D]

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var num := 1
var cleared := false
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	num = data.get("num", to_stage)
	print("world-portal", number_textures[1])
	StageContext.register_worldPortal_position(
		to_world * StageContext.WORLD_ID_MULTIPLY + to_stage,
		cur_position
	)
	cleared = StageManager.is_cleared(to_world, to_stage)
	update_sprite()


func update_sprite() -> void:
	number_sprite.texture = number_textures[num]
	if cleared:
		animSprite2D.modulate = Color("a5b3a1ff")
	else:
		animSprite2D.modulate = Color("#8dc977")

func _connect_check_pos():
	GridManager.element_settled.connect(func (pos: Position, elm: Element, tick: int):
		if not cleared:
			_check_pos(pos, elm, tick)
	)
	GridManager.element_interacted.connect(func (pos: Position, elm: Element, tick: int):
		if cleared:
			_check_pos(pos, elm, tick)
	)

#region animation

func _anim_move_map(tween: Tween, data: Dictionary) -> void:
	AudioManager.play_sfx("enter_stage")
	tween.tween_interval(0.0)
	# 실제 동작이 아닌 액션적인 무빙만 보여주는 섹션. 말그대로 애니메이션

#endregion
