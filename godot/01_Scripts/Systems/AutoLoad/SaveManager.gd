# AutoLoad - SaveManager.gd
extends Node

## 파일 입출력만 담당하는 저장소. 게임 로직은 일절 넣지 않는다.
## StageManager, AudioManager 등이 이 노드를 통해서만 디스크에 접근한다.
##
## 저장 형식: ConfigFile (user://save.cfg)
##   [meta]     version=1
##   [audio]    master_volume=1.0 / bgm_volume=0.8 / sfx_volume=1.0
##   [progress] world_1=[1, 2, 5]
##
## JSON 대신 ConfigFile을 쓰는 이유:
##  - int 키가 문자열로 강제 변환되지 않는다 (JSON은 무조건 String 키)
##  - Array / Dictionary / Vector2 등 Variant를 그대로 왕복시킨다
##  - 사람이 읽을 수 있어서 디버깅이 쉽다

signal loaded()
signal saved()

const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 1

## 이 시간 동안 추가 변경이 없으면 디스크에 쓴다.
## 볼륨 슬라이더처럼 초당 수십 번 값이 바뀌는 경우를 흡수한다.
const SAVE_DEBOUNCE := 0.5

var _config := ConfigFile.new()
var _dirty := false
var _save_timer: Timer


func _ready() -> void:
	# 일시정지 중에도 설정 저장이 동작해야 한다
	process_mode = Node.PROCESS_MODE_ALWAYS

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)

	load_data()


#region 공개 API
func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _config.get_value(section, key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	# 의도적으로 값 비교를 하지 않는다.
	# get_value()가 Dictionary/Array를 참조로 돌려주기 때문에,
	# 호출부가 그걸 수정한 뒤 되돌려주면 "같은 값"으로 보여 저장이 누락된다.
	_config.set_value(section, key, value)
	_mark_dirty()


func has_value(section: String, key: String) -> bool:
	return _config.has_section_key(section, key)


func erase(section: String, key: String) -> void:
	if _config.has_section_key(section, key):
		_config.erase_section_key(section, key)
		_mark_dirty()


func erase_section(section: String) -> void:
	if _config.has_section(section):
		_config.erase_section(section)
		_mark_dirty()


## 세이브 초기화 (설정은 유지하고 진행도만 지우고 싶다면 erase_section 사용)
func wipe() -> void:
	_config.clear()
	_config.set_value("meta", "version", SAVE_VERSION)
	_dirty = true
	flush()


## 즉시 디스크에 쓴다. 앱 종료/백그라운드 진입 시 자동 호출된다.
func flush() -> void:
	if not _dirty:
		return
	var err := _config.save(SAVE_PATH)
	if err != OK:
		push_error("[SaveManager] 저장 실패 (%d): %s" % [err, SAVE_PATH])
		return
	_dirty = false
	saved.emit()


func load_data() -> void:
	var err := _config.load(SAVE_PATH)
	if err == ERR_FILE_NOT_FOUND:
		# 첫 실행
		_config.set_value("meta", "version", SAVE_VERSION)
		loaded.emit()
		return
	if err != OK:
		push_error("[SaveManager] 로드 실패 (%d). 새 세이브로 시작한다." % err)
		_config.clear()
		_config.set_value("meta", "version", SAVE_VERSION)
		_mark_dirty()
		loaded.emit()
		return

	_migrate()
	loaded.emit()
#endregion


#region 내부
func _mark_dirty() -> void:
	_dirty = true
	# start()는 이미 돌고 있는 타이머를 처음부터 다시 시작시킨다 (디바운스)
	_save_timer.start(SAVE_DEBOUNCE)


func _migrate() -> void:
	var version := int(_config.get_value("meta", "version", 0))
	if version == SAVE_VERSION:
		return

	# 여기에 버전별 변환 로직을 순차로 추가한다.
	# 예:
	# if version < 2:
	#     ... v1 -> v2 변환 ...
	#     version = 2

	_config.set_value("meta", "version", SAVE_VERSION)
	_mark_dirty()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, \
		NOTIFICATION_EXIT_TREE, \
		NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# 모바일에서 앱이 백그라운드로 갈 때 저장하지 않으면
			# 태스크 스와이프 종료 시 진행도가 통째로 날아간다.
			flush()
#endregion
