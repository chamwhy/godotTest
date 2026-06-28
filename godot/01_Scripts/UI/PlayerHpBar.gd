extends Node

@export var heart_icons: Array[TextureRect] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	InGameManager.player_registered.connect(_on_player_registered)
	if InGameManager._player:                       # UI가 나중에 생기는 경우 대비
		_on_player_registered(InGameManager._player)

func _on_player_registered(player: Player) -> void:
	player.player_hp_changed.connect(update_health_ui)
	update_health_ui(player.cur_hp)  

func update_health_ui(current_hp: int):
	# 0부터 5까지 반복하며 체력 체크
	print("update_health_ui", current_hp)
	for i in range(heart_icons.size()):
		# 현재 인덱스(i)가 현재 체력보다 작으면 보이고, 아니면 숨김
		# 예: hp가 3이면 0,1,2번은 보이고 3,4,5번은 숨겨짐
		heart_icons[i].visible = (i < current_hp)
