extends Element
class_name Unit


#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true

@export var move_speed := 1
@export var atk_pow := 1
@export var max_hp: int = 1

#endregion

#region hp

var _cur_hp: int
var cur_hp := max_hp:
	set(v): _set_hp(v)
	get: return _get_hp()

# 자식이 오버라이드할 수 있도록 함수로 분리
func _set_hp(v):
	_cur_hp = clamp(v, 0, max_hp)

func _get_hp():
	return _cur_hp
#endregion

#region state
var is_dead := false
var is_fallen := false
#endregion


# test 용
func _ready() -> void:
	init()
	reset()


func init() -> void:
	pass

func reset() -> void:
	cur_hp = max_hp


func action_dir(dir: Position, tick: int) -> void:
	if dir.equals(Position.ZERO()):
		InGameManager.interact_element(self, cur_position, 0)
	else:
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
		var checks = InGameManager.can_pass(chk_pos.add(dir))
		print("check 222: ", checks, chk_pos.to_str(), dir.to_str())
		if remain_move > 0 and checks:
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
	
	if not InGameManager.has_tile(cur_position.x, cur_position.y):
		print("구멍에 빠짐")
		is_fallen = true
		# TODO: falling


# 순간이동
func move_inst(pos: Position) -> void:
	pass

# 속력 이동
func move_to(vel: Position, tick: int) -> void:
	if vel.is_zero(): return
	print("Move To: ", vel.to_str())
	var goal: Position = vel.add(cur_position)
	var dir: Position = vel.normalized()
	# 어차피 처음은 무조건 exit라 미리 더해두기
	var chk_pos: Position = cur_position.add(dir)
	var from: Position = cur_position.copy()
	
	var re = InGameManager.exit_element(self, cur_position, tick)
	
	print(re, cur_position.to_str(), tick)
	if self != re: print("오류임. 절대 무조건 같아야 함")
	
	while(true):
		if chk_pos.equals(goal): break
		InGameManager.pass_element(self, chk_pos, tick)
		chk_pos = chk_pos.add(dir)
		AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(self, "move", {
			"from": from,
			"to": chk_pos
		}), tick)
		from = chk_pos.copy()
		tick += 1
	# TODO: 현재 애니메이션 순서 관련해서 어떻게 애니메이션 큐에 넣을 지 고민중임	
	InGameManager.enter_element(self, chk_pos, tick)
	AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(self, "move", {
			"from": from,
			"to": chk_pos
		}), tick)

func attack(atk_power: int, dir: Position, tick: int) -> void:
	var targets: Array[Element] = InGameManager.get_elements(cur_position.add(dir))
	for target in targets:
		if target:
			# TODO: 일단 하드코딩으로 1로 채워둠.
			apply_on_hit(target, atk_power, tick)

func apply_on_hit(target: Element, atk_power: int, tick: int) -> void:
	var new_atk_data = AtkData.new(
		atk_power,
		cur_position,
		tick
	)
	
	if is_instance_valid(target) and target.hitable:
		target.on_hit(new_atk_data)

func on_heal(heal_data: HealData) -> void:
	cur_hp = cur_hp + heal_data.heal

func when_player_actioned() -> void:
	# abstract
	pass

func apply_data(data: Dictionary):
	super.apply_data(data)
	max_hp = data.get("mh", Config.DEFALT_UNIT_MAX_HP)
	# 의도적으로 맵 시작부터 체력이 깎여있는 경우. 만약 지정을 안했다면 max_hp로 자동지정.
	# 따라서 reset 하면 안됨.
	cur_hp = data.get("ch", max_hp)



#region animation

# unit.target(예: Player) 내부의 함수
func on_animate(action, data) -> Signal:
	var from_val = Position.position_to_world(data.get("from", cur_position))
	var to_val = Position.position_to_world(data.get("to", cur_position))
	var time = 0.2
	
	
	var tween = create_tween()
	
	# 애니메이션 종류에 따른 분기 처리
	match action:
		"move":
			tween.tween_property(self, "position", to_val, time).from(from_val).set_trans(Tween.TRANS_SINE)
		"move_reverse":
			tween.tween_property(self, "position", to_val, time)\
				.from(from_val)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_OUT)   # 앞으로 갈 때와 반대 이징
		"fade":
			tween.tween_property(self, "modulate:a", 1.0, time).from(0.0) # 투명도 조절
	# 트윈이 끝날 때 발생하는 'finished' 신호를 그대로 반환
	return tween.finished

#endregion
