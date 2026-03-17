# OnHitComp.gd
extends OnHitComp
class_name HpOnHitComp

# on hit 처리
func on_hit(atk_data: AtkData) -> void:
	var hp_comp: HpComp = null

	# cached_parent HpComp 직접 자식으로 가지고 있다면 캐싱
	if cached_parent.has_node("HpComp"):
		hp_comp = cached_parent.get_node("HpComp") as HpComp
	
	hp_comp.apply_damage(atk_data)
