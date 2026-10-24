# LogOverlay.gd
# AutoLoad — 반드시 오토로드 목록 맨 위
## 개발용 — 화면 좌하단에 LogUtil 기록을 띄운다. 새 줄은 맨 아래에 붙고 오래된 줄은 위로 밀려난다.
##
## 오토로드 맨 위에 두는 이유: 여기서 ErrorLogger를 거는데, 그 뒤에 컴파일되는
## 오토로드(Config 등)에서 나는 스크립트 오류까지 받으려면 가장 먼저 떠야 한다.
extends CanvasLayer

## 출시 빌드에서 끄려면 false
const ENABLED := true

## 화면에 보일 최대 줄 수 (줄바꿈된 줄 기준)
const MAX_VISIBLE_LINES := 14
## 로그 상자 폭 (기준 해상도 px). 가로 화면에서도 화면 비율이 아니라 이 폭으로 좌하단에만 붙는다.
const BOX_WIDTH := 860.0
## 모든 UI(화면 전환 100 포함) 위
const LAYER := 128

var _label: Label
var _shown_version := -1


func _init() -> void:
	if not ENABLED:
		return
	OS.add_logger(LogUtil.ErrorLogger.new())


func _ready() -> void:
	layer = LAYER
	visible = ENABLED
	if not ENABLED:
		return
	# 설정창이 트리를 멈춰도 로그는 계속 갱신
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 게임 폰트는 손글씨 영문이라 한글·경로가 안 읽힌다. 기기 기본 글꼴을 쓴다.
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["sans-serif"])

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_content_margin_all(10)

	_label = Label.new()
	# 좌하단에 붙이고, 줄이 늘면 위로 자란다
	_label.anchor_left = 0.0
	_label.anchor_right = 0.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 16
	_label.offset_right = 16 + BOX_WIDTH
	_label.offset_top = -16
	_label.offset_bottom = -16
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.max_lines_visible = MAX_VISIBLE_LINES
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_stylebox_override("normal", bg)
	_label.visible = false
	add_child(_label)


func _process(_delta: float) -> void:
	if _label == null or LogUtil.version == _shown_version:
		return
	_shown_version = LogUtil.version
	_label.text = "\n".join(LogUtil.get_lines())
	# 넘치면 앞(오래된) 줄을 건너뛰어 최신 줄이 항상 맨 아래에 보이게 한다
	_label.lines_skipped = maxi(0, _label.get_line_count() - MAX_VISIBLE_LINES)
	_label.visible = _label.text != ""
