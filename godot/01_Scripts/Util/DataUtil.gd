extends RefCounted
# AnimUtil.gd (AutoLoad 등록 or 그냥 클래스로)
class_name DataUtil

static func add_padding(grid: Array, padding: int, fill_value = null) -> Array:
	var result: Array = []
	
	# 원본의 가로 길이 (첫 행 기준, 비어있으면 0)
	var original_width: int = grid[0].size() if grid.size() > 0 else 0
	var new_width: int = original_width + padding * 2
	
	# 위쪽 패딩 행
	for i in padding:
		result.append(_make_row(new_width, fill_value))
	
	# 기존 행 + 좌우 패딩
	for row in grid:
		var new_row: Array = []
		for i in padding:
			new_row.append(fill_value)
		new_row.append_array(row)
		for i in padding:
			new_row.append(fill_value)
		result.append(new_row)
	
	# 아래쪽 패딩 행
	for i in padding:
		result.append(_make_row(new_width, fill_value))
	
	return result


static func _make_row(width: int, fill_value) -> Array:
	var row: Array = []
	row.resize(width)
	row.fill(fill_value)
	return row
