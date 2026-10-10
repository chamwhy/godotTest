# DeathHint.gd
## 플레이어가 죽어서 더 나아갈 방향이 없을 때 되돌리기 조작을 알려주는 안내.
##
## ─── 왜 전역 상태를 쓰지 않는가 ──────────────────────────────
## 이 게임의 죽음은 끝이 아니라 "되돌릴 수 있는 턴 결과"다. 그래서
## GameState를 건드리지 않고 플레이어 개체의 사망 플래그만 본다.
## 입력 체계가 PLAYING으로 유지돼야 더블 탭 되돌리기가 살아 있다.
## (GameState를 바꾸면 InputManager.check_input이 매 이벤트마다
##  제스처 상태를 버려서 더블 탭 인식 자체가 불가능해진다)
## ─────────────────────────────────────────────────────────────
extends Label

## 죽은 직후 띄우면 사망 연출을 덮는다. 한 박자 쉬고 띄운다.
const SHOW_DELAY := 1.0
const FADE_IN := 0.3
const FADE_OUT := 0.2

var _delay_timer: Timer
var _tween: Tween
var _shown := false


func _ready() -> void:
	modulate.a = 0.0
	visible = false

	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	_delay_timer.wait_time = SHOW_DELAY
	_delay_timer.timeout.connect(_fade_in)
	add_child(_delay_timer)

	# 턴이 끝날 때마다(정방향·되돌리기 공통) 다시 판정한다.
	ActionManager.turn_finished.connect(_refresh)
	# 리셋·홈·월드 이동은 모두 스테이지 로드를 거친다.
	StageDirector.stage_loaded.connect(_refresh)


## "지금 안내가 필요한가"를 판정하는 단 하나의 창구.
## 띄우는 조건과 지우는 조건을 따로 두면 반드시 어긋난다.
func _refresh() -> void:
	if _needs_hint():
		_arm()
	else:
		_disarm()


func _needs_hint() -> bool:
	var player: Player = PlayerRegistry.get_player()
	if player == null or not is_instance_valid(player):
		return false
	if not (player.is_dead or player.is_fallen):
		return false
	# 되돌릴 기록이 없으면 안내가 거짓말이 된다.
	return UndoManager.has_history()


func _arm() -> void:
	if _shown or not _delay_timer.is_stopped():
		return   # 이미 떠 있거나 띄우는 중
	_delay_timer.start()


func _disarm() -> void:
	_delay_timer.stop()
	if _shown:
		_fade_out()


func _fade_in() -> void:
	_shown = true
	_kill_tween()
	visible = true
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)


func _fade_out() -> void:
	_shown = false
	_kill_tween()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func(): visible = false)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
