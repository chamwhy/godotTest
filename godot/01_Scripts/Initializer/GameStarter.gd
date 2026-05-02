extends Node

@export var start_menu: Control
@export var hp_bar: Control
const tween_dur: float = 0.3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MapDrawer.draw_map(0,0)
	InputManager.start_game.connect(_start_game)

func _start_game() -> void:
	var tween = create_tween()
	tween.tween_property(start_menu, "modulate", Color(1, 1, 1, 0), tween_dur)
	var tween2 = create_tween()
	tween2.tween_property(hp_bar, "modulate", Color(1, 1, 1, 1), tween_dur)
