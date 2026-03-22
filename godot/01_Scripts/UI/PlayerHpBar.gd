extends Node

@export var heart_icons: Array[TextureRect] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	InGameManager.run_when_player_ready(func(player):
		player.player_hp_changed.connect(update_health_ui)
	)

func update_health_ui(current_hp: int):
	# 0부터 5까지 반복하며 체력 체크
	for i in range(heart_icons.size()):
		# 현재 인덱스(i)가 현재 체력보다 작으면 보이고, 아니면 숨김
		# 예: hp가 3이면 0,1,2번은 보이고 3,4,5번은 숨겨짐
		heart_icons[i].visible = (i < current_hp)
