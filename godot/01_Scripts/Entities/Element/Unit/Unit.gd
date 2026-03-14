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


func action_dir(dir: Position, tick: int) -> void:
	var real_dir = dir.normalized()
	if move_speed < 0:
		real_dir = real_dir * -1
	
	# 음수값 구현
	action2(real_dir, abs(move_speed), tick)

func action2(dir: Position, spd: int, tick: int) -> void:
	if not dir.is_straight(): return
	if dir.is_zero(): return
	
	var chk_pos: Position = cur_position.copy()
	
	
	var move_cnt := 0
	var remain_move: int = spd
	var remain_atk: int = atk_pow
	var was_blocked := false
	
	# 이동 체크
	while(true):
		# 모든 이동력을 다 쓴 상태
		if remain_move <= 0:
			break
		
		if remain_move > 0 and InGameManager.can_pass(chk_pos.add(dir)):
			remain_move -= 1
			# 해당 게임에선 이동력을 소모하면 같이 공격력도 소모함.
			remain_atk -= 1
			move_cnt += 1
			chk_pos = chk_pos.add(dir)
		else:
			if remain_move > 0:
				was_blocked = true
			break
	
	if move_cnt > 0:
		move_to(dir.multiply(move_cnt), tick)
		tick += 1
	
	if was_blocked and remain_atk > 0:
		attack(remain_atk, dir, tick)


# 순간이동
func move_inst(pos: Position) -> void:
	pass

# 속력 이동
func move_to(vel: Position, tick: int) -> void:
	if vel.is_zero(): return
	
	var dir: Position = vel.normalized()
	# 어차피 처음은 무조건 exit라 미리 더해두기
	var chk_pos: Position = dir.copy()
	
	var re = InGameManager.exit_element(self, cur_position, tick)
	
	print(re, cur_position.to_str(), tick)
	if self != re: print("오류임. 절대 무조건 같아야 함")
	
	while(true):
		if chk_pos.equals(vel): break
		tick += 1
		InGameManager.pass_element(self, cur_position.add(chk_pos), tick)
		AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(self, "move", {
			"from": cur_position.add(chk_pos),
			"to": cur_position.add(chk_pos).add(dir)
		}), tick)
		chk_pos = chk_pos.add(dir)
	# TODO: 현재 애니메이션 순서 관련해서 어떻게 애니메이션 큐에 넣을 지 고민중임
	
	tick += 1
	
	InGameManager.enter_element(self, cur_position.add(chk_pos), tick)
	# TODO: 이거 enter_element 함수로 옮겨야 할듯.
	cur_position = cur_position.add(chk_pos)

func attack(atk_power: int, pos: Position, tick: int) -> void:
	var el := InGameManager.get_element(pos, 1)
	# TODO: from도 attack pos 인수가 아닌, 공격 방향으로 인수 받고 -1 곱해서 전달해주기
	el.damaged(atk_pow, Position.ZERO(), tick)


func when_player_actioned() -> void:
	# abstract
	pass

func apply_data(data: Dictionary):
	super.apply_data(data)
	max_hp = data.get("mh", Config.DEFALT_UNIT_MAX_HP)
	# 의도적으로 맵 시작부터 체력이 깎여있는 경우. 만약 지정을 안했다면 max_hp로 자동지정.
	# 따라서 reset 하면 안됨.
	cur_hp = data.get("ch", max_hp)
	
