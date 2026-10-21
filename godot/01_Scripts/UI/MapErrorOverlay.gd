# MapErrorOverlay.gd
## 개발용 — 맵 읽기·생성이 실패하면 화면을 빨갛게 덮고 이유를 적는다.
##
## 실패가 이어질수록(리셋·월드 이동으로 다시 로드해도 또 실패) 빨간색이 진해진다.
## 한 번이라도 끝까지 성공하면 바로 사라진다.
##
## ─── 왜 "먼저 빨갛게" 하나 ──────────────────────────────────
## StageDirector는 로드를 시작할 때 begin()으로 일단 빨갛게 칠하고,
## 끝까지 무사히 갔을 때만 succeed()로 지운다. 그래서 이유를 아는 실패(fail)뿐 아니라
## 스크립트 오류로 load_stage가 중간에 끊긴 경우에도 화면이 빨갛게 남는다.
## 이 스크립트는 엔진 클래스만 쓴다. 게임 스크립트를 참조하면 정작 알려야 할 때
## 같은 컴파일 오류에 함께 엮일 수 있다.
## ─────────────────────────────────────────────────────────────
extends CanvasLayer
class_name MapErrorOverlay

## 출시 빌드에서 끄려면 false
const ENABLED := true

## 게임 UI(1)·엔딩(50) 위, 화면 전환(100) 아래
const LAYER := 90

## 빨간 덮개 불투명도: 첫 실패 → 실패가 이어질 때마다 더함 → 최대
const FIRST_ALPHA := 0.35
const STEP_ALPHA := 0.15
const MAX_ALPHA := 0.8

var _tint: ColorRect
var _label: Label
var _fail_streak := 0


func _init() -> void:
	layer = LAYER
	visible = false

	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

	# 게임 폰트는 손글씨 영문이라 한글·경로가 안 읽힌다. 기기 기본 글꼴을 쓴다.
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["sans-serif"])

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.offset_left = 40
	_label.offset_right = -40
	_label.offset_top = 160     # 메뉴 버튼 아래
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 12)
	add_child(_label)


## 로드 시작. succeed()가 불리기 전까진 실패로 본다.
func begin(what: String) -> void:
	if not ENABLED:
		return
	_fail_streak += 1
	_tint.color = Color(1, 0, 0, minf(FIRST_ALPHA + STEP_ALPHA * (_fail_streak - 1), MAX_ALPHA))
	_label.text = "맵 로드가 끝나지 않음: %s\n(스크립트 오류로 중간에 멈춘 것 — 로그 확인)" % what
	visible = true


## 이유를 아는 실패. 화면은 begin()에서 이미 빨갛다. 이유 글자만 바꾼다.
func fail(reason: String) -> void:
	if not ENABLED:
		return
	_label.text = reason
	push_error("MapErrorOverlay: " + reason)


func succeed() -> void:
	_fail_streak = 0
	visible = false
