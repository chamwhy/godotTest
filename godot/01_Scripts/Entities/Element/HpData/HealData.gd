extends Resource
class_name HealData

var heal: int
var tick: int


func _init(_heal: int, _tick: int) -> void:
	self.heal = _heal
	self.tick = _tick
