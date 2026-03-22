extends Resource
class_name AtkData

var dmg: int
var from: Position
var tick: int
# blow란?
# 타격을 의미함. 타격이란 행위로 인한 공격인지 아닌지 판별
# 플레이어가 때리면 타격, 레이저로 때리면 그냥 공격(blow 없음)
var has_blow: bool


func _init(_dmg: int, _from: Position, _tick: int, _has_blow: bool = true) -> void:
	self.dmg = _dmg
	self.from = _from
	self.tick = _tick
	self.has_blow = _has_blow
