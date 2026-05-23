# ChopEffect.gd
extends Node2D

@onready var sprite = $AnimatedSprite2D

func play() -> void:
	print("play")
	visible = true
	sprite.play("chop")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("test_x"):
		print("test x")
		sprite.play("chop")

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()  # 재생 끝나면 자동 삭제
