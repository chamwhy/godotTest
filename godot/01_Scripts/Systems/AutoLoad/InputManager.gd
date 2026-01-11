# AutoLoad
extends Node

# 행동 입력 신호
signal action_input(dir: Position)


# 게임 상호작용 가능 여부
var can_interact := false


func _process(_d: float) -> void:
	check_input()

func check_input() -> void:
	# TODO: 나중에 조작감 관련해서 바꿔야 함. 현재는 키에 대해서 우선순위가 존재함.
	if can_interact:
		if GameManager.cur_state == GameManager.GameState.PLAYING:
			input_playing()
		elif GameManager.cur_state == GameManager.GameState.MAIN_MENU:
			input_main_menu()
		elif GameManager.cur_state == GameManager.GameState.GAME_OVER:
			input_gameover()

#region GameStateInput

func input_main_menu() -> void:
	pass

func input_playing() -> void:	
	if Input.is_action_pressed("move_up"):
		emit_signal("action_input", Position.UP())
	elif Input.is_action_pressed("move_down"):
		emit_signal("action_input", Position.DOWN())
	elif Input.is_action_pressed("move_left"):
		emit_signal("action_input", Position.LEFT())
	elif Input.is_action_pressed("move_right"):
		emit_signal("action_input", Position.RIGHT())

func input_gameover() -> void:
	pass

#endregion
