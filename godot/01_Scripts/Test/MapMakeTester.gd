extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MapDrawer.draw_map(1,3)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("test_x"):
		print("test x")
		MapDrawer.draw_map(1,3)
