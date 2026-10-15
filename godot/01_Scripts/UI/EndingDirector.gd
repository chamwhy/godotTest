# EndingDirector.gd
## 마지막 스테이지를 깼을 때의 엔딩 연출 전체를 혼자 책임진다.
##
##   ① 화면을 검게 디졸브 아웃
##   ② 다시 디졸브 인 → 클리어 영상 재생
##   ③ 크레딧이 위로 흐르고, 마지막 줄이 화면 정중앙에 오면 멈춘다
##      (화면을 누르고 있는 동안은 2배 속도)
##   ④ 정중앙에 멈춘 뒤 다시 누르면 처음 게임 시작 화면으로
##
## 턴 파이프라인은 건드리지 않는다. 스테이지 전환(허브 복귀)은 평소대로
## 진행되고, 이 CanvasLayer가 그 위를 덮는다. 그래서 엔딩 때문에
## 게임 로직이 달라지는 지점이 없다.
extends CanvasLayer

## 이 스테이지를 깨면 엔딩이다.
@export var final_world := 2
@export var final_stage := 10

@export var clear_movie: Control    ## 클리어 영상 자리
@export var credits_root: Control   ## 스크롤이 보이는 창(클리핑 영역)
@export var scroller: Control       ## 실제로 움직이는 컨테이너
@export var credits_label: Label    ## 크레딧 본문
@export var coming_soon: Control    ## 마지막 줄. 이게 정중앙에 오면 멈춘다

## TODO: 클리어 영상이 아직 없다. 지금은 이 시간만큼 플레이스홀더를 보여준다.
## VideoStreamPlayer를 ClearMovie 아래에 넣고 _play_clear_movie만 바꾸면 된다.
@export var clear_movie_dur := 3.0

## 크레딧 속도는 글자량에 따라 체감이 크게 달라진다. 에디터에서 바로 조절한다.
@export var scroll_speed := 110.0    ## px/초
@export var fast_multiplier := 2.0   ## 누르고 있을 때

## TODO: 역할별 이름을 채워야 한다. 지금은 이름 없이 역할만 올라간다.
const CREDITS_TEXT := """MINOTAUR CAN THINK


T H A N K   Y O U
F O R   P L A Y I N G


WORLD 1
THE MAZE

WORLD 2
THE COCOON


GAME DESIGN

LEVEL DESIGN

PROGRAMMING

ART

SOUND


more worlds
are still being built
"""

enum Phase {
	IDLE,       ## 엔딩 아님
	MOVIE,      ## 디졸브 + 클리어 영상
	CREDITS,    ## 크레딧 흐르는 중
	WAIT_EXIT,  ## 마지막 줄이 정중앙. 터치 기다림
}

var _phase: Phase = Phase.IDLE
var _pressing := false
## 스크롤을 끝낸 그 손가락으로 바로 넘어가지 않게, 한 번 떼기를 요구한다.
var _needs_release := false
## 마지막 스테이지를 깼다. 다음 스테이지 로드가 끝나면 엔딩을 시작한다.
var _pending := false


func _ready() -> void:
	visible = false
	if credits_label:
		credits_label.text = CREDITS_TEXT
	StageContext.stage_completed.connect(_on_stage_completed)
	StageDirector.stage_loaded.connect(_on_stage_loaded)


func _on_stage_completed(world_id: int, stage_id: int) -> void:
	if _phase != Phase.IDLE or _pending: return
	if world_id != final_world or stage_id != final_stage: return

	# 턴 도중(ClearPortal.move_map)에 불린다. 입력은 지금 바로 막는다.
	InputManager.can_interact = false
	_pending = true


## 클리어 연출과 허브 복귀가 다 끝난 뒤에 엔딩을 시작한다.
## 턴 도중에 끼어들면 디졸브와 클리어 연출이 겹치고,
## 허브 로드가 페이드 중간에 터져 나온다.
func _on_stage_loaded() -> void:
	if not _pending: return
	_pending = false
	_run()


func _run() -> void:
	_phase = Phase.MOVIE
	_pressing = false
	_needs_release = false
	AudioManager.play_sfx("clear_world", {"duck": 0})

	# ① 검은 화면으로
	await SceneTransition.fade_out()

	# 인게임 HUD를 치우고 엔딩 화면을 올린다
	if GameStarter.instance:
		GameStarter.instance.set_hud_visible(false)
	visible = true
	clear_movie.visible = true
	credits_root.visible = false
	_reset_scroll()

	# ② 다시 인 → 클리어 영상
	await SceneTransition.fade_in()
	await _play_clear_movie()

	# ③ 크레딧
	clear_movie.visible = false
	credits_root.visible = true
	_phase = Phase.CREDITS


## TODO: 실제 영상으로 교체. 지금은 플레이스홀더를 정해진 시간만 보여준다.
func _play_clear_movie() -> void:
	await get_tree().create_timer(clear_movie_dur).timeout


func _reset_scroll() -> void:
	# 화면 아래에서 출발한다
	scroller.position.y = credits_root.size.y


func _process(delta: float) -> void:
	if _phase != Phase.CREDITS: return

	var speed := scroll_speed
	if _pressing:
		speed *= fast_multiplier
	scroller.position.y -= speed * delta

	var limit := _scroll_limit()
	if scroller.position.y <= limit:
		scroller.position.y = limit
		_phase = Phase.WAIT_EXIT
		# 지금 누르고 있던 손가락은 무효. 떼고 다시 눌러야 넘어간다.
		_needs_release = _pressing


## 마지막 줄의 중심이 화면 정중앙에 오는 scroller.position.y.
## coming_soon은 scroller의 자식이라 위치가 scroller 기준이므로,
## 레이아웃이 끝난 뒤의 실측값을 매 프레임 다시 읽는다.
func _scroll_limit() -> float:
	var screen_center := credits_root.size.y * 0.5
	var line_center := coming_soon.position.y + coming_soon.size.y * 0.5
	return screen_center - line_center


func _input(event: InputEvent) -> void:
	if _phase == Phase.IDLE: return

	if event is InputEventScreenTouch:
		_set_pressing(event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_pressing(event.pressed)
	elif event is InputEventKey and not event.echo:
		_set_pressing(event.pressed)   # PC에서 확인할 수 있도록


func _set_pressing(pressed: bool) -> void:
	if pressed:
		_pressing = true
		if _phase == Phase.WAIT_EXIT and not _needs_release:
			_exit_to_title()
	else:
		_pressing = false
		_needs_release = false


func _exit_to_title() -> void:
	_phase = Phase.IDLE
	await SceneTransition.fade_out()

	visible = false
	credits_root.visible = false
	clear_movie.visible = false
	if GameStarter.instance:
		GameStarter.instance.return_to_title()

	await SceneTransition.fade_in()
	InputManager.can_interact = true
