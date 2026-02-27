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
#region 레거시
#func action(vel: Position) -> void:
	## 순간이동이 아닌, 과정이 존재하는 이동은 무조건 직선
	#if not vel.is_straight(): return
	## 목표가 현위치인 경우
	#if vel.is_zero(): return
	#
	#var nor := vel.normalized()
	#var cur_check := Position.ZERO()
	#var _cur_vel := Position.ZERO()
	#var _is_blocked := false
	#var _atk_pow := atk_pow
	#
	#while(true):
		#if InGameManager.can_pass(cur_check):
			#_cur_vel = cur_check	# cur_check는 다시 생성하니 copy할 필요x
		#else:
			#_is_blocked = true
			#break
		#if cur_check.equals(vel):	break
		## TODO: 이동속도 음수일 경우
		#cur_check = cur_check.add(nor)
		#_atk_pow -= 1
	#
	#if not _is_blocked:
		#_atk_pow = 0
	#elif _cur_vel.is_zero():
		## TODO: 현재 공격의 방향을 이동방향에 쓰였던 _cur_vel을 통하여 계산하고 있음.
		## 따라서 아예 막힌 경우, 공격을 시행하지 못함.
		## 임시적으로 vel을 넣어줘서 해결.
		## 궁극적으로는 vel이 아닌 dir, move_dist, atk_power를 넘겨줘서 판단시켜야 함.
		#_cur_vel = vel.copy()
	## 이동
	#action_process(_cur_vel, _atk_pow)
	#
#
#func action_process(vel: Position, atk: int) -> void:
	#if vel.is_zero(): return
	#
	#InGameManager.entity_exit(cur_position, self)
	#var _now := Position.ZERO()
	#while(true):
		#_now = _now.add(vel.normalized())
		#if _now.equals(vel): break
		#InGameManager.entity_pass(cur_position.add(_now), self)
	#
	#if atk > 0:
		#attack(atk, vel.normalized())
	#InGameManager.entity_placed(cur_position.add(_now), self)
	#
	#var target_position = InGameManager.position_to_world(cur_position.add(vel))
	## Tween 생성 및 실행
	#var tween = create_tween()
	## 1.0초 동안 position을 target_position으로 부드럽게 변경 (TransitionType 설정 가능)
	#tween.tween_property(self, "position", target_position, 0.6).set_trans(Tween.TRANS_SINE)

#endregion
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
	if self != re: print("오류임. 절대 무조건 같아야 함")
	
	while(true):
		if chk_pos.equals(vel): break
		tick += 1
		InGameManager.pass_element(self, cur_position.add(chk_pos), tick)
		chk_pos = chk_pos.add(dir)
	# TODO: 현재 애니메이션 순서 관련해서 어떻게 애니메이션 큐에 넣을 지 고민중임
	
	tick += 1
	InGameManager.enter_element(self, cur_position.add(chk_pos), tick)

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
	
