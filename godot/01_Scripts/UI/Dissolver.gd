extends Sprite2D
class_name Dissolver

@onready var mat = material as ShaderMaterial

func _ready():
	# 게임 시작 시 GlobalDissolve(싱글톤 이름)에 자신을 등록
	UiManager.dissolver = self

func dissolve_out(duration: float):
	# 지정된 시간 동안 value를 0에서 1로 (사라지기)
	var tween = create_tween()
	tween.tween_property(material, "shader_parameter/progress", 1.0, 1.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func dissolve_in(duration: float):
	# 지정된 시간 동안 value를 1에서 0으로 (나타나기)
	var tween = create_tween()
	tween.tween_property(material, "shader_parameter/progress", 0.0, 1.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
