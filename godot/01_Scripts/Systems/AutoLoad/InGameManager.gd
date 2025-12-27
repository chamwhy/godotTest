# AutoLoad
extends Node

const MOVE_DELAY := 0.8
@onready var player: Player = $Player

# 현재 플레이어가 움직이는 지 여부(딜레이를 주기 위하)여
var is_moving: bool = true

func _ready() -> void:
	InputManager.move_input.connect(_move_inputed)
	
func _move_inputed(dir: Position):
	if is_moving: return
	if player.can_move_dir(dir):
		
	
	
#region Map

# 지나갈 수 있는 지 여부
func can_through(pos: Position) -> bool:
	return true

# 놓일 수 있는 지 여부
func can_placed(pos: Position) -> bool:
	return true

#endregion
