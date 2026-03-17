# HpComp.gd
extends Node
class_name HpComp

signal hp_changed(cur_hp: int)

@export var max_hp: int = 1
@export var cur_hp: int = -1

# 공격자쪽에서 참조 캐싱용 getter
var cached_parent: Element = null

func _ready():
	# 부모(Unit) 캐싱
	cached_parent = get_parent()
	# 초기 체력 세팅
	if cur_hp < 0:
		cur_hp = max_hp

# 체력 감소 처리
func apply_damage(atk_data: AtkData) -> void:
	cur_hp -= atk_data.dmg
	emit_signal("hp_changed", cur_hp)

	if cur_hp <= 0:
		cur_hp = 0
		cached_parent.died()
