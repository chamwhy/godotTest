# AutoLoad
extends Node

# 게임 상태 enum
enum GameState { MAIN_MENU, PLAYING, PAUSED, GAME_OVER }

var cur_state: GameState = GameState.MAIN_MENU

var IGM: InGameManager

func _ready() -> void:
	IGM = InGameManager.new()


func set_state(new_state: GameState) -> void:
	print("GameState changed: {GameSate.keys()[cur_state]} -> {GameSate.keys()[new_state]}")
	cur_state = new_state
