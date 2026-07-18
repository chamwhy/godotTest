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

#endregion

const Wall_Ratio := 0.4

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
		if randf() < Wall_Ratio:
			var rand_frame: SpriteFrames = random_wall_frames[randi() % random_wall_frames.size()]
			animSprite2D.sprite_frames = rand_frame
	else:
		animSprite2D.sprite_frames = destroyable_wall_frames[min(min_atk-1, destroyable_wall_frames.size()-1)]
	animSprite2D.animation = "default"
	animSprite2D.play()

func on_hit(atk_data: AtkData) -> bool:
	if not destroyable or min_atk > atk_data.dmg: 
		AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(
			self,
			"on_parryed",{},"",{}
		), atk_data.tick)
		return false
	AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(
		self,
		"on_damaged",{},"",{}
	), atk_data.tick)
	destroy_wall(atk_data.tick)
	return true

# Wall.gd
func destroy_wall(tick: int) -> void:
	# on_damaged 이펙트는 on_hit에서 이미 등록됨
	hide_for_undo(tick)   # exit + vanish 등록, undo 시 respawn 자동 재생

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
