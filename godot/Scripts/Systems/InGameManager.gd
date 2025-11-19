extends Node
class_name InGameManager

var is_moving: bool = true
var drawer: MapDrawer


func _init() -> void:
	drawer = MapDrawer.new()
