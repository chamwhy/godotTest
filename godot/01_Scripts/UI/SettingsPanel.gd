# SettingsPanel.gd
extends Control

## 설정 UI. 씬에 아래 노드를 만들고 "Access as Unique Name"(%)을 켜둘 것.
##   %MasterSlider : HSlider (min 0, max 1, step 0.01)
##   %BgmSlider    : HSlider
##   %SfxSlider    : HSlider
##   %CloseButton  : Button   (선택)
##   %MasterValue  : Label    (선택, "80%" 표시용)
##   %BgmValue     : Label    (선택)
##   %SfxValue     : Label    (선택)
##
## 여는 쪽:  $SettingsPanel.open()
## 우측 상단 버튼의 pressed 시그널에 연결하면 된다.

signal closed()

## 설정을 여는 동안 게임을 멈출지
@export var pause_game := true
## 슬라이더를 놓을 때 미리듣기 SFX를 재생할지
@export var preview_sfx_key := "menu_select"

@onready var _master: HSlider = %MasterSlider
@onready var _bgm: HSlider = %BgmSlider
@onready var _sfx: HSlider = %SfxSlider

var _syncing := false


func _ready() -> void:
	# 일시정지 중에도 조작 가능해야 한다
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	for slider: HSlider in [_master, _bgm, _sfx]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01

	_master.value_changed.connect(_on_master_changed)
	_bgm.value_changed.connect(_on_bgm_changed)
	_sfx.value_changed.connect(_on_sfx_changed)

	# 슬라이더에서 손을 뗐을 때만 미리듣기 (드래그 중 연타 방지)
	_sfx.drag_ended.connect(_on_sfx_drag_ended)

	if has_node("%CloseButton"):
		(get_node("%CloseButton") as Button).pressed.connect(close)

	# 다른 경로로 볼륨이 바뀌어도 슬라이더가 따라오도록
	AudioManager.volume_changed.connect(_on_volume_changed_externally)

	_sync_from_manager()


func open() -> void:
	_sync_from_manager()
	show()
	if pause_game:
		get_tree().paused = true
	# 설정 중에는 게임 입력이 먹으면 안 된다
	if InputManager != null:
		InputManager.can_interact = false


func close() -> void:
	hide()
	if pause_game:
		get_tree().paused = false
	if InputManager != null:
		InputManager.can_interact = true
	SaveManager.flush()   # 디바운스를 기다리지 않고 즉시 확정
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


#region 슬라이더 -> 매니저
func _on_master_changed(v: float) -> void:
	if _syncing: return
	AudioManager.set_master_volume(v)
	_update_label("%MasterValue", v)

func _on_bgm_changed(v: float) -> void:
	if _syncing: return
	AudioManager.set_bgm_volume(v)
	_update_label("%BgmValue", v)

func _on_sfx_changed(v: float) -> void:
	if _syncing: return
	AudioManager.set_sfx_volume(v)
	_update_label("%SfxValue", v)

func _on_sfx_drag_ended(value_changed: bool) -> void:
	if value_changed and AudioManager.has_sfx(preview_sfx_key):
		AudioManager.play_sfx(preview_sfx_key, {"bypass_dedup": true})
#endregion


#region 매니저 -> 슬라이더
func _on_volume_changed_externally(_kind: StringName, _value: float) -> void:
	if not visible:
		return
	_sync_from_manager()


func _sync_from_manager() -> void:
	_syncing = true
	_master.value = AudioManager.get_volume(&"master")
	_bgm.value = AudioManager.get_volume(&"bgm")
	_sfx.value = AudioManager.get_volume(&"sfx")
	_syncing = false

	_update_label("%MasterValue", _master.value)
	_update_label("%BgmValue", _bgm.value)
	_update_label("%SfxValue", _sfx.value)


func _update_label(path: String, v: float) -> void:
	if not has_node(path):
		return
	(get_node(path) as Label).text = "%d%%" % roundi(v * 100.0)
#endregion
