# LogUtil.gd
## print 대신 쓰는 로그 함수. 콘솔에 찍고, 화면 로그(LogOverlay)용으로 기록도 남긴다.
##
##   LogUtil.write("cam setting - pos: ", position)   # print와 같은 모양
##
## 엔진 오류·경고(push_error, 스크립트 오류 등)도 ErrorLogger가 같은 기록에 넣는다.
## 내보낸 빌드에서 "Could not resolve ..." 같은 컴파일 오류도 화면에서 보이게 하려는 것.
##
## ─── 의존성 없음 ────────────────────────────────────────────
## 어디서나 부르는 유틸이라 게임 스크립트를 하나도 참조하지 않는다.
## 참조하면 Config 때처럼 컴파일 순환에 엮일 수 있다.
## 화면 쪽(LogOverlay)은 version이 바뀌었는지 보고 알아서 다시 그린다.
## ─────────────────────────────────────────────────────────────
class_name LogUtil
extends RefCounted

## 기억할 최대 줄 수. 화면엔 이 중 아랫부분만 보인다.
const MAX_LINES := 60

## 기록이 바뀔 때마다 1씩 오른다. 화면은 이 값만 비교해 갱신 여부를 정한다.
static var version := 0

static var _lines: PackedStringArray = []
## ErrorLogger는 아무 스레드에서나 불릴 수 있다
static var _mutex := Mutex.new()


## print와 같은 인자를 받는다
static func write(...args: Array) -> void:
	var line := ""
	for a in args:
		line += str(a)
	print(line)
	_record(line)


## 지금까지의 기록 (오래된 것 → 최신 순)
static func get_lines() -> PackedStringArray:
	_mutex.lock()
	var copy := _lines.duplicate()
	_mutex.unlock()
	return copy


static func _record(line: String) -> void:
	_mutex.lock()
	_lines.append(line)
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice(_lines.size() - MAX_LINES)
	version += 1
	_mutex.unlock()


## 엔진이 내보내는 오류·경고를 받아 기록한다. OS.add_logger(LogUtil.ErrorLogger.new())
## print 출력(_log_message)은 받지 않는다. write가 이미 기록하므로 두 번 들어간다.
class ErrorLogger extends Logger:
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var tag: String = ["[오류]", "[경고]", "[스크립트]", "[셰이더]"][clampi(error_type, 0, 3)]
		var msg := rationale if rationale != "" else code
		# 스크립트에서 난 오류면 엔진 내부 위치 대신 스크립트 위치를 보여준다
		var where := ""
		if not script_backtraces.is_empty() and script_backtraces[0].get_frame_count() > 0:
			where = "%s:%d" % [script_backtraces[0].get_frame_file(0).get_file(), script_backtraces[0].get_frame_line(0)]
		elif file.ends_with(".gd"):
			where = "%s:%d" % [file.get_file(), line]
		LogUtil._record("%s %s%s" % [tag, msg, "  (" + where + ")" if where != "" else ""])
