extends Node
class_name TipContent

const FADE_TIME := 0.1
const SAVE_SECTION := "tip"

@export var tips: Dictionary[String, Control]

# Control별 진행 중인 트윈과 목표 상태 추적
var _tweens: Dictionary[Control, Tween] = {}
var _shown: Dictionary[Control, bool] = {}

var _cleared: Array[String] = []

static var instance: TipContent

func _ready() -> void:
	instance = self
	# 시작 시 전부 꺼진 상태로 초기화
	for tip in tips.values():
		if tip == null: continue
		tip.modulate.a = 0.0
		tip.visible = false
		_shown[tip] = false
	
	_cleared = []
	SaveManager.set_value(SAVE_SECTION, "cleared_tipList", _cleared)
	_cleared.assign(SaveManager.get_value(SAVE_SECTION, "cleared_tipList", []))


func show_tip(tip_name: String) -> void:
	if not tips.has(tip_name): return
	if _cleared.has(tip_name): 
		print(tip_name, ": 이미 본 tip임.")
		return
	else:
		_cleared.append(tip_name)
	
	GameManager.set_state(GameManager.GameState.TIP)
	SaveManager.set_value(SAVE_SECTION, "cleared_tipList", _cleared)
	
	close_all_tips()
	_tip_show(tips[tip_name])


func _tip_show(tip: Control) -> void:
	if tip == null: return
	if _shown.get(tip, false): return   # 이미 켜져 있음(또는 켜지는 중)

	_shown[tip] = true
	_kill_tween(tip)

	tip.visible = true
	
	print("show tip: ", tip)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tip, "modulate:a", 1.0, FADE_TIME)
	_tweens[tip] = tween


func _tip_hide(tip: Control) -> void:
	if tip == null: return
	if not _shown.get(tip, false): return   # 이미 꺼져 있음(또는 꺼지는 중)

	_shown[tip] = false
	_kill_tween(tip)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tip, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func(): tip.visible = false)
	_tweens[tip] = tween


func close_all_tips() -> void:
	for tip in tips.values():
		_tip_hide(tip)

func _kill_tween(tip: Control) -> void:
	var tween: Tween = _tweens.get(tip)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(tip)

#region 외부 입력

func _on_tip_pressed() -> void:
	InputManager.tip_pressed()

#endregion
