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

func apply_data(data: Dictionary):
	super.apply_data(data)
	max_hp = data.get("mh", Config.DEFALT_UNIT_MAX_HP)
	# 의도적으로 맵 시작부터 체력이 깎여있는 경우. 만약 지정을 안했다면 max_hp로 자동지정.
	# 따라서 reset 하면 안됨.
	cur_hp = data.get("ch", max_hp)
	
