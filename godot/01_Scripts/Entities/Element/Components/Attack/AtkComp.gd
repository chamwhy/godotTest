# AtkComp.gd
extends Node
class_name AtkComp

@export var is_blow := true
var dmg: int = 1:
	get:
		return dmg

# 공격 처리
# attacker: 공격자 Element
# target: 공격 대상 Element
# damage: 입힐 데미지
func attack(attkacker: Element, target: Element, damage: int) -> bool:
	if not target:
		return false
	
	# 캐싱된 OnHitComp 접근
	# 있으면 바로 적용, 없으면 공격 불가
	var on_hit_comp: OnHitComp = null

	# target이 OnHitComp 직접 자식으로 가지고 있다면 캐싱
	if target.has_node("OnHitComp"):
		on_hit_comp = target.get_node("OnHitComp") as OnHitComp

	var atk_data: AtkData = AtkData.new(
		dmg,
		attkacker.cur_position,
		is_blow
	)
	
	if on_hit_comp:
		on_hit_comp.on_hit(atk_data)
		return true
	else:
		# 공격 대상이 데미지를 받을 수 없으면 무시
		print("[AtkComp] Target ", target.name, " is not onhitable")
		return false

func get_targets(attacker: Element, dir: Position) -> Array[Element]:
	# TODO: 타겟 서치.
	return [InGameManager.get_element(attacker.cur_position.add(dir), 1)]
