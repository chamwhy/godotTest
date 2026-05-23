# Entity.gd
extends Node2D
class_name Entity



@onready var sprite2D = get_child(0) as Sprite2D

## --- Private Variables ---
var cur_position: Position = Position.ZERO()  # 현재 위치

var size = 100

## --- Initialization ---
#func _ready():
	# 모든 엔티티는 준비될 때 씬 트리에 따라 자신의 격자 위치를 시각적 위치로 설정합니다.
	#update_visual_position()

# test 용
func _ready() -> void:
	init()
	reset()

func init() -> void:
	_register_animations()

func reset() -> void:
	pass

func move_to_pos(pos: Position):
	print("move to pos!!!!")
	cur_position = pos
	print("move to ", pos.to_str(), Position.position_to_world(pos))
	position = Position.position_to_world(pos)
	


func apply_data(data: Dictionary):
	move_to_pos(Position.new(
		data.get("x", 0), 
		data.get("y", 0)
	))
	


#region Anim
signal animated(anim_name: String, data: Dictionary)

# action 이름 → Callable 등록소
var _anim_handlers: Dictionary = {}

# 자식이 override해서 자기 action 등록
func _register_animations() -> void:
	_anim_handlers["fade"] = _anim_fade

func on_animate(action: String, data: Dictionary) -> Signal:
	print("on_animate 호출됨: ", action)
	print("handlers: ", _anim_handlers.keys())  # ← 등록된 키 목록
	var tween = create_tween()
	tween.pause()
	animated.emit(action, data)
	if _anim_handlers.has(action):
		_anim_handlers[action].call(tween, data)
	else:
		push_warning("animation: 등록되지 않은 action → %s" % action)
		tween.tween_interval(0.0)
	tween.play()
	return tween.finished

func _anim_fade(tween: Tween, data: Dictionary) -> void:
	tween.tween_property(self, "modulate:a", 1.0, 0.2).from(0.0)


#endregion



enum SortLayer { TILE = 0, Element = 200 }
const LAYER_SIZE = 100
const MAX_MAP_HEIGHT = 5000.0


func _set_z_index(sort_layer: SortLayer):
	var y_offset = int((global_position.y / MAX_MAP_HEIGHT) * (LAYER_SIZE - 1))
	sprite2D.z_index = int(sort_layer) + clamp(y_offset, 0, LAYER_SIZE - 1)
