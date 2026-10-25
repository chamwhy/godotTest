extends Element
class_name Obstacle
## 부술 수 있는 장애물. 벽처럼 막지만 min_atk 이상의 힘으로 맞으면 부서진다.
##   ma 1 = 항아리 (평온의 힘 1로도 깨짐)
##   ma 2 = 기둥   (화남·격노의 힘 2가 있어야 깨짐)
## 공격력 최댓값이 2라서 ma는 1·2만 의미가 있다.

#region element 별 특성
#@export var is_block: bool = false  # 막힘 판정 여부
#@export var hitable: bool = true
var min_atk := 1
#endregion

#region sprites

## [0] 항아리(ma 1), [1] 기둥(ma 2)
@export var obstacle_frames: Array[SpriteFrames]
## obstacle_frames와 같은 순서
@export var destroy_audio: Array[String]

#endregion


func apply_data(data: Dictionary) -> void:
	super.apply_data(data)
	is_block = true
	hitable = true
	min_atk = maxi(1, int(data.get("ma", 1)))
	update_sprite()

func update_sprite() -> void:
	animSprite2D.sprite_frames = obstacle_frames[min(min_atk - 1, obstacle_frames.size() - 1)]
	animSprite2D.animation = "default"
	animSprite2D.play()

func on_hit(atk_data: AtkData) -> bool:
	if atk_data.dmg < min_atk:
		ActionManager.record_new(self, atk_data.tick, "on_parryed")
		return false
	destroy_obstacle(atk_data.tick)
	return true

# hide_for_undo만 남김 (vanish가 소멸 연출 담당)
func destroy_obstacle(tick: int) -> void:
	hide_for_undo(tick)

#@override
func _anim_vanish(tween: Tween, data: Dictionary) -> void:
	AudioManager.play_sfx(destroy_audio[min(min_atk - 1, destroy_audio.size() - 1)])
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		hide()
		modulate.a = 1.0   # 알파는 원복해두고 visible로만 제어
	)
