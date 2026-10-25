extends Element
class_name Chili
## 칠리(고추). 밟으면 먹고 체력이 1 깎인 뒤(화가 나고) 사라진다. 일회용.
## 피해량은 항상 1이다. 여러 칸 깎는 것은 가시(Trap)로만 만든다.
## 때리면 먹지 않고 부서진다 (화남이 걸으며 휘두르기로 앞 칸의 칠리를 치우는 것).
## 돌이 밟아도 먹힌다 — 돌은 피해를 받지 않으니 "돌로 칠리 치우기"가 된다.

const DAMAGE := 1

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var eaten := false
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = true

	# 연결은 super.apply_data(→ 자기 자신의 enter) 다음이어야 자기에게 발동하지 않는다
	GridManager.element_entered.connect(_check_pos)


func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	if not in_map: return   # 맵에서 빠진(해제 대기 중인) 개체는 반응하지 않는다
	if eaten or not pos.equals(cur_position): return
	if is_instance_valid(elm) and elm.hitable:
		elm.on_hit(AtkData.new(DAMAGE, cur_position, tick, false))
	eat(tick)

## 맞으면 먹히지 않고 부서진다
func on_hit(atk_data: AtkData) -> bool:
	if eaten: return false
	eat(atk_data.tick)
	return true

func eat(tick: int) -> void:
	eaten = true
	hide_for_undo(tick)

#@override
func _anim_vanish(tween: Tween, data: Dictionary) -> void:
	AudioManager.play_sfx("eat")
	super._anim_vanish(tween, data)


func save_undo_state() -> Dictionary:
	var dict = super.save_undo_state()
	dict["eaten"] = eaten
	return dict

## save_undo_state()가 반환한 Dictionary로 논리 상태를 복원한다.
func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	eaten = state.get("eaten", false)
