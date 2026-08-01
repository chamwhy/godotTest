class_name EffectUtil

#region chopEffect
const CHOP_EFFECT_SCENE = preload("res://04_Scenes/Effect/ChopEffect.tscn")

## 방향별 설정: rotation_degrees, flip_h, flip_v
## Position → rotation/flip 매핑
## 기본 스프라이트 방향: 아래→위 (UP)
const DIR_CONFIG = {
	"up":    { "rot": -90,   "flip_h": true, "flip_v": false },
	"down":  { "rot": 90,   "flip_h": true, "flip_v": false  },
	"left":  { "rot": 0, "flip_h": false, "flip_v": false },
	"right": { "rot": 0,  "flip_h": true, "flip_v": false },
}

static func spawn_chop(tree: SceneTree, target_position: Position, dir: Position, power: int) -> void:
	var world_pos: Vector2 = Position.position_to_world(target_position)
	var dir_key: String    = _dir_to_key(dir)
	
	var fx: Node2D = CHOP_EFFECT_SCENE.instantiate()
	tree.current_scene.add_child(fx)
	fx.global_position = world_pos
	
	var cfg = DIR_CONFIG[dir_key]
	fx.rotation_degrees = cfg["rot"]
	
	var sprite: AnimatedSprite2D = fx.get_node("AnimatedSprite2D")
	sprite.flip_h = cfg["flip_h"]
	sprite.flip_v = cfg["flip_v"]
	
	fx.play(power)

## Position → "up" / "down" / "left" / "right"
static func _dir_to_key(dir: Position) -> String:
	# Position이 어떤 API를 쓰는지 몰라서 두 가지 방식 모두 적어둠
	# → 네 Position 구현에 맞게 하나만 남겨줘

	# 방식 A: x/y 프로퍼티가 있을 때
	if   dir.y < 0: return "up"
	elif dir.y > 0: return "down"
	elif dir.x < 0: return "left"
	elif dir.x > 0: return "right"
	
	push_warning("EffectUtil: zero 방향이 들어왔습니다")
	return "up"
#endregion
