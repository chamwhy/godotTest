# AutoLoad - InputManager.gd
extends Node
## 전역 입력 매니저.
##
## 키보드/게임패드는 이벤트 기반으로, 터치는 제스처 인식 후 동일한 액션으로 변환한다.
##   · 스와이프     → 이동
##   · 길게 누르기  → 상호작용
##   · 더블 탭      → 되돌리기

signal start_game()

var can_interact := false

#region 터치 제스처 튜닝값
const SWIPE_MIN_DISTANCE := 50.0    # 이동으로 인정할 최소 거리(px)
const SWIPE_MAX_TIME := 0.5         # 이 시간을 넘긴 드래그는 스와이프로 보지 않음
const TAP_MAX_DISTANCE := 20.0      # 이 안에서 끝나면 제자리 탭
const DOUBLE_TAP_TIME := 0.25       # 이 시간 안에 두 번 탭하면 더블 탭
const DOUBLE_TAP_DISTANCE := 100.0  # 두 탭 위치가 이 거리 안이어야 더블 탭
const LONG_PRESS_TIME := 0.4        # 이 시간 이상 누르면 상호작용
const LONG_PRESS_MAX_MOVE := 20.0   # 누르는 동안 이만큼 움직이면 롱프레스 취소
#endregion

const UI_BLOCK_GROUP := "ui_blocker"
const PRIMARY_FINGER := 0

#region 터치 상태
var _touch_active := false      # 유효한 제스처를 추적 중
var _touch_blocked := false     # UI 위에서 시작 → 이번 제스처 전체 무시
var _long_press_fired := false  # 이번 제스처가 롱프레스로 이미 소비됨
var _touch_start_pos := Vector2.ZERO
var _touch_start_time := 0.0
var _long_press_timer: Timer

var _pending_tap := false       # 두 번째 탭을 기다리는 중
var _last_tap_pos := Vector2.ZERO
var _tap_timer: Timer
#endregion


#region 초기화
func _ready() -> void:
	_long_press_timer = _make_timer(LONG_PRESS_TIME, _on_long_press_timeout)
	_tap_timer = _make_timer(DOUBLE_TAP_TIME, _on_tap_timer_timeout)
	can_interact = true
	GameManager.set_state(GameManager.GameState.MAIN_MENU)


