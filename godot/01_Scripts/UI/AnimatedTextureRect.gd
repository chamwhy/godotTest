class_name AnimatedTextureRect
extends TextureRect
## AnimatedSprite2D처럼 SpriteFrames를 재생하는 TextureRect.
## 게임 오브젝트용으로 만든 SpriteFrames 리소스를 UI에서 그대로 재사용 가능.

signal animation_finished
signal frame_changed

@export var sprite_frames: SpriteFrames:
	set(value):
		sprite_frames = value
		_update_texture()

@export var animation: StringName = &"default":
	set(value):
		animation = value
		frame = 0
		_update_texture()

@export var autoplay := true
@export var speed_scale := 1.0

var frame := 0:
	set(value):
		if frame == value:
			return
		frame = value
		_update_texture()
		frame_changed.emit()

var _playing := false
var _time := 0.0


func _ready() -> void:
	_update_texture()
	if autoplay:
		play()


func _process(delta: float) -> void:
	if not _playing or sprite_frames == null:
		return
	if not sprite_frames.has_animation(animation):
		return

	var fps := sprite_frames.get_animation_speed(animation) * speed_scale
	if fps <= 0.0:
		return

	_time += delta
	var frame_duration := 1.0 / fps
	while _time >= frame_duration:
		_time -= frame_duration
		_advance_frame()


func play(anim: StringName = &"") -> void:
	if anim != &"":
		animation = anim
	_playing = true
	_time = 0.0


func stop() -> void:
	_playing = false
	frame = 0
	_time = 0.0


func pause() -> void:
	_playing = false


func _advance_frame() -> void:
	var count := sprite_frames.get_frame_count(animation)
	if count == 0:
		return

	if frame + 1 >= count:
		if sprite_frames.get_animation_loop(animation):
			frame = 0
		else:
			_playing = false
			animation_finished.emit()
	else:
		frame += 1


func _update_texture() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(animation):
		texture = null
		return
	if sprite_frames.get_frame_count(animation) == 0:
		texture = null
		return
	texture = sprite_frames.get_frame_texture(animation, frame)
