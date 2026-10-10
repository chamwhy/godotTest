extends Portal
class_name ClearPortal

const DEACT_ALPHA = 0.5
const ANIM_DUR_ACT = 0.3

# StageCont
var active := false:
	set(v):
		active = v
		base_alpha = 1.0 if v else DEACT_ALPHA

func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	StageContext.register_clear_portal(self)
	active = not StageContext.is_gated()   # setter가 base_alpha까지 처리
	modulate.a = base_alpha

## 활성화: 데이터(active) + 시각(record)을 함께 처리한다.
## 활성화 직후 "이미 포탈 위에 서 있는" 대상을 한 번 검사한다.
func activate(tick: int) -> void:
	active = true
	ActionManager.record_new(self, tick, "activate", {}, "deactivate", {})
	_check_occupant(tick)

## 포탈은 element_settled(이동이 끝난 순간)로만 발동한다.
## 그래서 플레이어가 포탈 위에 선 채로 마지막 누에고치를 부수면
## 활성화는 되지만 settled가 다시 오지 않아 영원히 발동하지 않는다.
## (제자리 타격은 이동 0칸이라 settled가 없다)
## 활성화 시점에 점유자를 한 번 검사해서 그 구멍을 막는다.
func _check_occupant(tick: int) -> void:
	var player: Player = PlayerRegistry.get_player()
	if player == null: return
	if player.is_dead or player.is_fallen: return
	if not player.in_map: return
	if player.cur_position.equals(cur_position):
		move_map(tick)

func move_map(tick: int) -> void:
	if not active: return
	StageContext.complete_stage()
	StageContext.request_map_change({
		"world": to_world,
		"stage": to_stage,
		"out_of": true,
		"out_of_w": StageContext.world,
		"out_of_s": StageContext.stage
	})
	ActionManager.record_new(self, tick, "move_map", {})

#region animation
func _register_animations() -> void:
	super._register_animations()
	_anim_handlers["activate"]   = _anim_activate
	_anim_handlers["deactivate"] = _anim_deactivate

func _anim_activate(tween: Tween, _data: Dictionary) -> void:
	tween.tween_property(self, "modulate:a", 1.0, ANIM_DUR_ACT) \
		.from(DEACT_ALPHA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _anim_deactivate(tween: Tween, _data: Dictionary) -> void:
	tween.tween_property(self, "modulate:a", DEACT_ALPHA, ANIM_DUR_ACT) \
		.from(1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _anim_move_map(tween: Tween, _data: Dictionary) -> void:
	AudioManager.play_sfx("clear_stage", {"duck": 0})
	tween.tween_interval(0.0)
#endregion

#region undo
func save_undo_state() -> Dictionary:
	var state := super.save_undo_state()
	state.merge({ "active": active })
	return state

func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	active = state["active"]
#endregion
