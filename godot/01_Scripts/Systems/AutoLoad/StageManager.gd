# stage_manager.gd (Autoload)
extends Node

const SAVE_PATH = "user://stages.json"

# { "1": { "1": true, "3": true }, "2": { "1": true } }
# world_id -> stage_id -> cleared
var cleared: Dictionary = {}

func _ready():
	load_data()

func clear_stage(world_id: int, stage_id: int) -> void:
	var w = str(world_id)
	if not cleared.has(w):
		cleared[w] = {}
	cleared[w][str(stage_id)] = true
	save_data()

func is_cleared(world_id: int, stage_id: int) -> bool:
	return cleared.get(str(world_id), {}).get(str(stage_id), false)

func is_unlocked(world_id: int, stage_id: int) -> bool:
	# 첫 스테이지는 항상 열림
	if stage_id == 1:
		return true
	# 이전 스테이지 클리어 여부로 판단
	return is_cleared(world_id, stage_id - 1)

func save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(cleared))
	file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if result is Dictionary:
		cleared = result
