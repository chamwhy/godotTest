extends Unit
class_name Player

func reset() -> void:
	InGameManager.player = self
	super.reset()


func apply_data(data: Dictionary):
	super.apply_data(data)
