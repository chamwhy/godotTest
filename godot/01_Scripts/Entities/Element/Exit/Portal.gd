extends Element
class_name Portal

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var to_world := 0
var to_stage := 0
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = false
	to_world = data.get("to_w", 0)
	to_stage = data.get("to_s", 0)
	
	InGameManager.element_entered.connect(_check_pos)
	# TODO: 상태에 따른 이미지 업데이트

func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	# 일단은 elm 상관없이 발동. 나중에 player 넣거나 아니면 몬스터가 밟는 거 자체를 기믹으로 할 수도?
	if pos.equals(cur_position):
		print("portal 발동.", cur_position.to_str(), pos.to_str())
		move_map(tick)

func move_map(tick: int) -> void:
	InGameManager.request_map_change(to_world, to_stage)
	AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(
		self,
		"move_map",
		{},
		"",
		{}
	), tick)
	


#region animation

func _register_animations() -> void:
	super._register_animations()          # 부모 것 먼저 등록
	_anim_handlers["move_map"] = _anim_move_map

func _anim_move_map(tween: Tween, data: Dictionary) -> void:
	tween.tween_interval(0.0)
	# 실제 동작이 아닌 액션적인 무빙만 보여주는 섹션. 말그대로 애니메이션

#endregion
