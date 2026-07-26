# AutoLoad - InputBuffer.gd
extends Node

## 턴 처리(이동/애니메이션) 중에 들어온 입력을 잠시 저장했다가,
## 다시 입력을 받을 수 있게 되는 순간 자동으로 흘려보내는 버퍼.
##
## 흐름: InputManager --push_*()--> InputBuffer --signal--> ActionManager
## 소비자(ActionManager 등)는 InputManager가 아니라 이쪽 시그널에 연결한다.

signal action_input(dir: Position)
signal back_input()

## 버퍼 유효 시간(초). 잠금이 풀렸을 때 이 시간 안에 들어온 입력만 재생된다.
## 0.15~0.25 사이가 무난. 너무 크면 "손 떼도 계속 움직이는" 느낌이 난다.
const BUFFER_TIME := 0.20

## 잠금 해제 직후 곧바로 emit하지 않고 한 프레임 미룰지 여부.
## 애니메이션 완료 콜백 안에서 unlock()을 호출하는 구조라면 true가 안전하다.
const DEFERRED_FLUSH := true

enum Kind { NONE, ACTION, BACK }

var _kind: Kind = Kind.NONE
var _dir: Position = null
var _stamp_ms: int = 0

## 중첩 잠금 지원(애니메이션 + 컷신 등이 동시에 잠글 수 있게)
var _lock_count: int = 0

var is_locked: bool:
	get:
		return _lock_count > 0

var has_buffered: bool:
	get:
		return _kind != Kind.NONE


#region 입력 주입 (InputManager가 호출)
func push_action(dir: Position) -> void:
	if is_locked:
		_store(Kind.ACTION, dir)
	else:
		action_input.emit(dir)


func push_back() -> void:
	if is_locked:
		_store(Kind.BACK, null)
	else:
		back_input.emit()

#endregion


#region 잠금 제어 (ActionManager가 호출)
func lock() -> void:
	_lock_count += 1


func unlock() -> void:
	_lock_count = max(_lock_count - 1, 0)
	if _lock_count > 0:
		return
	if DEFERRED_FLUSH:
		_flush.call_deferred()
	else:
		_flush()


## 맵 전환, 게임오버, 일시정지 해제 등 상태가 끊길 때 호출.
func reset() -> void:
	_lock_count = 0
	clear()


func clear() -> void:
	_kind = Kind.NONE
	_dir = null
	_stamp_ms = 0
#endregion


#region 내부
func _store(kind: Kind, dir: Position) -> void:
	# 슬롯 1개짜리 버퍼: 새 입력이 오면 이전 입력을 덮어쓴다.
	# (연타 시 "가장 마지막 의도"만 살아남게 하는 게 퍼즐 게임에서 가장 자연스럽다)
	_kind = kind
	_dir = dir
	_stamp_ms = Time.get_ticks_msec()


func _flush() -> void:
	if _kind == Kind.NONE:
		return
	# 잠금 해제 후 flush가 늦게 돌아오는 사이에 다시 잠겼을 수 있음
	if is_locked:
		return

	var kind := _kind
	var dir := _dir
	var elapsed := (Time.get_ticks_msec() - _stamp_ms) / 1000.0
	clear()

	if elapsed > BUFFER_TIME:
		return

	match kind:
		Kind.ACTION:
			action_input.emit(dir)
		Kind.BACK:
			back_input.emit()
#endregion
