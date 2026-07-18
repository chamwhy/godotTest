extends Portal
class_name WorldPortal

#region animation

func _anim_move_map(tween: Tween, data: Dictionary) -> void:
	tween.tween_interval(0.0)
	# 실제 동작이 아닌 액션적인 무빙만 보여주는 섹션. 말그대로 애니메이션

#endregion