func _make_timer(wait: float, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait
	timer.timeout.connect(callback)
	add_child(timer)
	return timer
#endregion


#region 진입점 / 상태 라우팅
func _unhandled_input(event: InputEvent) -> void:
	check_input(event)


func check_input(event: InputEvent) -> void:
	if not can_interact:
		_reset_touch()
		_cancel_pending_tap()
		return

	# 게임 도중 상태가 바뀌면 진행 중이던 제스처는 버린다
	if GameManager.cur_state != GameManager.GameState.PLAYING:
		_reset_touch()
		_cancel_pending_tap()

	match GameManager.cur_state:
		GameManager.GameState.PLAYING:
			_handle_playing(event)
		GameManager.GameState.TIP:
			_handle_confirm_screen(event, _close_tip)
		GameManager.GameState.MAIN_MENU:
			_handle_confirm_screen(event, _begin_game)
		GameManager.GameState.GAME_OVER:
			pass

#region 외부입력

func start_menu_pressed() -> void:
	if GameManager.cur_state == GameManager.GameState.MAIN_MENU:
		_begin_game()

func tip_pressed() -> void:
	if GameManager.cur_state == GameManager.GameState.TIP:
		_close_tip()
#endregion


## 아무 입력이나 받아 넘어가는 화면(메인 메뉴, 팁) 공통 처리
func _handle_confirm_screen(event: InputEvent, on_confirm: Callable) -> void:
	if _is_confirm_press(event):
		on_confirm.call()


func _is_confirm_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton \
	or event is InputEventJoypadButton \
	or event is InputEventScreenTouch:
		return event.pressed
	return false


func _begin_game() -> void:
	start_game.emit()
	GameManager.set_state(GameManager.GameState.PLAYING)


func _close_tip() -> void:
	TipContent.instance.close_all_tips()
	GameManager.set_state(GameManager.GameState.PLAYING)
#endregion


#region 플레이 중 입력
func _handle_playing(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	else:
		_handle_action_keys(event)


func _handle_action_keys(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("back"):
		InputBuffer.push_back()
	elif event.is_action_pressed("move_up"):
		InputBuffer.push_action(Position.UP())
	elif event.is_action_pressed("move_down"):
		InputBuffer.push_action(Position.DOWN())
	elif event.is_action_pressed("move_left"):
		InputBuffer.push_action(Position.LEFT())
	elif event.is_action_pressed("move_right"):
		InputBuffer.push_action(Position.RIGHT())
	elif event.is_action_pressed("interaction"):
		InputBuffer.push_action(Position.ZERO())
#endregion


#region 터치 제스처 인식
func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.index != PRIMARY_FINGER:
		return
	if event.pressed:
		_touch_begin(event.position)
	else:
		_touch_end(event.position)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != PRIMARY_FINGER or not _touch_active or _long_press_fired:
		return
	# 손가락이 흔들린 게 아니라 실제로 끌었다면 롱프레스는 취소
	if event.position.distance_to(_touch_start_pos) > LONG_PRESS_MAX_MOVE:
		_long_press_timer.stop()


func _touch_begin(pos: Vector2) -> void:
	_reset_touch()
	if _is_over_ui(pos):
		_touch_blocked = true
		_cancel_pending_tap()   # 메뉴 열면서 이전 탭이 되돌리기로 확정되는 것 방지
		return
	_touch_active = true
	_touch_start_pos = pos
	_touch_start_time = _now()
	_long_press_timer.start()


func _touch_end(pos: Vector2) -> void:
	if _touch_blocked or not _touch_active:
		_reset_touch()
		return

	var consumed := _long_press_fired
	var start_pos := _touch_start_pos
	var elapsed := _now() - _touch_start_time
	_reset_touch()

	if consumed:
		return                      # 롱프레스로 이미 처리된 제스처
	if _is_over_ui(pos):
		_cancel_pending_tap()
		return                      # UI 위에서 손을 뗌
	_resolve_gesture(start_pos, pos, elapsed)


func _resolve_gesture(start_pos: Vector2, end_pos: Vector2, elapsed: float) -> void:
	var delta: Vector2 = end_pos - start_pos
	var distance: float = delta.length()

	if distance < TAP_MAX_DISTANCE:
		_handle_tap(end_pos)
		return

	if elapsed > SWIPE_MAX_TIME or distance < SWIPE_MIN_DISTANCE:
		return                      # 너무 느리거나 짧은 드래그 → 무시

	# 탭 직후 스와이프한 경우, 대기 중이던 탭은 버린다
	_cancel_pending_tap()

	if absf(delta.x) > absf(delta.y):
		InputBuffer.push_action(Position.RIGHT() if delta.x > 0 else Position.LEFT())
	else:
		InputBuffer.push_action(Position.DOWN() if delta.y > 0 else Position.UP())


func _handle_tap(pos: Vector2) -> void:
	if _pending_tap and pos.distance_to(_last_tap_pos) < DOUBLE_TAP_DISTANCE:
		_cancel_pending_tap()
		InputBuffer.push_back()     # 더블 탭 → 되돌리기
	else:
		_pending_tap = true         # 첫 탭 → 두 번째 탭 대기
		_last_tap_pos = pos
		_tap_timer.start()


func _on_tap_timer_timeout() -> void:
	_pending_tap = false            # 두 번째 탭이 안 옴 → 싱글 탭은 무동작


func _cancel_pending_tap() -> void:
	_pending_tap = false
	if _tap_timer != null:
		_tap_timer.stop()


func _on_long_press_timeout() -> void:
	if not _touch_active or _long_press_fired:
		return
	_long_press_fired = true
	_cancel_pending_tap()           # 롱프레스 중이면 이전 탭은 무효
	InputBuffer.push_action(Position.ZERO())


func _reset_touch() -> void:
	_touch_active = false
	_touch_blocked = false
	_long_press_fired = false
	if _long_press_timer != null:
		_long_press_timer.stop()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
#endregion


#region UI 유틸
func _is_over_ui(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group(UI_BLOCK_GROUP):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		# CanvasLayer / 뷰포트 스케일까지 반영된 실제 화면상 사각형
		var rect: Rect2 = control.get_global_transform_with_canvas() \
			* Rect2(Vector2.ZERO, control.size)
		if rect.has_point(pos):
			return true
	return false
#endregion
