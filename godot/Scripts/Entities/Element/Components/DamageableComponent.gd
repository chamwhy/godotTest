# DamageableComponent.gd
extends Node
class_name DamageableComponent

signal hp_changed(current_hp: int)
signal died

var max_hp: int = 100
var current_hp: int = 100

# 공격자쪽에서 참조 캐싱용 getter
var cached_parent: Node = null

func _ready():
	# 부모(Unit) 캐싱
	cached_parent = get_parent()
	# 초기 체력 세팅
	current_hp = max_hp

# 체력 감소 처리
func apply_damage(amount: int) -> void:
	current_hp -= amount
	emit_signal("hp_changed", current_hp)

	if current_hp <= 0:
		current_hp = 0
		emit_signal("died")
