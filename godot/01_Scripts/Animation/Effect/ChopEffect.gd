# ChopEffect.gd
extends Node2D

@onready var sprite = $AnimatedSprite2D

@export var big_color: Color = Color(0.72, 0.1, 0.1)
@export var small_color: Color = Color(0.72, 0.35, 0.35)

func play(power: int) -> void:
	
	if power > 1:
		sprite.modulate = big_color
		visible = true
		sprite.play("chop_big")
	else:
		sprite.modulate = small_color
		visible = true
		sprite.play("chop_small")
	

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("test_x"):
		print("test x")
		sprite.play("chop")

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()  # 재생 끝나면 자동 삭제
