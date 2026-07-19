# PlayerAnimator.gd
extends AnimatedSprite2D
class_name PlayerAnimator

@onready var player = get_parent() as Player

@export var frame1: SpriteFrames
@export var frame2: SpriteFrames
@export var frame3: SpriteFrames

var look_r := true

func _ready() -> void:
	if player:
		player.animated.connect(_on_animate)
		player.player_emotion_changed.connect(_on_emotion_changed)

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

func _on_emotion_changed(emotion: Player.PlayerEmotion) -> void:
	if emotion == Player.PlayerEmotion.CALM:
		sprite_frames = frame1
	elif emotion == Player.PlayerEmotion.ANGRY:
		sprite_frames = frame2
	elif emotion == Player.PlayerEmotion.RAGE:
		sprite_frames = frame3
	self.animation = "default"
	self.play()


func set_look(look_right: bool) -> void:
	look_r = look_right
	flip_h = not look_r

func move(cnt: int, dir: Position) -> void:
	if dir.x != 0:
		set_look(dir.x > 0)

func attack(dir: Position) -> void:
	if dir.x != 0:
		set_look(dir.x > 0)
	# 공격 애니메이션이 있다면: _play_times("attack", 1)
