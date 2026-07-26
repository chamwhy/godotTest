# AutoLoad - StageManager.gd
extends Node

## 스테이지 해금/클리어 판정만 담당한다. 디스크 접근은 전부 SaveManager 경유.
## AutoLoad 순서: SaveManager 가 StageManager 보다 위에 있어야 한다.

signal stage_cleared(world_id: int, stage_id: int)

const SECTION := "progress"
const LEGACY_PATH := "user://stages.json"


func _ready() -> void:
	_import_legacy_json()


#region 공개 API
func clear_stage(world_id: int, stage_id: int) -> void:
	var list := get_cleared_stages(world_id)
	if stage_id in list:
		return
	list.append(stage_id)
	list.sort()
	SaveManager.set_value(SECTION, _key(world_id), list)
	stage_cleared.emit(world_id, stage_id)


func is_cleared(world_id: int, stage_id: int) -> bool:
	return stage_id in get_cleared_stages(world_id)


func is_unlocked(world_id: int, stage_id: int) -> bool:
	if stage_id == 1:
		return true
	return is_cleared(world_id, stage_id - 1)


## 항상 새 Array를 돌려준다. 호출부가 마음대로 수정해도 세이브가 오염되지 않는다.
func get_cleared_stages(world_id: int) -> Array:
	var stored: Variant = SaveManager.get_value(SECTION, _key(world_id), [])
	if stored is Array:
		return (stored as Array).duplicate()
	return []


func get_cleared_count(world_id: int) -> int:
	return get_cleared_stages(world_id).size()


## 해당 월드에서 다음에 플레이할 스테이지 번호
func get_next_stage(world_id: int) -> int:
	var list := get_cleared_stages(world_id)
	var n := 1
	while n in list:
		n += 1
	return n


func reset_progress() -> void:
	SaveManager.erase_section(SECTION)
#endregion


#region 내부
func _key(world_id: int) -> String:
	return "world_%d" % world_id


## 구버전 user://stages.json 을 한 번만 읽어와 새 형식으로 옮기고 삭제한다.
func _import_legacy_json() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return

	var file := FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if file == null:
		push_warning("[StageManager] 구버전 세이브를 열 수 없다: %s" % LEGACY_PATH)
		return

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("[StageManager] 구버전 세이브 형식이 올바르지 않다. 무시한다.")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PATH))
		return

	# { "1": { "1": true, "3": true } } -> world_1 = [1, 3]
	for world_key: String in (parsed as Dictionary):
		var stages: Variant = parsed[world_key]
		if not (stages is Dictionary):
			continue
		var list: Array = []
		for stage_key: String in (stages as Dictionary):
			if bool(stages[stage_key]) and stage_key.is_valid_int():
				list.append(int(stage_key))
		if list.is_empty():
			continue
		list.sort()
		# 기존 진행도가 이미 있으면 합친다
		var existing := get_cleared_stages(int(world_key))
		for s: int in list:
			if not (s in existing):
				existing.append(s)
		existing.sort()
		SaveManager.set_value(SECTION, _key(int(world_key)), existing)

	SaveManager.flush()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PATH))
	print("[StageManager] 구버전 stages.json 임포트 완료")
#endregion
