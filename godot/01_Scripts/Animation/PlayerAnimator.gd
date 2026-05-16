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

func move(cnt: int, dir: Position) -> void:
	print(cnt, dir.to_str(), sprite, anim_player)
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
	AnimUtil.play_times(anim_player, "walk", cnt)
	
