extends Node

@export var heart_icons: Array[AnimatedTextureRect] = []
@export var profile: AnimatedTextureRect
@export var profile_frames: Array[SpriteFrames]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerRegistry.run_when_player_ready(func(player: Player) -> void:
		player.player_hp_changed.connect(update_health_ui)
		update_health_ui(player.cur_hp)
	)

func update_health_ui(current_hp: int):
	# 하트 3개(최대 체력 3)를 돌며 체력 체크. profile_frames도 체력 1·2·3 순서(격노·화남·평온)
	LogUtil.write("update_health_ui", current_hp)
	profile.sprite_frames = profile_frames[clampi(current_hp - 1, 0, profile_frames.size() - 1)]
	profile.animation = "default"
	profile.play()
	for i in range(heart_icons.size()):
		# 현재 인덱스(i)가 현재 체력보다 작으면 보이고, 아니면 숨김
		# 예: hp가 2이면 0,1번은 보이고 2번은 숨겨짐
		heart_icons[i].visible = (i < current_hp)
