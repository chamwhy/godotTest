extends Node

@export var start_menu: Control
@export var hp_bar: Control
@export var start_world := 0
@export var start_stage := 0
const tween_dur: float = 0.3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioManager.report_health_tier(1, AudioManager.Source.SPAWN)
	StageDirector.load_stage(start_world,start_stage)
	InputManager.start_game.connect(_start_game)

func _start_game() -> void:
	AudioManager.play_sfx("game started")
	
	var tween = create_tween()
	tween.tween_property(start_menu, "modulate", Color(1, 1, 1, 0), tween_dur)
	var tween2 = create_tween()
	tween2.tween_property(hp_bar, "modulate", Color(1, 1, 1, 1), tween_dur)
