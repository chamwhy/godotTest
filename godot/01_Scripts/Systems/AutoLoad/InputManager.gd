# AutoLoad
extends Node

# 행동 입력 신호
signal action_input(dir: Position)
signal start_game()

# 게임 상호작용 가능 여부
var can_interact := false

# TODO: 나중에 false에서 켜주는 걸로 변경
func _ready() -> void:
	can_interact = true
	GameManager.set_state(GameManager.GameState.MAIN_MENU)

func _input(event: InputEvent) -> void:
	check_input(event)

func check_input(event: InputEvent) -> void:
	# TODO: 나중에 조작감 관련해서 바꿔야 함. 현재는 키에 대해서 우선순위가 존재함.
	if can_interact:
		if GameManager.cur_state == GameManager.GameState.PLAYING:
			input_playing()
		elif GameManager.cur_state == GameManager.GameState.MAIN_MENU:
			input_main_menu(event)
		elif GameManager.cur_state == GameManager.GameState.GAME_OVER:
			input_gameover()

#region GameStateInput

func input_main_menu(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.pressed:
			emit_signal("start_game")
			GameManager.set_state(GameManager.GameState.PLAYING)

func input_playing() -> void:	
	if Input.is_action_just_pressed("move_up"):
		print("up누름")
		emit_signal("action_input", Position.UP())
	elif Input.is_action_just_pressed("move_down"):
		print("down누름")
		emit_signal("action_input", Position.DOWN())
	elif Input.is_action_just_pressed("move_left"):
		print("left누름")
		emit_signal("action_input", Position.LEFT())
	elif Input.is_action_just_pressed("move_right"):
		print("right누름")
		emit_signal("action_input", Position.RIGHT())
	elif Input.is_action_just_pressed("interaction"):
		print("상호작용누름")
		emit_signal("action_input", Position.ZERO())

func input_gameover() -> void:
	pass

#endregion
