# AutoLoad - SaveManager.gd
extends Node


# 저장 파일 경로 (모바일/PC 공통)
const SAVE_PATH := "user://save.json"

# 게임 데이터
var curMapId : int = Config.START_MAP_ID
var curPos: Position = Position.ZERO()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#
## 🔹 데이터 저장
#func save_game():
	#var data := {
		#"player_lives": player_lives
	#}
	#var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	#if file:
		#file.store_string(JSON.stringify(data))
		#file.close()
		#print("✅ 게임 저장 완료:", ProjectSettings.globalize_path(SAVE_PATH))
#
## 🔹 데이터 불러오기
#func load_game():
	#if not FileAccess.file_exists(SAVE_PATH):
		#print("⚠️ 저장 파일 없음 — 새 데이터로 시작합니다.")
		#return
#
	#var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	#if not file:
		#print("❌ 저장 파일 열기 실패.")
		#return
#
	#var text := file.get_as_text()
	#file.close()
#
	#var result = JSON.parse_string(text)
	#if typeof(result) == TYPE_DICTIONARY:
		#score = result.get("score", 0)
		#player_lives = result.get("player_lives", 3)
		#print("✅ 데이터 불러오기 완료:", result)
	#else:
		#print("⚠️ 저장 데이터 손상 또는 형식 오류.")
