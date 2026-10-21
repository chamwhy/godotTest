extends RefCounted
class_name JsonParser


## 마지막 load_json_data가 실패한 이유. 성공하면 빈 문자열.
static var last_error := ""

static func load_json_data(path: String) -> Dictionary:
	last_error = ""
	var file = FileAccess.open(path, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		last_error = "파일 열기 실패: %s" % error_string(FileAccess.get_open_error())
		push_error("Error opening data file: ", path)
		return {}

	var json_string = file.get_as_text()
	file.close()

	# JSON.parse_string은 실패 이유를 버린다. 몇 번째 줄이 틀렸는지 남기려고 인스턴스로 파싱한다.
	var json := JSON.new()
	if json.parse(json_string) != OK:
		last_error = "JSON 문법 오류 %d번째 줄: %s" % [json.get_error_line(), json.get_error_message()]
		push_error("Error parsing JSON data in: ", path)
		return {}
	if not json.data is Dictionary:
		last_error = "JSON 맨 바깥이 { } 가 아님"
		push_error("Error parsing JSON data in: ", path)
		return {}

	return json.data


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
