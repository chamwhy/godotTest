extends Element
class_name Wall

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var destroyable := false
var min_atk := 0
#endregion

#region sprites

@export var random_wall_frames: Array[SpriteFrames]
@export var destroyable_wall_frames: Array[SpriteFrames]
@export var destroy_audio: Array[String]

#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true
	hitable = true
	min_atk = data.get("ma", 0)
	destroyable = min_atk != 0
	# TODO: 상태에 따른 이미지 업데이트
	update_sprite()

func update_sprite() -> void:
	if not destroyable:
		var rand_frame: SpriteFrames = random_wall_frames[randi() % random_wall_frames.size()]
		animSprite2D.sprite_frames = rand_frame
	else:
		animSprite2D.sprite_frames = destroyable_wall_frames[min(min_atk-1, destroyable_wall_frames.size()-1)]
	animSprite2D.animation = "default"
	animSprite2D.play()

func on_hit(atk_data: AtkData) -> bool:
	if not destroyable or min_atk > atk_data.dmg: 
		ActionManager.record_new(self, atk_data.tick, "on_parryed")
		return false
	destroy_wall(atk_data.tick)
	return true

# Wall.gd — destroy_wall: hide_for_undo만 남김 (vanish가 소멸 연출 담당)
func destroy_wall(tick: int) -> void:
	hide_for_undo(tick)

func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	destroyable = state["destroyable"]
	min_atk     = state["min_atk"]
	# update_sprite() 제거 — destroyable/min_atk는 턴 중에 안 변하므로 불필요
	# (남겨두면 non-destroyable 벽이 undo마다 randf로 스프라이트가 바뀜)
 
# ─────────────────────────────────────────────
# Undo 상태 저장/복원
# ─────────────────────────────────────────────
func save_undo_state() -> Dictionary:
	var state := super.save_undo_state()
	state.merge({
		"destroyable": destroyable,
		"min_atk":     min_atk,
	})
	return state

#@override
func _anim_vanish(tween: Tween, data: Dictionary) -> void:
	AudioManager.play_sfx(destroy_audio[min_atk-1])
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		hide()
		modulate.a = 1.0   # 알파는 원복해두고 visible로만 제어
	)
