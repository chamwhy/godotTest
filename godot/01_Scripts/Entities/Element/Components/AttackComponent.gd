# AttackComponent.gd
extends Node
class_name AttackComponent

# 공격 처리
# target: 공격 대상 Node
# damage: 입힐 데미지
func attack(target: Node, damage: int) -> void:
	if not target:
		return
	
	# 캐싱된 DamageableComponent 접근
	# 있으면 바로 적용, 없으면 공격 불가
	var dmg_comp: DamageableComponent = null

	# target이 DamageableComponent를 직접 자식으로 가지고 있다면 캐싱
	if target.has_node("DamageableComponent"):
		dmg_comp = target.get_node("DamageableComponent") as DamageableComponent

	if dmg_comp:
		dmg_comp.apply_damage(damage)
	else:
		# 공격 대상이 데미지를 받을 수 없으면 무시
		print("[AttackComponent] Target ", target.name, " is not damageable")
