# AutoLoad
extends Node

# 이동 입력 신호
signal move_input(dir: Position)

const MOVE_DELAY := 0.8


func _process(_d: float) -> void:
	if GameManager.IGM.is_moving:
		check_input()

func check_input() -> void:
	# TODO: 나중에 조작감 관련해서 바꿔야 함. 현재는 키에 대해서 우선순위가 존재함.
	if Input.is_action_pressed("move_up"):
		emit_signal("move_input", Position.UP())
	elif Input.is_action_pressed("move_down"):
		emit_signal("move_input", Position.DOWN())
	elif Input.is_action_pressed("move_left"):
		emit_signal("move_input", Position.LEFT())
	elif Input.is_action_pressed("move_right"):
		emit_signal("move_input", Position.RIGHT())
