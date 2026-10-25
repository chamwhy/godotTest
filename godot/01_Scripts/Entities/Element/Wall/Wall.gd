extends Element
class_name Wall
## 부서지지 않는 벽. 어떤 힘으로 때려도 튕겨 낸다.
## 부술 수 있는 것(항아리·기둥)은 벽이 아니라 Obstacle(장애물)이다.

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
#endregion

#region sprites

@export var random_wall_frames: Array[SpriteFrames]

#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true
	hitable = true
	update_sprite()

func update_sprite() -> void:
	var rand_frame: SpriteFrames = random_wall_frames[randi() % random_wall_frames.size()]
	animSprite2D.sprite_frames = rand_frame
	animSprite2D.animation = "default"
	animSprite2D.play()

func on_hit(atk_data: AtkData) -> bool:
	ActionManager.record_new(self, atk_data.tick, "on_parryed")
	return false
