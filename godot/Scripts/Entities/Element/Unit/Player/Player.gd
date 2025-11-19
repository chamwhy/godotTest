extends Unit
class_name Player



func reset() -> void:
	super.reset()

func move(dir: Position) -> void:
	super.move(dir)


func apply_data(data: EntityMapData):
	assert(data is PlayerMapData)
	super.apply_data(data)
	var d: PlayerMapData = data
