# Element.gd
# 규칙에 의해 영향을 받고 상호작용하는 모든 개체의 기본 클래스
extends Entity
class_name Element

#region element 별 특성
@export var is_block: bool = false  # 막힘 판정 여부
@export var hitable: bool = true

@onready var hit_effect: HitEffect = $Sprite2D/HitEffect
#endregion


func on_hit(atk_data: AtkData) -> bool:
	return false



func apply_data(data: Dictionary):
	super.apply_data(data)
	_set_z_index(SortLayer.Element)
	print("apply data")
	InGameManager.register_element(cur_position, self)


#region Anim
func _register_animations() -> void:
	super._register_animations()          # 부모 것 먼저 등록
	_anim_handlers["on_damaged"] = _anim_on_damaged
	_anim_handlers["on_parryed"] = _anim_on_parryed

func _anim_on_damaged(tween: Tween, data: Dictionary) -> void:
	hit_effect.play_hit()
	tween.tween_interval(0.0)

func _anim_on_parryed(tween: Tween, data: Dictionary) -> void:
	hit_effect.play_parry()
	tween.tween_interval(0.0)



#endregion


# ─────────────────────────────────────────────
# Undo 계약 (서브클래스가 override)
# ─────────────────────────────────────────────

## 현재 논리 상태를 Dictionary로 반환한다.
## 서브클래스는 super.save_undo_state() 결과에 자신의 필드를 merge해서 반환한다.
func save_undo_state() -> Dictionary:
	return {
		"position": cur_position.copy(),
		"is_block": is_block,
		"hitable":  hitable,
		"visible":  visible,
	}

## save_undo_state()가 반환한 Dictionary로 논리 상태를 복원한다.
## 서브클래스는 super.apply_undo(state)를 먼저 호출한 뒤 추가 처리한다.
func apply_undo(state: Dictionary) -> void:
	cur_position = state["position"]
	is_block     = state["is_block"]
	hitable      = state["hitable"]
	# 시각 위치는 애니메이션이 끝난 뒤 최종적으로 맞춰짐.
	# Undo 애니메이션의 undo_data.to 가 최종 위치이므로,
	# 여기선 논리값만 복원하고 position(픽셀)은 on_animate가 담당한다.
	if state.get("visible", true):
		show()

## 소멸 처리: queue_free 대신 숨김으로 처리한다.
## element_map 에서도 제거한다.
func hide_for_undo(tick: int) -> void:
	InGameManager.exit_element(self, cur_position, tick)
	hide()
