# AutoLoad - GameManager.gd
extends Node

# 게임 상태 enum
#
# "지금 어떤 입력 체계인가"만 담는다. 플레이어의 생사는 여기 들어오지 않는다.
# 이 게임의 죽음은 끝이 아니라 되돌릴 수 있는 턴 결과이고, 죽어도 입력 체계는
# PLAYING 그대로다(스와이프·탭·더블탭의 의미가 바뀌지 않는다). 생사는
# Unit.is_dead / is_fallen 이 개체 단위로 들고 있다.
enum GameState { MAIN_MENU, PLAYING, TIP }

var cur_state: GameState = GameState.MAIN_MENU
signal state_changed(state: GameState)


func set_state(new_state: GameState) -> void:
	print("GameState changed: %s -> %s" % [GameState.keys()[cur_state], GameState.keys()[new_state]])
	if cur_state != new_state:
		cur_state = new_state
		state_changed.emit(cur_state)


func load_map(world: int, stage: int, fadein = true, fadeout = true) -> bool:
	# fade-in
	if fadein:
		pass
	return false
