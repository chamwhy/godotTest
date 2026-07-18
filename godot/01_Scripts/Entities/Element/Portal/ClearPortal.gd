extends Portal
class_name ClearPortal

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
#var clear_world := 0
#var clear_stage := 0
#endregion

#func apply_data(data: Dictionary) -> void:
	#clear_world = data.get("cl_w", 0)
	#clear_stage = data.get("cl_s", 0)
	#super.apply_data(data)


func move_map(tick: int) -> void:
	InGameManager.complete_stage()
	InGameManager.request_map_change(
		{
			"world": to_world,
			"stage": to_stage,
			"out_of": true,
			"out_of_w": InGameManager.world,
			"out_of_s": InGameManager.stage
		})
	AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(
		self,
		"move_map",
		{},
		"",
		{}
	), tick)


#region animation

func _anim_move_map(tween: Tween, data: Dictionary) -> void:
	tween.tween_interval(0.0)
	# 실제 동작이 아닌 액션적인 무빙만 보여주는 섹션. 말그대로 애니메이션

#endregion
