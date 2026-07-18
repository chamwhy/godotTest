extends Element
class_name Trap

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var atk_pow := 0
var is_once := false
var traped := false
#endregion

#region sprite2ds

@export var trap_frames: Array[SpriteFrames]
@export var once_trap_frames: Array[SpriteFrames]

#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = true
	atk_pow = data.get("atk", 0)
	is_once = data.get("once", false)
	
	InGameManager.element_passed.connect(_check_pos)
	InGameManager.element_entered.connect(_check_pos)
	
	# TODO: 상태에 따른 이미지 업데이트
	update_sprite()

func update_sprite() -> void:
	var cnt: int = atk_pow-1
	if is_once:
		cnt = min(cnt, once_trap_frames.size()-1)
		animSprite2D.sprite_frames = once_trap_frames[cnt]
	else:
		cnt = min(cnt, trap_frames.size()-1)
		animSprite2D.sprite_frames = trap_frames[cnt]
	animSprite2D.animation = "default"
	animSprite2D.play()


func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	if not traped and pos.equals(cur_position):
		attack(elm, tick)
		if is_once:
			destroy_trap(tick)

func attack(target: Element, tick: int) -> void:
	var new_atk_data = AtkData.new(
		atk_pow,
		cur_position,
		tick,
		false
	)
	if is_instance_valid(target) and target.hitable:
		target.on_hit(new_atk_data)

func on_hit(atk_data: AtkData) -> bool:
	if not is_once: return false
	destroy_trap(atk_data.tick)
	return true


func destroy_trap(tick: int) -> void:
	InGameManager.exit_element(self, cur_position, tick)
	traped = true
	visible = false


func save_undo_state() -> Dictionary:
	var dict = super.save_undo_state()
	dict["traped"] = traped
	return dict

## save_undo_state()가 반환한 Dictionary로 논리 상태를 복원한다.
## 서브클래스는 super.apply_undo(state)를 먼저 호출한 뒤 추가 처리한다.
func apply_undo(state: Dictionary) -> void:
	super.apply_undo(state)
	traped = state.get("traped", false)
