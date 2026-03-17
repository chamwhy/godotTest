# OnHitComp.gd
extends Node
class_name OnHitComp



# 공격자쪽에서 참조 캐싱용 getter
var cached_parent: Element = null

func _ready():
	# 부모(Unit) 캐싱
	cached_parent = get_parent()

# on hit 처리
func on_hit(atkData: AtkData) -> void:
	cached_parent.died()
