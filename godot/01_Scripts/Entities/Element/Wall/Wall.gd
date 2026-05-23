extends Element
class_name Wall

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var destroyable := false
var min_atk := 0
#endregion

#region sprites

@export var wall_texture: Texture2D
@export var destroyable_wall_textures: Array[Texture2D]

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
		sprite2D.texture = wall_texture
	else:
		sprite2D.texture = destroyable_wall_textures[min(min_atk-1, destroyable_wall_textures.size()-1)]


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
	

# [변경] queue_free → hide_for_undo
func destroy_wall(tick: int) -> void:
	# 파괴 애니메이션이 있다면 AnimUnit(undo_action="") 으로 등록
	# undo_action="" → Undo 시 역산 애니메이션 없음
	# 대신 apply_undo 에서 show() 를 호출하면 "펑" 같은 재생성 이펙트를 넣을 수 있음
	AnimationQueue.add_anim_unit(AnimationQueue.AnimUnit.new(
		self,
		"destroy",   # 파괴 이펙트 (on_animate에서 구현)
		{},
		"",          # ← Undo 시 역산 애니메이션 없음 (재생성 이펙트는 apply_undo에서)
		{}
	), tick)
	hide_for_undo(tick)
 
 
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
 
func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)  # position, visible, is_block, hitable 복원
	destroyable = state["destroyable"]
	min_atk     = state["min_atk"]
	update_sprite()
	# TODO: 재생성 이펙트 (예: "펑" 파티클) 여기서 재생
