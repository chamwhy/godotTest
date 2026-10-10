extends Unit
class_name Goblin
## 플레이어가 한 번 행동할 때마다 한 칸 움직이는 적.
##
## ─── 왜 이 규칙인가 ─────────────────────────────────────────────
## 이 게임의 심장은 "체력 = 감정 = 할 수 있는 행동"이다. 고블린은 그 심장과
## 양방향으로 맞물린다.
##   · 내 감정이 고블린을 죽일 수 있는지를 정한다
##     (공격력 = 원래 공격력 − 이동한 칸수 이므로,
##      평온은 제자리에서만, 격노는 부딪힌 것만 죽일 수 있다)
##   · 고블린이 내 감정을 바꾼다 — 걸어다니는 고추다
## 또 "막는 물체"이므로 격노의 패리티를 깨는 **움직이는 브레이크**가 된다.
##
## ─── 결정적이어야 한다 ──────────────────────────────────────────
## 퍼즐 게임이므로 완전정보가 전제다. 난수는 쓰지 않는다.
## 순찰형은 바라보는 방향으로만, 추적형은 고정된 축 우선순위로만 움직인다.
## ─────────────────────────────────────────────────────────────

const KIND_PATROL := "patrol"
const KIND_CHASE := "chase"

var move_kind := KIND_PATROL
## 순찰 방향. 상태의 일부이므로 save_undo_state에 들어간다.
var face: Position = Position.RIGHT()
## 플레이어를 때릴 때의 피해량.
var hit_power := 1


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true      # 움직이는 벽이자 브레이크
	hitable = true
	max_hp = 1           # 1 이상 맞으면 죽는다 (누에고치와 같은 판정)
	cur_hp = 1
	move_kind = data.get("move", KIND_PATROL)
	hit_power = data.get("atk", 1)
	face = _dir_from_key(data.get("dir", "R"))
	_apply_kind_look()


static func _dir_from_key(key: String) -> Position:
	match key:
		"U": return Position.UP()
		"D": return Position.DOWN()
		"L": return Position.LEFT()
		_:   return Position.RIGHT()


## TODO: 고블린 전용 스프라이트로 교체. 지금은 누에고치 텍스처에 색만 입힌
## 플레이스홀더다. 순찰형과 추적형을 색으로만 구분하고 있다.
func _apply_kind_look() -> void:
	if animSprite2D == null:
		return
	animSprite2D.modulate = Color("#c0e080") if move_kind == KIND_PATROL else Color("#e08080")


#region 피격 — 체력 1이라 어떤 공격이든 죽는다
func on_hit(atk_data: AtkData) -> bool:
	if atk_data.dmg < 1:
		return false
	ActionManager.record_new(self, atk_data.tick, "on_damaged")
	_die(atk_data.tick)
	return true


func _die(tick: int) -> void:
	is_dead = true
	hide_for_undo(tick)   # 논리는 즉시 exit, 시각은 큐 타이밍에 vanish
#endregion


#region 고블린 턴
## 플레이어 행동이 끝난 뒤 ActionManager가 불러준다.
## 다음에 쓸 tick을 돌려준다 (연출이 플레이어 턴 뒤에 오도록).
func take_turn(tick: int) -> int:
	if is_dead or is_fallen or not in_map:
		return tick

	for d: Position in _candidate_dirs():
		var target: Position = cur_position.add(d)

		# 플레이어가 그 칸에 있으면 때리고 제자리에 선다
		if _player_at(target):
			if d.x != 0:
				look_right = d.x > 0
			attack(hit_power, d, tick)
			return tick + 1

		if not GridManager.can_pass(target):
			continue

		return _step_to(d, target, tick)

	# 한 칸도 가지 못했다.
	# 순찰형은 방향만 뒤집고 그 턴은 쉰다. 뒤집고 바로 움직이면 한 턴에 두 칸처럼
	# 보여서 플레이어가 주기를 셀 수 없다.
	if move_kind != KIND_CHASE:
		face = Position.new(-face.x, -face.y)
	return tick + 1


func _step_to(d: Position, target: Position, tick: int) -> int:
	var pre_look := look_right
	ActionManager.record_new(self, tick,
		"move",         {"from": cur_position.copy(), "to": target.copy()},
		"move_reverse", {"pre_look": pre_look, "from": target.copy(), "to": cur_position.copy()})
	if d.x != 0:
		look_right = d.x > 0

	GridManager.step_element(self, target, tick + 1)

	# 칸에 들어선 순간 함정에 맞아 죽었을 수 있다
	if is_dead or not in_map:
		return tick + 2

	# 구멍 위에 멈추면 낙하 (상자·플레이어와 같은 규칙)
	if not GridManager.has_tile(cur_position.x, cur_position.y):
		is_fallen = true
		ActionManager.record_new(self, tick + 1, "falling", {}, "undo_falling", {})
		return tick + 2

	GridManager.settle_element(self, tick + 1)
	return tick + 2


func _player_at(pos: Position) -> bool:
	var player: Player = PlayerRegistry.get_player()
	if player == null or not is_instance_valid(player):
		return false
	if player.is_dead or player.is_fallen or not player.in_map:
		return false
	return player.cur_position.equals(pos)


func _candidate_dirs() -> Array[Position]:
	if move_kind == KIND_CHASE:
		return _chase_dirs()
	return [face.copy()] as Array[Position]


## 먼 축을 먼저, 동률이면 가로를 먼저 시도한다.
## 이 우선순위가 고정이어야 플레이어가 다음 턴을 예측할 수 있다.
func _chase_dirs() -> Array[Position]:
	var out: Array[Position] = []
	var player: Player = PlayerRegistry.get_player()
	if player == null or not is_instance_valid(player):
		return out

	var dx: int = player.cur_position.x - cur_position.x
	var dy: int = player.cur_position.y - cur_position.y
	var hor_first: bool = absi(dx) >= absi(dy)

	if hor_first:
		if dx != 0: out.append(Position.new(signi(dx), 0))
		if dy != 0: out.append(Position.new(0, signi(dy)))
	else:
		if dy != 0: out.append(Position.new(0, signi(dy)))
		if dx != 0: out.append(Position.new(signi(dx), 0))
	return out
#endregion


#region undo — 방향도 상태다
func save_undo_state() -> Dictionary:
	var state := super.save_undo_state()
	state.merge({ "face": face.copy() })
	return state


func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	if state.has("face"):
		face = (state["face"] as Position).copy()
#endregion


#region animation
#@override
## TODO: 고블린 전용 처치음/파티클로 교체. 지금은 항아리 파괴음을 임시로 쓴다.
func _anim_vanish(tween: Tween, data: Dictionary) -> void:
	AudioManager.play_sfx("broken_jar")
	super._anim_vanish(tween, data)


func _anim_move(tween: Tween, data: Dictionary) -> void:
	AudioManager.play_sfx("move-1")
	_anim_move_base(tween, data, Tween.EASE_IN_OUT)
#endregion
