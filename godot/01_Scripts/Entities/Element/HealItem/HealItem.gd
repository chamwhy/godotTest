extends Element
class_name HealItem

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var heal_pow := 1
var healed := false
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = false
	heal_pow = data.get("heal", 1)
	
	GridManager.element_entered.connect(_check_pos)
	
	# TODO: 상태에 따른 이미지 업데이트

func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	if not healed and pos.equals(cur_position):
		heal(elm, tick)
		destroy_healItem(tick)

func heal(target: Element, tick: int) -> void:
	var new_heal_data = HealData.new(
		heal_pow,
		tick
	)
	if is_instance_valid(target) and target.has_method("on_heal"):
		target.on_heal(new_heal_data)


func destroy_healItem(tick: int) -> void:
	healed = true
	hide_for_undo(tick) 

func save_undo_state() -> Dictionary:
	var dict = super.save_undo_state()
	dict["healed"] = healed
	return dict

## save_undo_state()가 반환한 Dictionary로 논리 상태를 복원한다.
## 서브클래스는 super.apply_undo(state)를 먼저 호출한 뒤 추가 처리한다.
func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	healed = state.get("healed", false)
