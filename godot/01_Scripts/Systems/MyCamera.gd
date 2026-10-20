extends Camera2D
class_name MyCamera
## 맵을 화면에 맞추는 카메라.
##
## ─── 왜 화면이 바뀔 때마다 다시 맞추나 ──────────────────────
## 예전엔 스테이지 로드 순간에 한 번만 위치/줌을 정했다. 하지만 실제 기기에선
## 게임 도중에도 화면이 바뀐다.
##   · 태블릿: Android 16(targetSdk 36)부터 600dp 이상 화면에선 세로 고정이
##     무시된다. iPadOS 26도 창 크기를 자유롭게 바꾼다. → 가로·분할 화면으로 실행
##   · 회전, 분할 화면, 폴더블 펼침, 시스템 바 숨김 → 창 크기가 실행 중에 바뀜
##   · 시작 직후엔 창/인셋 정보가 아직 0이거나 임시값인 경우가 있음
## 그래서 setup_map은 "맵 정보"만 기억하고, 실제 위치/줌은 _refit이
## 지금 화면 상태로 매번 다시 계산한다.
##
## ─── 줌 규칙 ────────────────────────────────────────────────
##   · 맵 JSON의 zoom > 0: 기획 줌을 그대로 쓴다. 단, 지금 화면에서 타일 영역
##     (padding 제외)이 잘리면 잘리지 않을 때까지만 줄인다.
##     기준 해상도(1080x1920)에선 기획 줌 그대로라 보이는 모습이 같다.
##   · zoom == 0: padding 포함 격자 전체가 화면에 들어오게 자동으로 맞춘다.
## 맵은 항상 화면 정중앙에 둔다. 노치·시스템 바·HUD는 위아래(좌우) 중
## 더 많이 가린 쪽 기준으로 대칭으로 비켜서, 기획 때의 중앙 배치를 유지한다.
## ─────────────────────────────────────────────────────────────

static var instance: MyCamera

## HUD가 가리는 높이 (기준 해상도 px). 메뉴 버튼(위)·체력바(아래)에 맵이 깔리지 않게 한다.
@export var hud_reserve_top := 120.0
@export var hud_reserve_bottom := 200.0

## 화면 상태 재확인 주기(초).
## size_changed 없이 안전 영역만 바뀌는 경우(시스템 바 토글, 인셋 늦게 도착)를 잡는다.
const RECHECK_INTERVAL := 0.25

var _has_map := false
var _grid_rect := Rect2()      # padding 포함 격자 전체 (월드 px)
var _content_rect := Rect2()   # padding 제외 타일 영역 — 반드시 보여야 하는 곳
var _design_zoom := 0.0
var _offset_px := Vector2.ZERO
var _margin := 1.0

var _last_signature: Array = []
var _recheck_left := 0.0


func _enter_tree():
	instance = self

func _ready() -> void:
	# 회전·분할 화면·창 크기 변경. 같은 프레임에 여러 번 올 수 있어 지연 호출로 모은다.
	get_viewport().size_changed.connect(_refit, CONNECT_DEFERRED)

func _process(delta: float) -> void:
	if not _has_map:
		return
	_recheck_left -= delta
	if _recheck_left > 0.0:
		return
	_recheck_left = RECHECK_INTERVAL
	if _screen_signature() != _last_signature:
		_refit()


# 맵 정보를 기억하고 지금 화면에 맞춰 위치와 줌을 "즉시" 설정
# width/height는 padding 포함 크기
func setup_map(tile_size_x: int, tile_size_y: int, width: int, height: int, zoom_f: float = 0, offset_px: Vector2 = Vector2.ZERO, padding: int = 0, margin: float = 1):
	var tile := Vector2(tile_size_x, tile_size_y)
	_grid_rect = Rect2(Vector2.ZERO, tile * Vector2(width, height))
	_content_rect = Rect2(tile * padding, tile * Vector2(width - padding * 2, height - padding * 2))
	_design_zoom = zoom_f
	_offset_px = offset_px
	_margin = margin
	_has_map = true
	_refit()


