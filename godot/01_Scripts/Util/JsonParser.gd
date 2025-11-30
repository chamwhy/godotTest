extends RefCounted
class_name JsonParser


static func load_json_data(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		push_error("Error opening data file: ", path)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json_result = JSON.parse_string(json_string)
	if json_result == null:
		push_error("Error parsing JSON data in: ", path)
		return {}
		
	return json_result


# 딕셔너리를 JSON 파일로 저장하는 함수
static func save_json_data(path: String, data: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if FileAccess.get_open_error() != OK:
		push_error("Error saving data file: ", path)
		return false

	var json_string = JSON.stringify(data, "\t") # 보기 좋게 탭으로 포맷팅
	file.store_string(json_string)
	file.close()
	return true
