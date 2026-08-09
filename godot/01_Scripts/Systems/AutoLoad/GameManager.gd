# AutoLoad - GameManager.gd
extends Node

# 게임 상태 enum
enum GameState { MAIN_MENU, PLAYING, TIP, GAME_OVER }

var cur_state: GameState = GameState.MAIN_MENU
signal state_changed(state: GameState)


func set_state(new_state: GameState) -> void:
	print("GameState changed: {GameSate.keys()[cur_state]} -> {GameSate.keys()[new_state]}")
	if cur_state != new_state:
		cur_state = new_state
		state_changed.emit(cur_state)


func load_map(world: int, stage: int, fadein = true, fadeout = true) -> bool:
	# fade-in
	if fadein:
		pass
	return false
