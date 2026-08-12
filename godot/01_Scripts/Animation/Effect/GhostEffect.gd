# GhostEffect.gd
extends Node2D

@export var delay: float = 2
@export var rise_distance: float = 60
@export var duration: float = 1

func play() -> void:
	var tween := create_tween()
	# TODO: 왜인지 기다리지 못함.
	tween.tween_interval(delay)
	tween.set_parallel(true)
	
	tween.tween_property(self, "position", position + Vector2(0, -rise_distance), duration) \
		.set_trans(Tween.TRANS_QUART) \
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "modulate:a", 0.0, duration)

	tween.finished.connect(queue_free)
