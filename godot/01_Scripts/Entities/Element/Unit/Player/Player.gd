extends Unit
class_name Player



func reset() -> void:
	super.reset()

func move(dir: Position) -> void:
	super.move(dir)


func apply_data(data: Dictionary):
	super.apply_data(data)
