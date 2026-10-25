extends Element
class_name Trap
## 가시 함정. 들어오는 개체에게 atk(1~3)만큼 피해를 준다. 사라지지 않는다.
## 한 번 먹고 사라지는 것은 함정이 아니라 Chili(칠리)다.

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var atk_pow := 0
#endregion

#region sprite2ds

## 가시 개수 = 피해량. [0] 가시 1, [1] 가시 2, [2] 가시 3
@export var trap_frames: Array[SpriteFrames]

#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = false
	hitable = true
	atk_pow = data.get("atk", 0)

	GridManager.element_entered.connect(_check_pos)

	update_sprite()

func update_sprite() -> void:
	var cnt: int = clampi(atk_pow - 1, 0, trap_frames.size() - 1)
	animSprite2D.sprite_frames = trap_frames[cnt]
	animSprite2D.animation = "default"
	animSprite2D.play()


func _check_pos(pos: Position, elm: Element, tick: int) -> void:
	if not in_map: return   # 맵에서 빠진(해제 대기 중인) 개체는 반응하지 않는다
	if pos.equals(cur_position):
		LogUtil.write("trap check pos", pos.to_str(), elm, tick)
		attack(elm, tick)

func attack(target: Element, tick: int) -> void:
	var new_atk_data = AtkData.new(
		atk_pow,
		cur_position,
		tick,
		false
	)
	if is_instance_valid(target) and target.hitable:
		target.on_hit(new_atk_data)

## 가시는 맞아도 아무 일이 없다
func on_hit(atk_data: AtkData) -> bool:
	return false
