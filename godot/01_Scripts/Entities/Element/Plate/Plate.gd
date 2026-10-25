extends Element
class_name Plate
## 발판. 막는 개체(플레이어·상자·고블린·고치·벽·장애물)가 그 위에 "멈춰" 있으면 눌린다.
## 스테이지의 모든 발판이 눌려 있어야(그리고 고치가 전부 깨져야) 클리어 포탈이 켜진다.
## 무게가 떠나면 바로 다시 꺼진다 — "누르고 있어야" 하는 기믹.
##
## ─── 언제 눌리나 ────────────────────────────────────────────
##   · 눌림: 그 칸에서 이동이 끝났을 때(element_settled). 지나가기만 하면 안 눌린다.
##           세게 민 상자가 발판을 넘어가 버리는 것도 퍼즐 재료다.
##   · 떼짐: 그 칸에서 무언가 나갔을 때(element_exited) 남은 무게가 없으면.
##           부서지거나(고치·장애물) 죽어서 맵에서 빠져도 나간 것으로 친다.
## 그래서 플레이어가 발판에서 포탈로 걸어가면, 발판을 떠나는 순간 포탈이 꺼져
## 혼자서는 열 수 없다.
## ─────────────────────────────────────────────────────────────

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var pressed := false
#endregion

#region 임시 그림 (발판 리소스가 생기면 AnimatedSprite2D로 교체)
const SIZE := 150.0
const SINK := 10.0          # 눌렸을 때 가라앉는 깊이(px)
const COLOR_UP := Color(0.86, 0.84, 0.78)
const COLOR_DOWN := Color(0.62, 0.6, 0.55)
const COLOR_LINE := Color(0.1, 0.1, 0.1)

var _shown_pressed := false
#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = false
	StageContext.register_plate(self)
	GridManager.element_settled.connect(_on_cell_event)
	GridManager.element_exited.connect(_on_cell_event)


## 지금 이 칸에 발판을 누르는 무게가 있는가
func has_weight() -> bool:
	for elm in GridManager.get_elements(cur_position):
		if elm != self and elm.in_map and elm.blocking():
			return true
	return false


func _on_cell_event(pos: Position, _elm: Element, tick: int) -> void:
	if not in_map or not pos.equals(cur_position): return
	var now := has_weight()
	if now == pressed: return
	pressed = now
	if now:
		ActionManager.record_new(self, tick, "press", {}, "release", {})
	else:
		ActionManager.record_new(self, tick, "release", {}, "press", {})
	StageContext.refresh_gate(tick)


## 스폰 직후 놓인 위치만으로 상태를 맞춘다. 연출 없이 즉시.
func sync_pressed() -> void:
	pressed = has_weight()
	_set_shown(pressed)


#region Anim
func _register_animations() -> void:
	super._register_animations()
	_anim_handlers["press"]   = _anim_press
	_anim_handlers["release"] = _anim_release

func _anim_press(tween: Tween, _data: Dictionary) -> void:
	tween.tween_callback(_set_shown.bind(true))

func _anim_release(tween: Tween, _data: Dictionary) -> void:
	tween.tween_callback(_set_shown.bind(false))

func _set_shown(v: bool) -> void:
	_shown_pressed = v
	queue_redraw()

func _draw() -> void:
	var sink := SINK if _shown_pressed else 0.0
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_DOWN if _shown_pressed else COLOR_UP
	box.border_color = COLOR_LINE
	box.set_border_width_all(6)
	box.set_corner_radius_all(18)
	draw_style_box(box, Rect2(Vector2(-SIZE, -SIZE) * 0.5 + Vector2(0, sink), Vector2(SIZE, SIZE - sink)))
#endregion


#region undo
func save_undo_state() -> Dictionary:
	var dict = super.save_undo_state()
	dict["pressed"] = pressed
	return dict

## 그림은 되돌리기 연출(press/release 역재생)이 맞춘다
func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	pressed = state.get("pressed", false)
#endregion
