extends Element
class_name Wall

var destroyable := false
var min_atk := 0

func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true
	hitable = true
	min_atk = data.get("ma", 0)
	destroyable = min_atk != 0
	# TODO: 상태에 따른 이미지 업데이트
	
