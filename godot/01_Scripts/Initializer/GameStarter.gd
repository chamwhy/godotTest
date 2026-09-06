extends Node

@export var start_menu: Control
@export var hp_bar: Control
@export var develop := true
@export var start_world := 0
@export var start_stage := 0
const tween_dur: float = 0.3
const SAVE_SECTION := "start"

var _first := true
var wipe := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if wipe:
		SaveManager.wipe()
	
	_first = SaveManager.get_value(SAVE_SECTION, "first_game", true)
	SaveManager.set_value(SAVE_SECTION, "first_game", false)
	
	AudioManager.play_bgm()
	if develop:
		StageDirector.load_stage(start_world,start_stage)
	else:
		if _first:
			StageDirector.load_stage(1,1)
		else:
			StageDirector.load_stage(0,0)
	
	InputManager.start_game.connect(_start_game)

func _start_game() -> void:
	AudioManager.play_sfx("game started")
	var tween = create_tween()
	tween.tween_property(start_menu, "modulate", Color(1, 1, 1, 0), tween_dur)
	tween.finished.connect(func():
		start_menu.visible = false
	)
	var tween2 = create_tween()
	tween2.tween_property(hp_bar, "modulate", Color(1, 1, 1, 1), tween_dur)
