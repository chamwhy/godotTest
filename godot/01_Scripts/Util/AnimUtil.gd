extends RefCounted
# AnimUtil.gd (AutoLoad 등록 or 그냥 클래스로)
class_name AnimUtil

static func play_times(anim_player: AnimationPlayer, anim_name: String, times: int) -> void:
	if not anim_player or times <= 0: return
	anim_player.play(anim_name)
	var remaining = times - 1
	
	if remaining <= 0:
		return
	
	anim_player.animation_finished.connect(
		func(_anim):
			remaining -= 1
			if remaining > 0:
				anim_player.play(anim_name)
			,CONNECT_ONE_SHOT
	)
