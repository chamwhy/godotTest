# Element.gd
# 규칙에 의해 영향을 받고 상호작용하는 모든 개체의 기본 클래스
extends Entity
class_name Element

#region element 별 특성
@export var is_block: bool = false  # 막힘 판정 여부
@export var hitable: bool = true

@onready var hit_effect: HitEffect = $AnimatedSprite2D/HitEffect

var in_map := false   # 맵에 존재하는지 여부 (InGameManager가 관리)

#endregion


func on_hit(atk_data: AtkData) -> bool:
	return false



func apply_data(data: Dictionary):
	super.apply_data(data)
	print("unit apply")
	z_index = ZIndexer.calc(cur_position.y, ZIndexer.ZID_ELEMENT)
	InGameManager.register_element(cur_position, self)


#region Anim
# Element.gd

func _register_animations() -> void:
	super._register_animations()
	_anim_handlers["on_damaged"]   = _anim_on_damaged
	_anim_handlers["on_parryed"]   = _anim_on_parryed
	_anim_handlers["falling"]      = _anim_falling
	_anim_handlers["undo_falling"] = _anim_undo_falling
	_anim_handlers["vanish"]       = _anim_vanish     # ← 추가
	_anim_handlers["respawn"]      = _anim_respawn    # ← 추가


func _anim_on_damaged(tween: Tween, data: Dictionary) -> void:
	hit_effect.play_hit()
	tween.tween_interval(0.0)

func _anim_on_parryed(tween: Tween, data: Dictionary) -> void:
	hit_effect.play_parry()
	tween.tween_interval(0.0)

func _anim_falling(tween: Tween, data: Dictionary) -> void:
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 120, 1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _anim_undo_falling(tween: Tween, data: Dictionary) -> void:
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 120, 1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _anim_vanish(tween: Tween, data: Dictionary) -> void:
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		hide()
		modulate.a = 1.0   # 알파는 원복해두고 visible로만 제어
	)

func _anim_respawn(tween: Tween, data: Dictionary) -> void:
	show()
	tween.tween_property(self, "modulate:a", 1.0, 0.15).from(0.0)
	# TODO: "펑" 재생성 파티클은 여기서 재생


## 소멸 처리: 논리는 즉시 exit, 시각은 큐 타이밍에 맞춰 vanish
## Undo 시엔 자동으로 respawn이 역산 재생됨
func hide_for_undo(tick: int) -> void:
	InGameManager.exit_element(self, cur_position, tick)  # in_map=false 처리됨
	AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(
		self, "vanish", {}, "respawn", {}
	), tick)


func apply_undo(state: Dictionary) -> void:
	cur_position = state["position"]
	in_map       = state["in_map"]
	is_block     = state["is_block"]
	hitable      = state["hitable"]
	# visible/픽셀 position은 애니메이션(vanish/respawn/move_reverse)과
	# UndoManager._sync_visuals()가 담당


#endregion


# ─────────────────────────────────────────────
# Undo 계약 (서브클래스가 override)
# ─────────────────────────────────────────────

## 현재 논리 상태를 Dictionary로 반환한다.
## 서브클래스는 super.save_undo_state() 결과에 자신의 필드를 merge해서 반환한다.
func save_undo_state() -> Dictionary:
	return {
		"position": cur_position.copy(),
		"in_map":   in_map,
		"is_block": is_block,
		"hitable":  hitable,
		"visible":  visible,
	}
