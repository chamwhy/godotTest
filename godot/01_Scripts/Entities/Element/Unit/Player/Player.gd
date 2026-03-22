extends Unit
class_name Player

func reset() -> void:
	InGameManager.register_player(self)
	super.reset()


func apply_data(data: Dictionary):
	super.apply_data(data)

#region Emotion
enum PlayerEmotion {
	CALM,   # 평온 (기본 상태)
	ANGRY,  # 화남 (중간 단계: 불만이나 짜증이 섞인 상태)
	RAGE    # 격노 (최종 단계: 폭발하거나 통제 불능인 상태)
}

var cur_emotion: PlayerEmotion = PlayerEmotion.CALM

func set_player_emotion(emotion: PlayerEmotion) -> void:
	if emotion != cur_emotion:
		cur_emotion = emotion

func get_player_emotion(hp: int) -> PlayerEmotion:
	if 4 <= hp:
		return PlayerEmotion.CALM
	elif 2 <= hp:
		return PlayerEmotion.ANGRY
	else:
		return PlayerEmotion.RAGE

func get_atk_power_by_emotion(emotion: PlayerEmotion) -> int:
	return 1 if emotion == PlayerEmotion.CALM else 2

func get_move_speed_by_emotion(emotion: PlayerEmotion) -> int:
	return 2 if emotion == PlayerEmotion.RAGE else 1

#endregion

signal player_hp_changed(int)

func _set_hp(v):
	super._set_hp(v)
	var em = get_player_emotion(v)
	set_player_emotion(em)
	atk_pow = get_atk_power_by_emotion(em)
	move_speed = get_move_speed_by_emotion(em)
	player_hp_changed.emit(_cur_hp)

func on_hit(atk_data: AtkData) -> bool:
	cur_hp = cur_hp - atk_data.dmg
	return super.on_hit(atk_data)
