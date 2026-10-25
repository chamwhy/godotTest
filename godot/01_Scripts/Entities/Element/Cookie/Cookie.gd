extends Element
class_name Cookie
## 쿠키. 밟으면 먹고 체력이 heal만큼 회복된 뒤 사라진다. 일회용.
## 무엇이 밟든 사라진다 (회복 효과는 on_heal이 있는 개체만 받는다) → 돌로 쿠키를 치울 수 있다.

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var heal_pow := 1
var eaten := false
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = false
	heal_pow = data.get("heal", 1)

	GridManager.element_entered.connect(_check_pos)

func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	if not in_map: return   # 맵에서 빠진(해제 대기 중인) 개체는 반응하지 않는다
	if not eaten and pos.equals(cur_position):
		heal(elm, tick)
		eat(tick)

func heal(target: Element, tick: int) -> void:
	var new_heal_data = HealData.new(
		heal_pow,
		tick
	)
	if is_instance_valid(target) and target.has_method("on_heal"):
		target.on_heal(new_heal_data)


func eat(tick: int) -> void:
	eaten = true
	hide_for_undo(tick)

#@override
func _anim_vanish(tween: Tween, data: Dictionary) -> void:
	AudioManager.play_sfx("heal")
	super._anim_vanish(tween, data)

func save_undo_state() -> Dictionary:
	var dict = super.save_undo_state()
	dict["eaten"] = eaten
	return dict

## save_undo_state()가 반환한 Dictionary로 논리 상태를 복원한다.
## 서브클래스는 super.apply_undo(state)를 먼저 호출한 뒤 추가 처리한다.
func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	eaten = state.get("eaten", false)
