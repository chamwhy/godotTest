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
#TODO: look을 player로 옮겨야 하는 리팩토링 필
var look_right := true
#endregion

func blocking() -> bool:
	return is_block and not is_dead and not is_fallen

func reset() -> void:
	super.reset()
	cur_hp = max_hp

func action_dir(dir: Position, tick: int) -> void:
	if dir.equals(Position.ZERO()):
		GridManager.interact_element(self, cur_position, 0)
		return

	var real_dir = dir.normalized()
	if move_speed < 0:
		real_dir = real_dir * -1
	action2(real_dir, abs(move_speed), tick)


func action2(dir: Position, spd: int, tick: int) -> void:
	if not dir.is_straight(): return
	if dir.is_zero(): return

	# 사전 시뮬레이션 루프 제거. 이동하면서 매 칸 라이브로 판정한다.
	var res := move_to(dir, spd, tick)
	tick = res["tick"]

	# 이동한 만큼 공격력 소모
	var remain_atk: int = atk_pow - res["moved"]
	if res["blocked"] and remain_atk > 0:
		attack(remain_atk, res["dir"], tick, res["pos"])
		tick += 1

	# 낙하는 최종 착지 지점 기준 (A2: 죽어도 관성 유지)
	if not GridManager.has_tile(cur_position.x, cur_position.y):
		is_fallen = true
		ActionManager.record_new(self, tick, "falling", {}, "undo_falling", {})


## 운동량(방향 + 남은 이동력)은 로컬 보존, 위치는 매 스텝 라이브 조회.
## 외부가 cur_position을 바꾸면 그 지점에서 원래 벡터로 이어서 진행한다. (벡터 합성)
func move_to(dir: Position, spd: int, tick: int) -> Dictionary:
	var cur_dir: Position = dir.copy()
	var remain: int = spd
	var moved := 0
	var blocked := false

	while remain > 0:
		if cur_dir.is_zero(): break

		# 핵심: 로컬 커서가 아니라 라이브 위치에 벡터를 더한다
		var from_pos: Position = cur_position.copy()
		var to_pos: Position = from_pos.add(cur_dir)

		if not GridManager.can_pass(to_pos):
			blocked = true
			break

		var pre_look := look_right

		GridManager.step_element(self, to_pos, tick)

		if cur_dir.x != 0:
			look_right = cur_dir.x > 0

		# 칸마다 1 record → undo가 역순 재생하면 그대로 되감긴다
		ActionManager.record_new(self, tick,
			"move",         {"from": from_pos.copy(), "to": to_pos.copy()},
			"move_reverse", {"pre_look": pre_look, "from": to_pos.copy(), "to": from_pos.copy()})

		moved += 1
		remain -= 1
		tick += 1

		cur_dir = _redirect(cur_dir, to_pos)

	# 0칸이면 정착 이벤트 없음
	if moved > 0:
		GridManager.settle_element(self, tick)

	return {
		"tick": tick,
		"moved": moved,
		"blocked": blocked,
		"dir": cur_dir,
		"pos": cur_position.copy(),
	}


## 범퍼/컨베이어/반사판 등이 추가되면 여기서 방향을 꺾는다.
func _redirect(cur_dir: Position, _at_pos: Position) -> Position:
	return cur_dir


func attack(atk_power: int, dir: Position, tick: int, from_pos = null) -> void:
	var origin: Position = from_pos if from_pos != null else cur_position
	var targets: Array[Element] = GridManager.get_elements(origin.add(dir))
	for target in targets:
		if target:
			apply_on_hit(target, atk_power, tick)

	var pre_look := look_right
	ActionManager.record_new(self, tick,
		"attack", {"pos": origin.copy(), "dir": dir.copy(), "pow": atk_power},
		"undo_attack", {"pre_look": pre_look, "pos": origin.copy(), "dir": dir.copy()})

	if dir.x != 0:
		look_right = dir.x > 0

#region regacy
#func action_dir(dir: Position, tick: int) -> void:
	#if dir.equals(Position.ZERO()):
		#GridManager.interact_element(self, cur_position, 0)
	#else:
		#var real_dir = dir.normalized()
		#if move_speed < 0:
			#real_dir = real_dir * -1
		## 음수값 구현
		#action2(real_dir, abs(move_speed), tick)
#
#func action2(dir: Position, spd: int, tick: int) -> void:
	#if not dir.is_straight(): return
	#if dir.is_zero(): return
	#
	#var chk_pos: Position = cur_position.copy()
	#
	#
	#var move_cnt := 0
	#var remain_move: int = spd
	#var remain_atk: int = atk_pow
	#var was_blocked := false
	#
	## 이동 체크
	#while(true):
		## 모든 이동력을 다 쓴 상태
		#if remain_move <= 0:
			#break
		#var checks = GridManager.can_pass(chk_pos.add(dir))
		#if remain_move > 0 and checks:
			#remain_move -= 1
			## 해당 게임에선 이동력을 소모하면 같이 공격력도 소모함.
			#remain_atk -= 1
			#move_cnt += 1
			#chk_pos = chk_pos.add(dir)
		#else:
			#if remain_move > 0:
				#was_blocked = true
			#break
	#
	#if move_cnt > 0:
		#tick = move_to(dir, move_cnt, tick)
		#tick += 1
	#
	#if was_blocked and remain_atk > 0:
		#attack(remain_atk, dir, tick)
	#
	#if not GridManager.has_tile(cur_position.x, cur_position.y):
		#print("구멍에 빠짐")
		#is_fallen = true
		#ActionManager.record_new(self, tick, "falling", {}, "undo_falling", {})