#region 화면 맞춤
func _refit() -> void:
	if not _has_map or not is_inside_tree():
		return

	var screen := get_viewport().get_visible_rect()
	var usable := _usable_rect()
	# 시작 직후 등 창 크기가 아직 0이면 건너뛴다. 크기가 잡히면 재확인에서 다시 맞춘다.
	if not usable.has_area():
		return
	_last_signature = _screen_signature()

	# 중앙 + offset
	var center := (_grid_rect.get_center() + _offset_px).round()

	# 맵을 화면 정중앙에 둔 채로 쓸 수 있는 반폭/반높이 (화면 px)
	var screen_center := screen.get_center()
	var half_avail := Vector2(
		minf(screen_center.x - usable.position.x, usable.end.x - screen_center.x),
		minf(screen_center.y - usable.position.y, usable.end.y - screen_center.y))

	var zoom_factor: float
	if _design_zoom > 0:
		zoom_factor = minf(_design_zoom, _fit_zoom(_content_rect, center, half_avail))
	else:
		zoom_factor = _fit_zoom(_grid_rect, center, half_avail)
	# 화면이 극단적으로 작아도 0 줌(역행렬 불가)은 만들지 않는다
	if is_nan(zoom_factor) or is_inf(zoom_factor) or zoom_factor <= 0.0:
		return

	zoom = Vector2(zoom_factor, zoom_factor)
	position = center

	print("cam setting - pos: ", position, ", zoom: ", zoom_factor, " (design: ", _design_zoom,
		"), offset: ", _offset_px, ", screen: ", screen.size, ", usable: ", usable)


## target(월드 rect)이 center 기준으로 half_avail(화면 px) 안에 들어가는 최대 줌
func _fit_zoom(target: Rect2, center: Vector2, half_avail: Vector2) -> float:
	# offset 때문에 맵이 중앙에서 벗어나 있어도 먼 쪽 끝까지 들어가야 한다
	var half_need := Vector2(
		maxf(center.x - target.position.x, target.end.x - center.x),
		maxf(center.y - target.position.y, target.end.y - center.y)) * _margin
	if half_need.x <= 0.0 or half_need.y <= 0.0:
		return INF
	return minf(half_avail.x / half_need.x, half_avail.y / half_need.y)


## 맵을 놓을 수 있는 화면 영역 (뷰포트 좌표). HUD와 노치·시스템 바를 뺀다.
func _usable_rect() -> Rect2:
	var usable := get_viewport().get_visible_rect()
	# HUD는 안전 영역이 아니라 화면 끝에 붙어 있으므로 화면 끝 기준으로 뺀다
	usable.position.y += hud_reserve_top
	usable.size.y -= hud_reserve_top + hud_reserve_bottom
	var safe := _safe_rect_in_viewport()
	if safe.has_area():
		usable = usable.intersection(safe)
	return usable


## 노치·펀치홀·시스템 바를 뺀 영역 (뷰포트 좌표). 모르면 빈 Rect2.
func _safe_rect_in_viewport() -> Rect2:
	# 데스크톱에선 "작업 표시줄을 뺀 모니터 영역"이 돌아와 창과 무관하다. 모바일에서만 쓴다.
	if not OS.has_feature("mobile"):
		return Rect2()
	var safe := Rect2(DisplayServer.get_display_safe_area())
	# 안드로이드는 창 인셋을 아직 못 받았으면 0 크기를 돌려준다
	if not safe.has_area():
		return Rect2()
	# 창 픽셀 → 뷰포트 좌표. 스트레치 배율과 검은 띠 여백이 이 변환에 들어 있다.
	return get_viewport().get_screen_transform().affine_inverse() * safe


## 이 값이 바뀌면 다시 맞춘다
func _screen_signature() -> Array:
	var vp := get_viewport()
	var safe := DisplayServer.get_display_safe_area() if OS.has_feature("mobile") else Rect2i()
	return [vp.get_visible_rect(), vp.get_screen_transform(), safe]
#endregion
