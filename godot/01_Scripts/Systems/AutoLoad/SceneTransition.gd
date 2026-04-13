# ScreenTransition.gd — Autoload (싱글톤)으로 등록
extends CanvasLayer

signal transition_finished

@export var duration_out : float = 0.6
@export var duration_in  : float = 0.6
@export var max_pixel_size : float = 32.0

@onready var rect   = $ColorRect
@onready var tween  : Tween
var mat : ShaderMaterial

func _ready():
	mat = rect.material as ShaderMaterial
	rect.visible = false

# 외부에서 호출: await Transition.change_scene("res://scenes/Next.tscn")
func change_scene(path: String):
	await fade_out()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame  # 씬 로드 대기
	await fade_in()
	emit_signal("transition_finished")

func fade_out():
	rect.visible = true
	mat.set_shader_parameter("pixel_size", 1.0)
	mat.set_shader_parameter("fade_amount", 0.0)
	
	if tween: tween.kill()
	tween = create_tween().set_parallel(true)
	
	# 픽셀 커지면서
	tween.tween_method(
		_set_pixel, 1.0, max_pixel_size, duration_out
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# 동시에 검정으로 fade
	tween.tween_method(
		_set_fade, 0.0, 1.0, duration_out
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	await tween.finished

func fade_in():
	mat.set_shader_parameter("pixel_size", max_pixel_size)
	mat.set_shader_parameter("fade_amount", 1.0)
	
	if tween: tween.kill()
	tween = create_tween().set_parallel(true)
	
	# 픽셀 작아지면서
	tween.tween_method(
		_set_pixel, max_pixel_size, 1.0, duration_in
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 동시에 fade in
	tween.tween_method(
		_set_fade, 1.0, 0.0, duration_in
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	await tween.finished
	rect.visible = false

func _set_pixel(v: float): mat.set_shader_parameter("pixel_size", v)
func _set_fade(v:  float): mat.set_shader_parameter("fade_amount", v)
