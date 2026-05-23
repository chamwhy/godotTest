extends Node

@onready var anim_player: AnimationPlayer = $"."
@onready var sprite: Sprite2D = $"../PlayerIdle"
@onready var player = get_parent() as Player


func _ready() -> void:
	if player:
		player.animated.connect(_on_animate)

func _on_animate(anim_name: String, data: Dictionary) -> void:
	match anim_name:
		"move":
			var from: Position = data.get("from", Position.ZERO())
			var to: Position = data.get("to", Position.ZERO())
			var vel = to.subtract(from)
			move(1, vel)
		"attack":
			var dir: Position = data.get("dir", Position.ZERO())
			if not dir.is_zero():
				attack(dir)

func move(cnt: int, dir: Position) -> void:
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
	AnimUtil.play_times(anim_player, "walk", cnt)

func attack(dir: Position) -> void:
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
