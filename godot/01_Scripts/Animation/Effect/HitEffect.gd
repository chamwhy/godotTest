## HitEffect.gd
## 사용법: 어떤 Sprite2D/AnimatedSprite2D 에도 붙일 수 있는 범용 피격 이펙트
## Node로 추가하거나 코드에서 직접 호출 가능

extends Node
class_name HitEffect

# ── 설정값 ─────────────────────────────────────────
@export var duration: float = 0.5          # 이펙트 지속 시간 (초)
@export var parry_color: Color = Color.WHITE
@export var hit_color:   Color = Color(1, 0.1, 0.1)   # 빨간색
@export var max_intensity: float = 1

# ── 내부 변수 ───────────────────────────────────────
var _shader_material: ShaderMaterial
var _tween: Tween
var _target: CanvasItem   # Sprite2D, AnimatedSprite2D 등

const SHADER_PATH = "res://02_Material/Shader/hit_effect.gdshader"

# ── 초기화 ──────────────────────────────────────────
func _ready() -> void:
	# 부모가 CanvasItem이면 자동으로 타겟 설정
	if get_parent() is CanvasItem:
		setup(get_parent())

## 외부에서 직접 타겟을 지정할 때 사용
func setup(target: CanvasItem) -> void:
	_target = target
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = load(SHADER_PATH)
	_target.material = _shader_material
	_shader_material.set_shader_parameter("intensity", 0.0)

# ── 공개 API ────────────────────────────────────────

## 패링 (흰색)
func play_parry() -> void:
	_play(parry_color)

## 피격 (빨간색)
func play_hit() -> void:
	_play(hit_color)

## 커스텀 색상
func play_custom(color: Color) -> void:
	_play(color)

# ── 내부 로직 ────────────────────────────────────────
func _play(color: Color) -> void:
	if not _target:
		push_error("HitEffect: target이 설정되지 않았습니다. setup()을 먼저 호출하세요.")
		return
	
	# 이전 트윈이 실행 중이면 즉시 중단
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_shader_material.set_shader_parameter("hit_color", color)
	_shader_material.set_shader_parameter("intensity", max_intensity)
	
	_tween = get_tree().create_tween()
	_tween.tween_method(
		_set_intensity,
		max_intensity, 0.0,
		duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _set_intensity(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("intensity", value)
