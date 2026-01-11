# AutoLoad
extends Node

const MOVE_DELAY := 0.8
@onready var player: Player = $Player


# 현재 플레이어가 행동하는지 지 여부(딜레이를 주기 위하여)
var is_act: bool = true

func _ready() -> void:
	InputManager.action_input.connect(_action_inputed)
	
func _action_inputed(dir: Position):
	if is_act: return
	player.action_dir(dir)
	
#region Map

# 지나갈 수 있는 지 여부
func can_through(pos: Position) -> bool:
	return true

# 놓일 수 있는 지 여부
func can_placed(pos: Position) -> bool:
	return true


#endregion

#region MapPosition
func position_to_world(pos: Position) -> Vector2:
	return Vector2(pos.x + 0.5, pos.y + 0.5) * MapDrawer.tile_size

#endregion