#
#
## 순간이동
#func move_inst(pos: Position) -> void:
	#pass
#
## 속력 이동
#func move_to(dir: Position, spd: int, tick: int) -> int:
	#if dir.is_zero(): return tick
	#
	#var vel = dir.multiply(spd)
	#var goal: Position = vel.add(cur_position)
	#var chk_pos: Position = cur_position.add(dir)
	#var from: Position = cur_position.copy()
	#
	#
	#print("이동: ", from.to_str(), " -> ", goal.to_str())
	#var re = GridManager.exit_element(self, cur_position, tick)
	#if self != re: print("오류임. 절대 무조건 같아야 함")
 #
	#while true:
		#if chk_pos.equals(goal): break
		#GridManager.pass_element(self, chk_pos, tick)
		#chk_pos = chk_pos.add(dir)
		#print("====inside", from.to_str(), chk_pos.to_str(), spd)
		##ActionManager.record_new(self, tick,
			##"move",         {"from": from.copy(), "to": chk_pos.copy(), "spd": spd},
			##"move_reverse", {"pre_look": look_right, "from": chk_pos.copy(), "to": from.copy()})
		#if dir.x != 0:
			#look_right = dir.x > 0
		#from = chk_pos.copy()
		#tick += 1
	#print("====outside", from.to_str(), chk_pos.to_str(), spd)
	#ActionManager.record_new(self, tick,
			#"move",         {"from": from.copy(), "to": chk_pos.copy(), "spd": spd},
			#"move_reverse", {"pre_look": look_right, "from": chk_pos.copy(), "to": from.copy()})
	#
	## while 들어가기 전에 한 번 이동은 무조건 하니, look_right 수정
	#if dir.x != 0:
		#look_right = dir.x > 0
	## 도착을 기준으로 하니 tick에 1 추가
	#GridManager.enter_element(self, chk_pos, tick+1)
	#return tick
#
#
#func attack(atk_power: int, dir: Position, tick: int) -> void:
	#print("공격: ", cur_position.to_str(), " > ", dir.to_str())
	#var targets: Array[Element] = GridManager.get_elements(cur_position.add(dir))
	#for target in targets:
		#if target:
			## TODO: 일단 하드코딩으로 1로 채워둠.
			#apply_on_hit(target, atk_power, tick)
	#ActionManager.record_new(self, tick,
		#"attack", {"pos": cur_position.copy(), "dir": dir.copy(), "pow": atk_power},
		#"undo_attack", {"pre_look": look_right, "pos": cur_position.copy(), "dir": dir.copy()})
	#if dir.x != 0:
		#look_right = dir.x > 0

#endregion

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



func save_undo_state() -> Dictionary:
	var state := super.save_undo_state()
	state.merge({
		"cur_hp":    cur_hp,
		"is_dead":   is_dead,
		"is_fallen": is_fallen,
	})
	return state
 
func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	cur_hp    = state["cur_hp"]
	is_dead    = state["is_dead"]
	is_fallen  = state["is_fallen"]
	
 
 


#region animation

func _register_animations() -> void:
	super._register_animations()          # 부모 것 먼저 등록
	_anim_handlers["move"]         = _anim_move
	_anim_handlers["move_reverse"] = _anim_move_reverse
	_anim_handlers["attack"]       = _anim_attack
	_anim_handlers["undo_attack"]       = _undo_anim_attack

func _anim_move_base(tween: Tween, data: Dictionary, ease: Tween.EaseType) -> void:
	var from_pos: Position = data.get("from", cur_position)
	var to_pos: Position = data.get("to", cur_position)
	
	var from_val = Position.position_to_world(from_pos)
	var to_val = Position.position_to_world(to_pos)
	var to_z_index = ZIndexer.calc(to_pos.y, ZIndexer.ZID_ELEMENT)
	if to_z_index > z_index:
		z_index = to_z_index
	tween.tween_property(self, "position", to_val, 0.2) \
		.from(from_val).set_trans(Tween.TRANS_SINE).set_ease(ease)
	tween.tween_callback(func(): z_index = to_z_index)

func _anim_move(tween: Tween, data: Dictionary) -> void:
	_anim_move_base(tween, data, Tween.EASE_IN)

func _anim_move_reverse(tween: Tween, data: Dictionary) -> void:
	_anim_move_base(tween, data, Tween.EASE_OUT)

func _anim_attack(tween: Tween, data: Dictionary) -> void:
	var pos: Position = data.get("pos", cur_position)
	var dir: Position = data.get("dir", Position.ZERO())
	print("attack anim: pos=", pos.to_str(), ", dir=", dir.to_str())
	if not dir.is_zero():
		EffectUtil.spawn_chop(
			get_tree(), 
			pos.add(dir), 
			dir, 
			data.get("pow", 1))
	tween.tween_interval(0.2)

func _undo_anim_attack(tween: Tween, data: Dictionary) -> void:
	print("_undo_anim_attack")
	tween.tween_interval(0.0)

#endregion
