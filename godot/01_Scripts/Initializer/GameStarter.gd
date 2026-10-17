extends Node
class_name GameStarter

## 엔딩처럼 "처음 화면으로 되돌려야" 하는 쪽이 찾아올 수 있게 해둔다.
static var instance: GameStarter

@export var start_menu: Control
@export var hp_bar: Control
@export var develop := false
@export var start_world := 0
@export var start_stage := 0
const tween_dur: float = 0.3
const SAVE_SECTION := "start"

var _first := true
var wipe := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instance = self
	if wipe:
		SaveManager.wipe()
	
	_first = SaveManager.get_value(SAVE_SECTION, "first_game", true)
	SaveManager.set_value(SAVE_SECTION, "first_game", false)
	
	AudioManager.play_bgm()
	if develop:
		StageDirector.load_stage(start_world,start_stage)
	else:
		if _first:
			StageDirector.load_stage(1,1)
		else:
			StageDirector.load_stage(0,0)
	
	InputManager.start_game.connect(_start_game)

func _start_game() -> void:
	# enter_stage는 StageDirector.load_stage가 울린다 (리셋·홈·월드이동 포함)
	var tween = create_tween()
	tween.tween_property(start_menu, "modulate", Color(1, 1, 1, 0), tween_dur)
	tween.finished.connect(func():
		start_menu.visible = false
	)
	var tween2 = create_tween()
	tween2.tween_property(hp_bar, "modulate", Color(1, 1, 1, 1), tween_dur)


## 인게임 HUD(체력바·메뉴 버튼)를 보이거나 감춘다. 엔딩 연출용.
func set_hud_visible(v: bool) -> void:
	if hp_bar:
		hp_bar.visible = v


## 엔딩이 끝난 뒤 처음 게임 시작 화면으로 되돌린다.
## 다음 입력에서 _start_game이 다시 돌아 평소의 시작 흐름을 탄다.
func return_to_title() -> void:
	if hp_bar:
		hp_bar.visible = true
		hp_bar.modulate = Color(1, 1, 1, 0)
	if start_menu:
		start_menu.visible = true
		start_menu.modulate = Color(1, 1, 1, 1)
	StageDirector.load_stage(0, 0)
	GameManager.set_state(GameManager.GameState.MAIN_MENU)
