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
	StageContext.complete_stage()
	StageContext.request_map_change(
		{
			"world": to_world,
			"stage": to_stage,
			"out_of": true,
			"out_of_w": StageContext.world,
			"out_of_s": StageContext.stage
		})
	ActionManager.record_new(self, tick,
		"move_map", {})


#region animation

func _anim_move_map(tween: Tween, data: Dictionary) -> void:
	AudioManager.stop_bgm()
	AudioManager.play_sfx("clear_stage")
	tween.tween_interval(0.0)
	# 실제 동작이 아닌 액션적인 무빙만 보여주는 섹션. 말그대로 애니메이션

#endregion
