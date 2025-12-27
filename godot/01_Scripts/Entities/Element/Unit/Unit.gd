extends Element
class_name Unit

@export var max_hp: int
var cur_hp := 0
var move_speed := 1
var atk_pow := 1


# test 용
func _ready() -> void:
	reset()

func reset() -> void:
	cur_hp = max_hp


func can_move_dir(dir: Position) -> bool:
	# 순간이동이 아닌, 과정이 존재하는 이동은 무조건 직선
	if not dir.is_straight(): return false
	
	# 이동속도가 0이지만 목표가 자기 자신일 경우 = 성공
	if move_speed == 0:
		return dir.is_zero()
	
	var nor := dir.normalized()
	var cur_check := cur_position.copy()
	
	# 목표 지점 전까지 이동 방향에 따른 체크
	# 이동속도 음수이면 방향 반대로 감
	for i in range(0, abs(move_speed)-1):
		if sign(move_speed) > 0:
			cur_check = cur_check.add(nor)
		else:
			cur_check = cur_check.subtract(nor)
		if not InGameManager.can_through(cur_check):
			return false
	
	# 목표 지점 체크
	if sign(move_speed) > 0:
		cur_check = cur_check.add(nor)
	else:
		cur_check = cur_check.subtract(nor)
	if not InGameManager.can_placed(cur_check): return false
	
	return true

func move_dir(dir: Position) -> void:
	move(dir.normalized().multiply(move_speed))

func move(vel: Position) -> void:
	# 순간이동이 아닌, 과정이 존재하는 이동은 무조건 직선
	if not vel.is_straight(): return
	# 목표가 현위치인 경우
	if vel.is_zero(): return
	
	var nor := vel.normalized()
	var cur_check := cur_position.copy()
	var goal := cur_check.add(vel)
	
	while(true):
		cur_check = cur_check.add(nor)
		if cur_check.equals(goal):	break
		if not InGameManager.can_through(cur_check):
			return false
	
	# 목표 지점 체크
	cur_check = cur_check.add(nor)
	if not InGameManager.can_placed(cur_check): return false
	
	return true

# 순간이동
func move_inst(vel: Position) -> void:
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
	
