extends Element
class_name Unit

@export var max_hp: int
var cur_hp := 0


# test 용
func _ready() -> void:
	reset()

func reset() -> void:
	cur_hp = max_hp


func move(dir: Position) -> void:
	pass

func when_player_actioned() -> void:
	# abstract
	pass


func apply_data(data: EntityMapData):
	assert(data is UnitMapData)
	super.apply_data(data)
	var d: UnitMapData = data
