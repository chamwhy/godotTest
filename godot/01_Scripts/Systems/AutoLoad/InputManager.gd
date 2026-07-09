# AutoLoad - InputManager.gd
extends Node

signal action_input(dir: Position)
signal back_input()
signal start_game()

var can_interact := false

#region Swipe/Tap 설정
const SWIPE_MIN_DISTANCE := 50.0
const SWIPE_MAX_TIME := 0.5
const TAP_MAX_DISTANCE := 20.0
const DOUBLE_TAP_TIME := 0.25       # 이 시간 안에 두 번 탭하면 더블 탭
const DOUBLE_TAP_DISTANCE := 100.0  # 두 탭 위치가 이 거리 안이어야 더블 탭

var _touch_start_pos := Vector2.ZERO
var _touch_start_time := 0.0
var _touching := false

var _last_tap_pos := Vector2.ZERO
var _pending_tap := false           # 싱글 탭 확정 대기 중인지
var _tap_timer: Timer
#endregion

func _ready() -> void:
	can_interact = true
	GameManager.set_state(GameManager.GameState.MAIN_MENU)
	
	# 싱글 탭 확정용 타이머
	_tap_timer = Timer.new()
	_tap_timer.one_shot = true
	_tap_timer.wait_time = DOUBLE_TAP_TIME
	_tap_timer.timeout.connect(_on_tap_timer_timeout)
	add_child(_tap_timer)

func _input(event: InputEvent) -> void:
	check_input(event)

func check_input(event: InputEvent) -> void:
	if can_interact:
		if GameManager.cur_state == GameManager.GameState.PLAYING:
			input_playing()
			input_playing_touch(event)   # ← 터치 처리 추가
		elif GameManager.cur_state == GameManager.GameState.MAIN_MENU:
			input_main_menu(event)
		elif GameManager.cur_state == GameManager.GameState.GAME_OVER:
			input_gameover()

#region GameStateInput
func input_main_menu(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton \
	or event is InputEventJoypadButton or event is InputEventScreenTouch:  # ← 터치도 시작 가능
		if event.pressed:
			emit_signal("start_game")
			GameManager.set_state(GameManager.GameState.PLAYING)

func input_playing() -> void:
	if Input.is_action_just_pressed("back"):
		emit_signal("back_input")
	elif Input.is_action_just_pressed("move_up"):
		emit_signal("action_input", Position.UP())
	elif Input.is_action_just_pressed("move_down"):
		emit_signal("action_input", Position.DOWN())
	elif Input.is_action_just_pressed("move_left"):
		emit_signal("action_input", Position.LEFT())
	elif Input.is_action_just_pressed("move_right"):
		emit_signal("action_input", Position.RIGHT())
	elif Input.is_action_just_pressed("interaction"):
		emit_signal("action_input", Position.ZERO())

func input_playing_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# 첫 손가락만 추적 (멀티터치 무시)
			if event.index == 0:
				_touching = true
				_touch_start_pos = event.position
				_touch_start_time = Time.get_ticks_msec() / 1000.0
		else:
			if event.index == 0 and _touching:
				_touching = false
				_process_swipe(event.position)

func _process_swipe(end_pos: Vector2) -> void:
	var delta: Vector2 = end_pos - _touch_start_pos
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _touch_start_time
	var distance: float = delta.length()
	
	# 탭 판정
	if distance < TAP_MAX_DISTANCE:
		_handle_tap(end_pos)
		return
	
	if elapsed > SWIPE_MAX_TIME or distance < SWIPE_MIN_DISTANCE:
		return
	
	# 스와이프가 들어오면 대기 중인 탭은 취소 (탭 후 바로 스와이프하는 경우)
	_cancel_pending_tap()
	
	if abs(delta.x) > abs(delta.y):
		if delta.x > 0:
			emit_signal("action_input", Position.RIGHT())
		else:
			emit_signal("action_input", Position.LEFT())
	else:
		if delta.y > 0:
			emit_signal("action_input", Position.DOWN())
		else:
			emit_signal("action_input", Position.UP())


func _handle_tap(pos: Vector2) -> void:
	if _pending_tap and pos.distance_to(_last_tap_pos) < DOUBLE_TAP_DISTANCE:
		# 더블 탭 → 되돌리기
		_cancel_pending_tap()
		emit_signal("back_input")
	else:
		# 첫 탭 → 더블 탭 대기 시작
		_pending_tap = true
		_last_tap_pos = pos
		_tap_timer.start()


func _on_tap_timer_timeout() -> void:
	if _pending_tap:
		# 시간 내에 두 번째 탭이 안 옴 → 싱글 탭(상호작용) 확정
		_pending_tap = false
		emit_signal("action_input", Position.ZERO())


func _cancel_pending_tap() -> void:
	_pending_tap = false
	_tap_timer.stop()

func input_gameover() -> void:
	pass
#endregion
