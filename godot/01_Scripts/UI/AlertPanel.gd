extends Control
class_name AlertPanel
## 예/아니오 확인 창. 재사용 가능.
## 씬 구성:
##   AlertPanel (Control, Full Rect, Mouse Filter = Stop)  ← 뒤쪽 클릭 차단
##     Dim           : ColorRect (Full Rect, 반투명 검정)   (선택)
##     %MessageLabel : Label
##     %YesButton    : Button   ("예")
##     %NoButton     : Button   ("아니오")
##
## 사용:  var ok := await alert.ask("리셋 하시겠습니까?")

signal answered(confirmed: bool)

## 나타나기/사라지기 애니메이션 시간(초)
@export var fade_duration := 0.15

@onready var _label: Label = %MessageLabel
@onready var _yes: BaseButton = %YesButton
@onready var _no: BaseButton = %NoButton

var _active := false


func _ready() -> void:
	# 설정/게임이 일시정지여도 동작해야 한다
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	modulate.a = 0.0

	_yes.pressed.connect(_answer.bind(true))
	_no.pressed.connect(_answer.bind(false))


## 확인 창을 띄우고 선택할 때까지 기다린다. 예=true, 아니오=false.
func ask(message: String) -> bool:
	if _active:
		return false          # 중복 오픈 방지

	_label.text = message
	_active = true

	await _fade_in()
	_no.grab_focus()          # 기본 포커스는 안전한 '아니오'

	return await answered


func _answer(confirmed: bool) -> void:
	if not _active:
		return

	_active = false
	await _fade_out()
	answered.emit(confirmed)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_cancel"):
		_answer(false)
		get_viewport().set_input_as_handled()


#region 애니메이션

func _fade_in() -> void:
	show()

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, fade_duration)
	await tw.finished


func _fade_out() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tw.finished

	hide()

#endregion
